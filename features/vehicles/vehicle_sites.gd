class_name VehicleSites
extends RefCounted
## Deterministic rideable placement for one deployment.
##
## Guarantees exactly one rig (ground car) and one hover-bike at the drop zone,
## then places the specialist archetypes at their thematic POIs:
##   airplane  -> comms_array / relay_spire / crash_site, or any POI whose
##                POISpecs entry carries an aircraft vehicle tag
##   spaceship -> foundry_hall / derelict_ship / comms_array
##   horse     -> warden_outpost stable / faction_camp
## When the POI table (or world) does not provide a candidate the vehicle still
## spawns at a seed-derived offset from the drop zone, so a deployment always has
## all five rideables. Positions are snapped with a downward raycast against the
## World layer and fall back to world.sample_height.
##
## Usage (Deployment):
##   const VEHICLE_SITES_SCRIPT := preload("res://features/vehicles/vehicle_sites.gd")
##   VEHICLE_SITES_SCRIPT.new().build(_site_root, world, RunState.run_seed, _map_preset)

const VEHICLE_SCRIPTS := {
	&"rig": preload("res://features/vehicles/ground_car.gd"),
	&"hoverbike": preload("res://features/vehicles/hover_bike.gd"),
	&"airplane": preload("res://features/vehicles/airplane.gd"),
	&"spaceship": preload("res://features/vehicles/spaceship.gd"),
	&"horse": preload("res://features/vehicles/horse.gd"),
}

const POI_SPECS_PATH := "res://features/world/poi_specs.gd"

## Specialist archetype -> POI affinity. `poi_types` are tried in order; `tags`
## are matched against the POISpecs "vehicle" field when the table exists.
const ROLE_PREFERENCES := [
	{
		"id": &"airplane",
		"poi_types": [&"comms_array", &"relay_spire", &"crash_site"],
		"tags": [&"airplane", &"plane", &"aircraft", &"air"],
	},
	{
		"id": &"spaceship",
		"poi_types": [&"foundry_hall", &"derelict_ship", &"comms_array"],
		"tags": [&"spaceship", &"ship", &"vtol"],
	},
	{
		"id": &"horse",
		"poi_types": [&"warden_outpost", &"faction_camp"],
		"tags": [&"horse", &"mount", &"cavalry", &"beast"],
	},
]

const FALLBACK_DISTANCES := [58.0, 76.0, 94.0]


## Builds and parents every rideable under `site_root`. Deterministic for a given
## (seed_value, world) pair. Returns the spawned Rideable nodes.
func build(site_root: Node3D, world: Node, seed_value: int, preset: Dictionary = {}) -> Array[Rideable]:
	var spawned: Array[Rideable] = []
	if site_root == null:
		return spawned
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(seed_value)
	var drop_point := _drop_point(world)
	var preset_tags := _preset_tags(preset)
	var spec_tags := _PoiSpecTags.new()
	# --- Drop zone: one rig + one hover-bike, always -----------------------
	var rig_position := drop_point + Vector3(3.4 + rng.randf_range(0.0, 1.6), 0.0, -1.8 - rng.randf_range(0.0, 1.6))
	_append(spawned, site_root, world, &"rig", rig_position, rng.randf_range(-0.5, 0.5), 1)
	var bike_position := drop_point + Vector3(-3.6 - rng.randf_range(0.0, 1.8), 0.0, 2.4 + rng.randf_range(0.0, 1.4))
	_append(spawned, site_root, world, &"hoverbike", bike_position, PI + rng.randf_range(-0.5, 0.5), 2)
	# --- Specialist archetypes at their POIs -------------------------------
	var pois := _collect_pois(world)
	var used_pois: Dictionary = {}
	var fallback_index := 0
	for role in ROLE_PREFERENCES:
		var role_id := StringName(role.get("id", &""))
		var poi := _select_poi(pois, used_pois, role, preset_tags, spec_tags)
		var position := Vector3.ZERO
		var yaw := rng.randf_range(0.0, TAU)
		if poi.is_empty():
			var distance := float(FALLBACK_DISTANCES[fallback_index % FALLBACK_DISTANCES.size()])
			fallback_index += 1
			var angle := rng.randf_range(0.0, TAU)
			position = drop_point + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		else:
			var center: Vector3 = poi.get("position", drop_point)
			var radius := maxf(9.0, float(poi.get("radius", 30.0)) * 0.55)
			var angle := rng.randf_range(0.0, TAU)
			position = center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			yaw = float(poi.get("yaw", yaw))
		_append(spawned, site_root, world, role_id, position, yaw, 3 + spawned.size())
	# --- Optional preset extras (deterministic, capped) --------------------
	var extras := clampi(int(preset.get("vehicle_extra", 0)) if preset is Dictionary else 0, 0, 4)
	for index in extras:
		var extra_id: StringName = &"rig" if index % 2 == 0 else &"hoverbike"
		var angle := rng.randf_range(0.0, TAU)
		var distance := 40.0 + float(index) * 12.0
		var position := drop_point + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		_append(spawned, site_root, world, extra_id, position, rng.randf_range(0.0, TAU), 10 + index)
	return spawned


# --- spawning ---------------------------------------------------------------


func _append(
	spawned: Array[Rideable],
	site_root: Node3D,
	world: Node,
	vehicle_id: StringName,
	position: Vector3,
	yaw: float,
	index: int
) -> void:
	var vehicle := _spawn(site_root, world, vehicle_id, position, yaw, index)
	if vehicle != null:
		spawned.append(vehicle)


func _spawn(
	site_root: Node3D,
	world: Node,
	vehicle_id: StringName,
	position: Vector3,
	yaw: float,
	index: int
) -> Rideable:
	var script: Script = VEHICLE_SCRIPTS.get(vehicle_id, null)
	if script == null:
		return null
	var instance: Variant = script.new()
	if not (instance is CharacterBody3D):
		if instance is Node:
			(instance as Node).free()
		return null
	var vehicle := instance as Node3D
	vehicle.name = "Vehicle_%s_%d" % [String(vehicle_id), index]
	site_root.add_child(vehicle)
	vehicle.global_position = _snap_to_ground(site_root, world, position, 0.1)
	vehicle.rotation.y = yaw
	if vehicle.has_method("reset_physics_interpolation"):
		vehicle.call("reset_physics_interpolation")
	return vehicle as Rideable


## Raycast ground snap (World layer) with a world.sample_height fallback.
func _snap_to_ground(site_root: Node, world: Node, point: Vector3, lift: float) -> Vector3:
	if site_root != null and is_instance_valid(site_root) and site_root.is_inside_tree():
		var probe := VehiclePhysics.ground_probe(
			site_root.get_world_3d(), point + Vector3.UP * 24.0, 160.0, []
		)
		if probe.get("hit", false):
			return Vector3(point.x, float(probe["position"].y) + lift, point.z)
	if world != null and is_instance_valid(world) and world.has_method("sample_height"):
		var height := float(world.call("sample_height", Vector2(point.x, point.z)))
		return Vector3(point.x, height + lift, point.z)
	return point


func _drop_point(world: Node) -> Vector3:
	if world != null and is_instance_valid(world) and world.has_method("get_spawn_points"):
		var points: Array = world.call("get_spawn_points")
		if not points.is_empty() and points[0] is Vector3:
			return points[0]
	# Fallback world / tests: a stable origin so placement stays deterministic.
	return Vector3.ZERO


# --- POI selection ----------------------------------------------------------


func _collect_pois(world: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if world == null or not is_instance_valid(world) or not world.has_method("get_pois"):
		return out
	var raw: Variant = world.call("get_pois")
	if not (raw is Array):
		return out
	for entry in raw as Array:
		if entry is Dictionary and entry.get("position") is Vector3:
			out.append(entry)
	return out


func _select_poi(
	pois: Array[Dictionary],
	used: Dictionary,
	role: Dictionary,
	preset_tags: Dictionary,
	spec_tags: RefCounted
) -> Dictionary:
	var preferred_types: Array = role.get("poi_types", [])
	var role_tags: Array = role.get("tags", [])
	# 1. Authored POI type affinity (comms_array, foundry_hall, warden_outpost...).
	for wanted in preferred_types:
		var wanted_type := String(wanted)
		var fallback_match := {}
		for index in pois.size():
			var poi: Dictionary = pois[index]
			if String(poi.get("type", "")) != wanted_type:
				continue
			if not used.has(index):
				used[index] = true
				return poi
			if fallback_match.is_empty():
				fallback_match = poi
		if not fallback_match.is_empty():
			return fallback_match
	# 2. POISpecs vehicle tag / preset tag override.
	for index in pois.size():
		if used.has(index):
			continue
		var poi: Dictionary = pois[index]
		var tag := _vehicle_tag(poi, preset_tags, spec_tags)
		if tag == &"":
			continue
		if tag in role_tags:
			used[index] = true
			return poi
	# 3. Any POI whose spec carries an explicit vehicle tag.
	for index in pois.size():
		if used.has(index):
			continue
		var poi: Dictionary = pois[index]
		if _vehicle_tag(poi, preset_tags, spec_tags) != &"":
			used[index] = true
			return poi
	return {}


func _vehicle_tag(poi: Dictionary, preset_tags: Dictionary, spec_tags: RefCounted) -> StringName:
	var poi_type := StringName(poi.get("type", &""))
	if preset_tags.has(poi_type):
		return StringName(preset_tags[poi_type])
	if preset_tags.has(String(poi_type)):
		return StringName(preset_tags[String(poi_type)])
	return StringName(spec_tags.call("get_spec_vehicle", poi_type))


func _preset_tags(preset: Dictionary) -> Dictionary:
	var tags: Dictionary = {}
	if not (preset is Dictionary):
		return tags
	var raw: Variant = preset.get("vehicle_tags", {})
	if raw is Dictionary:
		for key in (raw as Dictionary).keys():
			tags[StringName(key)] = StringName((raw as Dictionary)[key])
	return tags


## Reads POISpecs.get_spec(type)["vehicle"] when the world-wave table exists.
## Static-only or instance APIs both work; any failure is a silent no-match so
## VehicleSites never becomes a hard dependency on the world wave.
class _PoiSpecTags extends RefCounted:
	var _script: Script = null
	var _instance: Object = null
	var _loaded: bool = false
	var _cache: Dictionary = {}

	func get_spec_vehicle(poi_type: StringName) -> StringName:
		if _cache.has(poi_type):
			return StringName(_cache[poi_type])
		var result := StringName("")
		if _ensure_loaded() and _instance != null and _instance.has_method("get_spec"):
			var spec: Variant = _instance.call("get_spec", poi_type)
			if spec is Dictionary:
				var raw: Variant = (spec as Dictionary).get("vehicle", &"")
				if raw != null and String(raw) != "" and String(raw) != "<null>":
					result = StringName(raw)
		_cache[poi_type] = result
		return result

	func _ensure_loaded() -> bool:
		if _loaded:
			return _instance != null
		_loaded = true
		if not ResourceLoader.exists(POI_SPECS_PATH):
			return false
		_script = load(POI_SPECS_PATH)
		if _script == null:
			return false
		if _script.can_instantiate():
			var created: Variant = _script.new()
			if created is Object:
				_instance = created as Object
		if _instance == null and _script.has_method("get_spec"):
			# Last resort: call the script object itself (covers static-only tables).
			var probe: Variant = _script.call("get_spec", &"__probe__")
			if probe != null:
				_instance = _script
		return _instance != null


static func _mix_seed(seed_value: int) -> int:
	var mixed := seed_value if seed_value != 0 else 1
	mixed = (mixed * 1103515245 + 12345) & 0x7FFFFFFF
	mixed = (mixed ^ (mixed >> 13)) & 0x7FFFFFFF
	if mixed == 0:
		mixed = 1
	return mixed
