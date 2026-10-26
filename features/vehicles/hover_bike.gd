extends "res://features/vehicles/vehicle_base.gd"
## HOVER BIKE — faster and nimbler than the rig, held ~1.2 m over the terrain by a
## spring-damper hover controller instead of wheels. Leans into turns and boosts.
## Tuning: 38 m/s (~137 km/h) top speed, 24 m/s^2 thrust, 3.2 rad/s turn rate.

const HOVER_HEIGHT := 1.2


func _make_spec() -> Dictionary:
	return {
		"id": &"hoverbike",
		"name": "Vale Hoverbike",
		"kind": &"hover",
		"seats": 1,
		"max_speed": 38.0,
		"accel": 24.0,
		"turn_rate": 3.2,
		"health": 180.0,
		"mass": 320.0,
		"icon": &"hoverbike",
		"hud_color": Color("62e6c3"),
		"boost_mult": 1.3,
		"grip": 6.0,
		"brake_force": 18.0,
	}


func _configure_body() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING


func _collision_extents() -> Vector3:
	return Vector3(1.0, 0.9, 2.6)


func _collision_offset() -> Vector3:
	return Vector3(0.0, 0.15, 0.0)


func _ride_height() -> float:
	return HOVER_HEIGHT


func _seat_offset() -> Vector3:
	return Vector3(0.0, -1.12, 0.05)


func _exit_offset() -> Vector3:
	return Vector3(1.6, 0.0, 0.0)


func _engine_id() -> StringName:
	return &"engine_bike"


func _step_vehicle(delta: float) -> void:
	var probe := _probe_ground(HOVER_HEIGHT + 6.0)
	var forward := _flat_forward()
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized() if right.length_squared() > 0.0001 else forward.cross(Vector3.UP)
	var speed := VehiclePhysics.forward_speed(velocity, forward)
	_grounded = VehiclePhysics.is_ground_contact(probe, HOVER_HEIGHT + 0.6)
	_ground_normal = probe.get("normal", Vector3.UP)
	_ground_distance = float(probe.get("distance", 999.0))
	# Hover controller: critically-damped spring toward HOVER_HEIGHT.
	if probe.get("hit", false):
		var target_vy := clampf(
			(_ride_height() - _ground_distance) * 9.0 - velocity.y * 3.0,
			-9.0,
			10.0
		)
		velocity.y = move_toward(velocity.y, target_vy, 34.0 * delta)
		# Keep the bike's up axis close to the slope normal.
		_ground_normal = VehiclePhysics.aligned_up(_ground_normal, probe.get("normal", Vector3.UP), 8.0, delta)
	else:
		velocity.y -= VehiclePhysics.gravity() * delta
	# Steering: very direct, with a small speed-based authority falloff.
	var authority := VehiclePhysics.steer_authority(speed, _max_speed(), 0.62)
	rotation.y += VehiclePhysics.yaw_delta(_steer_input, _turn_rate() * authority, speed, 1.2, delta)
	# Hover thrust: full authority in the air, grip only near the ground.
	var boosting := _boost_input and _boost > 0.02 and _throttle_input > 0.05
	var max_speed := _max_speed() * (1.0 + (_boost_mult() - 1.0) * (1.0 if boosting else 0.0))
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if absf(_throttle_input) > 0.02:
		var drive := _accel() * (1.35 if boosting else 1.0)
		horizontal = horizontal.move_toward(forward * _throttle_input * max_speed, drive * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, _accel() * 0.4 * delta)
	if _brake_input:
		horizontal = horizontal.move_toward(Vector3.ZERO, _brake_force() * delta)
	var grip := _grip() * (0.4 if _brake_input else 1.0)
	if not _grounded:
		grip *= 0.35
	horizontal = VehiclePhysics.apply_grip(horizontal, right, grip, delta)
	horizontal = VehiclePhysics.clamp_horizontal(horizontal, max_speed * 1.08)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	_update_boost(delta, boosting)
	if boosting and _speed_mps > 4.0:
		_spawn_effect(&"exhaust", 2)


func _update_visuals(delta: float) -> void:
	super._update_visuals(delta)
	if _visual_root == null:
		return
	var ratio := clampf(_speed_mps / maxf(1.0, _max_speed()), 0.0, 1.0)
	# Lean into the turn and pitch with acceleration; bob on the hover cushion.
	var lean := VehiclePhysics.bank_angle(_steer_input, ratio, 0.55)
	_visual_root.rotation.z = lerpf(_visual_root.rotation.z, lean, clampf(delta * 7.0, 0.0, 1.0))
	_visual_root.rotation.x = lerpf(_visual_root.rotation.x, -_throttle_input * 0.06, clampf(delta * 6.0, 0.0, 1.0))
	_visual_root.position.y = sin(_time * 3.6) * 0.045 * (1.0 - ratio * 0.4)
