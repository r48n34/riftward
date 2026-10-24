class_name EnemyAgent
extends CharacterBody3D
## RIFTWARD hostile agent: procedural low-poly body, perception-driven FSM,
## ranged/melee combat, elite affixes, boss phases, status effects and loot.
##
## Integration contract:
##   group "enemy_ai" (plus "enemy_elite"/"enemy_boss"), collision layer 4 (Enemy),
##   collision mask 1 | 2 (World + Player), child "Health" (HealthComponent),
##   root meta "health_component", weakpoint CollisionShape3D meta "weakpoint_mult".
## Weapons resolve damage through CombatUtils.apply_hit, so player hits just work.

signal defeated(enemy: EnemyAgent)

enum State { IDLE, PATROL, SEARCH, ENGAGE, FLEE, DEAD }

const AFFIX_ARMORED: StringName = &"armored"
const AFFIX_SHIELDED: StringName = &"shielded"
const AFFIX_BERSERK: StringName = &"berserk"
const AFFIX_VOLATILE: StringName = &"volatile"
const ELITE_AFFIXES: Array[StringName] = [AFFIX_ARMORED, AFFIX_SHIELDED, AFFIX_BERSERK, AFFIX_VOLATILE]

const HEALTH_BAR_SCRIPT: Script = preload("res://features/ai/enemy_health_bar.gd")
const TEAM: StringName = StatKeys.TEAM_ENEMY
const BODY_LAYER: int = 4          # Project layer 3 "Enemy"
const BODY_MASK: int = 1 | 2       # World + Player
const GRAVITY: float = 24.0
const PERCEPTION_INTERVAL: float = 0.2
const NAV_PROBE_INTERVAL: float = 2.0
const SEPARATION_INTERVAL: float = 0.5
const ALLY_SCAN_INTERVAL: float = 1.5
const MAX_AI_DISTANCE: float = 120.0
const DEATH_FREE_DELAY: float = 0.85

# --- Setup -------------------------------------------------------------
var enemy_data: EnemyData = null
var threat_level: int = 1
var elite_affix: StringName = &""
var display_name: String = "Hostile"
var role: StringName = &"rusher"
var style: StringName = &"humanoid"
var ranged: bool = true
var boss_phase: int = 1

# --- Components --------------------------------------------------------
var health: HealthComponent = null
var nav_agent: NavigationAgent3D = null
var visuals: Dictionary = {}

# --- Runtime stats -----------------------------------------------------
var move_speed: float = 4.0
var attack_range: float = 30.0
var preferred_range: float = 18.0
var attack_interval: float = 1.5
var attack_damage: float = 10.0
var projectile_speed: float = 28.0
var vision_range: float = 42.0
var weakpoint_mult: float = 1.8

# --- Public counters (diagnostics/tests) -------------------------------
var shots_fired: int = 0
var melee_attacks: int = 0
var loot_dropped: int = 0

# --- State machine -----------------------------------------------------
var state: State = State.IDLE

var _built: bool = false
var _dead: bool = false
var _rng := RandomNumberGenerator.new()
var _visual_root: Node3D = null
var _flash_material: StandardMaterial3D = null
var _accent_material: StandardMaterial3D = null
var _eye_material: StandardMaterial3D = null
var _flash_tween: Tween = null
var _muzzle: Marker3D = null
var _telegraph: MeshInstance3D = null
var _marker: Node3D = null
var _health_bar: Node3D = null
var _health_bar_timer: float = 0.0
var _health_bar_force: float = 0.0
var _body_scale: float = 1.0
var _height: float = 1.8
var _hover: float = 0.0
var _eye_height: float = 1.5
var _weak_local: Vector3 = Vector3(0.0, 1.5, 0.0)

var _run_state: Node = null
var _event_bus: Node = null
var _content_db: Node = null
var _audio: Node = null
var _factory_script: Script = null
var _factory_probed: bool = false

var _player: Node3D = null
var _target: Node3D = null
var _allies: Array[Node3D] = []
var _spawn_position: Vector3 = Vector3.ZERO
var _last_known: Vector3 = Vector3.ZERO
var _has_seen: bool = false
var _memory_left: float = 0.0
var _perception_timer: float = 0.0
var _ally_scan_timer: float = 0.0
var _target_refresh_timer: float = 0.0
var _nav_probe_timer: float = 0.0
var _nav_available: bool = false

var _state_timer: float = 0.0
var _attack_timer: float = 0.0
var _telegraph_timer: float = 0.0
var _telegraph_duration_value: float = 0.4
var _pending_attack: StringName = &""
var _strafe_dir: float = 1.0
var _strafe_timer: float = 2.0
var _patrol_goal: Vector3 = Vector3.ZERO
var _move_goal: Vector3 = Vector3.ZERO
var _has_move_goal: bool = false
var _move_speed_scale: float = 0.0
var _face_target: bool = false
var _stuck_timer: float = 0.0
var _recover_timer: float = 0.0
var _cover_timer: float = 0.0
var _cover_goal: Vector3 = Vector3.ZERO
var _cover_active: bool = false
var _separation: Vector3 = Vector3.ZERO
var _separation_timer: float = 0.0
var _boss_charge_timer: float = 8.0
var _boss_charge_time: float = 0.0
var _boss_attack_count: int = 0

var _stun_timer: float = 0.0
var _slow_timer: float = 0.0
var _burn_timer: float = 0.0
var _burn_dps: float = 0.0
var _burn_tick: float = 0.0
var _armor_timer: float = 0.0
var _base_armor: float = 0.0
var _pull_target: Vector3 = Vector3.ZERO
var _pull_strength: float = 0.0
var _pull_time: float = 0.0
var _marked_timer: float = 0.0
var _grave_time: float = 0.0
var _idle_scan_dir: float = 1.0
var _affix_health: float = 0.0
var _affix_shield: float = 0.0
var _affix_armor: float = 0.0


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func setup(data: EnemyData, threat: int = 1, elite_mod: StringName = &"") -> void:
	if _dead:
		return
	enemy_data = data
	threat_level = clampi(threat, 1, 4)
	elite_affix = elite_mod
	if _built:
		# Deployment pattern: add_child() -> position -> setup(). Rebuild so the
		# requested archetype/affix/threat replaces the deferred fallback body.
		if data != null:
			_rebuild()
	elif is_inside_tree():
		_build()


func _ready() -> void:
	add_to_group("enemy_ai")
	collision_layer = BODY_LAYER
	collision_mask = BODY_MASK
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.55
	_rng.randomize()
	_cache_services()
	if enemy_data != null and not _built:
		_build()
	else:
		# Give setup() one frame to arrive (spawners often configure after
		# add_child); fall back to a sensible archetype only if it never does.
		call_deferred("_fallback_build_if_needed")


func _fallback_build_if_needed() -> void:
	if _built or _dead or not is_inside_tree():
		return
	if enemy_data == null:
		enemy_data = _fallback_data()
	_build()


## Rebuilds components/visuals for a new archetype. Used when setup() arrives
## after the agent is already in the tree (e.g. Deployment spawn order).
func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	health = null
	nav_agent = null
	visuals = {}
	_visual_root = null
	_flash_material = null
	_accent_material = null
	_eye_material = null
	_muzzle = null
	_telegraph = null
	_marker = null
	_health_bar = null
	_health_bar_force = 0.0
	_flash_tween = null
	_built = false
	_dead = false
	boss_phase = 1
	state = State.IDLE
	_grave_time = 0.0
	_telegraph_timer = 0.0
	_telegraph_duration_value = 0.4
	_pending_attack = &""
	_stun_timer = 0.0
	_slow_timer = 0.0
	_burn_timer = 0.0
	_burn_dps = 0.0
	_armor_timer = 0.0
	_pull_time = 0.0
	_marked_timer = 0.0
	_cover_active = false
	_cover_timer = 0.0
	_boss_charge_time = 0.0
	_boss_attack_count = 0
	_has_seen = false
	_target = null
	_memory_left = 0.0
	_build()


func _fallback_data() -> EnemyData:
	if _content_db != null and _content_db.has_method("get_enemy"):
		var found = _content_db.call("get_enemy", &"ashen_scrapper")
		if found is EnemyData:
			return found
	return EnemyData.new()


func _cache_services() -> void:
	_run_state = get_node_or_null("/root/RunState")
	_event_bus = get_node_or_null("/root/EventBus")
	_content_db = get_node_or_null("/root/ContentDB")
	_audio = get_node_or_null("/root/AudioDirector")


func _build() -> void:
	if _built or enemy_data == null:
		return
	_built = true
	var data := enemy_data
	display_name = data.display_name if not data.display_name.is_empty() else "Hostile"
	role = data.role
	style = data.style
	ranged = data.ranged
	weakpoint_mult = maxf(1.0, data.weakpoint_mult)

	var threat_hp := 1.0 + 0.22 * float(threat_level - 1)
	var threat_dmg := 1.0 + 0.16 * float(threat_level - 1)
	var hp_mult := threat_hp * _mutator_mult("enemy_health") * _difficulty_stat("get_difficulty_enemy_health_mult")
	var dmg_mult := threat_dmg * _mutator_mult("enemy_damage") * _difficulty_stat("get_difficulty_enemy_damage_mult")

	if data.elite and not data.boss and elite_affix == &"":
		elite_affix = ELITE_AFFIXES[_rng.randi_range(0, ELITE_AFFIXES.size() - 1)]

	visuals = EnemyVisuals.build(data, self)
	_visual_root = visuals["root"]
	_flash_material = visuals["flash"]
	_accent_material = visuals["accent_material"]
	_eye_material = visuals["eye_material"]
	_muzzle = visuals["muzzle"]
	_body_scale = float(visuals["body_scale"])
	_height = float(visuals["height"])
	_hover = float(visuals["hover"])
	_eye_height = float(visuals["eye_y"])
	_weak_local = visuals["weak_local"]

	move_speed = maxf(1.0, data.move_speed * (1.0 + 0.03 * float(threat_level - 1)))
	attack_range = maxf(1.2, data.attack_range)
	preferred_range = clampf(data.preferred_range, 1.0, maxf(1.2, attack_range))
	attack_interval = maxf(0.35, data.attack_interval)
	attack_damage = maxf(1.0, data.damage * dmg_mult)
	projectile_speed = maxf(10.0, data.projectile_speed)
	vision_range = clampf(maxf(attack_range, preferred_range) + 10.0, 20.0, 72.0)

	var max_health := maxf(10.0, data.max_health * hp_mult)
	var max_shield := maxf(0.0, data.max_shield * (1.0 + 0.15 * float(threat_level - 1)))
	var armor := maxf(0.0, data.armor)
	_apply_affix_to_stats(max_health, max_shield, armor)
	max_health = _affix_health
	max_shield = _affix_shield
	armor = _affix_armor

	health = HealthComponent.new()
	health.name = "Health"
	health.team = TEAM
	add_child(health)
	health.configure(max_health, max_shield, armor, TEAM)
	health.shield_regen_delay = 6.0
	health.shield_regen_rate = maxf(5.0, max_shield * 0.05)
	set_meta("health_component", health)
	set_meta("enemy_name", display_name)
	set_meta("enemy_id", String(data.id))
	set_meta("is_boss", data.boss)
	set_meta("is_elite", data.elite)
	if data.boss:
		add_to_group("enemy_boss")
		add_to_group("enemy_elite")
	elif data.elite:
		add_to_group("enemy_elite")
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.status_applied.connect(_on_status_applied)
	health.shield_changed.connect(_on_shield_changed)
	_build_health_bar()

	_build_collision()
	_build_navigation()
	_build_telegraph()
	_build_marker()

	_attack_timer = _rng.randf_range(0.35, 1.1) * attack_interval
	_perception_timer = _rng.randf_range(0.0, PERCEPTION_INTERVAL)
	_ally_scan_timer = _rng.randf_range(0.0, ALLY_SCAN_INTERVAL)
	_nav_probe_timer = _rng.randf_range(0.0, NAV_PROBE_INTERVAL)
	_separation_timer = _rng.randf_range(0.0, SEPARATION_INTERVAL)
	_state_timer = _rng.randf_range(1.0, 2.6)
	_strafe_timer = _rng.randf_range(1.2, 2.8)
	_idle_scan_dir = 1.0 if _rng.randf() < 0.5 else -1.0
	_spawn_position = global_position if is_inside_tree() else position
	_last_known = _spawn_position
	_set_state(State.IDLE)
	if _hover > 0.01:
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	set_physics_process(true)


func _apply_affix_to_stats(max_health: float, max_shield: float, armor: float) -> void:
	_affix_health = max_health
	_affix_shield = max_shield
	_affix_armor = armor
	match elite_affix:
		AFFIX_ARMORED:
			_affix_armor += 55.0
		AFFIX_SHIELDED:
			_affix_shield += max_health * 0.6
		AFFIX_BERSERK:
			move_speed *= 1.22
			attack_interval *= 0.8
			attack_damage *= 1.12
			_affix_health *= 0.92
		AFFIX_VOLATILE:
			_affix_health *= 1.05
		_:
			pass


func _build_health_bar() -> void:
	if health == null:
		return
	_health_bar = HEALTH_BAR_SCRIPT.new()
	_health_bar.name = "HealthBar"
	_health_bar.position = Vector3(0.0, maxf(1.1, _height + 0.2), 0.0)
	add_child(_health_bar)
	var elite := (enemy_data != null and (enemy_data.elite or enemy_data.boss))
	_health_bar.call("setup", health.max_health, health.max_shield, elite)
	_health_bar.set("visibility_range", 120.0 if is_boss() else (80.0 if is_elite() else 55.0))
	_health_bar.call("set_values", health.health, health.max_health, health.shield, health.max_shield)
	_health_bar_force = 2.0


func get_health_bar() -> Node3D:
	return _health_bar


func _refresh_health_bar() -> void:
	if _health_bar == null or health == null or not is_instance_valid(_health_bar):
		return
	_health_bar.call("set_values", health.health, health.max_health, health.shield, health.max_shield)


func _on_shield_changed(_current: float, _maximum: float) -> void:
	_refresh_health_bar()


func _build_collision() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = float(visuals["radius"])
	capsule.height = maxf(capsule.radius * 2.0 + 0.1, float(visuals["capsule_h"]))
	var body_shape := CollisionShape3D.new()
	body_shape.name = "Collision"
	body_shape.shape = capsule
	body_shape.position = Vector3(0.0, _hover + capsule.height * 0.5, 0.0)
	add_child(body_shape)

	var weak_shape := CollisionShape3D.new()
	weak_shape.name = "Weakpoint"
	var weak_sphere := SphereShape3D.new()
	weak_sphere.radius = float(visuals["weak_radius"])
	weak_shape.shape = weak_sphere
	weak_shape.position = _weak_local
	weak_shape.set_meta("weakpoint_mult", weakpoint_mult)
	add_child(weak_shape)


func _build_navigation() -> void:
	nav_agent = NavigationAgent3D.new()
	nav_agent.name = "NavigationAgent3D"
	nav_agent.path_desired_distance = 0.9
	nav_agent.target_desired_distance = 1.2
	nav_agent.radius = maxf(0.3, float(visuals["radius"]))
	nav_agent.height = maxf(0.5, float(visuals["capsule_h"]))
	nav_agent.avoidance_enabled = false
	nav_agent.max_speed = move_speed
	nav_agent.path_max_distance = 6.0
	add_child(nav_agent)


func _build_telegraph() -> void:
	_telegraph = MeshInstance3D.new()
	_telegraph.name = "AttackTelegraph"
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	sphere.radial_segments = 8
	sphere.rings = 4
	_telegraph.mesh = sphere
	var color: Color = enemy_data.accent_color if enemy_data != null else Color("ffb866")
	_telegraph.material_override = EnemyVisuals.make_material(color, 3.4, 0.0, 0.3, true)
	_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_telegraph.visible = false
	_visual_root.add_child(_telegraph)
	if _muzzle != null:
		_telegraph.position = _muzzle.position


func _build_marker() -> void:
	_marker = Node3D.new()
	_marker.name = "MarkedMarker"
	_marker.position = Vector3(0.0, maxf(0.9, _height + 0.55), 0.0)
	var label := Label3D.new()
	label.name = "MarkLabel"
	label.text = "MARKED"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 26
	label.outline_size = 7
	label.modulate = Color("ffb866")
	label.outline_modulate = Color(0.02, 0.03, 0.04, 0.85)
	_marker.add_child(label)
	var diamond := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.16, 0.22, 0.16)
	diamond.mesh = prism
	diamond.material_override = EnemyVisuals.make_material(Color("ffb866"), 2.8, 0.0, 0.3, true)
	diamond.position = Vector3(0.0, -0.28, 0.0)
	diamond.rotation.z = PI
	diamond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.add_child(diamond)
	_marker.visible = false
	add_child(_marker)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func get_health_component() -> HealthComponent:
	return health


func get_enemy_data() -> EnemyData:
	return enemy_data


func is_boss() -> bool:
	return enemy_data != null and enemy_data.boss


func is_elite() -> bool:
	return enemy_data != null and enemy_data.elite


func is_alive() -> bool:
	return _built and not _dead and health != null and not health.dead


func is_flyer() -> bool:
	return style == &"flyer"


func get_elite_affix() -> StringName:
	return elite_affix


func get_threat() -> int:
	return threat_level


func get_display_name() -> String:
	return display_name


func get_state_name() -> String:
	return State.keys()[state].to_lower()


func get_boss_phase() -> int:
	return boss_phase


func get_marked_remaining() -> float:
	return _marked_timer


func get_target_node() -> Node3D:
	return _target


func get_spawn_position() -> Vector3:
	return _spawn_position


func get_shot_count() -> int:
	return shots_fired


func get_melee_count() -> int:
	return melee_attacks


func get_loot_dropped_count() -> int:
	return loot_dropped


func uses_navigation() -> bool:
	return _nav_available


func get_debug_info() -> Dictionary:
	return {
		"state": get_state_name(),
		"target": _target.get_instance_id() if (_target != null and is_instance_valid(_target)) else 0,
		"visible": _can_see(_target, vision_range) if (_target != null and is_instance_valid(_target)) else false,
		"attack_timer": _attack_timer,
		"telegraph": _telegraph_timer,
		"pending": String(_pending_attack),
		"stun": _stun_timer,
		"shots": shots_fired,
		"nav": _nav_available,
		"hp": health.health if health != null else 0.0,
		"pos": global_position,
	}


func apply_pull(target: Vector3, strength: float, duration: float) -> void:
	if _dead:
		return
	_pull_target = target
	_pull_strength = clampf(strength, 0.0, 20.0)
	_pull_time = maxf(_pull_time, maxf(0.05, duration))


func hear_noise(origin: Vector3, radius: float) -> void:
	if _dead or not _built:
		return
	var distance := global_position.distance_to(origin)
	if distance > maxf(0.0, radius):
		return
	if state == State.ENGAGE or state == State.FLEE:
		return
	_last_known = origin
	_has_seen = true
	_memory_left = maxf(_memory_left, 4.5)
	if state == State.IDLE or state == State.PATROL:
		_set_state(State.SEARCH)
	elif state == State.SEARCH:
		_state_timer = maxf(_state_timer, 2.5)
	if distance <= 12.0 and _player != null and is_instance_valid(_player) and _can_see(_player, vision_range):
		_target = _player
		_set_state(State.ENGAGE)


func set_marked(duration: float) -> void:
	if _dead:
		return
	_marked_timer = maxf(_marked_timer, maxf(0.1, duration))
	if _marker != null:
		_marker.visible = true


# ---------------------------------------------------------------------------
# Physics tick
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _built:
		return
	if _dead:
		_grave_tick(delta)
		return
	_tick_timers(delta)
	_tick_effects(delta)
	if _stun_timer > 0.0:
		_apply_locked_movement(delta)
		return
	_update_perception(delta)
	_update_behavior(delta)
	_update_movement(delta)


func _tick_timers(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_state_timer -= delta
	_memory_left = maxf(0.0, _memory_left - delta)
	_recover_timer = maxf(0.0, _recover_timer - delta)
	_cover_timer = maxf(0.0, _cover_timer - delta)
	_marked_timer = maxf(0.0, _marked_timer - delta)
	_slow_timer = maxf(0.0, _slow_timer - delta)
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = _rng.randf_range(1.2, 2.6)
		_strafe_dir = -_strafe_dir
	if _marker != null:
		_marker.visible = _marked_timer > 0.0
	_health_bar_force = maxf(0.0, _health_bar_force - delta)
	_health_bar_timer -= delta
	if _health_bar_timer <= 0.0:
		_health_bar_timer = 0.2
		if _health_bar != null and is_instance_valid(_health_bar):
			var distance := INF
			if _player != null and is_instance_valid(_player):
				distance = global_position.distance_to(_player.global_position)
			_health_bar.call("set_visibility_for_distance", distance, _health_bar_force > 0.0)
	_separation_timer -= delta
	if _separation_timer <= 0.0:
		_separation_timer = SEPARATION_INTERVAL
		_compute_separation()
	if _boss_charge_time > 0.0:
		_boss_charge_time = maxf(0.0, _boss_charge_time - delta)
	if _telegraph_timer > 0.0:
		_telegraph_timer -= delta
		var progress := 1.0 - clampf(_telegraph_timer / maxf(0.001, _telegraph_duration_value), 0.0, 1.0)
		if _telegraph != null and _telegraph.visible:
			_telegraph.scale = Vector3.ONE * lerpf(0.5, 2.1, progress)
		if _telegraph_timer <= 0.0:
			_show_telegraph(false)
			_execute_attack()


func _tick_effects(delta: float) -> void:
	if _burn_timer > 0.0:
		_burn_timer = maxf(0.0, _burn_timer - delta)
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			_apply_dot(_burn_dps * 0.5)
		if _burn_timer <= 0.0:
			_burn_dps = 0.0
	if _armor_timer > 0.0:
		_armor_timer = maxf(0.0, _armor_timer - delta)
		if _armor_timer <= 0.0 and health != null and not health.dead:
			health.set_armor(_base_armor)
	if _pull_time > 0.0:
		_pull_time = maxf(0.0, _pull_time - delta)
	if is_boss() and health != null and not health.dead:
		_check_phase()


func _apply_locked_movement(delta: float) -> void:
	if is_flyer():
		var target_y := _ground_height() + _hover + sin(Time.get_ticks_msec() * 0.0013 + _spawn_position.x) * 0.12
		velocity.y = clampf((target_y - global_position.y) * 2.0, -4.0, 4.0)
	else:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		elif velocity.y < 0.0:
			velocity.y = 0.0
	velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)
	move_and_slide()


# ---------------------------------------------------------------------------
# Perception
# ---------------------------------------------------------------------------

func _update_perception(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_target_refresh_timer -= delta
		if _target_refresh_timer <= 0.0:
			_target_refresh_timer = 1.0
			_player = get_tree().get_first_node_in_group("player") as Node3D
	_perception_timer -= delta
	if _perception_timer > 0.0:
		return
	_perception_timer = PERCEPTION_INTERVAL
	var player_distance := _distance_to_player()
	if player_distance > MAX_AI_DISTANCE + 40.0 and not is_boss():
		_target = null
		_has_seen = false
		if state == State.ENGAGE or state == State.SEARCH or state == State.FLEE:
			_set_state(State.IDLE)
	if player_distance > MAX_AI_DISTANCE and state != State.ENGAGE and state != State.FLEE:
		return
	_perceive()


func _perceive() -> void:
	var found := _find_visible_target()
	if found != null:
		_target = found
		_last_known = found.global_position
		_has_seen = true
		_memory_left = 6.0
		if state != State.ENGAGE and state != State.FLEE:
			_set_state(State.ENGAGE)
			_attack_timer = minf(_attack_timer, _rng.randf_range(0.25, 0.7))
		return
	if _target != null and (not is_instance_valid(_target) or _memory_left <= 0.0):
		_target = null
		if state == State.ENGAGE or state == State.FLEE:
			_set_state(State.SEARCH)


func _find_visible_target() -> Node3D:
	if _player != null and is_instance_valid(_player) and not _is_incapacitated(_player):
		if _can_see(_player, vision_range):
			return _player
	return _find_visible_ally()


func _find_visible_ally() -> Node3D:
	_ally_scan_timer -= PERCEPTION_INTERVAL
	if _ally_scan_timer <= 0.0:
		_ally_scan_timer = ALLY_SCAN_INTERVAL
		_allies.clear()
		for node in get_tree().get_nodes_in_group("allies"):
			if node is Node3D:
				_allies.append(node as Node3D)
	if _allies.is_empty():
		return null
	var best: Node3D = null
	var best_distance := vision_range
	for ally in _allies:
		if not is_instance_valid(ally) or _is_incapacitated(ally):
			continue
		var distance := global_position.distance_to(ally.global_position)
		if distance < best_distance and _can_see(ally, vision_range):
			best = ally
			best_distance = distance
	return best


func _is_incapacitated(node: Node) -> bool:
	if node == null:
		return true
	# Duck-typed on purpose: Player exposes is_dead/is_downed as bool properties,
	# AllyAgent exposes is_downed() as a method. Never use bool(...) conversions
	# here (Godot 4.7 rejects them for these reads) and never trust Object.get()
	# to be a bool when the member is a method (it returns a Callable).
	if _read_bool_member(node, "is_dead"):
		return true
	if _read_bool_member(node, "is_downed"):
		return true
	return false


func _read_bool_member(node: Node, member_name: String) -> bool:
	if node == null:
		return false
	if member_name in node:
		var value = node.get(member_name)
		if value is bool:
			return value
	if node.has_method(member_name):
		var result = node.call(member_name)
		if result is bool:
			return result
	return false


func _can_see(node: Node3D, max_range: float) -> bool:
	if node == null or not is_instance_valid(node) or not is_inside_tree():
		return false
	var eye := _eye_position()
	var target_position: Vector3 = node.global_position + Vector3.UP * 1.1
	var to_target := target_position - eye
	var distance := to_target.length()
	if distance > max_range or distance < 0.05:
		return false
	if distance > 6.5:
		var forward := -global_transform.basis.z
		if forward.dot(to_target / distance) < 0.34:
			return false
	if _read_bool_member(node, "is_cloaked"):
		return distance <= 4.5
	var query := PhysicsRayQueryParameters3D.create(eye, target_position, 1, [get_rid()])
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()


func _eye_position() -> Vector3:
	return global_position + Vector3.UP * _eye_height


func _distance_to_player() -> float:
	if _player != null and is_instance_valid(_player):
		return global_position.distance_to(_player.global_position)
	return 99999.0


func _flat_direction_to(target_position: Vector3) -> Vector3:
	var offset := target_position - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.0001:
		return Vector3.ZERO
	return offset.normalized()


# ---------------------------------------------------------------------------
# Behavior FSM
# ---------------------------------------------------------------------------

func _set_state(new_state: State) -> void:
	if new_state == State.ENGAGE and state == State.ENGAGE:
		return
	if new_state != State.ENGAGE and new_state != State.FLEE:
		_cancel_telegraph()
	match new_state:
		State.IDLE:
			_state_timer = _rng.randf_range(1.4, 3.0)
			_move_speed_scale = 0.0
			_has_move_goal = false
		State.PATROL:
			_pick_patrol_goal()
			_state_timer = _rng.randf_range(3.5, 6.5)
			_move_speed_scale = 0.42
		State.SEARCH:
			_state_timer = _rng.randf_range(3.0, 4.5)
			_move_speed_scale = 0.85
		State.ENGAGE:
			_attack_timer = minf(_attack_timer, _rng.randf_range(0.2, 0.6))
			_strafe_timer = _rng.randf_range(1.2, 2.6)
			_move_speed_scale = 1.0
		State.FLEE:
			_state_timer = _rng.randf_range(2.5, 4.0)
			_recover_timer = 8.0
			_move_speed_scale = 1.12
		State.DEAD:
			_has_move_goal = false
			_move_speed_scale = 0.0
	state = new_state


func _update_behavior(delta: float) -> void:
	_face_target = false
	if _distance_to_player() > MAX_AI_DISTANCE and state != State.ENGAGE and state != State.FLEE:
		_has_move_goal = false
		return
	match state:
		State.IDLE:
			_behavior_idle(delta)
		State.PATROL:
			_behavior_patrol(delta)
		State.SEARCH:
			_behavior_search(delta)
		State.ENGAGE:
			_behavior_engage(delta)
		State.FLEE:
			_behavior_flee(delta)
		State.DEAD:
			pass


func _behavior_idle(delta: float) -> void:
	_has_move_goal = false
	_move_speed_scale = 0.0
	rotation.y += delta * 0.45 * _idle_scan_dir
	if _state_timer <= 0.0:
		if _rng.randf() < 0.55:
			_set_state(State.PATROL)
		else:
			_idle_scan_dir = -_idle_scan_dir
			_state_timer = _rng.randf_range(1.5, 3.0)


func _behavior_patrol(_delta: float) -> void:
	_has_move_goal = true
	_move_goal = _patrol_goal
	_move_speed_scale = 0.42
	if global_position.distance_squared_to(_patrol_goal) < 2.2 or _state_timer <= 0.0:
		_set_state(State.IDLE)
		_state_timer = _rng.randf_range(1.2, 2.8)


func _behavior_search(delta: float) -> void:
	_has_move_goal = true
	_move_goal = _last_known
	_move_speed_scale = 0.85
	if global_position.distance_squared_to(_last_known) < 2.5:
		_has_move_goal = false
		rotation.y += delta * 1.2 * _strafe_dir
	if _state_timer <= 0.0:
		_set_state(State.IDLE)


func _behavior_engage(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_target = null
		_set_state(State.SEARCH)
		return
	var target_position: Vector3 = _target.global_position
	var visible := _can_see(_target, vision_range)
	if visible:
		_last_known = target_position
		_memory_left = 6.0
	elif _memory_left <= 0.0:
		_target = null
		_set_state(State.SEARCH)
		return
	var distance := global_position.distance_to(target_position)
	var flat := _flat_direction_to(target_position)

	if _should_flee():
		_set_state(State.FLEE)
		return

	if visible:
		_face_target = true
		if _attack_timer <= 0.0 and _telegraph_timer <= 0.0 and _stun_timer <= 0.0:
			_start_attack(distance)

	_boss_charge_timer -= delta
	if is_boss() and boss_phase >= 2 and _boss_charge_timer <= 0.0 and distance > 9.0:
		_boss_charge_timer = _rng.randf_range(6.5, 9.0)
		_boss_charge_time = 1.2
	if _boss_charge_time > 0.0 and _target != null:
		_has_move_goal = true
		_move_goal = target_position
		_move_speed_scale = 1.65
		return

	_has_move_goal = true
	if not visible:
		_move_goal = _last_known
		_move_speed_scale = 0.9
	else:
		_move_goal = _engage_goal(delta, distance, flat)
		_move_speed_scale = 1.0


func _behavior_flee(delta: float) -> void:
	_move_speed_scale = 1.12
	if _target == null or not is_instance_valid(_target):
		_set_state(State.ENGAGE)
		return
	_has_move_goal = true
	var away := _flat_direction_to(_target.global_position)
	_move_goal = _ground_point(global_position - away * 9.0 + Vector3(
		_rng.randf_range(-2.0, 2.0), 0.0, _rng.randf_range(-2.0, 2.0)
	), global_position.y)
	rotation.y += delta * 0.3 * _strafe_dir
	if _state_timer <= 0.0:
		_set_state(State.ENGAGE)


func _engage_goal(delta: float, distance: float, flat: Vector3) -> Vector3:
	if _target == null:
		return global_position
	if is_boss():
		if distance > preferred_range + 5.0:
			return _target.global_position
		if distance < preferred_range - 6.0:
			return global_position - flat * 5.0
		return _target.global_position if not ranged else _strafe_point(flat, 3.5)
	if not ranged:
		return _target.global_position
	if health != null and health.get_health_fraction() < 0.45 and not is_boss():
		if _cover_timer <= 0.0:
			_cover_timer = _rng.randf_range(4.5, 7.0)
			var cover := _find_cover_point()
			if cover != Vector3.ZERO:
				_cover_goal = cover
				_cover_active = true
		if _cover_active:
			if global_position.distance_squared_to(_cover_goal) < 2.2:
				_cover_active = false
			else:
				return _cover_goal
	if distance > preferred_range + 4.0:
		return _target.global_position
	if distance < preferred_range - 5.0:
		return _ground_point(global_position - flat * 4.5, global_position.y)
	return _strafe_point(flat, 4.0)


func _strafe_point(flat: Vector3, amount: float) -> Vector3:
	var tangent := Vector3(-flat.z, 0.0, flat.x) * _strafe_dir
	var point := global_position + tangent * amount + flat * 0.6
	return _ground_point(point, global_position.y)


func _pick_patrol_goal() -> void:
	var angle := _rng.randf_range(0.0, TAU)
	var radius := _rng.randf_range(3.0, 14.0)
	var candidate := _spawn_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	if _hover > 0.01:
		_patrol_goal = candidate
		return
	_patrol_goal = _ground_point(candidate, _spawn_position.y)


func _ground_point(xz: Vector3, fallback_y: float) -> Vector3:
	var from := Vector3(xz.x, global_position.y + 4.0, xz.z)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 12.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var landed: Vector3 = hit["position"]
		return landed + Vector3.UP * 0.05
	return Vector3(xz.x, fallback_y, xz.z)


func _ground_height() -> float:
	var from := global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 60.0, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var landed: Vector3 = hit["position"]
		return landed.y
	return global_position.y - _hover


func _find_cover_point() -> Vector3:
	if not is_inside_tree() or _target == null:
		return Vector3.ZERO
	var space := get_world_3d().direct_space_state
	var best_distance := 0.0
	var best := Vector3.ZERO
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var candidate := global_position + direction * 7.0
		candidate = _ground_point(candidate, global_position.y)
		var eye := candidate + Vector3.UP * 1.4
		var target_head := _target.global_position + Vector3.UP * 1.2
		var query := PhysicsRayQueryParameters3D.create(eye, target_head, 1)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		# Point is only useful if the enemy can still peek at the target.
		var score := global_position.distance_to(candidate)
		if score > best_distance:
			best_distance = score
			best = candidate
	return best


func _should_flee() -> bool:
	if is_boss() or health == null or health.dead:
		return false
	if _recover_timer > 0.0:
		return false
	if health.get_health_fraction() > 0.25:
		return false
	if ranged and (role == &"marksman" or role == &"support" or role == &"flyer"):
		return true
	return false


# ---------------------------------------------------------------------------
# Attacks
# ---------------------------------------------------------------------------

func _can_attack(distance: float) -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	if not ranged:
		return distance <= attack_range * 1.1
	if distance > attack_range:
		return false
	return _can_see(_target, attack_range + 8.0)


func _start_attack(distance: float) -> void:
	if not _can_attack(distance):
		return
	_face_target = true
	var duration := 0.42
	_pending_attack = &"ranged" if ranged else &"melee"
	if is_boss():
		_boss_attack_count += 1
		duration = 0.5
		var target_distance := global_position.distance_to(_target.global_position) if _target != null else 999.0
		if boss_phase >= 2 and target_distance <= 8.0:
			_pending_attack = &"slam"
			duration = 0.62
	_telegraph_duration_value = duration
	_telegraph_timer = duration
	_show_telegraph(true)
	if _telegraph != null:
		_telegraph.scale = Vector3.ONE * 0.5


func _show_telegraph(visible_state: bool) -> void:
	if _telegraph != null:
		_telegraph.visible = visible_state


func _cancel_telegraph() -> void:
	_telegraph_timer = 0.0
	_pending_attack = &""
	_show_telegraph(false)


func _execute_attack() -> void:
	var attack := _pending_attack
	_pending_attack = &""
	match attack:
		&"melee":
			_do_melee()
		&"slam":
			_do_slam()
		&"ranged":
			_do_ranged()
		_:
			pass


func _do_ranged() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var origin := _muzzle_position()
	var aim := _predict_aim(origin)
	var base_direction := aim - origin
	if base_direction.length_squared() < 0.0001:
		return
	base_direction = base_direction.normalized()
	var count := 1
	var spread_degrees := 2.0
	match role:
		&"marksman":
			spread_degrees = 0.8
		&"support":
			spread_degrees = 3.0
		_:
			spread_degrees = 2.2
	if is_boss():
		if boss_phase >= 2:
			count = 3
			spread_degrees = 4.5
		if boss_phase >= 3:
			count = 5
			spread_degrees = 3.5
	var fx_parent := _fx_parent()
	for i in count:
		var direction := base_direction
		if count > 1:
			var offset := (float(i) - float(count - 1) * 0.5) * spread_degrees
			direction = base_direction.rotated(Vector3.UP, deg_to_rad(offset))
		elif spread_degrees > 0.01:
			direction = base_direction.rotated(Vector3.UP, deg_to_rad(_rng.randf_range(-spread_degrees, spread_degrees)))
		EnemyProjectile.spawn(fx_parent, origin, direction, projectile_speed, attack_damage, self, _bolt_color(), _bolt_damage_type())
		shots_fired += 1
	_attack_timer = _attack_interval_value()
	CombatVFX.muzzle_flash(fx_parent, origin, _bolt_color())
	_play_audio(_shot_sound(), origin, -8.0)


func _do_melee() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var target_position: Vector3 = _target.global_position + Vector3.UP * 1.0
	var distance := global_position.distance_to(_target.global_position)
	if distance <= attack_range * 1.7:
		var data := DamageData.make(attack_damage, TEAM, StatKeys.DMG_KINETIC, self)
		data.hit_position = target_position
		data.hit_normal = _flat_direction_to(_target.global_position) * -1.0
		data.is_melee = true
		CombatUtils.apply_hit(_target, data)
		var fx_parent := _fx_parent()
		CombatVFX.spawn_tracer(fx_parent, _muzzle_position(), target_position, _bolt_color())
		CombatVFX.impact(fx_parent, target_position, Vector3.UP, _bolt_color())
		_play_audio(&"hit", target_position, -8.0)
	melee_attacks += 1
	_attack_timer = _attack_interval_value()
	var lunge := _flat_direction_to(_target.global_position) * 4.2
	velocity.x += lunge.x
	velocity.z += lunge.z
	if not is_flyer() and is_on_floor():
		velocity.y = 2.2


func _do_slam() -> void:
	var fx_parent := _fx_parent()
	_enemy_aoe(global_position, 7.0, attack_damage * 1.5, StatKeys.DMG_KINETIC)
	CombatVFX.explosion(fx_parent, global_position + Vector3.UP * 0.4, 6.0, _bolt_color())
	CombatVFX.ring(fx_parent, global_position + Vector3.UP * 0.1, 6.5, _bolt_color(), 0.55)
	_play_audio(&"explosion", global_position, -3.0)
	_attack_timer = maxf(1.1, attack_interval * 1.5)


## AoE helper that includes the Player layer (8 == Friendly, 2 == Player).
## CombatUtils.aoe_damage intentionally excludes layer 2, so enemy hazards use this.
func _enemy_aoe(origin: Vector3, radius: float, damage: float, damage_type: StringName) -> int:
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, origin)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.collision_mask = 2 | 8
	var results := space.intersect_shape(params, 24)
	var seen: Dictionary = {}
	var count := 0
	for result in results:
		var collider = result.get("collider")
		if collider == null or seen.has(collider.get_instance_id()):
			continue
		seen[collider.get_instance_id()] = true
		var target_health := CombatUtils.find_health(collider)
		if target_health == null or target_health.dead or target_health.team == TEAM:
			continue
		var center: Vector3 = origin
		var parent := target_health.get_parent()
		if parent is Node3D:
			center = (parent as Node3D).global_position
		var falloff := clampf(1.0 - origin.distance_to(center) / maxf(radius, 0.1), 0.3, 1.0)
		var data := DamageData.make(damage * falloff, TEAM, damage_type, self)
		data.hit_position = center
		target_health.take_damage(data)
		count += 1
	return count


func _attack_interval_value() -> float:
	return maxf(0.3, attack_interval * _rng.randf_range(0.86, 1.16))


func _predict_aim(origin: Vector3) -> Vector3:
	var target_position: Vector3 = _target.global_position + Vector3.UP * 1.05
	var travel := clampf(origin.distance_to(target_position) / maxf(8.0, projectile_speed), 0.0, 1.6)
	var target_velocity := Vector3.ZERO
	if _target is CharacterBody3D:
		target_velocity = (_target as CharacterBody3D).velocity
	return target_position + target_velocity * travel * 0.55


func _muzzle_position() -> Vector3:
	if _muzzle != null and is_instance_valid(_muzzle):
		return _muzzle.global_position
	return _eye_position()


func _bolt_color() -> Color:
	var data := enemy_data
	if data == null:
		return Color("ffb866")
	return data.eye_color if data.eye_color != Color.BLACK else data.accent_color


func _bolt_damage_type() -> StringName:
	match style:
		&"beast":
			return StatKeys.DMG_CORROSIVE
		&"flyer":
			return StatKeys.DMG_SHOCK
		_:
			return StatKeys.DMG_ENERGY


func _shot_sound() -> StringName:
	match style:
		&"beast":
			return &"shot_carbine"
		&"flyer":
			return &"shot_arc"
		&"heavy", &"titan":
			return &"shot_lmg"
		_:
			return &"shot_pistol"


# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

func _update_movement(delta: float) -> void:
	var desired := Vector3.ZERO
	if _has_move_goal:
		var direction := _steer_direction(delta)
		var speed := move_speed * _current_speed_scale()
		desired = direction * speed
	desired += _separation * 1.3
	if _pull_time > 0.0:
		var pull_offset := _pull_target - global_position
		if pull_offset.length_squared() > 0.01:
			desired += pull_offset.normalized() * _pull_strength

	var accel := 34.0 if _has_move_goal else 22.0
	velocity.x = move_toward(velocity.x, desired.x, accel * delta)
	velocity.z = move_toward(velocity.z, desired.z, accel * delta)

	if is_flyer():
		var hover_y := _ground_height() + _hover
		var bob := sin(Time.get_ticks_msec() * 0.0013 + _spawn_position.x) * 0.12
		velocity.y = clampf((hover_y + bob - global_position.y) * 2.2, -5.0, 5.0)
	else:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		elif velocity.y < 0.0:
			velocity.y = 0.0
		# Unstick: hop over low cover when pushing against world geometry.
		var horizontal_speed := Vector3(velocity.x, 0.0, velocity.z).length()
		if _has_move_goal and horizontal_speed < 0.7 and desired.length_squared() > 1.0:
			_stuck_timer += delta
		else:
			_stuck_timer = 0.0
		if _stuck_timer > 0.7:
			_stuck_timer = 0.0
			if is_on_floor() and _rng.randf() < 0.6:
				velocity.y = 5.4
			if state == State.PATROL:
				_pick_patrol_goal()
	move_and_slide()

	if _face_target and _target != null and is_instance_valid(_target):
		_face_towards(_flat_direction_to(_target.global_position), delta, 10.0)
	elif desired.length_squared() > 0.05:
		_face_towards(Vector3(desired.x, 0.0, desired.z).normalized(), delta, 7.0)


func _steer_direction(delta: float) -> Vector3:
	_nav_probe_timer -= delta
	if _nav_probe_timer <= 0.0:
		_nav_probe_timer = NAV_PROBE_INTERVAL
		_probe_navigation()
	if _nav_available and nav_agent != null:
		if nav_agent.target_position.distance_squared_to(_move_goal) > 2.25:
			nav_agent.target_position = _move_goal
		var next := nav_agent.get_next_path_position()
		var nav_direction := next - global_position
		nav_direction.y = 0.0
		if nav_direction.length_squared() > 0.04:
			return nav_direction.normalized()
	var flat := _move_goal - global_position
	flat.y = 0.0
	if flat.length_squared() > 0.01:
		return flat.normalized()
	return Vector3.ZERO


func _probe_navigation() -> void:
	_nav_available = false
	if nav_agent == null or not is_inside_tree():
		return
	var map := nav_agent.get_navigation_map()
	if not map.is_valid():
		return
	var regions := NavigationServer3D.map_get_regions(map)
	if regions.is_empty():
		return
	var destination := _move_goal if _has_move_goal else global_position + Vector3(3.0, 0.0, 0.0)
	var path := NavigationServer3D.map_get_path(map, global_position, destination, true, 1)
	_nav_available = path.size() >= 2


func _current_speed_scale() -> float:
	var scale := _move_speed_scale
	if _slow_timer > 0.0:
		scale *= 0.55
	if _pull_time > 0.0:
		scale *= 0.45
	return scale


func _face_towards(direction: Vector3, delta: float, speed: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-flat.x, -flat.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * speed))


func _compute_separation() -> void:
	_separation = Vector3.ZERO
	if not is_inside_tree():
		return
	var processed := 0
	for node in get_tree().get_nodes_in_group("enemy_ai"):
		if node == self or not (node is Node3D):
			continue
		if processed >= 12:
			break
		var other := node as Node3D
		if not is_instance_valid(other):
			continue
		var offset := global_position - other.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > 0.05 and distance < 3.0:
			_separation += offset / distance * (1.0 - distance / 3.0)
			processed += 1
	_separation = _separation.limit_length(1.6)


# ---------------------------------------------------------------------------
# Status effects
# ---------------------------------------------------------------------------

func _on_status_applied(status_type: StringName, power: float, duration: float) -> void:
	if _dead:
		return
	match status_type:
		StatKeys.STATUS_SHOCK:
			_stun_timer = maxf(_stun_timer, clampf(0.35 + duration * 0.25, 0.35, 1.25))
			_slow_timer = maxf(_slow_timer, duration * 0.8)
			_cancel_telegraph()
			_impact_flash(Color("9fdcff"))
			_spawn_status_vfx(Color("9fdcff"))
		StatKeys.STATUS_BURN:
			_burn_timer = maxf(_burn_timer, maxf(1.0, duration))
			_burn_dps = maxf(_burn_dps, maxf(2.0, power * 2.5))
			_burn_tick = minf(_burn_tick, 0.25)
			_impact_flash(Color("ff9a5c"))
			_spawn_status_vfx(Color("ff9a5c"))
		StatKeys.STATUS_CORRODE:
			_apply_corrode(duration)
			_impact_flash(Color("a6e36e"))
			_spawn_status_vfx(Color("a6e36e"))
		StatKeys.STATUS_SLOW:
			_slow_timer = maxf(_slow_timer, duration)
			_spawn_status_vfx(Color("8fb4ff"))
		_:
			pass


func _apply_corrode(duration: float) -> void:
	if health == null or health.dead:
		return
	if _armor_timer <= 0.0:
		_base_armor = health.armor
	_armor_timer = maxf(_armor_timer, maxf(0.5, duration))
	health.set_armor(maxf(0.0, _base_armor * 0.55))


func _apply_dot(amount: float) -> void:
	if health == null or health.dead:
		return
	var data := DamageData.make(amount, StatKeys.TEAM_NEUTRAL, StatKeys.DMG_BURN, null)
	data.hit_position = global_position + Vector3.UP
	health.take_damage(data)


func _spawn_status_vfx(color: Color) -> void:
	var parent := _fx_parent()
	if parent == null:
		return
	CombatVFX.impact(parent, global_position + Vector3.UP * maxf(0.6, _eye_height * 0.8), Vector3.UP, color)


# ---------------------------------------------------------------------------
# Damage, death and loot
# ---------------------------------------------------------------------------

func _on_damaged(info: Dictionary) -> void:
	if _dead:
		return
	_health_bar_force = 4.0
	_refresh_health_bar()
	_flash_hit()
	_play_audio(&"hit", global_position, -16.0)
	if is_boss():
		_check_phase()
	var source = info.get("source", null)
	if source is Node3D and is_instance_valid(source) and not _is_friendly_source(source):
		_target = source as Node3D
		_last_known = (_target as Node3D).global_position
		_has_seen = true
		_memory_left = 7.0
		if state == State.IDLE or state == State.PATROL or state == State.SEARCH:
			_set_state(State.ENGAGE)


func _is_friendly_source(source: Node) -> bool:
	if source == null:
		return true
	return source.is_in_group("enemy_ai")


func _check_phase() -> void:
	if not is_boss() or health == null or health.dead:
		return
	var phases := maxi(1, enemy_data.boss_phases)
	if phases <= 1:
		return
	var desired := 1 + int((1.0 - health.get_health_fraction()) * float(phases))
	desired = clampi(desired, 1, phases)
	if desired > boss_phase:
		_enter_phase(desired)


func _enter_phase(phase: int) -> void:
	boss_phase = phase
	_attack_timer = 0.8
	_boss_charge_timer = minf(_boss_charge_timer, 2.0)
	_cancel_telegraph()
	if health != null:
		health.set_invulnerable(0.7)
		health.restore_shield(health.max_shield * 0.35)
	var parent := _fx_parent()
	if parent != null:
		CombatVFX.ring(parent, global_position + Vector3.UP * 0.2, 7.5, _bolt_color(), 0.9)
		CombatVFX.explosion(parent, global_position + Vector3.UP * 1.4, 3.2, _bolt_color())
	_play_audio(&"storm", global_position, 0.0)
	_impact_flash(_bolt_color())
	if _event_bus != null:
		_event_bus.emit_signal("notification_requested", "%s - Phase %d" % [display_name, phase], _phase_line(phase), &"danger")
		_event_bus.emit_signal("radio_message", display_name, _phase_line(phase))


func _phase_line(phase: int) -> String:
	match phase:
		2:
			return "The reach answers. You are still standing in it."
		3:
			return "Everything here ends with me."
	return "Enough. Now you see what I am."


func _on_died() -> void:
	if _dead:
		return
	_dead = true
	state = State.DEAD
	_has_move_goal = false
	_move_speed_scale = 0.0
	_grave_time = 0.0
	_cancel_telegraph()
	if _health_bar != null and is_instance_valid(_health_bar):
		_health_bar.visible = false
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if nav_agent != null:
		nav_agent.target_position = global_position
		nav_agent.avoidance_enabled = false
		nav_agent.set_physics_process(false)
	_spawn_death_vfx()
	_roll_loot()
	_report_kill()
	defeated.emit(self)


func _spawn_death_vfx() -> void:
	var parent := _fx_parent()
	if parent == null:
		return
	if enemy_data != null and "volatile_death" in enemy_data.behavior_flags:
		_enemy_aoe(global_position, 4.5, attack_damage * 1.6, StatKeys.DMG_KINETIC)
		CombatVFX.ring(parent, global_position + Vector3.UP * 0.1, 4.5, Color("ff7a4a"), 0.55)
		CombatVFX.explosion(parent, global_position + Vector3.UP * 0.6, 3.6, Color("ff7a4a"))
		_play_audio(&"explosion", global_position, -3.0)
	var radius := 5.5 if is_boss() else 1.7
	CombatVFX.explosion(parent, global_position + Vector3.UP * minf(1.4, _height * 0.5), radius, _bolt_color())
	CombatVFX.impact(parent, global_position + Vector3.UP * (_height * 0.6), Vector3.UP, _bolt_color())
	if is_boss():
		CombatVFX.ring(parent, global_position + Vector3.UP * 0.15, 10.0, _bolt_color(), 1.2)
	_play_audio(&"explosion" if is_boss() else &"kill", global_position, 0.0 if is_boss() else -4.0)
	if elite_affix == AFFIX_VOLATILE:
		_enemy_aoe(global_position, 5.5, attack_damage * 1.2, StatKeys.DMG_KINETIC)
		CombatVFX.ring(parent, global_position + Vector3.UP * 0.1, 5.5, Color("ff7a4a"), 0.6)
		CombatVFX.explosion(parent, global_position + Vector3.UP * 0.5, 4.0, Color("ff7a4a"))
		_play_audio(&"explosion", global_position, -2.0)


func _report_kill() -> void:
	if _run_state != null and _run_state.has_method("record_kill"):
		_run_state.call("record_kill", is_boss(), enemy_data.xp if enemy_data != null else 0)
	if _event_bus != null and _event_bus.has_signal("enemy_killed"):
		_event_bus.emit_signal("enemy_killed", display_name, global_position, is_boss())
	if is_boss() and _event_bus != null:
		_event_bus.emit_signal("notification_requested", "Boss Eliminated", "%s has fallen." % display_name, &"success")
		_event_bus.emit_signal("radio_message", "Mara Voss", "Warden signature down. Whatever that was, it felt the Reach bend.")


func _roll_loot() -> void:
	var parent := get_parent() as Node3D
	if parent == null or not is_instance_valid(parent):
		return
	var payload := _build_loot_payload()
	if payload.is_empty():
		return
	EnemyLootDrop.spawn(parent, _loot_ground_position(), payload)
	loot_dropped += 1


func _loot_ground_position() -> Vector3:
	var from := global_position + Vector3.UP * 2.0
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 80.0, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var landed: Vector3 = hit["position"]
		return landed + Vector3.UP * 0.04
	return global_position + Vector3.UP * 0.04


func _build_loot_payload() -> Dictionary:
	var data := enemy_data
	if data == null:
		return {}
	var min_rarity := 0
	var item_chance := 0.14 + 0.06 * float(threat_level - 1)
	# Difficulty loot luck raises the item chance and the rarity floor. Gated on
	# RunState.active so headless sandbox scenes keep the authored defaults.
	var loot_luck := _difficulty_loot_luck()
	item_chance = clampf(item_chance + loot_luck, 0.0, 1.0)
	if loot_luck >= 0.10:
		min_rarity = maxi(min_rarity, 1)
	if data.elite:
		item_chance = 1.0
		min_rarity = maxi(min_rarity, 2)
	if data.boss:
		item_chance = 1.0
		min_rarity = maxi(min_rarity, 3)

	var item: Dictionary = {}
	var rarity := 0
	if _rng.randf() < item_chance and _content_db != null:
		var slot := _random_loot_slot()
		var level := maxi(1, threat_level * 2 + (2 if data.elite else 0) + (4 if data.boss else 0))
		var profile := get_node_or_null("/root/ProfileState")
		if profile != null and profile.has_method("get_level"):
			level = maxi(level, int(profile.call("get_level")))
		var factory := _item_factory()
		if factory != null:
			var rolled_rarity := int(factory.call("roll_rarity", _rng, loot_luck, min_rarity))
			var generated = factory.call("generate_random_for_slot", _rng, slot, rolled_rarity, level, 0)
			if generated is Dictionary:
				item = generated
		if item.is_empty():
			item = _fallback_loot_item(slot, min_rarity, level)
		if not item.is_empty():
			rarity = int(item.get("rarity", rarity))
	rarity = maxi(rarity, min_rarity)

	var salvage_scale := (0.9 + _rng.randf() * 0.3) * (1.0 + 0.12 * float(threat_level - 1))
	var salvage := int(round(float(data.salvage) * data.loot_bonus * salvage_scale * _mutator_mult("reward")))
	salvage = maxi(1, salvage)
	var cores := 0
	if data.boss:
		cores = 2
	elif data.elite and _rng.randf() < 0.6:
		cores = 1

	var label := display_name
	var item_label := ""
	if not item.is_empty():
		var info := _describe_item(item)
		item_label = String(info.get("display_name", "Gear"))
		var rarity_name := String(info.get("rarity_name", ""))
		label = "%s %s" % [rarity_name, item_label]
	return {
		"salvage": salvage,
		"cores": cores,
		"item": item,
		"rarity": rarity,
		"label": label,
		"item_label": item_label,
		"prompt": "Collect %s  [E]" % label,
		"threat": threat_level,
		"boss": data.boss,
	}


func _random_loot_slot() -> StringName:
	var roll := _rng.randi_range(0, 6)
	match roll:
		0:
			return StatKeys.SLOT_SIDEARM
		1:
			return StatKeys.SLOT_HELMET
		2:
			return StatKeys.SLOT_CHEST
		3:
			return StatKeys.SLOT_LEGS
		4:
			return StatKeys.SLOT_CLOAK
		5:
			return StatKeys.SLOT_CHARM
		_:
			return StatKeys.SLOT_PRIMARY


## Loads the shared ItemFactory lazily so the AI scripts never hard-depend on
## a sibling gameplay script at compile time (keeps headless --script tests and
## hot-reloads resilient). Returns null when unavailable -> internal fallback.
func _item_factory() -> Script:
	if _factory_probed:
		return _factory_script
	_factory_probed = true
	var loaded = load("res://features/loot/item_factory.gd")
	if loaded is Script and (loaded as Script).can_instantiate():
		_factory_script = loaded as Script
	return _factory_script


func _describe_item(item: Dictionary) -> Dictionary:
	var factory := _item_factory()
	if factory != null:
		var info = factory.call("describe", item)
		if info is Dictionary:
			return info
	var base := String(item.get("base_id", "gear")).replace("_", " ").capitalize()
	var rarity := clampi(int(item.get("rarity", 0)), 0, StatKeys.RARITY_NAMES.size() - 1)
	return {"display_name": base, "rarity_name": StatKeys.RARITY_NAMES[rarity], "value": 0}


## Minimal ItemFactory-compatible item roll used only when the shared factory
## cannot be loaded. Produces the same save-format dictionary.
func _fallback_loot_item(slot: StringName, min_rarity: int, level: int) -> Dictionary:
	if _content_db == null:
		return {}
	var rarity := clampi(min_rarity + _rng.randi_range(0, 1), 0, 4)
	var kind := "gear"
	var base_id: StringName = &""
	var item_slot := String(slot)
	if slot == StatKeys.SLOT_PRIMARY or slot == StatKeys.SLOT_SIDEARM:
		var weapons: Array = _content_db.call("get_weapons_for_slot", slot)
		if weapons.is_empty():
			return {}
		base_id = weapons[_rng.randi_range(0, weapons.size() - 1)].id
		kind = "weapon"
	else:
		var templates: Dictionary = _content_db.get("item_templates")
		var candidates: Array = []
		for template in templates.values():
			if template.slot == slot:
				candidates.append(template)
		if candidates.is_empty():
			return {}
		var chosen = candidates[_rng.randi_range(0, candidates.size() - 1)]
		base_id = chosen.id
	if base_id == &"":
		return {}
	var affixes: Array = []
	var pool: Array = _content_db.call("get_affixes_for_slot", slot)
	var counts := [0, 1, 2, 2, 3]
	var chosen_ids: Array[String] = []
	for i in int(counts[rarity]):
		if pool.is_empty():
			break
		var pick: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)]
		var affix_id := String(pick.get("id", ""))
		if affix_id in chosen_ids:
			continue
		chosen_ids.append(affix_id)
		var values: PackedFloat32Array = pick.get("values", PackedFloat32Array([0.0]))
		var value: float = values[clampi(rarity, 0, values.size() - 1)]
		affixes.append({"id": affix_id, "value": value})
	return {
		"uid": 0,
		"kind": kind,
		"base_id": String(base_id),
		"slot": item_slot,
		"rarity": rarity,
		"level": maxi(1, level),
		"affixes": affixes,
	}


func _grave_tick(delta: float) -> void:
	_grave_time += delta
	if not is_flyer():
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		elif velocity.y < 0.0:
			velocity.y = 0.0
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	move_and_slide()
	if _visual_root != null:
		_visual_root.rotation.z = lerpf(_visual_root.rotation.z, 1.15, minf(1.0, delta * 3.2))
		_visual_root.position.y = lerpf(_visual_root.position.y, -_hover - 0.35, minf(1.0, delta * 2.4))
		var shrink := clampf(1.0 - _grave_time / DEATH_FREE_DELAY, 0.02, 1.0)
		_visual_root.scale = Vector3.ONE * _body_scale * shrink
	if _grave_time >= DEATH_FREE_DELAY:
		queue_free()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _mutator_mult(key: String) -> float:
	if _run_state != null and _run_state.has_method("get_mutator_multiplier"):
		return maxf(0.1, float(_run_state.call("get_mutator_multiplier", key, 1.0)))
	return 1.0


## Difficulty hp/damage multipliers only apply during a real deployment. Sandbox
## scenes (e.g. ai_test) never start a run, so RunState stays inactive and the
## authored enemy stats remain untouched.
func _difficulty_stat(method_name: String) -> float:
	if _run_state == null or not is_instance_valid(_run_state):
		return 1.0
	if _run_state.get("active") != true:
		return 1.0
	if _run_state.has_method(method_name):
		return maxf(0.1, float(_run_state.call(method_name)))
	return 1.0


func _difficulty_loot_luck() -> float:
	if _run_state == null or not is_instance_valid(_run_state):
		return 0.0
	if _run_state.get("active") != true:
		return 0.0
	if _run_state.has_method("get_difficulty_loot_luck"):
		return clampf(float(_run_state.call("get_difficulty_loot_luck")), 0.0, 0.5)
	return 0.0


func _fx_parent() -> Node3D:
	var parent := get_parent() as Node3D
	if parent != null and is_instance_valid(parent):
		return parent
	if is_inside_tree():
		return get_tree().current_scene as Node3D
	return null


func _play_audio(id: StringName, world_position: Vector3, volume_db: float = -6.0) -> void:
	if _audio != null and _audio.has_method("play_3d"):
		_audio.call("play_3d", id, world_position, volume_db)


func _flash_hit() -> void:
	if _flash_material == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_material.albedo_color = Color(1.0, 0.93, 0.83, 0.5)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_material, "albedo_color:a", 0.0, 0.16)


func _impact_flash(color: Color) -> void:
	if _flash_material == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_material.albedo_color = Color(color.r, color.g, color.b, 0.55)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_material, "albedo_color:a", 0.0, 0.22)
