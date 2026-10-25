class_name Player
extends CharacterBody3D
## First-person player: camera, movement, vitals, weapon/ability composition,
## interaction, downed/revive, and HUD snapshots. All combat state is scene-local.

signal hud_updated(snapshot: Dictionary)
signal hitmarker(killed: bool, crit: bool)
signal damage_indicator(world_direction: Vector3)
signal downed_changed(is_downed: bool, bleedout: float)
signal interact_prompt_changed(text: String)
signal died

const WALK_SPEED := 5.4
const SPRINT_SPEED := 7.8
const CROUCH_SPEED := 2.9
const SLIDE_SPEED := 11.5
const ACCEL_GROUND := 48.0
const ACCEL_AIR := 14.0
const FRICTION_GROUND := 10.0
const JUMP_VELOCITY := 5.4
const MOUSE_CLAMP := deg_to_rad(89.0)
const DOWNED_BLEEDOUT := 20.0
const SELF_REVIVE_TIME := 8.0
const MechanicUnlocks := preload("res://features/player/mechanic_unlocks.gd")

var health_component: HealthComponent
var stats_component: StatsComponent
var weapon_controller: WeaponController
var ability_manager: AbilityManager
var camera: Camera3D
var head: Node3D
var camera_pivot: Node3D

var yaw: float = 0.0
var pitch: float = 0.0
var base_fov: float = 90.0
var mouse_sensitivity: float = 0.0022
var ads_sensitivity_scale: float = 0.7
var invert_y: bool = false
var callsign: String = "Warden"

var is_downed: bool = false
var bleedout_left: float = 0.0
var revive_charges: int = 1
var revive_progress: float = 0.0
var is_dead: bool = false

var _capsule: CapsuleShape3D
var _collision: CollisionShape3D
var _sprinting: bool = false
var _crouching: bool = false
var _sliding: bool = false
var _slide_timer: float = 0.0
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _footstep_timer: float = 0.0
var _interaction_timer: float = 0.0
var _interact_target: Node = null
var _interact_prompt: String = ""
var _hud_timer: float = 0.0
var _recoil: Vector2 = Vector2.ZERO
var _trauma: float = 0.0
var _trauma_time: float = 0.0
var _clamp_floor: float = 0.0
var _history: Array[Dictionary] = []
var _history_timer: float = 0.0
var _cloak_timer: float = 0.0
var _cloak_visual: bool = false
var _overclock_timer: float = 0.0
var _fire_rate_mult: float = 1.0
var _hyperfocus_timer: float = 0.0
var _grenade_charges: int = 2
var _melee_cooldown: float = 0.0
var _squad_command_index: int = 0
var _pet_command_cooldown: float = 0.0
var _self_revive_used: int = 0
var _was_down: bool = false
var _locked_notice_time: float = -100.0
var _locked_notice_id: StringName = &""
var _exfil_notice_time: float = -100.0
var _world_node: Node = null
var _fluid_type: int = 0
var _fluid_level: float = 0.0
var _fluid_move_mult: float = 1.0
var _hazard_tick: float = 0.0
var _headlamp: OmniLight3D = null
var _lamp_timer: float = 0.0


func _ready() -> void:
	add_to_group("player")
	add_to_group("player_team")
	_build_body()
	_build_vitals()
	_build_weapons()
	_build_abilities()
	_connect_settings()
	_apply_profile_cosmetics()
	_cache_world()
	_record_history()
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	update_hud()
	EventBus.radio_message.emit("Mara Voss", "Riftwarden, you're on the ground. Stay sharp.")


func _build_body() -> void:
	collision_layer = 2
	collision_mask = 1 | 128
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.45
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.38
	_capsule.height = 1.8
	_collision = CollisionShape3D.new()
	_collision.name = "Collision"
	_collision.shape = _capsule
	_collision.position = Vector3(0.0, 0.9, 0.0)
	add_child(_collision)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 1.62, 0.0)
	add_child(head)
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	head.add_child(camera_pivot)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = float(App.get_setting("fov", 90.0))
	camera.near = 0.04
	camera.far = 900.0
	camera.current = true
	camera_pivot.add_child(camera)
	base_fov = camera.fov
	# A small night headlamp keeps the frontier readable after dusk without
	# flattening the day/night contrast.
	_headlamp = OmniLight3D.new()
	_headlamp.name = "Headlamp"
	_headlamp.light_color = Color(0.72, 0.82, 1.0)
	_headlamp.light_energy = 0.0
	_headlamp.omni_range = 20.0
	_headlamp.omni_attenuation = 1.4
	_headlamp.shadow_enabled = false
	_headlamp.position = Vector3(0.0, 0.0, -0.15)
	camera.add_child(_headlamp)
	mouse_sensitivity = float(App.get_setting("mouse_sensitivity", 0.0022))
	ads_sensitivity_scale = float(App.get_setting("ads_sensitivity_scale", 0.7))
	invert_y = bool(App.get_setting("invert_y", false))
	callsign = ProfileState.get_callsign()


func _build_vitals() -> void:
	stats_component = StatsComponent.new()
	stats_component.name = "Stats"
	add_child(stats_component)
	var stats := PlayerStats.base_with_profile(ProfileState)
	for id in RunState.rift_mods:
		var mod := ContentDB.get_rift_mod(id)
		if mod != null:
			stats[mod.stat] = float(stats.get(mod.stat, 0.0)) + mod.value if mod.op == &"add" else float(stats.get(mod.stat, 1.0)) * mod.value
	stats_component.set_base_stats(stats)
	health_component = HealthComponent.new()
	health_component.name = "Health"
	health_component.team = StatKeys.TEAM_PLAYER
	add_child(health_component)
	health_component.configure(
		stats_component.get_stat(StatKeys.HEALTH_MAX, 100.0),
		stats_component.get_stat(StatKeys.SHIELD_MAX, 50.0),
		stats_component.get_stat(StatKeys.ARMOR, 10.0),
		StatKeys.TEAM_PLAYER
	)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_health_died)
	set_meta("health_component", health_component)


func _build_weapons() -> void:
	weapon_controller = WeaponController.new()
	weapon_controller.name = "WeaponController"
	add_child(weapon_controller)
	weapon_controller.setup(self, camera)
	weapon_controller.hit_confirmed.connect(_on_hit_confirmed)


func _build_abilities() -> void:
	ability_manager = AbilityManager.new()
	ability_manager.name = "AbilityManager"
	add_child(ability_manager)
	var loadout := ProfileState.get_ability_loadout()
	var ultimate := ContentDB.get_ultimate_for_discipline(ProfileState.get_discipline())
	ability_manager.setup(self, loadout, ultimate.id if ultimate != null else &"")


func _connect_settings() -> void:
	EventBus.settings_changed.connect(_on_setting_changed)


func _on_setting_changed(key: String, value: Variant) -> void:
	match key:
		"fov":
			base_fov = float(value)
		"mouse_sensitivity":
			mouse_sensitivity = float(value)
		"ads_sensitivity_scale":
			ads_sensitivity_scale = float(value)
		"invert_y":
			invert_y = bool(value)


func _apply_profile_cosmetics() -> void:
	var suit := ContentDB.get_cosmetic(StringName(ProfileState.get_equipped_cosmetic("suit")))
	if suit != null:
		# Visual tint is primarily a hub/3rd-person concern; first-person gets an accent.
		pass


# ---------------------------------------------------------------------------
# Input and movement
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if is_dead or is_downed:
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var ads := weapon_controller.get_ads_amount() if weapon_controller != null else 0.0
		var ads_zoom := weapon_controller.get_ads_zoom() if weapon_controller != null else 1.0
		var zoom_scale := clampf(ads_zoom, 0.35, 1.0)
		var target_scale := ads_sensitivity_scale * zoom_scale
		var sens := mouse_sensitivity * lerpf(1.0, target_scale, ads)
		yaw -= motion.relative.x * sens
		var y: float = motion.relative.y * sens
		if invert_y:
			y = -y
		pitch = clampf(pitch - y, -MOUSE_CLAMP, MOUSE_CLAMP)
		head.rotation.x = pitch
		rotation.y = yaw


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if is_downed:
		_update_downed(delta)
		return
	_update_fluid_state(delta)
	_update_headlamp(delta)
	_apply_gamepad_look(delta)
	_update_timers(delta)
	_update_movement(delta)
	_update_interaction(delta)
	_try_interact()
	_try_exfil_call()
	_update_aim_fov(delta)
	_update_hud_accumulator(delta)
	_update_history(delta)
	_melee_cooldown = maxf(0.0, _melee_cooldown - delta)
	if Input.is_action_just_pressed("melee"):
		if ProfileState.is_mechanic_unlocked(&"melee"):
			_melee()
		else:
			_notify_locked(&"melee")
	if Input.is_action_just_pressed("grenade"):
		if ProfileState.is_mechanic_unlocked(&"grenade"):
			_throw_grenade()
		else:
			_notify_locked(&"grenade")
	_pet_command_cooldown = maxf(0.0, _pet_command_cooldown - delta)
	if Input.is_action_just_pressed("squad_command"):
		if ProfileState.is_mechanic_unlocked(&"squad_command"):
			_issue_squad_command()
		else:
			_notify_locked(&"squad_command")
	if Input.is_action_just_pressed("pet_command") and _pet_command_cooldown <= 0.0:
		if ProfileState.is_mechanic_unlocked(&"pet_command"):
			_issue_pet_command()
		else:
			_notify_locked(&"pet_command")
	if _cloak_timer > 0.0 and Input.is_action_just_pressed("fire"):
		_cloak_timer = 0.0
		_set_cloak_visual(false)


func _apply_gamepad_look(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length_squared() > 0.01:
		yaw -= look.x * 2.7 * delta
		pitch = clampf(pitch - look.y * 2.0 * delta, -MOUSE_CLAMP, MOUSE_CLAMP)
		head.rotation.x = pitch
		rotation.y = yaw


func _update_movement(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var wants_sprint := Input.is_action_pressed("sprint") and input.y < 0.1 and not _crouching
	_sprinting = wants_sprint and direction.length_squared() > 0.01 and is_on_floor() and _fluid_type == 0
	var walk_speed := stats_component.get_stat(StatKeys.MOVE_SPEED, WALK_SPEED)
	var sprint_speed := stats_component.get_stat(StatKeys.SPRINT_SPEED, SPRINT_SPEED)
	var target_speed := walk_speed
	if _crouching:
		target_speed = CROUCH_SPEED
	elif _sprinting:
		target_speed = sprint_speed
	var crouch_pressed := Input.is_action_just_pressed("crouch") or Input.is_action_just_pressed("crouch_alt")
	if crouch_pressed:
		var can_slide := ProfileState.is_mechanic_unlocked(&"slide")
		if _sprinting and is_on_floor() and not _sliding and can_slide:
			_sliding = true
			_slide_timer = 0.7
			_crouching = true
			_set_crouch_shape(true)
		elif not _crouching:
			_crouching = true
			_set_crouch_shape(true)
		elif _can_stand_up():
			_crouching = false
			_set_crouch_shape(false)
	if _sliding:
		_slide_timer -= delta
		target_speed = SLIDE_SPEED * clampf(_slide_timer / 0.7, 0.55, 1.0)
		if Input.is_action_just_pressed("jump") and _can_stand_up():
			_sliding = false
			_crouching = false
			_set_crouch_shape(false)
			velocity.y = JUMP_VELOCITY
		if _slide_timer <= 0.0:
			_sliding = false
			if _can_stand_up():
				_crouching = false
				_set_crouch_shape(false)
	target_speed *= _fluid_move_mult
	if not is_on_floor():
		_coyote = 0.12
	else:
		_coyote = maxf(0.0, _coyote - delta)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = 0.12
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)
	if _jump_buffer > 0.0 and (_coyote > 0.0 or is_on_floor() or _fluid_type == 1) and not _sliding:
		if _crouching and not _can_stand_up():
			_jump_buffer = 0.0
		else:
			if _fluid_type == 1:
				velocity.y = 3.2
			else:
				velocity.y = stats_component.get_stat(StatKeys.JUMP_VELOCITY, JUMP_VELOCITY)
			_jump_buffer = 0.0
			_coyote = 0.0
			_set_crouch_shape(false)
			_crouching = false
	if not is_on_floor():
		var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
		if _fluid_type == 1:
			velocity.y -= gravity * 0.25 * delta
			if global_position.y < _fluid_level - 0.4:
				velocity.y += 10.0 * delta
			velocity.y = clampf(velocity.y, -3.5, 4.5)
		else:
			velocity.y -= gravity * delta
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var accel := ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	if direction.length_squared() > 0.01:
		horizontal = horizontal.move_toward(direction * target_speed, accel * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, (FRICTION_GROUND if is_on_floor() else 2.0) * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	if is_on_floor() and absf(velocity.y) < 0.2:
		velocity.y = 0.0
	_update_footsteps(delta)


# ---------------------------------------------------------------------------
# Fluid, hazard and night visibility
# ---------------------------------------------------------------------------

func _cache_world() -> void:
	if _world_node == null or not is_instance_valid(_world_node):
		_world_node = get_tree().get_first_node_in_group("world")


## Analytic water/lava query against the world builder. Water grants buoyancy and
## a swim speed; lava deals heat damage through the normal health pipeline.
func _update_fluid_state(delta: float) -> void:
	_cache_world()
	_fluid_move_mult = 1.0
	if _world_node == null or not _world_node.has_method("sample_fluid"):
		_set_fluid_type(0, 0.0)
		return
	var fluid: Dictionary = _world_node.call("sample_fluid", Vector2(global_position.x, global_position.z))
	var fluid_type := int(fluid.get("type", 0))
	var level := float(fluid.get("level", 0.0))
	if fluid_type == 0 or global_position.y >= level + 0.15:
		_set_fluid_type(0, level)
		_hazard_tick = 0.0
		return
	_set_fluid_type(fluid_type, level)
	if fluid_type == 1:
		var swim := clampf(get_stat(StatKeys.SWIM_SPEED, 1.0), 0.5, 2.0)
		_fluid_move_mult = swim * 0.68
	else:
		_fluid_move_mult = 0.5
		_hazard_tick -= delta
		if _hazard_tick <= 0.0:
			_hazard_tick = 0.5
			var resist := clampf(get_stat(StatKeys.HAZARD_RESIST, 0.0), 0.0, 0.8)
			take_fall_or_hazard_damage(9.0 * (1.0 - resist), self)
			EventBus.notification_requested.emit("LAVA", "Get out of the lava.", &"danger")


func _set_fluid_type(fluid_type: int, level: float) -> void:
	_fluid_level = level
	if fluid_type == _fluid_type:
		return
	_fluid_type = fluid_type
	var state: StringName = &"none"
	if fluid_type == 1:
		state = &"water"
	elif fluid_type == 2:
		state = &"lava"
	EventBus.hazard_state_changed.emit(state)


func _update_headlamp(delta: float) -> void:
	_lamp_timer -= delta
	if _lamp_timer > 0.0:
		return
	_lamp_timer = 2.0
	if _headlamp == null:
		return
	var cycle := get_tree().get_first_node_in_group("day_night")
	var night := false
	if cycle != null and cycle.has_method("is_night"):
		night = bool(cycle.call("is_night"))
	_headlamp.light_energy = 0.9 if night else 0.0


func get_fluid_type() -> int:
	return _fluid_type


func is_in_fluid() -> bool:
	return _fluid_type != 0


func set_hazard_resist(value: float, duration: float) -> void:
	apply_temporary_modifier(&"hazard_resist", StatKeys.HAZARD_RESIST, &"add", value, duration)


func set_fluid_mobility(mult: float, duration: float) -> void:
	apply_temporary_modifier(&"fluid_mobility", StatKeys.SWIM_SPEED, &"mult", mult, duration)


func _set_crouch_shape(crouch: bool) -> void:
	if _capsule == null:
		return
	var target_height := 1.2 if crouch else 1.8
	var target_offset := 0.6 if crouch else 0.9
	_capsule.height = target_height
	_collision.position.y = target_offset
	var head_target := 0.92 if crouch else 1.62
	var tween := create_tween()
	tween.tween_property(head, "position:y", head_target, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _can_stand_up() -> bool:
	if not is_inside_tree():
		return true
	var probe := CapsuleShape3D.new()
	probe.radius = maxf(0.2, _capsule.radius if _capsule != null else 0.35)
	probe.height = 1.5
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = probe
	params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, 1.05, 0.0))
	params.collision_mask = 1
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = [get_rid()]
	var hits := get_world_3d().direct_space_state.intersect_shape(params, 1)
	return hits.is_empty()


func is_crouching() -> bool:
	return _crouching


func _notify_locked(mechanic_id: StringName) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if mechanic_id == _locked_notice_id and now - _locked_notice_time < 5.0:
		return
	var data := MechanicUnlocks.entry(mechanic_id)
	if data.is_empty():
		return
	_locked_notice_id = mechanic_id
	_locked_notice_time = now
	EventBus.notification_requested.emit(
		"FIELD TRAINING",
		"%s unlocks at Warden level %d." % [String(data.get("name", "Mechanic")), int(data.get("level", 1))],
		&"warning"
	)


func _update_footsteps(delta: float) -> void:
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	if not is_on_floor() or speed < 1.0:
		_footstep_timer = 0.0
		return
	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		_footstep_timer = 0.36 if _sprinting else (0.62 if _crouching else 0.48)
		AudioDirector.play_sfx(&"footstep", -22.0)


func _update_timers(delta: float) -> void:
	_recoil = _recoil.move_toward(Vector2.ZERO, 28.0 * delta)
	camera_pivot.rotation_degrees.x = _recoil.y
	camera_pivot.rotation_degrees.y = _recoil.x
	_trauma = maxf(0.0, _trauma - delta * 2.4)
	_trauma_time += delta
	if _trauma > 0.0:
		var shake := _trauma * _trauma * 0.018
		camera_pivot.position = Vector3(
			sin(_trauma_time * 43.0) * shake,
			cos(_trauma_time * 51.0) * shake,
			sin(_trauma_time * 37.0) * shake * 0.5
		)
		camera_pivot.rotation_degrees.z = sin(_trauma_time * 31.0) * shake * 4.0
	else:
		camera_pivot.position = camera_pivot.position.lerp(Vector3.ZERO, minf(1.0, delta * 12.0))
		camera_pivot.rotation_degrees.z = lerpf(camera_pivot.rotation_degrees.z, 0.0, minf(1.0, delta * 10.0))
	_cloak_timer = maxf(0.0, _cloak_timer - delta)
	if _cloak_timer <= 0.0 and _cloak_visual:
		_set_cloak_visual(false)
	_overclock_timer = maxf(0.0, _overclock_timer - delta)
	if _overclock_timer <= 0.0:
		_fire_rate_mult = 1.0
	_hyperfocus_timer = maxf(0.0, _hyperfocus_timer - delta)


func _update_aim_fov(delta: float) -> void:
	var ads := weapon_controller.get_ads_amount() if weapon_controller != null else 0.0
	var ads_zoom := weapon_controller.get_ads_zoom() if weapon_controller != null else 0.82
	var target := base_fov * lerpf(1.0, clampf(ads_zoom, 0.2, 1.0), ads)
	if _sprinting:
		target = base_fov * 1.04
	camera.fov = lerpf(camera.fov, target, minf(1.0, delta * 9.0))


func _update_hud_accumulator(delta: float) -> void:
	_hud_timer += delta
	if _hud_timer >= 0.1:
		_hud_timer = 0.0
		update_hud()


func _update_history(delta: float) -> void:
	_history_timer += delta
	if _history_timer >= 0.2:
		_history_timer = 0.0
		_record_history()


func _record_history() -> void:
	_history.append({"time": Time.get_ticks_msec(), "pos": global_position})
	if _history.size() > 40:
		_history.pop_front()


func get_history_position(seconds_ago: float) -> Vector3:
	var target_ms := Time.get_ticks_msec() - int(seconds_ago * 1000.0)
	var fallback := global_position
	for entry in _history:
		if int(entry.time) <= target_ms:
			fallback = entry.pos
	return fallback


func teleport_to(target: Vector3) -> void:
	global_position = target
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	RecordHistoryImmediate()


func RecordHistoryImmediate() -> void:
	_record_history()


func get_forward() -> Vector3:
	return -camera.global_transform.basis.z


func get_camera_position() -> Vector3:
	return camera.global_position


func get_effect_parent() -> Node3D:
	var parent := get_parent()
	if parent is Node3D:
		return parent
	return get_tree().current_scene as Node3D


func get_aim_point(distance: float = 100.0) -> Vector3:
	var origin := camera.global_position
	var forward := get_forward()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * distance, CombatUtils.HIT_MASK, [get_rid()])
	query.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return origin + forward * distance
	return hit.position


func is_sprinting() -> bool:
	return _sprinting


func get_move_speed_ratio() -> float:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).length()
	return clampf(horizontal / maxf(0.1, stats_component.get_stat(StatKeys.SPRINT_SPEED, SPRINT_SPEED)), 0.0, 1.0)


func is_cloaked() -> bool:
	return _cloak_timer > 0.0


func is_hyperfocused() -> bool:
	return _hyperfocus_timer > 0.0


func get_fire_rate_mult() -> float:
	return _fire_rate_mult * (1.35 if _hyperfocus_timer > 0.0 else 1.0)


func get_stat(key: StringName, fallback: float = 0.0) -> float:
	if stats_component == null:
		return fallback
	return stats_component.get_stat(key, fallback)


func get_health_component() -> HealthComponent:
	return health_component


func get_stats_component() -> StatsComponent:
	return stats_component


func get_camera() -> Camera3D:
	return camera


# ---------------------------------------------------------------------------
# Combat modifiers, health, downed/revive
# ---------------------------------------------------------------------------

func add_recoil(offset: Vector2) -> void:
	_recoil += offset * 0.65
	_recoil.y = clampf(_recoil.y, -3.0, 7.0)


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount * float(App.get_setting("camera_shake", 1.0)), 0.0, 1.0)


func set_invulnerable(duration: float) -> void:
	health_component.set_invulnerable(duration)


func set_cloaked(duration: float) -> void:
	_cloak_timer = maxf(_cloak_timer, duration)
	_set_cloak_visual(true)
	AudioDirector.play_sfx(&"ability", -9.0)


func _set_cloak_visual(cloaked: bool) -> void:
	_cloak_visual = cloaked
	if weapon_controller != null and weapon_controller.viewmodel_root != null:
		weapon_controller.viewmodel_root.visible = not cloaked
	if cloaked:
		EventBus.notify("Phase Cloak", "You are bending light. Attacking breaks the cloak.", &"ability")


func set_overclock(duration: float, mult: float) -> void:
	_overclock_timer = maxf(_overclock_timer, duration)
	_fire_rate_mult = maxf(1.0, mult)


func set_hyperfocused(duration: float) -> void:
	_hyperfocus_timer = maxf(_hyperfocus_timer, duration)
	if weapon_controller != null:
		weapon_controller._recoil_index = 0


func apply_temporary_modifier(
	id: StringName,
	stat: StringName,
	op: StringName,
	value: float,
	duration: float
) -> void:
	if stats_component == null:
		return
	var source := StringName("temp_" + String(id))
	stats_component.remove_modifiers_from(source)
	stats_component.add_modifier({"id": id, "source": source, "stat": stat, "op": op, "value": value})
	var timer := get_tree().create_timer(maxf(0.05, duration))
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and stats_component != null:
			stats_component.remove_modifiers_from(source)
	)
	update_hud()


func _on_damaged(info: Dictionary) -> void:
	var source = info.get("source", null)
	if source is Node3D and is_instance_valid(source):
		damage_indicator.emit((source.global_position - global_position).normalized())
	AudioDirector.play_sfx(&"player_hurt", -3.0)
	add_trauma(0.18)
	if health_component.shield <= 0.0 and health_component.max_shield > 0.0:
		AudioDirector.play_sfx(&"shield_break", -6.0)
	update_hud()


func _on_health_died() -> void:
	if is_dead or is_downed:
		return
	is_downed = true
	bleedout_left = DOWNED_BLEEDOUT
	revive_progress = 0.0
	weapon_controller.set_enabled(false)
	ability_manager.enabled = false
	_sprinting = false
	_sliding = false
	velocity = Vector3.ZERO
	head.position.y = 0.7
	camera_pivot.rotation_degrees.z = 12.0
	EventBus.player_downed.emit(true)
	downed_changed.emit(true, bleedout_left)
	AudioDirector.play_sfx(&"player_hurt")
	EventBus.notify("DOWNED", "Hold E to stabilize. A Warden or Driftling can revive you.", &"danger")
	update_hud()


func _update_downed(delta: float) -> void:
	bleedout_left -= delta
	if Input.is_action_pressed("revive") and revive_charges > _self_revive_used:
		revive_progress += delta / SELF_REVIVE_TIME
		if revive_progress >= 1.0:
			revive_self()
	else:
		revive_progress = maxf(0.0, revive_progress - delta * 0.5)
	head.rotation.z = lerpf(head.rotation.z, 0.18, minf(1.0, delta * 2.0))
	camera_pivot.rotation_degrees.z = lerpf(camera_pivot.rotation_degrees.z, 10.0, minf(1.0, delta * 3.0))
	downed_changed.emit(true, bleedout_left)
	if _hud_timer >= 0.1:
		_hud_timer = 0.0
		update_hud()
	_hud_timer += delta
	if bleedout_left <= 0.0:
		_permanent_death()


func revive_self() -> void:
	if not is_downed:
		return
	_self_revive_used += 1
	revive_charges = maxi(0, revive_charges - 1)
	_exit_downed()
	EventBus.notify("Stabilized", "You pulled yourself back from the edge.", &"success")


func revive_from_ally(amount: float = 0.5) -> void:
	if not is_downed:
		return
	health_component.revive(health_component.max_health * amount)
	_exit_downed()
	EventBus.notify("Revived", "Your squad pulled you back.", &"success")


func _exit_downed() -> void:
	is_downed = false
	bleedout_left = 0.0
	revive_progress = 0.0
	if health_component.dead:
		health_component.revive(health_component.max_health * 0.4)
	weapon_controller.set_enabled(true)
	ability_manager.enabled = true
	head.position.y = 1.62
	head.rotation = Vector3(pitch, 0.0, 0.0)
	head.rotation.z = 0.0
	camera_pivot.rotation = Vector3.ZERO
	EventBus.player_downed.emit(false)
	downed_changed.emit(false, 0.0)
	update_hud()


func _permanent_death() -> void:
	if is_dead:
		return
	is_dead = true
	is_downed = false
	weapon_controller.set_enabled(false)
	ability_manager.enabled = false
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	EventBus.player_downed.emit(false)
	downed_changed.emit(false, 0.0)
	died.emit()
	update_hud()


func heal(amount: float) -> void:
	if health_component != null:
		health_component.heal(amount)


func take_fall_or_hazard_damage(amount: float, source: Node = null) -> void:
	if is_dead or is_downed:
		return
	var data := DamageData.make(amount, StatKeys.TEAM_NEUTRAL, StatKeys.DMG_KINETIC, source)
	health_component.take_damage(data)


func _on_hit_confirmed(killed: bool, crit: bool) -> void:
	hitmarker.emit(killed, crit)
	if killed:
		add_trauma(0.18)


# ---------------------------------------------------------------------------
# Interaction, grenades, melee
# ---------------------------------------------------------------------------

func _update_interaction(delta: float) -> void:
	_interaction_timer -= delta
	if _interaction_timer > 0.0:
		return
	_interaction_timer = 0.12
	var origin := camera.global_position
	var forward := get_forward()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * 3.4, 1 | 32)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var target: Node = null
	if not hit.is_empty():
		var collider = hit.collider
		if collider is Node and (collider.is_in_group("interactable") or collider.has_method("get_interact_prompt")):
			target = collider as Node
		elif collider is Node and (collider as Node).get_parent() != null and (collider as Node).get_parent().is_in_group("interactable"):
			target = (collider as Node).get_parent()
	var prompt := ""
	if target != null and target.has_method("get_interact_prompt"):
		prompt = String(target.call("get_interact_prompt"))
	_interact_target = target
	if prompt != _interact_prompt:
		_interact_prompt = prompt
		interact_prompt_changed.emit(prompt)


func _try_interact() -> void:
	# Interaction input must be evaluated every physics tick; the ray/prompt
	# refresh is throttled, so checking input only there would drop presses.
	if not Input.is_action_just_pressed("interact"):
		return
	if _interact_target == null or not is_instance_valid(_interact_target):
		return
	if _interact_target.has_method("interact"):
		_interact_target.call("interact", self)
	elif _interact_target.has_method("use"):
		_interact_target.call("use", self)


## Radio-calls the extraction dropship while standing on an exfil pad. E on the
## beacon remains the primary interaction; this is the rebindable alternate.
func _try_exfil_call() -> void:
	if not Input.is_action_just_pressed("call_exfil"):
		return
	var deployment := _find_deployment()
	if deployment == null or not deployment.has_method("get_exfil_sites"):
		return
	var pad: Node3D = null
	for beacon in deployment.call("get_exfil_sites"):
		if beacon is Node3D and is_instance_valid(beacon):
			if global_position.distance_to((beacon as Node3D).global_position) <= 12.0:
				pad = beacon as Node3D
				break
	if pad == null:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _exfil_notice_time > 4.0:
			_exfil_notice_time = now
			EventBus.notification_requested.emit(
				"NO EXFIL PAD",
				"Stand on an exfil pad to call the dropship.",
				&"warning"
			)
		return
	if deployment.has_method("request_extraction"):
		deployment.call("request_extraction", pad)


func _find_deployment() -> Node:
	if App != null:
		var active = App.get_deployment()
		if active != null and is_instance_valid(active):
			return active
	var node := get_parent()
	while node != null:
		if node.has_method("request_extraction") and node.has_method("get_exfil_sites"):
			return node
		node = node.get_parent()
	return null


func _issue_squad_command() -> void:
	var commands: Array[StringName] = [&"follow", &"hold", &"focus"]
	var command := commands[_squad_command_index % commands.size()]
	_squad_command_index += 1
	var manager := get_tree().get_first_node_in_group("companion_manager")
	if manager == null or not manager.has_method("issue_squad_command"):
		return
	var target: Node = _nearest_hostile() if command == &"focus" else null
	manager.call("issue_squad_command", command, target)
	EventBus.notification_requested.emit("Squad", "Wardens ordered to %s." % String(command), &"info")


func _issue_pet_command() -> void:
	var pet := get_tree().get_first_node_in_group("pets")
	if pet == null or not pet.has_method("force_ability"):
		return
	if bool(pet.call("force_ability")):
		_pet_command_cooldown = 8.0
		EventBus.notification_requested.emit("Driftling", "Companion ability triggered.", &"info")


func _nearest_hostile() -> Node:
	var nearest: Node = null
	var best := INF
	for enemy in get_tree().get_nodes_in_group("enemy_ai"):
		if enemy is Node3D and is_instance_valid(enemy):
			var distance := global_position.distance_squared_to((enemy as Node3D).global_position)
			if distance < best:
				best = distance
				nearest = enemy
	return nearest


func _throw_grenade() -> void:
	if _grenade_charges <= 0:
		return
	_grenade_charges -= 1
	var data := ContentDB.get_grenade(&"frag")
	var projectile := CombatProjectile.new()
	projectile.name = "Grenade"
	projectile.setup(
		camera.global_position + get_forward() * 0.8,
		get_forward() + Vector3.UP * 0.08,
		16.0,
		data.damage if data != null else 90.0,
		StatKeys.TEAM_PLAYER,
		self,
		0.16,
		data.radius if data != null else 5.0,
		Color("ffb866"),
		12.0,
		2.1
	)
	projectile.rotation = Vector3.ZERO
	get_effect_parent().add_child(projectile)
	AudioDirector.play_sfx(&"ui_confirm", -12.0)
	update_hud()


func _melee() -> void:
	if _melee_cooldown > 0.0:
		return
	_melee_cooldown = 0.72
	var origin := camera.global_position
	var forward := get_forward()
	var result := CombatUtils.melee_strike(
		self,
		camera,
		36.0 * get_stat(StatKeys.DAMAGE_MULT, 1.0),
		2.6,
		StatKeys.DMG_KINETIC,
		Color("ffb866")
	)
	if bool(result.get("applied", false)):
		hitmarker.emit(bool(result.get("killed", false)), true)
	AudioDirector.play_sfx(&"hit", -4.0)
	CombatVFX.ring(get_effect_parent(), origin + forward * 1.2, 0.8, Color("ffb866"), 0.25)


# ---------------------------------------------------------------------------
# HUD
# ---------------------------------------------------------------------------

func update_hud() -> void:
	if not is_inside_tree():
		return
	hud_updated.emit(get_hud_snapshot())


func get_hud_snapshot() -> Dictionary:
	var weapon_info: Dictionary = weapon_controller.get_hud_info() if weapon_controller != null else {}
	var abilities: Array = ability_manager.get_hud_states() if ability_manager != null else []
	return {
		"callsign": callsign,
		"health": health_component.health if health_component != null else 0.0,
		"max_health": health_component.max_health if health_component != null else 100.0,
		"shield": health_component.shield if health_component != null else 0.0,
		"max_shield": health_component.max_shield if health_component != null else 0.0,
		"weapon_name": String(weapon_info.get("weapon_name", "Weapon")),
		"weapon_slot": String(weapon_info.get("weapon_slot", "primary")),
		"weapon_slot_label": String(weapon_info.get("weapon_slot_label", "PRIMARY")),
		"weapon_slot_index": int(weapon_info.get("weapon_slot_index", 0)),
		"weapon_style": String(weapon_info.get("weapon_style", "rifle")),
		"weapon_accent": weapon_info.get("weapon_accent", Color("62e6c3")),
		"weapon_slots": weapon_info.get("weapon_slots", []),
		"is_melee": bool(weapon_info.get("is_melee", false)),
		"rarity": int(weapon_info.get("rarity", 0)),
		"rarity_color": weapon_info.get("rarity_color", Color("a7b4b6")),
		"ammo": int(weapon_info.get("ammo", 0)),
		"reserve": int(weapon_info.get("reserve", 0)),
		"mag_size": int(weapon_info.get("mag_size", 0)),
		"reloading": bool(weapon_info.get("reloading", false)),
		"reload_progress": float(weapon_info.get("reload_progress", 0.0)),
		"is_ads": bool(weapon_info.get("is_ads", false)),
		"ads_amount": float(weapon_info.get("ads_amount", 0.0)),
		"ads_zoom": float(weapon_info.get("ads_zoom", 0.82)),
		"weapon_range": float(weapon_info.get("effective_range", 120.0)),
		"charge": float(weapon_info.get("charge", 0.0)),
		"inventory_key": App.get_action_binding_text(&"inventory", "I") if App != null else "I",
		"abilities": abilities,
		"grenade_name": "Frag",
		"grenade_charges": _grenade_charges,
		"kills": RunState.kills,
		"downed": is_downed,
		"bleedout": bleedout_left,
		"revive_progress": revive_progress,
		"revive_charges": revive_charges - _self_revive_used,
		"interact_prompt": _interact_prompt,
		"position": global_position,
		"yaw": yaw,
		"crouching": _crouching,
		"cloaked": is_cloaked(),
		"hyperfocused": is_hyperfocused(),
		"health_fraction": health_component.get_health_fraction() if health_component != null else 0.0,
		"shield_fraction": clampf(health_component.shield / maxf(1.0, health_component.max_shield), 0.0, 1.0) if health_component != null else 0.0,
	}


func get_inventory_snapshot() -> Dictionary:
	var weapons: Array = weapon_controller.get_loadout_info() if weapon_controller != null else []
	var gear: Array = []
	for entry in [
		[StatKeys.SLOT_HELMET, "Helmet"],
		[StatKeys.SLOT_CHEST, "Chest"],
		[StatKeys.SLOT_LEGS, "Legs"],
		[StatKeys.SLOT_CLOAK, "Cloak"],
		[StatKeys.SLOT_CHARM, "Charm"],
	]:
		var slot: StringName = entry[0]
		var item := ProfileState.get_equipped_item(slot)
		var info := ItemFactory.describe(item)
		gear.append({
			"slot": String(slot),
			"label": String(entry[1]),
			"name": String(info.get("display_name", "Empty")) if not info.is_empty() else "Empty",
			"rarity": int(info.get("rarity", 0)),
			"rarity_color": info.get("rarity_color", Color("5d6f72")),
			"armor": float(info.get("armor", 0.0)),
			"empty": info.is_empty(),
		})
	var records := ProfileState.get_records()
	return {
		"callsign": callsign,
		"weapons": weapons,
		"gear": gear,
		"satchel_items": RunState.satchel_items.duplicate(true),
		"satchel_salvage": RunState.satchel_salvage,
		"satchel_cores": RunState.satchel_cores,
		"rift_mods": RunState.rift_mods.map(func(id: StringName) -> String: return String(id)),
		"locker_count": ProfileState.get_inventory_size(),
		"extractions": int(records.get("extractions", 0)),
		"run_active": RunState.active,
		"time_left": RunState.get_time_left(),
		"extraction_state": String(RunState.extraction_state),
		"kills": RunState.kills,
		"level": ProfileState.get_level(),
	}


func notify_deployable_removed(_deployable: Node) -> void:
	pass

