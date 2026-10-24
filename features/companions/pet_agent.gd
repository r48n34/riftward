class_name PetAgent
extends Node3D
## Floating Driftling companion. Charming, non-blocking support creature:
##  - follows the player with a springy float and teleports if left > 30m behind
##  - "mote"  : periodically restores shield/health
##  - "cinder": periodic plasma bolt at the nearest enemy (<= 20m)
##  - "pip"   : periodic scan that marks nearby enemies / reveals loot
##  - can be temporarily disabled (self-repairs) and cloaked for Ghost Protocol
## It never blocks the player: the node has no collision body.

signal ability_used(effect: StringName)
signal disabled_changed(is_disabled: bool)
signal cloaked_changed(is_cloaked: bool)

const Visuals := preload("res://features/companions/companion_visuals.gd")

const TEAM: StringName = StatKeys.TEAM_FRIENDLY
const ENEMY_MASK := 1 | 4
const TELEPORT_DISTANCE := 30.0
const DISABLED_TIME := 6.0
const DEFAULT_COOLDOWN := 3.0

var data: PetData = null
var player: Node = null
var rank: int = 1
var effect: StringName = &"mote_shield"

var _applied: bool = false
var _health: HealthComponent = null
var _visual: Node3D = null
var _wing_l: Node3D = null
var _wing_r: Node3D = null
var _wing_base_l: Vector3 = Vector3.ZERO
var _wing_base_r: Vector3 = Vector3.ZERO
var _mote_ring: Node3D = null
var _light: OmniLight3D = null
var _beam: MeshInstance3D = null
var _halo: MeshInstance3D = null
var _nameplate: Label3D = null
var _effects_root: Node3D = null

var _float_velocity: Vector3 = Vector3.ZERO
var _bob_time: float = 0.0
var _ability_timer: float = 5.0
var _attack_timer: float = 0.5
var _target_retry: float = 0.0
var _recent_target: Node = null

var _disabled: bool = false
var _disabled_timer: float = 0.0
var _cloaked: bool = false
var _cloak_timer: float = 0.0


func _ready() -> void:
	add_to_group("pets")
	add_to_group("friendly")
	if data != null:
		_apply_setup()


func setup(p_data: PetData, p_player: Node, p_rank: int = 1) -> void:
	data = p_data
	player = p_player
	rank = clampi(p_rank, 1, 5)
	if is_inside_tree():
		_apply_setup()


func _apply_setup() -> void:
	if _applied:
		return
	_applied = true
	add_to_group("pets")
	add_to_group("friendly")
	if data == null:
		data = PetData.new()
		data.id = &"mote"
		data.display_name = "Driftling"
		data.role = &"support"
		data.effect = &"mote_shield"
	effect = data.effect
	if effect == &"":
		match data.id:
			&"cinder":
				effect = &"cinder_bolt"
			&"pip":
				effect = &"pip_scan"
			_:
				effect = &"mote_shield"
	_build_health()
	_build_visual()
	_resolve_effects_root()
	_ability_timer = randf_range(2.0, 5.0)
	_attack_timer = randf_range(0.6, 1.4)
	if _has_player():
		global_position = _anchor_position()


func _build_health() -> void:
	if _health != null:
		return
	_health = HealthComponent.new()
	_health.name = "PetHealth"
	add_child(_health)
	_health.configure(60.0 + 15.0 * float(rank - 1), 0.0, 0.0, TEAM)
	_health.died.connect(_on_health_died)


func _build_visual() -> void:
	var kit: Dictionary = Visuals.build_driftling(data)
	_visual = kit["root"] as Node3D
	add_child(_visual)
	_wing_l = kit["wing_l"] as Node3D
	_wing_r = kit["wing_r"] as Node3D
	_wing_base_l = kit["wing_base_l"]
	_wing_base_r = kit["wing_base_r"]
	_mote_ring = kit["mote_ring"] as Node3D
	_light = kit["light"] as OmniLight3D
	_beam = kit["beam"] as MeshInstance3D
	_halo = kit["halo"] as MeshInstance3D
	_nameplate = kit["nameplate"] as Label3D


func _resolve_effects_root() -> void:
	if _effects_root != null and is_instance_valid(_effects_root):
		return
	if _has_player() and player.has_method("get_effect_parent"):
		var effects = player.call("get_effect_parent")
		if effects is Node3D and is_instance_valid(effects):
			_effects_root = effects as Node3D
			return
	var parent := get_parent()
	if parent is Node3D:
		_effects_root = parent as Node3D


func _effects() -> Node3D:
	if _effects_root != null and is_instance_valid(_effects_root):
		return _effects_root
	var parent := get_parent()
	if parent is Node3D:
		_effects_root = parent as Node3D
		return _effects_root
	return self


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func get_pet_data() -> PetData:
	return data


func get_display_name() -> String:
	return data.display_name if data != null else "Driftling"


func get_rank() -> int:
	return rank


func get_health_component() -> HealthComponent:
	return _health


func get_player() -> Node:
	return player if player != null and is_instance_valid(player) else null


func is_disabled() -> bool:
	return _disabled


func is_cloaked() -> bool:
	return _cloaked


func set_nameplate_visible(is_visible: bool) -> void:
	if _nameplate != null:
		_nameplate.visible = is_visible


## Used by Mender field / medic support effects. Repairs the Driftling itself.
func heal(amount: float) -> void:
	if _health == null or amount <= 0.0:
		return
	if _health.dead:
		_recover()
		return
	_health.heal(amount)
	_pulse_visual(data.color if data != null else Visuals.MINT)


## Brief malfunction: the Driftling drops, then self-repairs. Never permanent.
func disable(duration: float = DISABLED_TIME) -> void:
	if _disabled:
		return
	_disabled = true
	_disabled_timer = maxf(0.4, duration)
	_refresh_visibility()
	if _light != null:
		_light.light_energy = 0.0
	CombatVFX.impact(_effects(), global_position, Vector3.UP, Color("ff6e6e"))
	AudioDirector.play_3d(&"hit", global_position, -12.0)
	disabled_changed.emit(true)


func set_cloaked(duration: float) -> void:
	_cloak_timer = maxf(_cloak_timer, maxf(0.0, duration))
	if _cloak_timer > 0.0 and not _cloaked:
		_cloaked = true
		_refresh_visibility()
		cloaked_changed.emit(true)


func can_act() -> bool:
	return _applied and not _disabled and not _cloaked and _health != null and not _health.dead


func get_status() -> Dictionary:
	return {
		"id": String(data.id) if data != null else "",
		"name": get_display_name(),
		"role": String(data.role) if data != null else "support",
		"effect": String(effect),
		"rank": rank,
		"disabled": _disabled,
		"cloaked": _cloaked,
		"health": _health.health if _health != null else 0.0,
		"max_health": _health.max_health if _health != null else 0.0,
	}


## Debug/test hook: immediately performs this Driftling's role effect.
func force_ability() -> bool:
	if not can_act():
		return false
	match effect:
		&"mote_shield":
			return _use_mote()
		&"cinder_bolt":
			return _use_cinder()
		&"pip_scan":
			return _use_pip()
		_:
			return _use_mote()


# ---------------------------------------------------------------------------
# Floating follow / animation
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _applied or _visual == null:
		return
	_bob_time += delta
	_update_float(delta)
	_update_animation(delta)


func _update_float(delta: float) -> void:
	if _has_player() and not _disabled:
		var anchor := _anchor_position()
		var displacement := anchor - global_position
		_float_velocity += displacement * 30.0 * delta
		_float_velocity *= maxf(0.0, 1.0 - 7.5 * delta)
		global_position += _float_velocity * delta
		if global_position.distance_to(anchor) > TELEPORT_DISTANCE:
			global_position = anchor
			_float_velocity = Vector3.ZERO
	elif not _has_player():
		_float_velocity = _float_velocity.lerp(Vector3.ZERO, minf(1.0, delta * 2.0))
		global_position += Vector3(0.0, sin(_bob_time * 1.9) * 0.1 * delta, 0.0)
	var look := Vector3(_float_velocity.x, 0.0, _float_velocity.z)
	if look.length() < 0.35 and _has_player():
		look = _player_forward()
	if look.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-look.x, -look.z), 1.0 - exp(-6.0 * delta))


func _update_animation(delta: float) -> void:
	_visual.position.y = sin(_bob_time * 2.4) * 0.07
	_visual.rotation.x = sin(_bob_time * 1.7) * 0.055
	_visual.rotation.z = sin(_bob_time * 1.3) * 0.04
	if _wing_l != null:
		_wing_l.rotation.z = _wing_base_l.z + sin(_bob_time * 13.0) * 0.42
	if _wing_r != null:
		_wing_r.rotation.z = _wing_base_r.z - sin(_bob_time * 13.0) * 0.42
	if _mote_ring != null:
		_mote_ring.rotation.y += delta * 1.7
		_mote_ring.rotation.x = sin(_bob_time * 1.1) * 0.3
	if _halo != null:
		_halo.rotation.y += delta * 0.9
	if _light != null and not _disabled and not _cloaked:
		_light.light_energy = 0.85 + sin(_bob_time * 3.1) * 0.15


# ---------------------------------------------------------------------------
# Role effects
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _applied:
		return
	if _cloaked:
		_cloak_timer = maxf(0.0, _cloak_timer - delta)
		if _cloak_timer <= 0.0:
			_cloaked = false
			_refresh_visibility()
			cloaked_changed.emit(false)
	if _disabled:
		_disabled_timer = maxf(0.0, _disabled_timer - delta)
		if _disabled_timer <= 0.0:
			_recover()
		return
	if not can_act():
		return
	_target_retry = maxf(0.0, _target_retry - delta)
	match effect:
		&"mote_shield":
			_tick_mote(delta)
		&"cinder_bolt":
			_tick_cinder(delta)
		&"pip_scan":
			_tick_pip(delta)


func _tick_mote(delta: float) -> void:
	_ability_timer = maxf(0.0, _ability_timer - delta)
	if _ability_timer > 0.0:
		return
	_ability_timer = maxf(2.0, float(data.cooldown)) if data != null else 14.0
	if not _use_mote():
		_ability_timer = 2.5


func _use_mote() -> bool:
	var health := _player_health()
	if health == null or health.dead:
		return false
	var missing_health := health.max_health - health.health
	var missing_shield := 0.0
	if health.max_shield > 0.0:
		missing_shield = health.max_shield - health.shield
	if missing_health <= 0.5 and missing_shield <= 0.5:
		return false
	var magnitude := _magnitude()
	var restored := health.restore_shield(magnitude)
	var healed := 0.0
	if restored < magnitude * 0.5:
		healed = health.heal(magnitude * 0.5)
	var accent: Color = data.color if data != null else Visuals.MINT
	CombatVFX.ring(_effects(), _player_position() + Vector3.UP * 0.3, 1.8, accent, 0.75)
	_pulse_visual(accent)
	AudioDirector.play_3d(&"heal", _player_position(), -10.0)
	ability_used.emit(&"mote_shield")
	return healed > 0.0 or restored > 0.0


func _tick_cinder(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	if _attack_timer > 0.0:
		return
	_attack_timer = maxf(1.2, float(data.cooldown)) if data != null else 3.0
	if not _use_cinder():
		_attack_timer = 0.6


func _use_cinder() -> bool:
	var target := _nearest_enemy(20.0)
	if target == null:
		return false
	var origin := global_position + Vector3(0.0, 0.05, 0.0)
	var aim := _aim_point(target)
	var direction := (aim - origin)
	if direction.length_squared() < 0.01:
		return false
	direction = direction.normalized()
	var spread := maxf(0.03, 0.06 + origin.distance_to(aim) * 0.01)
	aim += Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))
	direction = (origin.direction_to(aim))
	var ray_start := origin + direction * 0.2
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_start + direction * 24.0, ENEMY_MASK)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end_point := ray_start + direction * 20.0
	if not hit.is_empty():
		end_point = hit["position"]
		var collider = hit["collider"]
		var health := CombatUtils.find_health(collider)
		if health != null and not health.dead and health.team != TEAM:
			var damage_data := DamageData.make(_magnitude() * 0.85, TEAM, StatKeys.DMG_ENERGY, self)
			damage_data.hit_position = end_point
			damage_data.hit_normal = hit["normal"]
			damage_data.status_type = StatKeys.STATUS_BURN
			damage_data.status_power = 0.6
			damage_data.status_duration = 2.0
			CombatUtils.apply_hit(collider, damage_data, int(hit.get("shape", -1)))
			CombatVFX.impact(_effects(), end_point, hit["normal"], Color("ffb866"))
	var accent: Color = data.color if data != null else Visuals.AMBER
	CombatVFX.spawn_tracer(_effects(), origin, end_point, accent)
	CombatVFX.muzzle_flash(_effects(), origin, accent)
	_pulse_visual(accent)
	AudioDirector.play_3d(&"shot_arc", origin, -17.0)
	ability_used.emit(&"cinder_bolt")
	return true


func _tick_pip(delta: float) -> void:
	_ability_timer = maxf(0.0, _ability_timer - delta)
	if _ability_timer > 0.0:
		return
	_ability_timer = maxf(3.0, float(data.cooldown)) if data != null else 12.0
	if not _use_pip():
		_ability_timer = 2.5


func _use_pip() -> bool:
	var radius := _magnitude()
	var marked := 0
	for node in get_tree().get_nodes_in_group("enemy_ai"):
		if marked >= 10:
			break
		if node == null or not is_instance_valid(node) or not (node is Node3D):
			continue
		if global_position.distance_to((node as Node3D).global_position) > radius:
			continue
		if _is_dead(node):
			continue
		if node.has_method("set_marked"):
			node.call("set_marked", 8.0)
			marked += 1
	var revealed := 0
	for group_name in ["loot", "loot_drop", "pickups", "pickup"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node == null or not is_instance_valid(node) or not (node is Node3D):
				continue
			if global_position.distance_to((node as Node3D).global_position) > radius:
				continue
			if node.has_method("reveal"):
				node.call("reveal", 8.0)
				revealed += 1
			elif node.has_method("set_marked"):
				node.call("set_marked", 8.0)
				revealed += 1
	if marked == 0 and revealed == 0:
		return false
	if _beam != null:
		_beam.visible = true
		var beam_tween := create_tween()
		beam_tween.tween_interval(0.45)
		beam_tween.tween_callback(_hide_beam)
	var accent: Color = data.color if data != null else Visuals.BLUE
	CombatVFX.ring(_effects(), global_position, 3.4, accent, 0.8)
	AudioDirector.play_3d(&"scan", global_position, -13.0)
	if marked > 0:
		EventBus.notify("Pip", "%d signature(s) marked within %dm." % [marked, int(radius)], &"scan")
	ability_used.emit(&"pip_scan")
	return true


func _hide_beam() -> void:
	if _beam != null and is_instance_valid(_beam):
		_beam.visible = false


func _pulse_visual(color: Color) -> void:
	if _visual == null:
		return
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE * 1.22, 0.1)
	tween.tween_property(_visual, "scale", Vector3.ONE, 0.22)
	if _light != null:
		var base_energy := _light.light_energy
		_light.light_energy = 2.4
		_light.light_color = color
		var light_tween := create_tween()
		light_tween.tween_property(_light, "light_energy", base_energy, 0.4)


# ---------------------------------------------------------------------------
# Damage / disabled / cloak
# ---------------------------------------------------------------------------

func _on_health_died() -> void:
	disable(DISABLED_TIME)


func _recover() -> void:
	if not _disabled:
		return
	_disabled = false
	_disabled_timer = 0.0
	if _health != null:
		_health.reset_full()
	_refresh_visibility()
	if _light != null:
		_light.light_energy = 1.0
	CombatVFX.ring(_effects(), global_position, 1.4, Visuals.MINT, 0.6)
	AudioDirector.play_3d(&"ability_ready", global_position, -14.0)
	disabled_changed.emit(false)


func _refresh_visibility() -> void:
	if _visual == null:
		return
	_visual.visible = not (_disabled or _cloaked)
	if _light != null:
		_light.visible = not (_disabled or _cloaked)


func _nearest_enemy(max_distance: float) -> Node:
	var best: Node = null
	var best_distance := max_distance
	if _recent_target != null and is_instance_valid(_recent_target) and not _is_dead(_recent_target) and _recent_target is Node3D:
		if global_position.distance_to((_recent_target as Node3D).global_position) <= max_distance:
			if _has_los(_recent_target):
				return _recent_target
	_recent_target = null
	for node in get_tree().get_nodes_in_group("enemy_ai"):
		if node == null or not is_instance_valid(node) or not (node is Node3D):
			continue
		if _is_dead(node):
			continue
		var distance := global_position.distance_to((node as Node3D).global_position)
		if distance > best_distance:
			continue
		if not _has_los(node):
			continue
		best_distance = distance
		best = node
	_recent_target = best
	return best


func _has_los(target: Node) -> bool:
	if target == null or not is_instance_valid(target) or not (target is Node3D):
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position, _aim_point(target), ENEMY_MASK)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var health := CombatUtils.find_health(hit["collider"])
	return health != null and health.team != TEAM


func _aim_point(target: Node) -> Vector3:
	if not (target is Node3D):
		return global_position
	var target_node := target as Node3D
	var height := 1.2
	if target_node.has_meta("aim_height"):
		height = float(target_node.get_meta("aim_height"))
	return target_node.global_position + Vector3.UP * height


func _is_dead(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return true
	if "is_dead" in node and bool(node.get("is_dead")):
		return true
	var health: HealthComponent = null
	if node.has_method("get_health_component"):
		var candidate = node.call("get_health_component")
		if candidate is HealthComponent:
			health = candidate as HealthComponent
	if health == null:
		health = CombatUtils.find_health(node)
	return health != null and health.dead


func _magnitude() -> float:
	var base := float(data.magnitude) if data != null else 20.0
	return base * (1.0 + 0.15 * float(rank - 1))


# ---------------------------------------------------------------------------
# Player helpers
# ---------------------------------------------------------------------------

func _has_player() -> bool:
	return player != null and is_instance_valid(player) and player is Node3D and player.is_inside_tree()


func _player_position() -> Vector3:
	if _has_player():
		return (player as Node3D).global_position
	return global_position


func _player_forward() -> Vector3:
	if not _has_player():
		return Vector3.FORWARD
	if player.has_method("get_forward"):
		var forward = player.call("get_forward")
		if forward is Vector3:
			var flat := forward as Vector3
			flat.y = 0.0
			if flat.length_squared() > 0.01:
				return flat.normalized()
	var basis_forward := -(player as Node3D).global_transform.basis.z
	basis_forward.y = 0.0
	if basis_forward.length_squared() > 0.01:
		return basis_forward.normalized()
	return Vector3.FORWARD


func _player_health() -> HealthComponent:
	if not _has_player():
		return null
	if player.has_method("get_health_component"):
		var health = player.call("get_health_component")
		if health is HealthComponent:
			return health as HealthComponent
	return CombatUtils.find_health(player)


func _anchor_position() -> Vector3:
	if not _has_player():
		return global_position
	var basis := (player as Node3D).global_transform.basis
	var right := Vector3(basis.x.x, 0.0, basis.x.z)
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	right = right.normalized()
	var back := Vector3(basis.z.x, 0.0, basis.z.z)
	if back.length_squared() < 0.01:
		back = Vector3.BACK
	back = back.normalized()
	return _player_position() + Vector3.UP * 1.75 + right * 1.15 + back * 1.5


func _exit_tree() -> void:
	player = null
	_recent_target = null
	_effects_root = null
