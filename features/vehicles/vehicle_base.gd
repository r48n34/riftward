class_name Rideable
extends CharacterBody3D
## Base class for every drivable/rideable vehicle in RIFTWARD.
##
## All archetypes are CharacterBody3D nodes with hand-rolled raycast suspension,
## steering and thrust (see VehiclePhysics) so behaviour is deterministic and can
## be exercised headless. The Player hook contract is:
##   Player.enter_vehicle(vehicle) -> vehicle.mount(player)   (player reparents)
##   Player.exit_vehicle()         -> vehicle.dismount()      (player reparents back)
##
## Subclasses override the tuning hooks (_make_spec, _configure_body,
## _step_vehicle, _update_visuals, _extra_hud_data, _engine_id) but share mount /
## dismount / damage / HUD / interaction plumbing here.

signal mounted(player: Node)
signal dismounted(player: Node, forced: bool)
signal hud_updated(snapshot: Dictionary)
signal destroyed(vehicle: Node)

## Physics layer 11 "Vehicle" (bit value 1024).
const VEHICLE_LAYER := 1 << 10
## World | Player | Enemy.
const VEHICLE_MASK := 1 | 2 | 4
const HUD_INTERVAL := 0.1
const MOUNT_INPUT_GRACE := 0.35

const PARTICLE_LIBRARY_PATH := "res://features/fx/particle_library.gd"

var _spec: Dictionary = {}
var _health: float = 100.0
var _boost: float = 1.0
var _occupied: bool = false
var _destroyed: bool = false
var _driver: Node = null
var _seat: Node3D = null
var _exit_node: Node3D = null
var _visual_root: Node3D = null
var _collision: CollisionShape3D = null
var _driver_original_parent: Node = null
var _driver_layer: int = 2
var _driver_mask: int = 1

var _control: Dictionary = {}
var _throttle_input: float = 0.0
var _steer_input: float = 0.0
var _brake_input: bool = false
var _boost_input: bool = false
var _jump_input: bool = false
var _horn_input: bool = false
var _ascend_input: bool = false
var _descend_input: bool = false

var _gait: StringName = &"idle"
var _time: float = 0.0
var _speed_mps: float = 0.0
var _grounded: bool = false
var _ground_normal: Vector3 = Vector3.UP
var _ground_distance: float = 999.0
var _hud_timer: float = 0.0
var _engine_timer: float = 0.0
var _horn_cooldown: float = 0.0
var _was_boosting: bool = false
var _mount_time: float = -10.0
var _smoke_timer: float = 0.0
var _engine_loop: AudioStreamPlayer3D = null
var _wind_loop: AudioStreamPlayer3D = null
var _fx_cooldowns: Dictionary = {}

# --- lifecycle -------------------------------------------------------------


func _ready() -> void:
	add_to_group("rideable")
	add_to_group("interactable")
	collision_layer = VEHICLE_LAYER
	collision_mask = VEHICLE_MASK
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.35
	_configure_body()
	_spec = _make_spec()
	_health = _max_health()
	_boost = 1.0
	_ensure_nodes()
	set_physics_process(true)


## Virtual: subclasses flip motion mode (grounded vs floating) here.
func _configure_body() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED


func _ensure_nodes() -> void:
	if _spec.is_empty():
		_spec = _make_spec()
	if _collision == null:
		_collision = CollisionShape3D.new()
		_collision.name = "Collision"
		var shape := BoxShape3D.new()
		shape.size = _collision_extents()
		_collision.shape = shape
		_collision.position = _collision_offset()
		add_child(_collision)
	if _seat == null:
		_seat = Node3D.new()
		_seat.name = "Seat"
		_seat.position = _seat_offset()
		add_child(_seat)
	if _exit_node == null:
		_exit_node = Node3D.new()
		_exit_node.name = "Exit"
		_exit_node.position = _exit_offset()
		add_child(_exit_node)
	if _visual_root == null:
		_visual_root = VehicleBuilder.build_mesh(get_vehicle_id())
		if _visual_root != null:
			_visual_root.name = "Visuals"
			add_child(_visual_root)


# --- identity and spec -----------------------------------------------------


func get_vehicle_id() -> StringName:
	return StringName(get_vehicle_spec().get("id", &"vehicle"))


func get_vehicle_spec() -> Dictionary:
	if _spec.is_empty():
		_spec = _make_spec()
	return _spec.duplicate(true)


## Virtual: per-archetype tuning dictionary. Required keys are documented in
## the task contract; extra keys are archetype-specific tuning.
func _make_spec() -> Dictionary:
	return {
		"id": &"vehicle",
		"name": "Vehicle",
		"kind": &"ground",
		"seats": 1,
		"max_speed": 20.0,
		"accel": 10.0,
		"turn_rate": 2.0,
		"health": 200.0,
		"mass": 800.0,
		"icon": &"vehicle",
		"hud_color": Color("62e6c3"),
	}


func _max_health() -> float:
	return maxf(1.0, float(get_vehicle_spec().get("health", 100.0)))


func _max_speed() -> float:
	return maxf(1.0, float(get_vehicle_spec().get("max_speed", 20.0)))


func _accel() -> float:
	return maxf(0.5, float(get_vehicle_spec().get("accel", 10.0)))


func _turn_rate() -> float:
	return maxf(0.05, float(get_vehicle_spec().get("turn_rate", 2.0)))


func _boost_mult() -> float:
	return maxf(1.0, float(get_vehicle_spec().get("boost_mult", 1.25)))


func _grip() -> float:
	return maxf(0.5, float(get_vehicle_spec().get("grip", 8.0)))


func _brake_force() -> float:
	return maxf(1.0, float(get_vehicle_spec().get("brake_force", 20.0)))


func _engine_id() -> StringName:
	return &""


## Virtual: wind loop for airborne archetypes (airplane, spaceship).
func _wind_loop_id() -> StringName:
	return &""


# --- geometry hooks (subclass) ---------------------------------------------


func _collision_extents() -> Vector3:
	return Vector3(2.0, 1.2, 4.0)


func _collision_offset() -> Vector3:
	var extents := _collision_extents()
	return Vector3(0.0, extents.y * 0.5 + _ride_height() - extents.y * 0.45, 0.0)


func _seat_offset() -> Vector3:
	return Vector3(0.0, 0.2, 0.0)


func _exit_offset() -> Vector3:
	return Vector3(2.4, 0.0, 0.0)


func _ride_height() -> float:
	return 0.55


func _suspension_length() -> float:
	return _ride_height() + 3.0


# --- interaction / mounting ------------------------------------------------


func get_seat_node() -> Node3D:
	_ensure_nodes()
	return _seat


func is_occupied() -> bool:
	return _occupied


func get_interact_prompt() -> String:
	if _destroyed:
		return ""
	if _occupied:
		return ""
	var key := "E"
	if App != null and App.has_method("get_action_binding_text"):
		key = String(App.get_action_binding_text(&"interact", "E"))
	return "%s — Ride %s" % [key, String(get_vehicle_spec().get("name", "Vehicle"))]


## Interaction convention entry point. Prefer the Player hook (it owns combat,
## collider state and the EventBus signals); fall back to a bare mount for
## stubs/AI so the primitive still works outside a real Player.
func interact(player: Node) -> void:
	if _destroyed or player == null:
		return
	if _occupied:
		if player == _driver:
			if player.has_method("exit_vehicle"):
				player.call("exit_vehicle", get_exit_position())
			else:
				dismount(false)
		return
	if player.has_method("enter_vehicle"):
		player.call("enter_vehicle", self)
	else:
		mount(player)


## Seats the player: captures its restore state, reparents it onto the seat and
## reports occupancy. Idempotent — a second call while occupied returns false.
func mount(player: Node) -> bool:
	if _destroyed or _occupied or player == null or not is_instance_valid(player):
		return false
	if not (player is Node3D):
		return false
	_driver = player
	_driver_original_parent = player.get_parent()
	if player is CollisionObject3D:
		var body := player as CollisionObject3D
		_driver_layer = body.collision_layer
		_driver_mask = body.collision_mask
		# Deferred: mount happens inside _physics_process (interaction raycast),
		# so immediate physics-server writes can trip the flush guard.
		body.set_deferred("collision_layer", 0)
		body.set_deferred("collision_mask", 0)
	var seat := get_seat_node()
	if seat != null and seat.is_inside_tree() and player.is_inside_tree():
		var previous := player.get_parent()
		if previous != null and previous != seat:
			previous.remove_child(player)
		if player.get_parent() != seat:
			seat.add_child(player)
		var body_node := player as Node3D
		body_node.position = Vector3.ZERO
		body_node.rotation = Vector3.ZERO
	_occupied = true
	_mount_time = _time
	_boost = maxf(_boost, 0.6)
	_play_sfx(_engine_id(), -10.0)
	_start_engine_audio()
	_spawn_effect(&"dust", 10)
	mounted.emit(player)
	if EventBus != null and EventBus.has_signal(&"vehicle_mounted"):
		EventBus.emit_signal(&"vehicle_mounted", self, get_vehicle_id())
	return true


## Removes the rider and puts it back where it came from. Safe during scene
## teardown, when the player was freed, or when nothing is mounted.
func dismount(forced: bool = false) -> void:
	if not _occupied:
		return
	var player := _driver
	var exit_position := get_exit_position()
	_occupied = false
	_driver = null
	_control.clear()
	_throttle_input = 0.0
	_steer_input = 0.0
	_brake_input = false
	_boost_input = false
	_jump_input = false
	_ascend_input = false
	_descend_input = false
	var player_valid := player != null and is_instance_valid(player)
	if player_valid:
		if player is CollisionObject3D:
			var body := player as CollisionObject3D
			body.set_deferred("collision_layer", _driver_layer)
			body.set_deferred("collision_mask", _driver_mask)
		var parent := _driver_original_parent
		if parent == null or not is_instance_valid(parent):
			parent = get_parent()
		if parent != null and is_instance_valid(parent):
			var current_parent := player.get_parent()
			if current_parent != null:
				current_parent.remove_child(player)
			parent.add_child(player)
			if player is Node3D:
				var body_node := player as Node3D
				body_node.global_position = exit_position
				body_node.rotation = Vector3(0.0, global_rotation.y, 0.0)
			if player.has_method("teleport_to"):
				player.call("teleport_to", exit_position)
	_driver_original_parent = null
	_stop_engine_audio()
	_play_sfx(&"brake", -12.0)
	_spawn_effect(&"dust", 8)
	var report_player: Node = player if player_valid else null
	dismounted.emit(report_player, forced)
	if EventBus != null and EventBus.has_signal(&"vehicle_dismounted"):
		EventBus.emit_signal(&"vehicle_dismounted", self, get_vehicle_id())
	# If the Player still believes it is riding us (its own _update_ride() calls
	# dismount() directly rather than exit_vehicle()), let the documented Player
	# hook finish clearing combat/collider/state so we never leave a stale rider.
	# Safe in both directions: exit_vehicle() is a no-op once it has already
	# dropped the rideable reference.
	if player_valid and player.has_method("is_riding") and bool(player.call("is_riding")):
		if player.has_method("get_rideable") and player.call("get_rideable") == self:
			if player.has_method("exit_vehicle"):
				player.call("exit_vehicle", exit_position)


## True while a rider is seated (weapon/ability lock is the Player hook's job;
## this is what the HUD and the player report read).
func is_weapon_locked() -> bool:
	return _occupied


func get_driver() -> Node:
	return _driver if _driver != null and is_instance_valid(_driver) else null


## Safe dismount spot: ground-snapped, headroom checked, with deterministic side
## fallbacks so it never hands the player a point inside geometry.
func get_exit_position() -> Vector3:
	_ensure_nodes()
	var base := global_position
	var forward := _flat_forward()
	var right := global_transform.basis.x
	right.y = 0.0
	if right.length_squared() < 0.0001:
		right = forward.cross(Vector3.UP).normalized()
	else:
		right = right.normalized()
	var candidates: Array[Vector3] = []
	var offset := _exit_offset()
	if _exit_node != null and _exit_node.is_inside_tree():
		candidates.append(_exit_node.global_position)
	candidates.append(base + right * maxf(1.6, absf(offset.x)) + Vector3.UP * 0.4)
	candidates.append(base - right * maxf(1.6, absf(offset.x)) + Vector3.UP * 0.4)
	candidates.append(base - forward * maxf(1.8, absf(offset.z)) + Vector3.UP * 0.4)
	if not is_inside_tree():
		return candidates[candidates.size() - 1]
	var fallback := base + Vector3.UP * 1.6
	for candidate in candidates:
		var snapped := _snap_to_ground(candidate, 1.2)
		if _exit_is_clear(snapped):
			return snapped
	return fallback


# --- damage ----------------------------------------------------------------


func apply_damage(amount: float, source: Node = null) -> void:
	if _destroyed or amount <= 0.0:
		return
	_health = maxf(0.0, _health - amount)
	_play_sfx(&"vehicle_hit", -5.0)
	_spawn_effect(&"sparks", 10)
	if source is Node3D and is_instance_valid(source) and _visual_root != null:
		_smoke_timer = 0.0
	if _health <= 0.0:
		_destroy_vehicle()


func _destroy_vehicle() -> void:
	if _destroyed:
		return
	_destroyed = true
	_stop_engine_audio()
	_play_sfx(&"vehicle_explode", -1.0)
	_spawn_effect(&"smoke", 20)
	if _visual_root != null:
		_visual_root.rotation.z = 0.05
		_visual_root.position.y = -0.1
	if _occupied:
		dismount(true)
	destroyed.emit(self)


func is_destroyed() -> bool:
	return _destroyed


func get_health() -> float:
	return _health


func get_max_health() -> float:
	return _max_health()


# --- input / control -------------------------------------------------------


## Headless/AI control override. Keys: throttle, steer, brake, boost, jump,
## horn, ascend, descend. Calling with an empty dictionary releases control.
func set_control_state(state: Dictionary) -> void:
	_control = state.duplicate(true)


func get_control_state() -> Dictionary:
	return _control.duplicate(true)


func _read_inputs() -> void:
	_throttle_input = 0.0
	_steer_input = 0.0
	_brake_input = false
	_boost_input = false
	_jump_input = false
	_horn_input = false
	_ascend_input = false
	_descend_input = false
	if not _control.is_empty():
		_throttle_input = clampf(float(_control.get("throttle", 0.0)), -1.0, 1.0)
		_steer_input = clampf(float(_control.get("steer", 0.0)), -1.0, 1.0)
		_brake_input = bool(_control.get("brake", false))
		_boost_input = bool(_control.get("boost", false))
		_jump_input = bool(_control.get("jump", false))
		_horn_input = bool(_control.get("horn", false))
		_ascend_input = bool(_control.get("ascend", false))
		_descend_input = bool(_control.get("descend", false))
		return
	if not _occupied or _destroyed:
		return
	var move := _action_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	_throttle_input = clampf(-move.y, -1.0, 1.0)
	_steer_input = clampf(move.x, -1.0, 1.0)
	_brake_input = _action_pressed(&"crouch") or _action_pressed(&"crouch_alt")
	_boost_input = _action_pressed(&"sprint")
	_jump_input = _action_just_pressed(&"jump")
	_horn_input = _action_just_pressed(&"fire")
	_ascend_input = _action_pressed(&"jump")
	_descend_input = _action_pressed(&"crouch")
	if _time - _mount_time > MOUNT_INPUT_GRACE and _action_just_pressed(&"interact"):
		if _driver != null and is_instance_valid(_driver) and _driver.has_method("exit_vehicle"):
			_driver.call("exit_vehicle", get_exit_position())
		else:
			dismount(false)


func _action_vector(left: StringName, right: StringName, forward: StringName, back: StringName) -> Vector2:
	for action in [left, right, forward, back]:
		if not InputMap.has_action(action):
			return Vector2.ZERO
	return Input.get_vector(left, right, forward, back)


func _action_pressed(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)


func _action_just_pressed(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)


# --- physics ---------------------------------------------------------------


func _physics_process(delta: float) -> void:
	_time += delta
	_read_inputs()
	if _destroyed:
		_settle(delta)
	elif _occupied or not _control.is_empty():
		_step_vehicle(delta)
	else:
		_settle(delta)
	move_and_slide()
	_speed_mps = Vector3(velocity.x, 0.0, velocity.z).length()
	_update_visuals(delta)
	_update_audio(delta)
	_emit_hud(delta)
	_update_smoke(delta)


## Virtual: archetype movement. Base implementation is the shared ground-vehicle
## model: raycast suspension, speed-limited steering, throttle/brake and grip.
func _step_vehicle(delta: float) -> void:
	var probe := _probe_ground(_suspension_length())
	_grounded = VehiclePhysics.is_ground_contact(probe, _suspension_length())
	_ground_normal = probe.get("normal", Vector3.UP)
	_ground_distance = float(probe.get("distance", _suspension_length()))
	var forward := _flat_forward()
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized() if right.length_squared() > 0.0001 else forward.cross(Vector3.UP)
	var speed := VehiclePhysics.forward_speed(velocity, forward)
	var authority := VehiclePhysics.steer_authority(speed, _max_speed(), 0.45)
	rotation.y += VehiclePhysics.yaw_delta(_steer_input, _turn_rate() * authority, speed, 1.5, delta)
	if _grounded:
		var target_vy := VehiclePhysics.suspension_velocity(_ground_distance, _ride_height(), velocity.y, 16.0, 8.0, 8.0)
		velocity.y = move_toward(velocity.y, target_vy, 26.0 * delta)
	else:
		velocity.y -= VehiclePhysics.gravity() * delta
	var boosting := _boost_input and _boost > 0.02 and _throttle_input > 0.05
	var max_speed := _max_speed() * (1.0 + (_boost_mult() - 1.0) * (1.0 if boosting else 0.0))
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if absf(_throttle_input) > 0.02:
		var drive := _accel() * (1.4 if boosting else 1.0)
		horizontal = horizontal.move_toward(forward * _throttle_input * max_speed, drive * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, _accel() * 0.32 * delta)
	if _brake_input:
		horizontal = horizontal.move_toward(Vector3.ZERO, _brake_force() * delta)
	var grip := _grip() * (0.32 if _brake_input else 1.0)
	horizontal = VehiclePhysics.apply_grip(horizontal, right, grip, delta)
	horizontal = VehiclePhysics.clamp_horizontal(horizontal, max_speed * 1.08)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	_update_boost(delta, boosting)


## Unoccupied / wrecked vehicles rest on the ground under gravity.
func _settle(delta: float) -> void:
	var probe := _probe_ground(_suspension_length())
	_grounded = VehiclePhysics.is_ground_contact(probe, _suspension_length())
	_ground_normal = probe.get("normal", Vector3.UP)
	_ground_distance = float(probe.get("distance", _suspension_length()))
	if _grounded:
		var target_vy := VehiclePhysics.suspension_velocity(_ground_distance, _ride_height(), velocity.y, 14.0, 8.0, 6.0)
		velocity.y = move_toward(velocity.y, target_vy, 24.0 * delta)
	else:
		velocity.y -= VehiclePhysics.gravity() * delta
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, 8.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	_boost = minf(1.0, _boost + 0.2 * delta)


func _update_boost(delta: float, boosting: bool) -> void:
	if boosting:
		_boost = maxf(0.0, _boost - 0.32 * delta)
	else:
		_boost = minf(1.0, _boost + 0.16 * delta)


func _probe_ground(max_distance: float) -> Dictionary:
	if not is_inside_tree():
		return {
			"hit": false,
			"position": global_position + Vector3.DOWN * max_distance,
			"normal": Vector3.UP,
			"distance": max_distance,
			"collider": null,
		}
	return VehiclePhysics.ground_probe(get_world_3d(), global_position, max_distance, [get_rid()])


func _flat_forward() -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3.FORWARD
	return forward.normalized()


func _snap_to_ground(point: Vector3, lift: float = 0.1) -> Vector3:
	if not is_inside_tree():
		return point
	var probe := VehiclePhysics.ground_probe(
		get_world_3d(), point + Vector3.UP * 3.0, 9.0, [get_rid()]
	)
	if probe.get("hit", false):
		return Vector3(point.x, float(probe["position"].y) + lift, point.z)
	return point


func _exit_is_clear(point: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var probe := SphereShape3D.new()
	probe.radius = 0.45
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = probe
	params.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.9)
	params.collision_mask = 1
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


# --- presentation ----------------------------------------------------------


## Virtual: archetype visual animation (wheel spin, lean, gallop bob...).
func _update_visuals(delta: float) -> void:
	if _visual_root == null:
		return
	var ratio := clampf(_speed_mps / maxf(1.0, _max_speed()), 0.0, 1.0)
	var radius := maxf(0.15, float(_visual_root.get_meta("wheel_radius", 0.55)))
	var forward_speed := VehiclePhysics.forward_speed(velocity, _flat_forward())
	for wheel_name in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
		var wheel := _visual_root.get_node_or_null(wheel_name) as Node3D
		if wheel == null:
			continue
		wheel.rotation.x += forward_speed / radius * delta
		if wheel_name == "WheelFL" or wheel_name == "WheelFR":
			wheel.rotation.y = -_steer_input * 0.42
	var propeller := _visual_root.get_node_or_null("Propeller") as Node3D
	if propeller != null and _throttle_input > 0.05:
		propeller.rotation.z += delta * (30.0 + ratio * 40.0)
	_pulse_glow(ratio)


func _pulse_glow(speed_ratio: float) -> void:
	if _visual_root == null:
		return
	var material: Variant = _visual_root.get_meta("glow_material", null)
	if material is StandardMaterial3D:
		var glow_material := material as StandardMaterial3D
		glow_material.emission_energy_multiplier = 2.4 + sin(_time * 6.0) * 0.35 + speed_ratio * 1.6
	var headlight: Variant = _visual_root.get_meta("headlight", null)
	if headlight is OmniLight3D:
		(headlight as OmniLight3D).light_energy = 1.4 + speed_ratio * 1.1


func _update_audio(delta: float) -> void:
	_horn_cooldown = maxf(0.0, _horn_cooldown - delta)
	if not _occupied:
		_was_boosting = false
		return
	var ratio := clampf(_speed_mps / maxf(1.0, _max_speed()), 0.0, 1.0)
	if _engine_loop != null and is_instance_valid(_engine_loop):
		_engine_loop.pitch_scale = lerpf(0.85, 1.4, ratio)
	if _wind_loop != null and is_instance_valid(_wind_loop):
		_wind_loop.volume_db = lerpf(-38.0, -14.0, ratio)
		_wind_loop.pitch_scale = lerpf(0.8, 1.25, ratio)
	if _horn_input and _horn_cooldown <= 0.0:
		_horn_cooldown = 1.0
		_play_sfx(&"horn", -8.0)
	if _boost_input and _boost > 0.05 and not _was_boosting:
		_play_sfx(&"boost", -9.0)
	_was_boosting = _boost_input


func _update_smoke(delta: float) -> void:
	if _health > _max_health() * 0.35:
		return
	_smoke_timer -= delta
	if _smoke_timer <= 0.0:
		_smoke_timer = 1.4
		_spawn_effect(&"smoke", 6)


func _emit_hud(delta: float) -> void:
	_hud_timer += delta
	if _hud_timer < HUD_INTERVAL:
		return
	_hud_timer = 0.0
	hud_updated.emit(get_hud_snapshot())


# --- HUD -------------------------------------------------------------------


func get_speed_kph() -> float:
	return VehiclePhysics.speed_kph(velocity)


func get_gait() -> StringName:
	return _gait


func get_stamina() -> float:
	return _boost


func get_gear() -> int:
	return VehiclePhysics.gear_for(VehiclePhysics.speed_kph(velocity) / maxf(1.0, _max_speed() * 3.6), 5)


func get_hud_snapshot() -> Dictionary:
	var spec := get_vehicle_spec()
	var snapshot := {
		"id": StringName(spec.get("id", &"vehicle")),
		"name": String(spec.get("name", "Vehicle")),
		"kind": String(spec.get("kind", &"ground")),
		"speed_kph": get_speed_kph(),
		"max_speed_kph": _max_speed() * 3.6,
		"health": _health,
		"max_health": _max_health(),
		"boost": _boost,
		"stamina": get_stamina(),
		"gear": get_gear(),
		"icon": spec.get("icon", &"vehicle"),
		"accent": spec.get("hud_color", Color("62e6c3")),
		"weapon_locked": is_weapon_locked(),
		"occupied": _occupied,
		"destroyed": _destroyed,
		"gait": String(_gait),
	}
	var extra := _extra_hud_data()
	for key in extra.keys():
		snapshot[key] = extra[key]
	return snapshot


## Virtual: archetype-specific HUD values (stall, docked, gait phase...).
func _extra_hud_data() -> Dictionary:
	return {}


# --- audio / VFX helpers (no hard dependencies) ----------------------------


func has_audio_stream(id: StringName) -> bool:
	if AudioDirector == null:
		return false
	if AudioDirector.has_method("has_stream"):
		return bool(AudioDirector.call("has_stream", id))
	if AudioDirector.has_method("get_stream"):
		return AudioDirector.call("get_stream", id) != null
	return false


func _play_sfx(id: StringName, volume_db: float = -8.0) -> void:
	if id == &"" or not has_audio_stream(id):
		return
	# Headless runs have no audio device; skipping playback keeps CI logs clean
	# and avoids AudioStream playback objects surviving engine shutdown.
	if DisplayServer.get_name() == "headless":
		return
	AudioDirector.play_sfx(id, volume_db)


## Starts the authored engine loop (audio wave's play_loop_3d) while riding.
func _start_engine_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var engine := _engine_id()
	if engine != &"" and _engine_loop == null and has_audio_stream(engine):
		_engine_loop = _start_loop(engine)
	var wind := _wind_loop_id()
	if wind != &"" and _wind_loop == null and has_audio_stream(wind):
		_wind_loop = _start_loop(wind)
		if _wind_loop != null:
			_wind_loop.volume_db = -38.0


func _start_loop(id: StringName) -> AudioStreamPlayer3D:
	if not AudioDirector.has_method("play_loop_3d"):
		return null
	var player: Variant = AudioDirector.call("play_loop_3d", id, self)
	if player is AudioStreamPlayer3D:
		return player as AudioStreamPlayer3D
	return null


func _stop_engine_audio() -> void:
	if _engine_loop != null and is_instance_valid(_engine_loop):
		_engine_loop.stop()
		_engine_loop.queue_free()
	_engine_loop = null
	if _wind_loop != null and is_instance_valid(_wind_loop):
		_wind_loop.stop()
		_wind_loop.queue_free()
	_wind_loop = null


## ParticleLibrary is authored by the VFX wave. Prefers its spawn() helper (which
## auto-frees the burst) and falls back to make(); missing packs are a silent
## no-op so headless suites stay green. Effects are rate-limited per id.
func _spawn_effect(effect_id: StringName, count: int = 10) -> void:
	if not ResourceLoader.exists(PARTICLE_LIBRARY_PATH):
		return
	var last_time := float(_fx_cooldowns.get(effect_id, -100.0))
	if _time - last_time < 0.2:
		return
	_fx_cooldowns[effect_id] = _time
	var library_script: Script = load(PARTICLE_LIBRARY_PATH)
	if library_script == null:
		return
	var parent := get_parent()
	if library_script.has_method("spawn") and parent is Node3D:
		var spawned: Variant = library_script.call(
			"spawn", parent as Node3D, effect_id, global_position, count
		)
		if spawned is Node3D:
			return
	if not library_script.has_method("make"):
		return
	var instance: Variant = library_script.call("make", effect_id, count)
	if not (instance is Node3D):
		return
	var effect := instance as Node3D
	if parent == null:
		effect.free()
		return
	parent.add_child(effect)
	effect.global_position = global_position
	if effect is GPUParticles3D:
		(effect as GPUParticles3D).emitting = true
	elif effect is CPUParticles3D:
		(effect as CPUParticles3D).emitting = true
