extends "res://features/vehicles/vehicle_base.gd"
## RIG — the fast ground car. Wheeled suspension, high top speed, a handbrake that
## breaks rear grip for drifts, and a boost reserve that refills while coasting.
## Tuning: 30 m/s (~108 km/h) top speed, 16 m/s^2 drive, 2.1 rad/s turn rate.


func _make_spec() -> Dictionary:
	return {
		"id": &"rig",
		"name": "Rift Rig",
		"kind": &"ground",
		"seats": 2,
		"max_speed": 30.0,
		"accel": 16.0,
		"turn_rate": 2.1,
		"health": 340.0,
		"mass": 1600.0,
		"icon": &"rig",
		"hud_color": Color("ffb866"),
		"boost_mult": 1.35,
		"grip": 8.0,
		"brake_force": 24.0,
	}


func _collision_extents() -> Vector3:
	return Vector3(2.2, 1.4, 4.4)


func _collision_offset() -> Vector3:
	return Vector3(0.0, 0.45, 0.0)


func _ride_height() -> float:
	return 0.55


func _seat_offset() -> Vector3:
	return Vector3(0.0, -0.72, -0.15)


func _exit_offset() -> Vector3:
	return Vector3(2.6, 0.0, 0.2)


func _engine_id() -> StringName:
	return &"engine_rig"


func _step_vehicle(delta: float) -> void:
	super._step_vehicle(delta)
	# Handbrake drift: while braking above ~8 m/s the rear steps out a little,
	# turning some forward momentum into lateral slip before grip recovers.
	if _brake_input and _grounded:
		var forward := _flat_forward()
		var speed := VehiclePhysics.forward_speed(velocity, forward)
		if speed > 8.0:
			var right := global_transform.basis.x
			right.y = 0.0
			right = right.normalized()
			velocity += right * (-_steer_input * speed * 0.35 * delta)
			velocity.x = lerpf(velocity.x, forward.x * speed, clampf(delta * 2.0, 0.0, 1.0))
			velocity.z = lerpf(velocity.z, forward.z * speed, clampf(delta * 2.0, 0.0, 1.0))
			if absf(_steer_input) > 0.2:
				_spawn_effect(&"dust", 2)


func _update_visuals(delta: float) -> void:
	super._update_visuals(delta)
	if _visual_root == null:
		return
	# Chassis squat under acceleration and dive under braking.
	var target_pitch := 0.0
	if absf(_throttle_input) > 0.1 and _grounded:
		target_pitch = -_throttle_input * 0.03
	if _brake_input and _speed_mps > 3.0:
		target_pitch = 0.05
	_visual_root.rotation.x = lerpf(_visual_root.rotation.x, target_pitch, clampf(delta * 5.0, 0.0, 1.0))
