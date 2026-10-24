class_name AbilityManager
extends Node
## Scene-scoped ability caster. Cooldown truth lives here and ticks on the
## physics clock; effects are resolved through a small, readable registry.

signal abilities_changed

var player: Node = null
var abilities: Array[AbilityData] = []
var ultimate: AbilityData = null
var cooldowns: Array[float] = [0.0, 0.0, 0.0]
var enabled: bool = true
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	set_physics_process(false)


func setup(p_player: Node, loadout: Array[StringName], ultimate_id: StringName = &"") -> void:
	player = p_player
	abilities.clear()
	for id in loadout:
		var data := ContentDB.get_ability(id)
		if data != null and not data.is_ultimate:
			abilities.append(data)
		if abilities.size() >= 2:
			break
	ultimate = ContentDB.get_ability(ultimate_id)
	if ultimate == null or not ultimate.is_ultimate:
		ultimate = null
		if player != null and ContentDB != null:
			ultimate = ContentDB.get_ultimate_for_discipline(ProfileState.get_discipline())
	cooldowns = [0.0, 0.0, 0.0]
	enabled = true
	set_physics_process(true)
	abilities_changed.emit()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not enabled:
		return
	var changed := false
	for i in cooldowns.size():
		if cooldowns[i] > 0.0:
			cooldowns[i] = maxf(0.0, cooldowns[i] - delta)
			if cooldowns[i] == 0.0:
				changed = true
	if changed:
		abilities_changed.emit()
		player.call("update_hud")
	if player.has_method("is_downed") and player.call("is_downed"):
		return
	if Input.is_action_just_pressed("ability_1"):
		cast_ability(0)
	elif Input.is_action_just_pressed("ability_2"):
		cast_ability(1)
	if Input.is_action_just_pressed("ultimate"):
		cast_ability(2)


func get_hud_states() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in 2:
		var data: AbilityData = abilities[i] if i < abilities.size() else null
		result.append(_hud_entry(data, i))
	result.append(_hud_entry(ultimate, 2))
	return result


func _hud_entry(data: AbilityData, slot: int) -> Dictionary:
	if data == null:
		return {"empty": true}
	var total := _effective_cooldown(data)
	return {
		"empty": false,
		"name": data.display_name,
		"description": data.description,
		"icon": String(data.icon),
		"color": data.color,
		"cooldown": cooldowns[slot],
		"cooldown_total": total,
		"ready": cooldowns[slot] <= 0.0,
		"is_ultimate": slot == 2,
		"charges": 1,
	}


func _effective_cooldown(data: AbilityData) -> float:
	var mult := 1.0
	if player != null and player.has_method("get_stat"):
		mult = float(player.call("get_stat", StatKeys.COOLDOWN_MULT, 1.0))
	return maxf(1.5, data.cooldown * mult)


func can_cast(slot: int) -> bool:
	if not enabled or player == null or not is_instance_valid(player):
		return false
	if player.has_method("is_downed") and player.call("is_downed"):
		return false
	if slot < 0 or slot > 2:
		return false
	if cooldowns[slot] > 0.0:
		return false
	var data: AbilityData = ultimate if slot == 2 else (abilities[slot] if slot < abilities.size() else null)
	return data != null


func cast_ability(slot: int) -> bool:
	if not can_cast(slot):
		return false
	var data: AbilityData = ultimate if slot == 2 else abilities[slot]
	cooldowns[slot] = _effective_cooldown(data)
	_execute_effect(data, slot)
	AudioDirector.play_sfx(&"ability", -3.0)
	abilities_changed.emit()
	if player.has_method("update_hud"):
		player.call("update_hud")
	EventBus.notification_requested.emit(data.display_name, data.description, &"ability")
	if player.has_method("add_trauma"):
		player.call("add_trauma", 0.12 if slot == 2 else 0.04)
	return true


func _execute_effect(data: AbilityData, slot: int) -> void:
	match data.effect_id:
		&"blink":
			_effect_blink(data)
		&"deploy_wall":
			_effect_wall(data)
		&"cloak":
			_effect_cloak(data)
		&"overclock":
			_effect_overclock(data)
		&"chain_lightning":
			_effect_chain(data)
		&"gravity_well":
			_effect_gravity(data)
		&"cone_slam":
			_effect_slam(data)
		&"deploy_turret":
			_effect_turret(data, false)
		&"scan":
			_effect_scan(data)
		&"mender_field":
			_effect_mender(data)
		&"barrage":
			_effect_barrage(data)
		&"rewind":
			_effect_rewind(data)
		&"ultimate_iron_tide":
			_effect_iron_tide(data)
		&"ultimate_ghost":
			_effect_ghost(data)
		&"ultimate_siege":
			_effect_turret(data, true)
		&"ultimate_hyperfocus":
			_effect_hyperfocus(data)
		_:
			EventBus.notify("Unknown ability", "No effect registered for " + String(data.effect_id), &"error")


func _effect_blink(data: AbilityData) -> void:
	var forward: Vector3 = player.call("get_forward")
	var origin: Vector3 = player.global_position + Vector3.UP * 0.8
	var distance := maxf(4.0, float(data.magnitude))
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * distance, 1 | 4 | 8)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	var target := origin + forward * distance
	if not hit.is_empty():
		target = hit.position - forward * 0.6
	var finish := Vector3(target.x, player.global_position.y + 0.05, target.z)
	player.call("teleport_to", finish)
	CombatVFX.ring(_fx_parent(), finish, 1.7, data.color, 0.45)
	CombatVFX.beam_burst(_fx_parent(), player.global_position, finish, data.color)
	player.call("set_invulnerable", 0.3)


func _effect_wall(data: AbilityData) -> void:
	var forward: Vector3 = player.call("get_forward")
	var position: Vector3 = player.global_position + forward * 2.6
	_spawn_deployable(&"wall", position, forward, data.duration, data.magnitude, data.color)
	CombatVFX.ring(_fx_parent(), position, 2.4, data.color, 0.4)


func _effect_cloak(data: AbilityData) -> void:
	player.call("set_cloaked", data.duration)
	player.call("apply_temporary_modifier", &"cloak_speed", StatKeys.MOVE_SPEED, &"add", 1.0, data.duration)
	CombatVFX.ring(_fx_parent(), player.global_position, 2.0, data.color, data.duration * 0.5)


func _effect_overclock(data: AbilityData) -> void:
	player.call("set_overclock", data.duration, data.magnitude)
	player.call("apply_temporary_modifier", &"overclock_reload", StatKeys.RELOAD_SPEED, &"mult", 1.25, data.duration)
	player.call("apply_temporary_modifier", &"overclock_handling", StatKeys.HANDLING, &"add", 0.25, data.duration)
	CombatVFX.ring(_fx_parent(), player.global_position, 1.6, data.color, 0.5)


func _effect_chain(data: AbilityData) -> void:
	var targets := _enemies_in_radius(player.global_position, data.range)
	targets = targets.slice(0, maxi(1, data.projectile_count))
	var from: Vector3 = player.call("get_camera_position")
	for enemy in targets:
		var to: Vector3 = (enemy as Node3D).global_position + Vector3.UP
		CombatVFX.beam_burst(_fx_parent(), from, to, data.color)
		_damage_enemy(enemy, data.magnitude, StatKeys.DMG_SHOCK, StatKeys.STATUS_SHOCK)
		from = to


func _effect_gravity(data: AbilityData) -> void:
	var point := _aim_point(data.range)
	var root := Node3D.new()
	_fx_parent().add_child(root)
	root.global_position = point
	CombatVFX.ring(root, point, data.radius, data.color, data.duration)
	CombatVFX.ring(root, point, data.radius * 0.5, data.color, data.duration * 0.7)
	var timer := get_tree().create_timer(data.duration)
	timer.timeout.connect(root.queue_free)
	for enemy in _enemies_in_radius(point, data.radius):
		if enemy.has_method("apply_pull"):
			enemy.call("apply_pull", point, 5.0, data.duration)


func _effect_slam(data: AbilityData) -> void:
	var forward: Vector3 = player.call("get_forward")
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	for enemy in get_tree().get_nodes_in_group("enemy_ai"):
		if not enemy is Node3D:
			continue
		var offset: Vector3 = (enemy as Node3D).global_position - player.global_position
		if offset.length() > data.range:
			continue
		if flat_forward.dot(Vector3(offset.x, 0.0, offset.z).normalized()) < 0.35:
			continue
		CombatVFX.impact(_fx_parent(), (enemy as Node3D).global_position + Vector3.UP, Vector3.UP, data.color)
		_damage_enemy(enemy, data.magnitude, StatKeys.DMG_KINETIC, StatKeys.STATUS_SLOW)
		if enemy.has_method("apply_pull"):
			enemy.call("apply_pull", player.global_position + flat_forward * 4.0, 3.0, 0.7)
	CombatVFX.ring(_fx_parent(), player.global_position + flat_forward * 2.0, data.radius, data.color, 0.5)


func _effect_turret(data: AbilityData, heavy: bool) -> void:
	var forward: Vector3 = player.call("get_forward")
	var aim := _aim_point(12.0)
	var position := aim
	var count := 1
	if heavy:
		count = 2
		player.call("apply_temporary_modifier", &"siege_armor", StatKeys.ARMOR, &"add", 20.0, data.duration)
	for i in count:
		var offset := Vector3(cos(i * TAU / count + 0.4), 0.0, sin(i * TAU / count + 0.4)) * (2.2 if heavy else 0.0)
		_spawn_deployable(&"turret", position + offset, forward, data.duration, data.magnitude * (1.8 if heavy else 1.0), data.color)
	CombatVFX.ring(_fx_parent(), position, 2.0, data.color, 0.55)


func _effect_scan(data: AbilityData) -> void:
	player.call("apply_temporary_modifier", &"scan_crit", StatKeys.CRIT_CHANCE, &"add", 0.1, data.duration)
	var enemies := _enemies_in_radius(player.global_position, data.radius)
	for enemy in enemies:
		if enemy.has_method("set_marked"):
			enemy.call("set_marked", data.duration)
	CombatVFX.ring(_fx_parent(), player.global_position, data.radius, data.color, 0.8)
	EventBus.notify("Pulse Scan", "Marked %d targets." % enemies.size(), &"success")


func _effect_mender(data: AbilityData) -> void:
	var health = player.call("get_health_component")
	if health != null and health.has_method("heal"):
		health.heal(data.magnitude * 2.0)
		health.restore_shield(data.magnitude)
	for node in get_tree().get_nodes_in_group("allies"):
		if node.has_method("heal"):
			node.call("heal", data.magnitude)
	for node in get_tree().get_nodes_in_group("pets"):
		if node.has_method("heal"):
			node.call("heal", data.magnitude)
	CombatVFX.ring(_fx_parent(), player.global_position, data.radius, data.color, data.duration)
	AudioDirector.play_sfx(&"heal", -5.0)


func _effect_barrage(data: AbilityData) -> void:
	var point := _aim_point(data.range)
	var parent := _fx_parent()
	CombatVFX.ring(parent, point, data.radius, data.color, 1.2)
	for i in int(maxi(1, data.projectile_count)):
		var offset := Vector3(rng.randf_range(-data.radius, data.radius), 0.0, rng.randf_range(-data.radius, data.radius))
		var delay := 0.15 + i * 0.18
		_barrage_impact(point + offset, data, delay)


func _barrage_impact(point: Vector3, data: AbilityData, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		return
	CombatUtils.aoe_damage(point, data.radius * 0.55, data.magnitude, StatKeys.TEAM_PLAYER, player, StatKeys.DMG_KINETIC, player.get_world_3d())
	CombatVFX.explosion(_fx_parent(), point, data.radius * 0.55, data.color)
	AudioDirector.play_3d(&"explosion", point, -8.0)


func _effect_rewind(data: AbilityData) -> void:
	var pos: Vector3 = player.call("get_history_position", 3.0)
	player.call("teleport_to", pos)
	var health = player.call("get_health_component")
	if health != null:
		health.heal(health.max_health * 0.3)
	CombatVFX.ring(_fx_parent(), pos, 1.8, data.color, 0.7)
	CombatVFX.beam_burst(_fx_parent(), player.global_position, pos, data.color)


func _effect_iron_tide(data: AbilityData) -> void:
	var health = player.call("get_health_component")
	if health != null:
		health.heal(health.max_health * 0.5)
		health.restore_shield(health.max_shield)
	player.call("set_invulnerable", 2.0)
	player.call("apply_temporary_modifier", &"iron_tide_armor", StatKeys.ARMOR, &"add", 60.0, data.duration)
	for enemy in _enemies_in_radius(player.global_position, data.radius):
		_damage_enemy(enemy, data.magnitude, StatKeys.DMG_KINETIC, StatKeys.STATUS_SLOW)
		if enemy.has_method("apply_pull"):
			enemy.call("apply_pull", player.global_position, 8.0, 1.0)
	CombatVFX.explosion(_fx_parent(), player.global_position, data.radius, data.color)
	CombatVFX.ring(_fx_parent(), player.global_position, data.radius, data.color, 1.2)


func _effect_ghost(data: AbilityData) -> void:
	player.call("set_cloaked", data.duration)
	player.call("apply_temporary_modifier", &"ghost_crit", StatKeys.CRIT_CHANCE, &"add", 0.2, data.duration)
	player.call("apply_temporary_modifier", &"ghost_critdmg", StatKeys.CRIT_MULT, &"add", 0.5, data.duration)
	for ally in get_tree().get_nodes_in_group("allies"):
		if ally.has_method("set_cloaked"):
			ally.call("set_cloaked", data.duration)
	CombatVFX.ring(_fx_parent(), player.global_position, 3.0, data.color, 0.8)


func _effect_hyperfocus(data: AbilityData) -> void:
	player.call("set_hyperfocused", data.duration)
	player.call("apply_temporary_modifier", &"hyperfocus_handling", StatKeys.HANDLING, &"add", 0.5, data.duration)
	player.call("apply_temporary_modifier", &"hyperfocus_crit", StatKeys.CRIT_MULT, &"add", 0.75, data.duration)
	CombatVFX.ring(_fx_parent(), player.global_position, 2.0, data.color, 0.9)


func _spawn_deployable(mode: StringName, position: Vector3, forward: Vector3, lifetime: float, damage: float, color: Color) -> void:
	var parent := _fx_parent()
	var deployable := AbilityDeployable.new()
	parent.add_child(deployable)
	deployable.setup(mode, player, position, forward, lifetime, damage, color)


func _damage_enemy(enemy: Node, amount: float, damage_type: StringName = StatKeys.DMG_KINETIC, status: StringName = StatKeys.STATUS_NONE) -> void:
	var health := CombatUtils.find_health(enemy)
	if health == null or health.dead:
		return
	var data := DamageData.make(amount, StatKeys.TEAM_PLAYER, damage_type, player)
	data.status_type = status
	data.status_power = 1.0
	data.status_duration = 2.0
	data.hit_position = (enemy as Node3D).global_position + Vector3.UP if enemy is Node3D else player.global_position
	health.take_damage(data)


func _enemies_in_radius(center: Vector3, radius: float) -> Array:
	var result: Array = []
	for enemy in get_tree().get_nodes_in_group("enemy_ai"):
		if not enemy is Node3D or not is_instance_valid(enemy):
			continue
		var health := CombatUtils.find_health(enemy)
		if health == null or health.dead:
			continue
		if center.distance_to((enemy as Node3D).global_position) <= radius:
			result.append(enemy)
	result.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return center.distance_squared_to(a.global_position) < center.distance_squared_to(b.global_position)
	)
	return result


func _aim_point(max_range: float) -> Vector3:
	var origin: Vector3 = player.call("get_camera_position")
	var forward: Vector3 = player.call("get_forward")
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * max_range, 1 | 4 | 8)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.position
	return origin + forward * max_range


func _fx_parent() -> Node3D:
	if player != null and player.has_method("get_effect_parent"):
		var parent = player.call("get_effect_parent")
		if parent is Node3D:
			return parent
	return get_tree().current_scene as Node3D

