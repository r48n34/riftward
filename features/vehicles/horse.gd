extends "res://features/vehicles/vehicle_base.gd"
## HORSE — the Warden steed. Gaits are driven by input hold time and stamina:
## idle -> walk -> trot -> canter -> gallop, with a hard turn-rate limit that
## tightens as the gait opens up. Jumping costs stamina. The gallop bob and leg
## swing are bone-less node offsets so there is no animation rig to maintain.
## Tuning: 18 m/s (~65 km/h) at gallop, 8 m/s^2 acceleration, 2.6 rad/s turn.

const GAITS := [
	{"id": &"idle", "speed": 0.0, "drain": -0.06},
	{"id": &"walk", "speed": 3.4, "drain": -0.04},
	{"id": &"trot", "speed": 7.2, "drain": 0.02},
	{"id": &"canter", "speed": 12.0, "drain": 0.05},
	{"id": &"gallop", "speed": 18.0, "drain": 0.09},
]
## Seconds of forward hold needed before each gait unlocks.
const GAIT_HOLDS := [0.0, 0.0, 0.9, 2.0, 3.2]
const LEG_NAMES := ["LegFL", "LegFR", "LegRL", "LegRR"]
const JUMP_VELOCITY := 6.2
const STAMINA_DRAIN_GATE := 0.02

var _gait_index: int = 0
var _gait_hold: float = 0.0
var _gait_phase: float = 0.0
var _stamina: float = 1.0


func _make_spec() -> Dictionary:
	return {
		"id": &"horse",
		"name": "Warden Steed",
		"kind": &"beast",
		"seats": 1,
		"max_speed": 18.0,
		"accel": 8.0,
		"turn_rate": 2.6,
		"health": 220.0,
		"mass": 600.0,
		"icon": &"horse",
		"hud_color": Color("ffb866"),
		"boost_mult": 1.0,
		"grip": 10.0,
		"brake_force": 12.0,
		"gaits": ["idle", "walk", "trot", "canter", "gallop"],
	}


func _collision_extents() -> Vector3:
	return Vector3(0.9, 1.4, 2.4)


func _collision_offset() -> Vector3:
	return Vector3(0.0, 0.85, 0.05)


func _ride_height() -> float:
	return 0.05


func _seat_offset() -> Vector3:
	return Vector3(0.0, 0.23, 0.02)


func _exit_offset() -> Vector3:
	return Vector3(1.5, 0.0, 0.0)


func _engine_id() -> StringName:
	return &""


func get_gait() -> StringName:
	return _gait


func get_gait_index() -> int:
	return _gait_index


func get_stamina() -> float:
	return _stamina


func get_gait_speed() -> float:
	return float(GAITS[_gait_index].get("speed", 0.0))


func mount(player: Node) -> bool:
	var accepted := super.mount(player)
	if accepted:
		_gait_index = 0
		_gait_hold = 0.0
		_gait_phase = 0.0
		_stamina = maxf(_stamina, 0.65)
		_gait = &"idle"
		_play_sfx(&"whinny", -8.0)
	return accepted


func dismount(forced: bool = false) -> void:
	super.dismount(forced)
	_gait_index = 0
	_gait_hold = 0.0
	_gait = &"idle"


## Deployment `summon_ride` hook: teleports the unoccupied horse next to the
## given origin (usually the player) and reports whether it moved.
func summon(origin: Vector3) -> bool:
	if _occupied or _destroyed or not is_inside_tree():
		return false
	var target := _snap_to_ground(origin + Vector3(2.6, 0.0, 2.6), 0.15)
	global_position = target
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	_play_sfx(&"whinny", -6.0)
	_spawn_effect(&"dust", 12)
	return true


## Convenience wrapper so `summon_ride` can pass the player node directly.
func whistle(player: Node = null) -> bool:
	var origin := global_position
	if player is Node3D and is_instance_valid(player):
		origin = (player as Node3D).global_position
	return summon(origin)


func _update_gait(delta: float) -> void:
	if not _occupied and _control.is_empty():
		_gait_index = 0
		_gait_hold = 0.0
		_gait = &"idle"
		return
	if _throttle_input > 0.1:
		_gait_hold += delta * (1.7 if _boost_input else 1.0)
		var target := 1
		if _gait_hold >= float(GAIT_HOLDS[4]):
			target = 4
		elif _gait_hold >= float(GAIT_HOLDS[3]):
			target = 3
		elif _gait_hold >= float(GAIT_HOLDS[2]):
			target = 2
		if _stamina <= STAMINA_DRAIN_GATE:
			target = mini(target, 2)
		_gait_index = target
	else:
		_gait_hold = maxf(0.0, _gait_hold - delta * 2.4)
		_gait_index = 0
	_gait = StringName(GAITS[_gait_index]["id"])


func _step_vehicle(delta: float) -> void:
	_update_gait(delta)
	var probe := _probe_ground(_suspension_length())
	_grounded = VehiclePhysics.is_ground_contact(probe, _suspension_length())
	_ground_normal = probe.get("normal", Vector3.UP)
	_ground_distance = float(probe.get("distance", _suspension_length()))
	var forward := _flat_forward()
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized() if right.length_squared() > 0.0001 else forward.cross(Vector3.UP)
	if _grounded:
		var target_vy := VehiclePhysics.suspension_velocity(_ground_distance, _ride_height(), velocity.y, 14.0, 8.0, 7.0)
		velocity.y = move_toward(velocity.y, target_vy, 30.0 * delta)
	else:
		velocity.y -= VehiclePhysics.gravity() * delta
	# Gait-limited ground speed.
	var gait_speed := get_gait_speed() * (0.85 + 0.15 * _stamina)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if _throttle_input > 0.05:
		horizontal = horizontal.move_toward(forward * gait_speed * _throttle_input, _accel() * delta)
	elif _throttle_input < -0.05:
		horizontal = horizontal.move_toward(Vector3.ZERO, _brake_force() * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, 5.5 * delta)
	# Turn-rate limit: a gallop cannot pivot like a walk.
	var turn := _turn_rate() * lerpf(1.0, 0.45, float(_gait_index) / 3.0)
	rotation.y += VehiclePhysics.yaw_delta(_steer_input, turn, horizontal.length(), 1.0, delta)
	horizontal = VehiclePhysics.apply_grip(horizontal, right, _grip(), delta)
	horizontal = VehiclePhysics.clamp_horizontal(horizontal, 20.0)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	# Jump: costs stamina and drops the gait one step.
	if _jump_input and _grounded and _stamina > 0.12:
		velocity.y = JUMP_VELOCITY
		_stamina = maxf(0.0, _stamina - 0.1)
		_gait_index = mini(_gait_index, 2)
		_gait_hold = float(GAIT_HOLDS[_gait_index])
		_play_sfx(&"whinny", -7.0)
		_spawn_effect(&"dust", 8)
	# Stamina economy: galloping drains, walking recovers.
	var drain := float(GAITS[_gait_index].get("drain", 0.0))
	_stamina = clampf(_stamina - drain * delta, 0.0, 1.0)
	if _stamina <= STAMINA_DRAIN_GATE and _gait_index >= 3:
		_gait_index = 2
		_gait_hold = float(GAIT_HOLDS[2])
		_gait = StringName(GAITS[_gait_index]["id"])


func _update_visuals(delta: float) -> void:
	if _visual_root == null:
		return
	var speed_ratio := clampf(_speed_mps / 18.0, 0.0, 1.0)
	_gait_phase += delta * (2.0 + float(_gait_index) * 3.4) * (0.35 + speed_ratio)
	# Node-offset gallop bob (no bones): vertical bounce plus body sway.
	var bob_amplitudes := [0.0, 0.015, 0.04, 0.075, 0.12]
	var amplitude := float(bob_amplitudes[_gait_index])
	_visual_root.position.y = absf(sin(_gait_phase)) * amplitude
	_visual_root.rotation.z = sin(_gait_phase * 0.5) * 0.015 * speed_ratio
	_visual_root.rotation.x = lerpf(_visual_root.rotation.x, -_throttle_input * 0.05 * speed_ratio, clampf(delta * 4.0, 0.0, 1.0))
	# Four-beat leg swing on the hip pivots.
	var stride := 0.16 + float(_gait_index) * 0.12
	for index in LEG_NAMES.size():
		var leg := _visual_root.get_node_or_null(LEG_NAMES[index]) as Node3D
		if leg == null:
			continue
		var phase_offset := 0.0
		if index % 2 == 1:
			phase_offset += PI
		if index >= 2:
			phase_offset += PI * 0.5
		leg.rotation.x = sin(_gait_phase + phase_offset) * stride
	var tail := _visual_root.get_node_or_null("Tail") as Node3D
	if tail != null:
		tail.rotation.z = sin(_gait_phase * 0.8) * 0.18
		tail.rotation.x = 0.1 + sin(_gait_phase * 0.46) * 0.08
	_pulse_glow(speed_ratio)


func _update_audio(delta: float) -> void:
	_horn_cooldown = maxf(0.0, _horn_cooldown - delta)
	if not _occupied:
		return
	_engine_timer -= delta
	if _engine_timer <= 0.0:
		match _gait_index:
			4:
				_engine_timer = 0.24
				_play_sfx(&"hoof_gallop", -13.0)
			3:
				_engine_timer = 0.32
				_play_sfx(&"hoof_trot", -13.0)
			2:
				_engine_timer = 0.42
				_play_sfx(&"hoof_trot", -15.0)
			1:
				_engine_timer = 0.62
				_play_sfx(&"hoof_walk", -16.0)
			_:
				_engine_timer = 1.0
	if _horn_input and _horn_cooldown <= 0.0:
		_horn_cooldown = 1.2
		_play_sfx(&"whinny", -7.0)


func get_hud_snapshot() -> Dictionary:
	var snapshot := super.get_hud_snapshot()
	snapshot["boost"] = _stamina
	snapshot["stamina"] = _stamina
	snapshot["gear"] = _gait_index + 1
	snapshot["gait"] = String(_gait)
	return snapshot


func _extra_hud_data() -> Dictionary:
	return {
		"gait": String(_gait),
		"gait_index": _gait_index,
		"stamina": _stamina,
		"gait_speed_kph": get_gait_speed() * 3.6,
	}
