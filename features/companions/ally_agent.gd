class_name AllyAgent
extends CharacterBody3D
## Friendly Warden squadmate. Follows the player in formation, fights the
## "enemy_ai" group with ranged fire, supports by role (medic / heavy / scout /
## engineer), can be downed and revived, and auto-revives a downed player.
##
## Design guarantees:
##  - Friendly fire can never hurt the player or other Wardens (ray masks and
##    turret targeting only ever hit layer 1/world + layer 3/enemy).
##  - No per-frame group scans: targeting refreshes on a ~0.5s timer.
##  - No navigation dependency: direct steering with obstacle probing plus a
##    teleport catch-up (stuck > 3s or player > 40m away) so allies never vanish.

signal downed_changed(is_downed: bool)
signal revived(by: Node)
signal extracted(ally: Node)
signal command_changed(command: StringName)
signal barked(line: String)

const Visuals := preload("res://features/companions/companion_visuals.gd")
const ShockTurretScript := preload("res://features/companions/shock_turret.gd")

const TEAM: StringName = StatKeys.TEAM_FRIENDLY
const FRIENDLY_LAYER := 8
const INTERACT_LAYER := 32
const WORLD_MASK := 1
const ENEMY_MASK := 1 | 4  # world + enemy only: allies can never hit friendlies
const ENGAGE_RANGE := 35.0
const TELEPORT_DISTANCE := 40.0
const STUCK_TELEPORT_TIME := 3.0
const REVIVE_RANGE := 2.5
const REVIVE_TIME := 3.0
const DOWNED_DURATION := 20.0
const RUN_SPEED := 6.0
const SPRINT_CATCHUP := 7.8
const ACCEL := 22.0

const ROLE_STATS := {
	&"medic": {
		"health": 120.0, "shield": 50.0, "armor": 10.0, "damage": 7.0,
		"cadence": 1.0, "range": 13.0, "sound": &"shot_smg",
	},
	&"heavy": {
		"health": 200.0, "shield": 40.0, "armor": 18.0, "damage": 9.0,
		"cadence": 0.72, "range": 7.0, "sound": &"shot_lmg",
	},
	&"scout": {
		"health": 110.0, "shield": 30.0, "armor": 6.0, "damage": 16.0,
		"cadence": 2.4, "range": 19.0, "sound": &"shot_dmr",
	},
	&"engineer": {
		"health": 145.0, "shield": 45.0, "armor": 12.0, "damage": 11.0,
		"cadence": 1.7, "range": 11.0, "sound": &"shot_shotgun",
	},
}

const BARK_LINES := {
	&"medic": {
		&"engage": ["Contact. I have them.", "I've got your flank.", "Suppressing. Move."],
		&"ability": ["Mender field deployed.", "Patches for everyone.", "Shields topped up."],
		&"low": ["I'm hurt. Still moving.", "Need a patch when you can."],
	},
	&"heavy": {
		&"engage": ["Contact. Drawing fire.", "They're on me. Keep moving.", "Big one. I'll hold."],
		&"ability": ["Aegis up. Stay near me.", "Plates down. Hit them now."],
		&"low": ["Taking hits. Still standing.", "Armour's shredded. Give me a second."],
	},
	&"scout": {
		&"engage": ["Eyes on. Marking targets.", "Contact at range. I'll paint them.", "Got a clean line."],
		&"ability": ["Targets painted.", "Pulse scan out. They're lit up.", "Marks down. Hit the weak points."],
		&"low": ["I'm hit. Disengaging.", "They found me. Need cover."],
	},
	&"engineer": {
		&"engage": ["Contact. Setting up.", "I'll keep them off you.", "Turret's coming online."],
		&"ability": ["Turret deployed.", "Shock line is live.", "Ground's covered."],
		&"low": ["I'm hurt. Turret's still up.", "Taking fire. Not done yet."],
	},
}

const COMMON_BARKS := {
	&"downed": ["I'm down! Need a hand!", "Hit hard. I need a revive."],
	&"revive_move": ["Warden's down. I'm on them.", "Hold on. I'm coming."],
	&"revive": ["Back on your feet.", "Up you go. Stay close."],
	&"extract": ["I'm out. Don't wait for me."],
	&"kill": ["Target down.", "One less.", "Clear."],
}

var data: AllyData = null
var player: Node = null
var rank: int = 1
var role: StringName = &"medic"
var health_component: HealthComponent = null
var downed: bool = false
var alive: bool = true
var command: StringName = &"follow"
var focus_target: Node = null
var hold_position: Vector3 = Vector3.ZERO

var _applied: bool = false
var _collision_built: bool = false
var _max_health: float = 120.0
var _max_shield: float = 50.0
var _armor: float = 10.0
var _base_damage: float = 7.0
var _cadence: float = 0.28
var _preferred_range: float = 13.0
var _fire_sound: StringName = &"shot_smg"

var _visual: Node3D = null
var _hips: Node3D = null
var _head: Node3D = null
var _leg_l: Node3D = null
var _leg_r: Node3D = null
var _arm_l: Node3D = null
var _arm_r: Node3D = null
var _arm_l_base: Vector3 = Vector3.ZERO
var _arm_r_base: Vector3 = Vector3.ZERO
var _weapon_pivot: Node3D = null
var _muzzle: Marker3D = null
var _marker: Node3D = null
var _marker_base_y: float = 2.4
var _nameplate: Label3D = null
var _glow: OmniLight3D = null
var _effects_root: Node3D = null

var _target: Node = null
var _target_retry: float = 0.0
var _los_timer: float = 0.0
var _has_los: bool = false
var _fire_timer: float = 0.4
var _ability_timer: float = 4.0
var _bark_cooldown: float = 0.0
var _was_combat: bool = false

var _downed_timer: float = 0.0
var _revive_channel: float = 0.0
var _revive_announced: bool = false

var _anim_time: float = 0.0
var _anim_phase: float = 0.0
var _formation_index: int = 0

var _stuck_time: float = 0.0
var _sep_timer: float = 0.0
var _neighbors: Array = []

var _gravity: float = 9.8


func _ready() -> void:
	add_to_group("allies")
	add_to_group("friendly")
	collision_layer = FRIENDLY_LAYER
	collision_mask = WORLD_MASK
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.5
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_build_collision()
	if data != null:
		_apply_setup()
	elif player != null:
		_apply_setup()


# ---------------------------------------------------------------------------
# Setup / public API
# ---------------------------------------------------------------------------

func setup(p_data: AllyData, p_player: Node, p_rank: int = 1) -> void:
	data = p_data
	player = p_player
	rank = clampi(p_rank, 1, 5)
	if is_inside_tree():
		_apply_setup()


func _build_collision() -> void:
	if _collision_built:
		return
	_collision_built = true
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.75
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.875, 0.0)
	add_child(shape)


func _apply_setup() -> void:
	if _applied:
		return
	_applied = true
	add_to_group("allies")
	add_to_group("friendly")
	if data == null:
		data = AllyData.new()
		data.id = &"warden"
		data.display_name = "Warden"
		data.role = &"medic"
	role = data.role
	if not ROLE_STATS.has(role):
		role = &"medic"
	_apply_role_stats()
	_build_health()
	_build_visual()
	_resolve_effects_root()
	_ability_timer = randf_range(3.0, 6.5)
	_fire_timer = randf_range(0.15, 0.7)
	_stuck_time = 0.0
	if _has_player():
		global_position = _find_ground(_follow_anchor())


func _apply_role_stats() -> void:
	var stats: Dictionary = ROLE_STATS[role]
	var health_mult := 1.0 + 0.12 * float(rank - 1)
	var damage_mult := 1.0 + 0.10 * float(rank - 1)
	_max_health = float(stats["health"]) * health_mult
	_max_shield = float(stats["shield"]) * (1.0 + 0.06 * float(rank - 1))
	_armor = float(stats["armor"]) + 2.0 * float(rank - 1)
	_base_damage = float(stats["damage"]) * damage_mult
	var base_interval: float = data.fire_interval if data != null else 0.28
	if base_interval <= 0.0:
		base_interval = 0.28
	_cadence = maxf(0.11, base_interval * float(stats["cadence"]))
	_preferred_range = float(stats["range"])
	_fire_sound = StringName(stats["sound"])


func _build_health() -> void:
	if health_component != null:
		return
	health_component = HealthComponent.new()
	health_component.name = "Health"
	add_child(health_component)
	health_component.configure(_max_health, _max_shield, _armor, TEAM)
	health_component.died.connect(_on_health_died)
	health_component.damaged.connect(_on_damaged)
	set_meta("health_component", health_component)


func _build_visual() -> void:
	var weapon: WeaponData = ContentDB.get_weapon(data.weapon_id)
	if weapon == null:
		weapon = ContentDB.get_weapon(&"wisp_smg")
	var kit: Dictionary = Visuals.build_warden(data, weapon)
	_visual = kit["root"] as Node3D
	add_child(_visual)
	_hips = kit["hips"] as Node3D
	_head = kit["head"] as Node3D
	_leg_l = kit["leg_l"] as Node3D
	_leg_r = kit["leg_r"] as Node3D
	_arm_l = kit["arm_l"] as Node3D
	_arm_r = kit["arm_r"] as Node3D
	_arm_l_base = kit["arm_l_base"]
	_arm_r_base = kit["arm_r_base"]
	_weapon_pivot = kit["weapon_pivot"] as Node3D
	_muzzle = kit["muzzle"] as Marker3D
	_marker = kit["marker"] as Node3D
	_marker_base_y = float(kit["marker_base_y"])
	_nameplate = kit["nameplate"] as Label3D
	_glow = kit["light"] as OmniLight3D


func _resolve_effects_root() -> void:
	if _effects_root != null and is_instance_valid(_effects_root):
		return
	if player != null and is_instance_valid(player) and player.has_method("get_effect_parent"):
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


func set_formation_index(index: int) -> void:
	_formation_index = maxi(0, index)


func set_nameplate_visible(is_visible: bool) -> void:
	if _nameplate != null:
		_nameplate.visible = is_visible


func set_command(p_command: StringName) -> void:
	issue_command(p_command, null)


func issue_command(p_command: StringName, target: Node = null) -> void:
	match p_command:
		&"follow":
			command = &"follow"
			focus_target = null
		&"hold":
			command = &"hold"
			hold_position = global_position
			focus_target = null
		&"focus":
			command = &"focus"
			if target != null and is_instance_valid(target):
				focus_target = target
		&"revive":
			command = &"revive"
			if target != null and is_instance_valid(target):
				focus_target = target
		_:
			command = &"follow"
			focus_target = null
	_revive_channel = 0.0
	command_changed.emit(command)


func get_command() -> StringName:
	return command


func get_focus_target() -> Node:
	return focus_target if focus_target != null and is_instance_valid(focus_target) else null


func get_ally_data() -> AllyData:
	return data


func get_display_name() -> String:
	return data.display_name if data != null else "Warden"


func get_role() -> StringName:
	return role


func get_rank() -> int:
	return rank


func get_health_component() -> HealthComponent:
	return health_component


func is_downed() -> bool:
	return downed


func is_alive() -> bool:
	return alive


func get_player() -> Node:
	return player if player != null and is_instance_valid(player) else null


func get_status() -> Dictionary:
	return {
		"id": String(data.id) if data != null else "",
		"name": get_display_name(),
		"role": String(role),
		"rank": rank,
		"health": health_component.health if health_component != null else 0.0,
		"max_health": health_component.max_health if health_component != null else _max_health,
		"shield": health_component.shield if health_component != null else 0.0,
		"shield_max": health_component.max_shield if health_component != null else _max_shield,
		"downed": downed,
		"alive": alive,
		"command": String(command),
		"position": global_position,
	}


func get_interact_prompt() -> String:
	if not downed or not alive:
		return ""
	return "Revive " + get_display_name()


func interact(who: Node) -> void:
	if not downed or not alive:
		return
	revive_from_ally(0.5, who)


func revive_from_ally(amount: float = 0.5, reviver: Node = null) -> void:
	if not downed or not alive or health_component == null:
		return
	downed = false
	_downed_timer = 0.0
	_revive_channel = 0.0
	remove_from_group("interactable")
	collision_layer = FRIENDLY_LAYER
	health_component.revive(maxf(1.0, health_component.max_health * clampf(amount, 0.05, 1.0)))
	health_component.set_invulnerable(1.2)
	if _visual != null:
		_visual.rotation.z = 0.0
		_visual.position.y = 0.0
	if _weapon_pivot != null:
		_weapon_pivot.visible = true
	if _marker != null:
		_marker.visible = true
	downed_changed.emit(false)
	revived.emit(reviver)
	CombatVFX.ring(_effects(), global_position + Vector3.UP * 0.3, 2.0, Visuals.MINT, 0.6)
	AudioDirector.play_3d(&"heal", global_position, -8.0)
	EventBus.notify(get_display_name() + " revived", "The squad is back to full strength.", &"success")
	_bark(&"revive", true)


func heal_from_ally(amount: float) -> void:
	if health_component == null or downed or not alive:
		return
	health_component.heal(amount)
	health_component.restore_shield(amount * 0.6)


func force_ability() -> bool:
	if downed or not alive or not _applied:
		return false
	_ability_timer = 0.0
	return _dispatch_ability()


# ---------------------------------------------------------------------------
# Physics / behaviour
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _applied:
		return
	_bark_cooldown = maxf(0.0, _bark_cooldown - delta)
	_anim_time += delta
	if downed:
		_update_downed(delta)
		return
	if not alive:
		return
	if health_component == null or health_component.dead:
		return
	if not _has_player():
		_gravity_step(delta)
		_update_visual(delta)
		return
	_tick_targeting(delta)
	var revive_target := _revive_target()
	if revive_target != null:
		_update_revive(revive_target, delta)
	else:
		_update_ability(delta)
		_update_combat(delta)
	_update_movement(delta)
	_update_visual(delta)


func _gravity_step(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.1
	velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
	velocity.z = move_toward(velocity.z, 0.0, ACCEL * delta)
	move_and_slide()
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0


func _update_movement(delta: float) -> void:
	var desired := _desired_position()
	var flat_pos := Vector3(global_position.x, 0.0, global_position.z)
	var flat_des := Vector3(desired.x, 0.0, desired.z)
	var to_target := flat_des - flat_pos
	var dist := to_target.length()
	var move_dir := Vector3.ZERO
	if dist > 0.7:
		move_dir = to_target / dist
		var in_combat := _target != null and _has_los and _can_engage_target()
		if in_combat and dist < 4.0:
			move_dir *= 0.3
		move_dir = _avoid_obstacles(move_dir)
	var sep := _separation(delta)
	var steering := move_dir + sep
	if steering.length() > 1.0:
		steering = steering.normalized()
	var speed := RUN_SPEED
	if command != &"hold" and _distance_to_player() > 12.0:
		speed = SPRINT_CATCHUP
	velocity.x = move_toward(velocity.x, steering.x * speed, ACCEL * delta)
	velocity.z = move_toward(velocity.z, steering.z * speed, ACCEL * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.1
	move_and_slide()
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	_update_catchup(delta, desired)


func _avoid_obstacles(dir: Vector3) -> Vector3:
	if dir.length_squared() < 0.01:
		return dir
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 1.9, WORLD_MASK)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return dir
	var normal: Vector3 = hit["normal"]
	normal.y = 0.0
	if normal.length_squared() < 0.01:
		return dir
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	if normal.dot(side) > 0.0:
		side = -side
	return (dir * 0.3 + side).normalized()


func _separation(delta: float) -> Vector3:
	_sep_timer -= delta
	if _sep_timer <= 0.0:
		_sep_timer = 0.35
		_neighbors = get_tree().get_nodes_in_group("allies")
	var push := Vector3.ZERO
	for node in _neighbors:
		if node == self or node == null or not is_instance_valid(node) or not (node is Node3D):
			continue
		var other := node as Node3D
		var offset := global_position - other.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > 0.001 and distance < 1.7:
			push += offset.normalized() * (1.7 - distance) * 0.7
	if _has_player():
		var to_player := _player_position() - global_position
		to_player.y = 0.0
		var pd := to_player.length()
		if pd > 0.001 and pd < 1.9:
			push -= to_player.normalized() * (1.9 - pd) * 0.9
	return push


func _update_catchup(delta: float, desired: Vector3) -> void:
	if command == &"hold":
		_stuck_time = 0.0
		return
	if _distance_to_player() > TELEPORT_DISTANCE:
		_teleport_to(_follow_anchor(), true)
		return
	var dist := Vector3(desired.x - global_position.x, 0.0, desired.z - global_position.z).length()
	var horizontal_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	if dist > 2.2 and horizontal_speed < 0.9:
		_stuck_time += delta
	else:
		_stuck_time = maxf(0.0, _stuck_time - delta * 2.0)
	if _stuck_time > STUCK_TELEPORT_TIME:
		_stuck_time = 0.0
		_teleport_to(desired, true)


func _desired_position() -> Vector3:
	if downed or not alive:
		return global_position
	var revive_target := _revive_target()
	if revive_target != null and revive_target is Node3D:
		var rpos := (revive_target as Node3D).global_position
		if _flat_distance_to(rpos) <= REVIVE_RANGE:
			return global_position
		return rpos
	if command == &"hold":
		return hold_position
	if command == &"focus" and focus_target != null and is_instance_valid(focus_target) and focus_target is Node3D:
		return _combat_anchor_for(focus_target as Node3D)
	var anchor := _follow_anchor()
	if _target != null and is_instance_valid(_target) and _target is Node3D and _has_los and _can_engage_target():
		var enemy_pos := (_target as Node3D).global_position
		var flat := Vector3(enemy_pos.x - global_position.x, 0.0, enemy_pos.z - global_position.z)
		var dist := flat.length()
		if dist > 0.01:
			var dir := flat / dist
			if dist > _preferred_range + 2.0:
				var approach := Vector3(enemy_pos.x, 0.0, enemy_pos.z) - dir * _preferred_range
				var leash := Vector3(anchor.x, 0.0, anchor.z)
				if leash.distance_to(approach) < 13.0:
					anchor = approach
			elif dist < _preferred_range - 4.0:
				anchor = Vector3(global_position.x, global_position.y, global_position.z) - dir * 4.0
	return anchor


func _combat_anchor_for(target: Node3D) -> Vector3:
	var target_pos := target.global_position
	var flat := Vector3(target_pos.x - global_position.x, 0.0, target_pos.z - global_position.z)
	var dist := flat.length()
	if dist < 0.01:
		return global_position
	return target_pos - flat.normalized() * _preferred_range


func _follow_anchor() -> Vector3:
	if not _has_player():
		return global_position
	var forward := _player_forward()
	var right := forward.cross(Vector3.UP)
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	right = right.normalized()
	var lateral := -1.7 if _formation_index % 2 == 0 else 1.7
	var depth := 2.2 + 0.75 * float(int(_formation_index / 2))
	var anchor := _player_position() + right * lateral - forward * depth
	return anchor


func _teleport_to(pos: Vector3, show_ring: bool) -> void:
	global_position = _find_ground(pos)
	velocity = Vector3.ZERO
	_stuck_time = 0.0
	reset_physics_interpolation()
	if show_ring:
		CombatVFX.ring(_effects(), global_position + Vector3.UP * 0.2, 1.4, Visuals.MINT, 0.45)


func _find_ground(pos: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		pos + Vector3.UP * 6.0,
		pos - Vector3.DOWN * 14.0,
		WORLD_MASK
	)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return pos
	return (hit["position"] as Vector3) + Vector3.UP * 0.05


# ---------------------------------------------------------------------------
# Targeting / combat
# ---------------------------------------------------------------------------

func _tick_targeting(delta: float) -> void:
	if _target != null and (not is_instance_valid(_target) or _is_dead(_target) or _flat_distance_to(_target_global_position()) > ENGAGE_RANGE + 10.0):
		_target = null
		_was_combat = false
	_target_retry -= delta
	if _target_retry > 0.0:
		return
	_target_retry = 0.5
	if command == &"focus" and focus_target != null and is_instance_valid(focus_target) and not _is_dead(focus_target) and focus_target is Node3D:
		if _target != focus_target:
			_target = focus_target
			_has_los = false
			_los_timer = 0.0
		return
	if _target != null:
		return
	var best: Node = null
	var best_distance := 1e20
	var own_position := global_position
	for node in get_tree().get_nodes_in_group("enemy_ai"):
		if node == null or not is_instance_valid(node) or not (node is Node3D):
			continue
		if _is_dead(node):
			continue
		var distance := own_position.distance_to((node as Node3D).global_position)
		if distance > ENGAGE_RANGE:
			continue
		if distance < best_distance:
			best_distance = distance
			best = node
	_target = best
	if _target != null and not _was_combat:
		_was_combat = true
		_los_timer = 0.0
		_bark(&"engage", false)


func _update_combat(delta: float) -> void:
	_fire_timer = maxf(0.0, _fire_timer - delta)
	if _target == null or not is_instance_valid(_target) or not (_target is Node3D):
		return
	if not _can_engage_target():
		return
	_los_timer -= delta
	if _los_timer <= 0.0:
		_los_timer = 0.22
		_has_los = _check_los()
	if not _has_los:
		return
	if _fire_timer > 0.0:
		return
	_fire_at_target()
	_fire_timer = _cadence


func _can_engage_target() -> bool:
	if _target == null or not is_instance_valid(_target) or not (_target is Node3D):
		return false
	var distance := _flat_distance_to((_target as Node3D).global_position)
	return distance <= ENGAGE_RANGE


func _check_los() -> bool:
	if _target == null or not is_instance_valid(_target) or not (_target is Node3D):
		return false
	var origin := global_position + Vector3.UP * 1.45
	var aim := _aim_point(_target)
	var query := PhysicsRayQueryParameters3D.create(origin, aim, ENEMY_MASK)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var health := CombatUtils.find_health(hit["collider"])
	return health != null and health.team != TEAM


func _fire_at_target() -> void:
	if _target == null or not is_instance_valid(_target) or not (_target is Node3D):
		return
	var origin := _muzzle_position()
	var aim := _aim_point(_target)
	var distance := origin.distance_to(aim)
	var spread := maxf(0.06, 0.1 + distance * 0.016)
	aim += Vector3(randf_range(-spread, spread), randf_range(-spread * 0.7, spread * 0.7), randf_range(-spread, spread))
	var direction := (aim - origin)
	if direction.length_squared() < 0.01:
		return
	direction = direction.normalized()
	var ray_start := origin + direction * 0.25
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_start + direction * (distance + 8.0), ENEMY_MASK)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end_point := ray_start + direction * distance
	var killed := false
	if not hit.is_empty():
		end_point = hit["position"]
		var collider = hit["collider"]
		var health := CombatUtils.find_health(collider)
		if health != null and not health.dead and health.team != TEAM:
			var damage_data := DamageData.make(_damage_at(distance), TEAM, StatKeys.DMG_BALLISTIC, self)
			damage_data.hit_position = end_point
			damage_data.hit_normal = hit["normal"]
			damage_data.crit = randf() < 0.08
			var applied := CombatUtils.apply_hit(collider, damage_data, int(hit.get("shape", -1)))
			killed = bool(applied.get("killed", false))
			CombatVFX.impact(_effects(), end_point, hit["normal"], Visuals.AMBER if damage_data.crit else Visuals.MINT)
	CombatVFX.spawn_tracer(_effects(), origin, end_point, Visuals.MINT.lerp(Color.WHITE, 0.3))
	CombatVFX.muzzle_flash(_effects(), origin, Color("c8ffe9"))
	AudioDirector.play_3d(_fire_sound, origin, -15.0)
	if killed:
		_bark(&"kill", false)


func _damage_at(distance: float) -> float:
	var falloff := clampf(1.0 - distance / 70.0, 0.55, 1.0)
	return _base_damage * falloff


func _aim_point(target: Node) -> Vector3:
	if not (target is Node3D):
		return global_position
	var target_node := target as Node3D
	var height := 1.2
	if target_node.has_meta("aim_height"):
		height = float(target_node.get_meta("aim_height"))
	return target_node.global_position + Vector3.UP * height


func _muzzle_position() -> Vector3:
	if _muzzle != null and is_instance_valid(_muzzle):
		return _muzzle.global_position
	return global_position + Vector3.UP * 1.35


# ---------------------------------------------------------------------------
# Role abilities
# ---------------------------------------------------------------------------

func _update_ability(delta: float) -> void:
	_ability_timer = maxf(0.0, _ability_timer - delta)
	if _ability_timer > 0.0:
		return
	_dispatch_ability()


func _dispatch_ability() -> bool:
	match role:
		&"medic":
			return _ability_medic()
		&"heavy":
			return _ability_heavy()
		&"scout":
			return _ability_scout()
		&"engineer":
			return _ability_engineer()
	_ability_timer = 6.0
	return false


func _ability_medic() -> bool:
	var player_health := _player_health()
	if player_health == null or player_health.dead:
		_ability_timer = 3.0
		return false
	var missing_health := player_health.max_health - player_health.health
	var missing_shield := player_health.max_shield - player_health.shield
	if missing_health <= 0.5 and missing_shield <= 0.5:
		_ability_timer = 2.5
		return false
	player_health.heal(14.0 + 4.0 * float(rank))
	player_health.restore_shield(20.0 + 5.0 * float(rank))
	for node in get_tree().get_nodes_in_group("allies"):
		if node == self or node == null or not is_instance_valid(node) or not (node is Node3D):
			continue
		if (node as Node3D).global_position.distance_to(global_position) > 12.0:
			continue
		if node.has_method("heal_from_ally"):
			node.call("heal_from_ally", 10.0 + 2.0 * float(rank))
	var player_pos := _player_position()
	CombatVFX.ring(_effects(), player_pos + Vector3.UP * 0.3, 2.2, Visuals.MINT, 0.7)
	AudioDirector.play_3d(&"heal", player_pos, -9.0)
	_bark(&"ability", false)
	_ability_timer = 16.0 + randf() * 3.0
	return true


func _ability_heavy() -> bool:
	if _target == null or not is_instance_valid(_target) or not (_target is Node3D):
		_ability_timer = 1.5
		return false
	for node in get_tree().get_nodes_in_group("enemy_ai"):
		if node == null or not is_instance_valid(node) or not (node is Node3D):
			continue
		if (node as Node3D).global_position.distance_to(global_position) > 20.0:
			continue
		if node.has_method("hear_noise"):
			node.call("hear_noise", global_position, 18.0)
	if player != null and is_instance_valid(player) and player.has_method("apply_temporary_modifier"):
		player.call("apply_temporary_modifier", &"aegis_wall", StatKeys.ARMOR, &"add", 20.0 + 3.0 * float(rank), 6.0)
	CombatVFX.ring(_effects(), global_position + Vector3.UP * 0.3, 2.6, Visuals.AMBER, 0.6)
	AudioDirector.play_3d(&"ability", global_position, -10.0)
	_bark(&"ability", false)
	_ability_timer = 20.0 + randf() * 4.0
	return true


func _ability_scout() -> bool:
	var marked := 0
	for node in get_tree().get_nodes_in_group("enemy_ai"):
		if node == null or not is_instance_valid(node) or not (node is Node3D):
			continue
		if _is_dead(node):
			continue
		if (node as Node3D).global_position.distance_to(global_position) > 28.0:
			continue
		if node.has_method("set_marked"):
			node.call("set_marked", 7.0)
			marked += 1
		if marked >= 8:
			break
	if marked == 0:
		_ability_timer = 2.0
		return false
	if player != null and is_instance_valid(player) and player.has_method("apply_temporary_modifier"):
		player.call("apply_temporary_modifier", &"pulse_scan", StatKeys.CRIT_CHANCE, &"add", 0.1, 6.0)
	CombatVFX.ring(_effects(), global_position + Vector3.UP * 0.3, 3.4, Visuals.BLUE, 0.7)
	AudioDirector.play_3d(&"scan", global_position, -10.0)
	_bark(&"ability", false)
	_ability_timer = 15.0 + randf() * 3.0
	return true


func _ability_engineer() -> bool:
	if _target == null or not is_instance_valid(_target) or not (_target is Node3D):
		_ability_timer = 1.5
		return false
	var direction := (_target as Node3D).global_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = _player_forward()
	direction = direction.normalized()
	var anchor := global_position + direction * 2.4
	var turret := ShockTurretScript.new()
	turret.name = "ShockTurret"
	_effects().add_child(turret)
	turret.setup(TEAM, 10.0 + 3.0 * float(rank), 12.0, 5.5, self)
	turret.global_position = _find_ground(anchor)
	CombatVFX.ring(_effects(), turret.global_position + Vector3.UP * 0.2, 2.0, Visuals.VIOLET, 0.6)
	AudioDirector.play_3d(&"ability", turret.global_position, -9.0)
	_bark(&"ability", false)
	_ability_timer = 22.0 + randf() * 4.0
	return true


# ---------------------------------------------------------------------------
# Revive behaviour
# ---------------------------------------------------------------------------

func _revive_target() -> Node:
	if _player_is_downed():
		return player
	if command == &"revive" and focus_target != null and is_instance_valid(focus_target) and _node_is_downed(focus_target):
		return focus_target
	return null


func _update_revive(target: Node, delta: float) -> void:
	if target == null or not is_instance_valid(target) or not (target is Node3D):
		_revive_channel = 0.0
		_revive_announced = false
		return
	var target_pos := (target as Node3D).global_position
	if _flat_distance_to(target_pos) > REVIVE_RANGE:
		_revive_channel = 0.0
		_revive_announced = false
		return
	velocity.x = 0.0
	velocity.z = 0.0
	_revive_channel += delta
	if not _revive_announced:
		_revive_announced = true
		_bark(&"revive_move", true)
		AudioDirector.play_3d(&"ability", global_position, -10.0)
		CombatVFX.ring(_effects(), target_pos + Vector3.UP * 0.3, 1.6, Visuals.MINT, 0.7)
	if _revive_channel >= REVIVE_TIME:
		_complete_revive(target)
		_revive_channel = 0.0
		_revive_announced = false


func _complete_revive(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target == player:
		if player.has_method("revive_from_ally"):
			player.call("revive_from_ally", 0.5)
		else:
			var player_health := _player_health()
			if player_health != null:
				player_health.revive(player_health.max_health * 0.5)
	else:
		if target.has_method("revive_from_ally"):
			target.call("revive_from_ally", 0.5, self)
		elif target.has_method("interact"):
			target.call("interact", self)
	if target is Node3D:
		var target_pos := (target as Node3D).global_position
		CombatVFX.ring(_effects(), target_pos + Vector3.UP * 0.3, 2.0, Visuals.MINT, 0.6)
		AudioDirector.play_3d(&"heal", target_pos, -8.0)
	_bark(&"revive", true)


# ---------------------------------------------------------------------------
# Downed / extraction
# ---------------------------------------------------------------------------

func _on_health_died() -> void:
	if downed or not alive:
		return
	_enter_downed()


func _enter_downed() -> void:
	downed = true
	_target = null
	_was_combat = false
	_revive_channel = 0.0
	_revive_announced = false
	_downed_timer = DOWNED_DURATION
	velocity = Vector3.ZERO
	collision_layer = FRIENDLY_LAYER | INTERACT_LAYER
	add_to_group("interactable")
	if _weapon_pivot != null:
		_weapon_pivot.visible = false
	if _marker != null:
		_marker.visible = false
	if _glow != null:
		_glow.light_energy = 0.18
	downed_changed.emit(true)
	CombatVFX.ring(_effects(), global_position + Vector3.UP * 0.2, 1.8, Color("ff6e6e"), 0.7)
	AudioDirector.play_3d(&"player_hurt", global_position, -9.0)
	EventBus.notify(get_display_name() + " is down", "Reach them and press E to revive.", &"danger")
	_bark(&"downed", true)


func _update_downed(delta: float) -> void:
	_downed_timer = maxf(0.0, _downed_timer - delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.1
	velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
	move_and_slide()
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	if _visual != null:
		_visual.rotation.z = lerpf(_visual.rotation.z, 1.25, minf(1.0, delta * 4.0))
		_visual.position.y = lerpf(_visual.position.y, -0.55, minf(1.0, delta * 4.0))
	if _downed_timer <= 0.0:
		_self_extract()


func _self_extract() -> void:
	if not alive:
		return
	alive = false
	downed = false
	remove_from_group("interactable")
	remove_from_group("allies")
	extracted.emit(self)
	EventBus.notify(get_display_name() + " self-extracted", "The squad is a Warden short.", &"danger")
	_bark(&"extract", true)
	AudioDirector.play_3d(&"exfil", global_position, -12.0)
	if health_component != null:
		health_component.set_process(false)
	var tween := create_tween()
	tween.set_parallel(true)
	if _visual != null:
		tween.tween_property(_visual, "scale", Vector3.ONE * 0.02, 0.55)
	tween.tween_property(self, "position", position - Vector3(0.0, 0.5, 0.0), 0.55)
	tween.chain().tween_callback(queue_free)


func _on_damaged(info: Dictionary) -> void:
	if downed or not alive:
		return
	var hit_position := global_position + Vector3.UP * 1.2
	CombatVFX.impact(_effects(), hit_position, Vector3.UP, Color("ff6e6e"))
	AudioDirector.play_3d(&"hit", hit_position, -12.0)
	if health_component != null and health_component.get_health_fraction() < 0.35 and _bark_cooldown <= 0.0:
		_bark(&"low", false)


# ---------------------------------------------------------------------------
# Visuals / animation
# ---------------------------------------------------------------------------

func _update_visual(delta: float) -> void:
	if _visual == null:
		return
	var horizontal_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var moving := horizontal_speed > 0.35
	if moving:
		_anim_phase += delta * (4.0 + horizontal_speed * 0.9)
		var swing := sin(_anim_phase) * clampf(horizontal_speed / RUN_SPEED, 0.15, 1.0) * 0.55
		if _leg_l != null:
			_leg_l.rotation.x = swing
		if _leg_r != null:
			_leg_r.rotation.x = -swing
		if _arm_l != null:
			_arm_l.rotation.x = _arm_l_base.x - swing * 0.45
		if _arm_r != null:
			_arm_r.rotation.x = _arm_r_base.x + swing * 0.35
		_visual.position.y = absf(sin(_anim_phase)) * 0.035
	else:
		if _leg_l != null:
			_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.0, minf(1.0, delta * 7.0))
		if _leg_r != null:
			_leg_r.rotation.x = lerpf(_leg_r.rotation.x, 0.0, minf(1.0, delta * 7.0))
		if _arm_l != null:
			_arm_l.rotation.x = lerpf(_arm_l.rotation.x, _arm_l_base.x, minf(1.0, delta * 7.0))
		if _arm_r != null:
			_arm_r.rotation.x = lerpf(_arm_r.rotation.x, _arm_r_base.x, minf(1.0, delta * 7.0))
		_visual.position.y = lerpf(_visual.position.y, sin(_anim_time * 1.8) * 0.012, minf(1.0, delta * 5.0))
	var facing := _facing_point()
	if facing.length_squared() > 0.01:
		var yaw := atan2(-facing.x, -facing.z)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-9.0 * delta))
	if _weapon_pivot != null:
		if _target != null and is_instance_valid(_target) and (_target is Node3D):
			var aim := _aim_point(_target)
			if _weapon_pivot.global_position.distance_to(aim) > 0.15:
				_weapon_pivot.look_at(aim, Vector3.UP)
		else:
			_weapon_pivot.rotation = _weapon_pivot.rotation.lerp(Vector3.ZERO, minf(1.0, delta * 6.0))
	if _marker != null:
		_marker.rotation.y += delta * 1.2
		_marker.position.y = _marker_base_y + sin(_anim_time * 2.2) * 0.05
	if _glow != null:
		_glow.light_energy = 0.4 + sin(_anim_time * 3.1) * 0.08


func _facing_point() -> Vector3:
	if _target != null and is_instance_valid(_target) and (_target is Node3D):
		return (_target as Node3D).global_position - global_position
	var horizontal_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	if horizontal_speed > 0.5:
		return Vector3(velocity.x, 0.0, velocity.z)
	if _has_player():
		return _player_forward()
	return Vector3.ZERO


func _bark(kind: StringName, force: bool) -> void:
	if not force and _bark_cooldown > 0.0:
		return
	var lines: Array = []
	var role_lines: Dictionary = BARK_LINES.get(role, {})
	if role_lines.has(kind):
		lines = role_lines[kind]
	elif COMMON_BARKS.has(kind):
		lines = COMMON_BARKS[kind]
	if lines.is_empty():
		return
	var line: String = String(lines.pick_random())
	EventBus.radio_message.emit(get_display_name(), line)
	barked.emit(line)
	_bark_cooldown = 16.0 + randf() * 8.0


# ---------------------------------------------------------------------------
# Player / target helpers
# ---------------------------------------------------------------------------

func _has_player() -> bool:
	return player != null and is_instance_valid(player) and player is Node3D and player.is_inside_tree()


func _player_position() -> Vector3:
	if _has_player():
		return (player as Node3D).global_position
	return global_position


func _player_forward() -> Vector3:
	if _has_player():
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


func _player_is_downed() -> bool:
	if not _has_player():
		return false
	if "is_downed" in player:
		return bool(player.get("is_downed"))
	if player.has_method("is_downed"):
		return bool(player.call("is_downed"))
	return false


func _player_is_dead() -> bool:
	if not _has_player():
		return false
	if "is_dead" in player:
		return bool(player.get("is_dead"))
	return false


func _distance_to_player() -> float:
	if not _has_player():
		return 0.0
	return global_position.distance_to(_player_position())


func _flat_distance_to(target: Vector3) -> float:
	return Vector2(target.x - global_position.x, target.z - global_position.z).length()


func _target_global_position() -> Vector3:
	if _target != null and is_instance_valid(_target) and _target is Node3D:
		return (_target as Node3D).global_position
	return global_position


func _node_is_downed(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if "is_downed" in node:
		return bool(node.get("is_downed"))
	if node.has_method("is_downed"):
		return bool(node.call("is_downed"))
	return false


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


func _exit_tree() -> void:
	player = null
	_target = null
	focus_target = null
	_neighbors.clear()
	_effects_root = null
