class_name VehiclePhysics
extends RefCounted
## Deterministic, hand-rolled vehicle math shared by every Rideable archetype.
##
## The project runs Jolt and needs repeatable headless behaviour, so rideables are
## CharacterBody3D nodes driven by ray probes and explicit forces instead of
## VehicleBody3D wheel joints. Everything here is pure math: no scene access, no
## randomness, no timers.

const DEFAULT_GRAVITY := 9.8


## Gravity used by rideable integration. Reads the project setting so the whole
## gameplay layer stays consistent if it is retuned.
static func gravity() -> float:
	return maxf(0.1, float(ProjectSettings.get_setting("physics/3d/default_gravity", DEFAULT_GRAVITY)))


## Downward ray probe used for suspension, hover height and landing.
## Returns {hit: bool, position: Vector3, normal: Vector3, distance: float,
## collider: Object}. When nothing is hit, distance equals max_distance.
static func ground_probe(
	world_3d: World3D,
	origin: Vector3,
	max_distance: float,
	exclude: Array = []
) -> Dictionary:
	var result := {
		"hit": false,
		"position": origin + Vector3.DOWN * max_distance,
		"normal": Vector3.UP,
		"distance": max_distance,
		"collider": null,
	}
	if world_3d == null or max_distance <= 0.0:
		return result
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * max_distance, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var valid: Array[RID] = []
	for entry in exclude:
		if entry is RID:
			valid.append(entry)
	query.exclude = valid
	var hit: Dictionary = world_3d.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return result
	var point: Vector3 = hit.get("position", result["position"])
	result["hit"] = true
	result["position"] = point
	result["normal"] = hit.get("normal", Vector3.UP)
	result["distance"] = origin.distance_to(point)
	result["collider"] = hit.get("collider", null)
	return result


## Spring-damper force for one suspension strut. Positive compression pushes the
## chassis away from the ground; damping bleeds vertical oscillation.
static func suspension_force(
	compression: float,
	vertical_speed: float,
	stiffness: float = 55.0,
	damping: float = 9.0
) -> float:
	return compression * stiffness - vertical_speed * damping


## Target vertical velocity that settles the chassis at `ride_height` above the
## probed ground. `vertical_speed` is the current velocity.y.
static func suspension_velocity(
	distance: float,
	ride_height: float,
	vertical_speed: float,
	stiffness: float = 16.0,
	damping: float = 8.0,
	limit: float = 12.0
) -> float:
	var target := (ride_height - distance) * stiffness - vertical_speed * damping
	return clampf(target, -limit, limit)


## Ground vehicles lose steering authority at speed so high-speed runs stay
## stable. Returns a multiplier in [min_authority, 1].
static func steer_authority(speed: float, max_speed: float, min_authority: float = 0.4) -> float:
	if max_speed <= 0.01:
		return 1.0
	var ratio := clampf(absf(speed) / max_speed, 0.0, 1.0)
	return lerpf(1.0, min_authority, ratio * ratio)


## Yaw change for one physics frame. Positive steer means "turn right", which is
## a negative rotation.y in Godot. Ground vehicle only: air/space craft apply
## their own authority curves.
static func yaw_delta(
	steer: float,
	turn_rate: float,
	speed: float,
	grip_min: float = 1.5,
	delta: float = 1.0 / 60.0
) -> float:
	if absf(steer) <= 0.0001 or turn_rate <= 0.0:
		return 0.0
	var grip := clampf(absf(speed) / maxf(0.01, grip_min), 0.0, 1.0)
	return -steer * turn_rate * grip * delta


## Lateral grip: removes sideways velocity. Low grip means the chassis drifts.
static func apply_grip(horizontal: Vector3, right: Vector3, grip: float, delta: float) -> Vector3:
	var lateral := horizontal.dot(right)
	return horizontal - right * lateral * clampf(grip * delta, 0.0, 1.0)


## Hard horizontal speed clamp (the vertical axis is integrated separately).
static func clamp_horizontal(horizontal: Vector3, max_speed: float) -> Vector3:
	if max_speed <= 0.0:
		return Vector3.ZERO
	if horizontal.length() > max_speed:
		return horizontal.normalized() * max_speed
	return horizontal


## Lift curve for winged flight: 0 below stall speed, 1 at or above cruise speed.
static func lift_ratio(speed: float, stall_speed: float, cruise_speed: float) -> float:
	if speed <= stall_speed:
		return 0.0
	var span := maxf(1.0, cruise_speed - stall_speed)
	return clampf((speed - stall_speed) / span, 0.0, 1.0)


## Visual bank/lean for a body that rolls into a turn (radians).
static func bank_angle(steer: float, speed_ratio: float, max_bank: float = 0.5) -> float:
	return -steer * max_bank * clampf(speed_ratio, 0.0, 1.0)


## Pulls a body's up axis toward the ground normal without snapping it.
static func aligned_up(current_up: Vector3, ground_normal: Vector3, strength: float, delta: float) -> Vector3:
	var target := ground_normal.normalized()
	if target.length_squared() < 0.5:
		target = Vector3.UP
	return current_up.lerp(target, clampf(strength * delta, 0.0, 1.0)).normalized()


## VTOL altitude clamp. Returns a vertical velocity correction: positive when
## below the floor, negative above the ceiling, zero inside the band.
static func altitude_clamp_velocity(altitude: float, ceiling: float) -> float:
	if altitude <= 0.02:
		return 2.0
	if altitude >= ceiling:
		return -2.0
	return 0.0


## Forward speed in km/h for the HUD dial (horizontal component only).
static func speed_kph(velocity: Vector3) -> float:
	return Vector3(velocity.x, 0.0, velocity.z).length() * 3.6


## Signed forward speed along a unit forward vector (m/s).
static func forward_speed(velocity: Vector3, forward: Vector3) -> float:
	return velocity.dot(forward)


static func approach(current: float, target: float, rate: float, delta: float) -> float:
	return move_toward(current, target, maxf(0.0, rate) * delta)


## Discrete gear for the HUD, derived from the speed fraction.
static func gear_for(speed_ratio: float, gears: int = 5) -> int:
	var safe := maxi(1, gears)
	return clampi(1 + int(clampf(speed_ratio, 0.0, 1.0) * float(safe) * 0.999), 1, safe)


## Landing / taxi helper: true when the probe is close enough to call it ground.
static func is_ground_contact(probe: Dictionary, tolerance: float) -> bool:
	return bool(probe.get("hit", false)) and float(probe.get("distance", 999.0)) <= tolerance
