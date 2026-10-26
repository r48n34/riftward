extends "res://features/vehicles/vehicle_base.gd"
## SPACESHIP — VTOL skiff: vertical thrusters hold an altitude band, forward
## thrust is strong, and it auto-docks when it settles slowly onto a marked pad.
## Tuning: 60 m/s (~216 km/h) top speed, 30 m/s^2 thrust, 1.6 rad/s yaw,
## 120 m altitude clamp.

const HOVER_ALTITUDE := 2.4
const MAX_ALTITUDE := 120.0
const ASCEND_SPEED := 9.0
const DESCEND_SPEED := 7.0
const DOCK_GROUPS: Array[StringName] = [&"dock_pad", &"exfil_beacon", &"vehicle_dock"]

var _docked: bool = false
var _altitude: float = 0.0


func _make_spec() -> Dictionary:
	return {
		"id": &"spaceship",
		"name": "Void Skiff",
		"kind": &"vtol",
		"seats": 1,
		"max_speed": 60.0,
		"accel": 30.0,
		"turn_rate": 1.6,
		"health": 500.0,
		"mass": 3200.0,
		"icon": &"spaceship",
		"hud_color": Color("c79cff"),
		"boost_mult": 1.3,
		"max_altitude": MAX_ALTITUDE,
		"hover_altitude": HOVER_ALTITUDE,
	}


func _configure_body() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING


func _collision_extents() -> Vector3:
	return Vector3(2.6, 1.5, 5.2)


func _collision_offset() -> Vector3:
	return Vector3(0.0, 0.55, 0.0)


func _ride_height() -> float:
	return 0.9


func _seat_offset() -> Vector3:
	return Vector3(0.0, -0.52, -0.35)


func _exit_offset() -> Vector3:
	return Vector3(3.1, 0.0, 0.3)


func _engine_id() -> StringName:
	return &"engine_ship"


func _wind_loop_id() -> StringName:
	return &"wind_loop"


func is_docked() -> bool:
	return _docked


func get_altitude() -> float:
	return _altitude


func _step_vehicle(delta: float) -> void:
	var probe := _probe_ground(MAX_ALTITUDE + 20.0)
	_grounded = VehiclePhysics.is_ground_contact(probe, 2.0)
	_ground_normal = probe.get("normal", Vector3.UP)
	_ground_distance = float(probe.get("distance", MAX_ALTITUDE + 20.0))
	_altitude = _ground_distance if probe.get("hit", false) else MAX_ALTITUDE + 20.0
	var forward := _flat_forward()
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized() if right.length_squared() > 0.0001 else forward.cross(Vector3.UP)
	# VTOL vertical control: jump climbs, crouch descends, otherwise hold altitude.
	var target_vy := 0.0
	if _ascend_input:
		target_vy = ASCEND_SPEED
	elif _descend_input:
		target_vy = -DESCEND_SPEED
	elif probe.get("hit", false):
		target_vy = clampf((_ride_height() - _altitude) * 1.8, -5.0, 5.0)
	else:
		target_vy = 0.0
	# Hard altitude clamp: never below the skids, never above the ceiling.
	var altitude_clamp := VehiclePhysics.altitude_clamp_velocity(_altitude, MAX_ALTITUDE)
	if altitude_clamp > 0.0 and target_vy < altitude_clamp:
		target_vy = altitude_clamp
	elif altitude_clamp < 0.0 and target_vy > altitude_clamp:
		target_vy = altitude_clamp
	velocity.y = move_toward(velocity.y, target_vy, 16.0 * delta)
	# Forward and lateral thrust with weak aerodynamic grip.
	var boosting := _boost_input and _boost > 0.02 and _throttle_input > 0.05
	var max_speed := _max_speed() * (1.0 + (_boost_mult() - 1.0) * (1.0 if boosting else 0.0))
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if absf(_throttle_input) > 0.02:
		var drive := _accel() * (1.3 if boosting else 1.0)
		horizontal = horizontal.move_toward(forward * _throttle_input * max_speed, drive * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, _accel() * 0.3 * delta)
	if _brake_input:
		horizontal = horizontal.move_toward(Vector3.ZERO, _brake_force() * delta)
	horizontal = VehiclePhysics.apply_grip(horizontal, right, 2.5, delta)
	horizontal = VehiclePhysics.clamp_horizontal(horizontal, max_speed * 1.08)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	# Yaw with a mild bank.
	var authority := VehiclePhysics.steer_authority(Vector3(velocity.x, 0.0, velocity.z).length(), _max_speed(), 0.55)
	rotation.y += VehiclePhysics.yaw_delta(_steer_input, _turn_rate() * authority, horizontal.length(), 2.0, delta)
	rotation.z = lerpf(rotation.z, -_steer_input * 0.28, clampf(delta * 3.0, 0.0, 1.0))
	_update_boost(delta, boosting)
	# Docking: slow, low, and standing over a marked pad.
	var collider = probe.get("collider", null)
	var on_pad := false
	if collider is Node and is_instance_valid(collider):
		for group_name in DOCK_GROUPS:
			if (collider as Node).is_in_group(group_name):
				on_pad = true
				break
	var was_docked := _docked
	_docked = (
		probe.get("hit", false)
		and _altitude < 3.2
		and horizontal.length() < 2.0
		and on_pad
	)
	if _docked:
		velocity.x = 0.0
		velocity.z = 0.0
	if _docked and not was_docked:
		_play_sfx(&"brake", -10.0)
		_spawn_effect(&"dust", 10)


func _update_visuals(delta: float) -> void:
	super._update_visuals(delta)
	if _visual_root == null:
		return
	# Hover bob + VTOL thruster wash.
	var ratio := clampf(_speed_mps / maxf(1.0, _max_speed()), 0.0, 1.0)
	_visual_root.position.y = sin(_time * 2.2) * (0.05 - ratio * 0.03)
	if _ascend_input or _grounded:
		_spawn_effect(&"smoke", 1)


func _extra_hud_data() -> Dictionary:
	return {
		"docked": _docked,
		"altitude": _altitude,
		"max_altitude": MAX_ALTITUDE,
	}
