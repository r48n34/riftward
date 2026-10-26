extends "res://features/vehicles/vehicle_base.gd"
## AIRPLANE — winged aircraft that needs airspeed to stay up. Below stall speed it
## sinks and the nose drops; above takeoff speed it climbs on lift. On the ground
## it taxis on three wheels and rolls to a stop.
## Tuning: 90 m/s (~324 km/h) top speed, 20 m/s^2 engine thrust, 1.2 rad/s yaw.

const STALL_SPEED := 30.0
const CRUISE_SPEED := 62.0
const TAKEOFF_SPEED := 38.0

var _stall: bool = false
var _airspeed: float = 0.0


func _make_spec() -> Dictionary:
	return {
		"id": &"airplane",
		"name": "Kestrel Wing",
		"kind": &"air",
		"seats": 1,
		"max_speed": 90.0,
		"accel": 20.0,
		"turn_rate": 1.2,
		"health": 420.0,
		"mass": 2400.0,
		"icon": &"airplane",
		"hud_color": Color("6fa8ff"),
		"boost_mult": 1.2,
		"stall_speed": STALL_SPEED,
		"takeoff_speed": TAKEOFF_SPEED,
	}


func _configure_body() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING


func _collision_extents() -> Vector3:
	return Vector3(2.0, 1.3, 6.2)


func _collision_offset() -> Vector3:
	return Vector3(0.0, 0.6, 0.0)


func _ride_height() -> float:
	return 0.45


func _seat_offset() -> Vector3:
	return Vector3(0.0, -0.07, -0.72)


func _exit_offset() -> Vector3:
	return Vector3(3.0, 0.0, -1.2)


func _engine_id() -> StringName:
	return &"engine_plane"


func _wind_loop_id() -> StringName:
	return &"wind_loop"


func get_airspeed() -> float:
	return _airspeed


func is_stalling() -> bool:
	return _stall


func _step_vehicle(delta: float) -> void:
	var probe := _probe_ground(8.0)
	_grounded = VehiclePhysics.is_ground_contact(probe, 1.4)
	_ground_normal = probe.get("normal", Vector3.UP)
	_ground_distance = float(probe.get("distance", 999.0))
	var forward := -global_transform.basis.z
	_airspeed = velocity.dot(forward)
	# Engine thrust (reverse thrust is weak — this is not a helicopter).
	if _throttle_input > 0.02:
		velocity += forward * _accel() * _throttle_input * delta
	elif _throttle_input < -0.02:
		velocity += forward * _accel() * 0.4 * _throttle_input * delta
	# Gravity vs. wing lift.
	var grav := VehiclePhysics.gravity()
	velocity.y -= grav * delta
	var lift := VehiclePhysics.lift_ratio(maxf(0.0, _airspeed), STALL_SPEED, CRUISE_SPEED) * grav * 2.05
	velocity.y += lift * delta
	# Pitch: W/S = throttle, Space = nose up, Ctrl = nose down.
	var pitch_input := 0.0
	if _jump_input or _ascend_input:
		pitch_input += 1.0
	if _descend_input:
		pitch_input -= 1.0
	var pitch_target := pitch_input * 0.42
	if absf(pitch_input) < 0.05:
		pitch_target = 0.04 if _airspeed > TAKEOFF_SPEED else 0.0
	rotation.x = lerpf(rotation.x, pitch_target, clampf(delta * 1.8, 0.0, 1.0))
	if _airspeed > 5.0:
		velocity.y += sin(rotation.x) * _airspeed * 0.4 * delta
	# Yaw and roll.
	rotation.y -= _steer_input * _turn_rate() * clampf(_airspeed / 55.0, 0.3, 1.0) * delta
	rotation.z = lerpf(rotation.z, -_steer_input * 0.55, clampf(delta * 3.2, 0.0, 1.0))
	# Aerodynamic damping bleeds sideways slip.
	var right := global_transform.basis.x
	velocity -= right * velocity.dot(right) * clampf(delta * 2.2, 0.0, 1.0)
	# Taxi/landing: wheels on the ground, rolling friction and pitch settle.
	if _grounded and _airspeed < TAKEOFF_SPEED:
		rotation.x = lerpf(rotation.x, 0.0, clampf(delta * 4.0, 0.0, 1.0))
		rotation.z = lerpf(rotation.z, 0.0, clampf(delta * 5.0, 0.0, 1.0))
		if velocity.y < 0.0:
			velocity.y = move_toward(velocity.y, 0.0, 14.0 * delta)
		var rolling := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, 2.6 * delta)
		velocity.x = rolling.x
		velocity.z = rolling.z
		if absf(_throttle_input) < 0.05:
			_stall = false
	# Stall: no airspeed means the nose drops and the aircraft falls.
	_stall = _airspeed < STALL_SPEED and not _grounded
	if _stall and not _grounded:
		rotation.x = lerpf(rotation.x, -0.28, clampf(delta * 1.4, 0.0, 1.0))
		velocity.y -= 3.0 * delta
	velocity = velocity.limit_length(_max_speed() * 1.1)
	_update_boost(delta, _boost_input and _throttle_input > 0.1)
	_grounded = _grounded and _airspeed < TAKEOFF_SPEED


func _update_visuals(delta: float) -> void:
	super._update_visuals(delta)
	if _visual_root == null:
		return
	# Control surfaces are baked into the merged body; the visible feedback is the
	# airframe's bank handled on the chassis itself. Exhaust only under power.
	if _throttle_input > 0.35 and _speed_mps > 6.0:
		_spawn_effect(&"exhaust", 1)


func _extra_hud_data() -> Dictionary:
	return {
		"stall": _stall,
		"airspeed_kph": maxf(0.0, _airspeed) * 3.6,
		"stall_speed_kph": STALL_SPEED * 3.6,
		"takeoff_speed_kph": TAKEOFF_SPEED * 3.6,
	}
