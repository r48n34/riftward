extends Node
## WORLD SELF-TEST ??headless validation of the procedural frontier.
##
## Run with:
##   godot --headless --path <project> res://features/world/world_test.tscn
##
## Exits with code 0 on success, 1 on any failed assertion. Prints generation
## timing and content statistics so regressions are visible in CI logs.

const WorldBuilderScript := preload("res://features/world/world_builder.gd")
const POISpecsScript := preload("res://features/world/poi_specs.gd")
const TEST_SEED := 12345
const TIMEOUT_SECONDS := 180.0
## 13 authored types + 3 exfil pads + the 7 second-wave kits = 20.
const REQUIRED_TYPES: Array[StringName] = [
	&"faction_camp", &"relay_spire", &"crash_site", &"vault", &"warden_outpost",
	&"anomaly", &"ruin_field", &"ashen_stockade", &"bloom_hive", &"choir_post",
	&"colony_ruins", &"derelict_ship", &"exfil_pad", &"foundry_hall",
	&"hab_cluster", &"comms_array", &"fuel_depot", &"clinic_shelter",
	&"research_lab", &"water_works",
]
## Second-wave kits must each author a real detail pass (>= 60 primitives).
const SECOND_WAVE_TYPES: Array[StringName] = [
	&"foundry_hall", &"hab_cluster", &"comms_array", &"fuel_depot",
	&"clinic_shelter", &"research_lab", &"water_works",
]
const MIN_KIT_PRIMITIVES := 60
const MIN_CLUTTER_INSTANCES := 400

var _world = null
var _done := false


func _ready() -> void:
	print("[world-test] starting world generation (seed %d)" % TEST_SEED)
	_world = WorldBuilderScript.new()
	_world.name = "World"
	add_child(_world)
	# Exercise the full planet/fluid/weather preset path (the default frontier
	# without a preset stays available for the standalone preview).
	if ContentDB != null:
		var preset: Dictionary = ContentDB.get_map_preset(&"verdant_verge")
		if not preset.is_empty():
			_world.apply_preset(preset)
	_world.generation_progress.connect(_on_progress)
	_world.generation_finished.connect(_on_finished)
	var timeout := _make_timeout()
	await _world.generate(TEST_SEED)
	_done = true
	if is_instance_valid(timeout):
		timeout.queue_free()
	await get_tree().physics_frame
	var errors := await _validate()
	if errors.is_empty():
		print("[world-test] PASS")
		get_tree().quit(0)
	else:
		for err in errors:
			push_error("[world-test] FAIL: %s" % err)
		print("[world-test] FAILED with %d problem(s)" % errors.size())
		get_tree().quit(1)


func _make_timeout() -> Node:
	var timer := Timer.new()
	timer.wait_time = TIMEOUT_SECONDS
	timer.one_shot = true
	timer.timeout.connect(
		func() -> void:
			if not _done:
				push_error("[world-test] TIMEOUT after %.0fs" % TIMEOUT_SECONDS)
				get_tree().quit(1)
	)
	add_child(timer)
	timer.start()
	return timer


func _on_progress(value: float, label: String) -> void:
	print("[world-test] %3d%% %s" % [int(value * 100.0), label])


func _on_finished(ok: bool) -> void:
	print("[world-test] generation_finished(%s)" % str(ok))


func _validate() -> Array[String]:
	var errors: Array[String] = []
	var t := Time.get_ticks_msec()

	# --- seed -----------------------------------------------------------------
	if _world.get_world_seed() != TEST_SEED:
		errors.append("get_world_seed() returned %d, expected %d" % [_world.get_world_seed(), TEST_SEED])

	# --- spawns ---------------------------------------------------------------
	var spawns: Array = _world.get_spawn_points()
	if spawns.size() != 2:
		errors.append("get_spawn_points() returned %d entries, expected 2" % spawns.size())
	for i in spawns.size():
		var sp: Vector3 = spawns[i]
		var ground: float = _world.sample_height(Vector2(sp.x, sp.z))
		if absf(ground - sp.y) > 0.05:
			errors.append("spawn %d y=%.2f does not match sample_height=%.2f" % [i, sp.y, ground])

	# --- exfils ---------------------------------------------------------------
	var exfils: Array = _world.get_exfil_points()
	if exfils.size() != 3:
		errors.append("get_exfil_points() returned %d entries, expected 3" % exfils.size())
	for i in exfils.size():
		var ex: Dictionary = exfils[i]
		if not ex.has("position") or not ex.has("name"):
			errors.append("exfil %d missing position/name" % i)
			continue
		if not (ex["position"] is Vector3):
			errors.append("exfil %d position is not a Vector3" % i)
		if String(ex["name"]).is_empty():
			errors.append("exfil %d has an empty name" % i)
	for i in exfils.size():
		for j in range(i + 1, exfils.size()):
			var a: Vector3 = exfils[i]["position"]
			var b: Vector3 = exfils[j]["position"]
			if a.distance_to(b) < 120.0:
				errors.append("exfils %d and %d are too close (%.0fm)" % [i, j, a.distance_to(b)])

	# --- POIs -----------------------------------------------------------------
	var pois: Array = _world.get_pois()
	if pois.size() < 24:
		errors.append("get_pois() returned %d entries, expected >= 24 (21 layout + 3 exfil)" % pois.size())
	var type_counts: Dictionary = {}
	var biomes: Dictionary = {}
	var interior_count := 0
	for i in pois.size():
		var poi: Dictionary = pois[i]
		for key in ["position", "type", "name", "radius"]:
			if not poi.has(key):
				errors.append("POI %d missing key '%s'" % [i, key])
		if not (poi.get("position") is Vector3):
			errors.append("POI %d position is not a Vector3" % i)
			continue
		if float(poi.get("radius", 0.0)) <= 1.0:
			errors.append("POI %d has invalid radius" % i)
		if String(poi.get("name", "")).is_empty():
			errors.append("POI %d has an empty name" % i)
		var type := String(poi.get("type", ""))
		type_counts[type] = int(type_counts.get(type, 0)) + 1
		var pos: Vector3 = poi["position"]
		biomes[_world.get_biome_at(Vector2(pos.x, pos.z))] = true
		if not (poi.get("interior", {}) as Dictionary).is_empty():
			interior_count += 1
	for required in REQUIRED_TYPES:
		if not type_counts.has(String(required)) or int(type_counts[String(required)]) < 1:
			errors.append("POI type '%s' missing from layout" % String(required))
	if biomes.size() < 2:
		errors.append("POIs only landed in %d biome(s); expected at least 2" % biomes.size())
	if interior_count < 8:
		errors.append("only %d POIs expose enterable interiors; expected >= 8" % interior_count)
	if _world.get_biome_names().size() != 3:
		errors.append("get_biome_names() did not return 3 planet biome names")

	# --- POI specs: thread-safe catalogue covers every authored type --------
	var spec_errors: Array[String] = POISpecsScript.validate()
	for spec_error in spec_errors:
		errors.append("POISpecs: %s" % spec_error)
	if POISpecsScript.TYPE_IDS.size() != 20:
		errors.append("POISpecs.TYPE_IDS has %d entries, expected 20" % POISpecsScript.TYPE_IDS.size())
	if (POISpecsScript.all() as Array).size() != 20:
		errors.append("POISpecs.all() returned %d specs, expected 20" % (POISpecsScript.all() as Array).size())
	for required in REQUIRED_TYPES:
		if not POISpecsScript.has_spec(required):
			errors.append("POISpecs is missing a spec for '%s'" % String(required))
	for entry in WorldBuilderScript.POI_LAYOUT:
		var layout_type := StringName(String(entry["type"]))
		if not POISpecsScript.has_spec(layout_type):
			errors.append("POI_LAYOUT type '%s' has no POISpec" % String(layout_type))
			continue
		var spec: Dictionary = POISpecsScript.get_spec(layout_type)
		if absf(float(spec.get("radius", 0.0)) - float(entry["radius"])) > 0.01:
			errors.append("POISpecs radius for '%s' does not match POI_LAYOUT" % String(layout_type))
		if absf(float(spec.get("pad", 0.0)) - float(entry["pad"])) > 0.01:
			errors.append("POISpecs pad for '%s' does not match POI_LAYOUT" % String(layout_type))
	for entry in WorldBuilderScript.EXTRA_POI_KINDS:
		var extra_type := StringName(String(entry["type"]))
		if not POISpecsScript.has_spec(extra_type):
			errors.append("EXTRA_POI_KINDS type '%s' has no POISpec" % String(extra_type))
	# Vehicle metadata must only use the five supported vehicle ids.
	for spec in POISpecsScript.all():
		var vehicle := StringName(String((spec as Dictionary).get("vehicle", &"")))
		if not POISpecsScript.VEHICLES.has(vehicle):
			errors.append("POISpecs vehicle '%s' is not supported" % String(vehicle))

	# --- New-kit authored content budget ------------------------------------
	var kit_primitives: Dictionary = {}
	var kit_collision: Dictionary = {}
	var structures_root_early: Node3D = _world.get_structures_root()
	if structures_root_early != null:
		for child in structures_root_early.get_children():
			if not (child is Node3D):
				continue
			var info: Dictionary = child.get_meta("world_info", {})
			var kit_type := String(info.get("type", ""))
			if kit_type.is_empty():
				continue
			kit_primitives[kit_type] = maxi(int(kit_primitives.get(kit_type, 0)), int(child.get_meta("primitive_count", 0)))
			kit_collision[kit_type] = maxi(int(kit_collision.get(kit_type, 0)), int(child.get_meta("collision_triangle_count", 0)))
		var second_wave_report: PackedStringArray = []
		for kit_type in SECOND_WAVE_TYPES:
			var prims := int(kit_primitives.get(String(kit_type), 0))
			if prims < MIN_KIT_PRIMITIVES:
				errors.append("new kit '%s' authored only %d primitives (expected >= %d)" % [String(kit_type), prims, MIN_KIT_PRIMITIVES])
			second_wave_report.append("%s=%d" % [String(kit_type), prims])
		print("[world-test] second-wave kit primitives: %s" % " ".join(second_wave_report))
	else:
		errors.append("structures root missing before primitive audit")

	# --- fluid basins ---------------------------------------------------------
	var basins: Array = _world.get_fluid_basins()
	if basins.is_empty():
		errors.append("world generated no fluid basins")
	if _world.get_fluid_root() == null:
		errors.append("fluid root missing")
	var fluid_meshes := 0
	if _world.get_fluid_root() != null:
		for child in _world.get_fluid_root().get_children():
			if child is MeshInstance3D:
				fluid_meshes += 1
	if basins.size() > 0 and fluid_meshes == 0:
		errors.append("fluid basins exist but no fluid surface meshes were built")
	for basin in basins:
		var center: Vector2 = basin.get("center", Vector2.ZERO)
		var sample: Dictionary = _world.sample_fluid(center)
		if int(sample.get("type", 0)) == 0:
			errors.append("sample_fluid() found no fluid at basin centre %s" % str(center))
			break

	# --- environment systems --------------------------------------------------
	if _world.get_environment_director() == null:
		errors.append("environment director missing")
	if _world.get_day_night_cycle() == null:
		errors.append("day/night cycle missing")
	if _world.get_weather_system() == null:
		errors.append("weather system missing")
	if _world.get_day_night_cycle() != null:
		var clock := String(_world.get_day_night_cycle().call("get_clock_text"))
		if clock.length() != 5:
			errors.append("day/night clock text malformed: '%s'" % clock)
	if _world.get_weather_system() != null:
		var weather: Dictionary = _world.get_weather_system().call("get_state")
		if String(weather.get("display_name", "")).is_empty():
			errors.append("weather system has no active state")

	# --- terrain --------------------------------------------------------------
	var heights: Array[float] = []
	for ix in 12:
		for iz in 12:
			var x: float = -_world.map_size * 0.45 + _world.map_size * 0.9 * float(ix) / 11.0
			var z: float = -_world.map_size * 0.45 + _world.map_size * 0.9 * float(iz) / 11.0
			heights.append(_world.sample_height(Vector2(x, z)))
	var h_min: float = heights.min()
	var h_max: float = heights.max()
	if h_max - h_min < 25.0:
		errors.append("terrain relief too flat: %.1fm (expected > 25m)" % (h_max - h_min))

	# --- map texture ----------------------------------------------------------
	var map_texture: Texture2D = _world.get_map_texture()
	if map_texture == null:
		errors.append("get_map_texture() returned null")
	else:
		if map_texture.get_width() != _world.map_texture_resolution:
			errors.append("map texture width %d, expected %d" % [map_texture.get_width(), _world.map_texture_resolution])

	# --- nav region -----------------------------------------------------------
	var nav_region: NavigationRegion3D = _world.get_nav_region()
	if nav_region == null:
		errors.append("get_nav_region() returned null")
	elif nav_region.navigation_mesh == null:
		errors.append("nav region has no navigation mesh")
	else:
		var poly_count := nav_region.navigation_mesh.get_polygon_count()
		if poly_count < 100:
			errors.append("navmesh has only %d polygons (expected > 100)" % poly_count)

	# --- scene content --------------------------------------------------------
	var terrain_root: Node3D = _world.get_terrain_root()
	if terrain_root == null:
		errors.append("terrain root missing")
	else:
		var chunk_count := terrain_root.get_child_count()
		if chunk_count != _world.terrain_chunks * _world.terrain_chunks:
			errors.append("terrain has %d chunks, expected %d" % [chunk_count, _world.terrain_chunks * _world.terrain_chunks])
		var tris := 0
		for chunk in terrain_root.get_children():
			for child in chunk.get_children():
				if child is MeshInstance3D and child.mesh is ArrayMesh:
					tris += (child.mesh as ArrayMesh).surface_get_array_index_len(0) / 3
		print("[world-test] terrain triangles: %d" % tris)
	var structures_root: Node3D = _world.get_structures_root()
	if structures_root == null:
		errors.append("structures root missing")
	elif structures_root.get_child_count() < 30:
		errors.append("structures root has %d children, expected >= 30 (17 POIs + 2 drop zones + roadside)" % structures_root.get_child_count())
	var scatter_root: Node3D = _world.get_scatter_root()
	if scatter_root == null:
		errors.append("scatter root missing")
	else:
		var multimesh_instances := 0
		var prop_instances := 0
		var clutter_batches := 0
		var clutter_instances := 0
		for child in scatter_root.get_children():
			if child is MultiMeshInstance3D and child.multimesh != null:
				multimesh_instances += 1
				prop_instances += child.multimesh.instance_count
				if String(child.name).begins_with("POIClutter"):
					clutter_batches += 1
					clutter_instances += child.multimesh.instance_count
		if multimesh_instances < 4:
			errors.append("only %d MultiMesh scatter batches; expected >= 4" % multimesh_instances)
		if prop_instances < 1000:
			errors.append("only %d scattered props; expected >= 1000" % prop_instances)
		var scatter_stats: Dictionary = _world.get_generation_stats()
		var clutter_stat := int((scatter_stats.get("scatter", {}) as Dictionary).get("clutter_instances", 0))
		if clutter_batches < 1:
			errors.append("no POI-local clutter MultiMesh batches found")
		if clutter_instances < MIN_CLUTTER_INSTANCES or clutter_stat < MIN_CLUTTER_INSTANCES:
			errors.append("POI clutter instances %d (stat %d), expected >= %d" % [clutter_instances, clutter_stat, MIN_CLUTTER_INSTANCES])
		print("[world-test] scatter batches: %d, instances: %d" % [multimesh_instances, prop_instances])
		print("[world-test] POI clutter batches: %d, instances: %d" % [clutter_batches, clutter_instances])
		# LootCache contract: world exposes usable clutter loot-prop anchors.
		var loot_props: Array = _world.get_loot_props()
		if loot_props.size() < 20:
			errors.append("get_loot_props() returned %d anchors, expected >= 20" % loot_props.size())
		for prop in loot_props:
			if not (prop is Dictionary):
				errors.append("loot prop entry is not a Dictionary")
				break
			var prop_dict: Dictionary = prop
			if not (prop_dict.get("position", null) is Vector3):
				errors.append("loot prop is missing a Vector3 position")
				break
			if String(prop_dict.get("kind", "")).is_empty():
				errors.append("loot prop is missing a kind")
				break
			if not POISpecsScript.has_spec(StringName(prop_dict.get("poi_type", &""))):
				errors.append("loot prop poi_type '%s' has no spec" % String(prop_dict.get("poi_type", &"")))
				break
		print("[world-test] loot-prop anchors: %d" % loot_props.size())

	# --- physical ground check ------------------------------------------------
	var space := get_viewport().world_3d.direct_space_state
	if spawns.size() > 0:
		var sp: Vector3 = spawns[0]
		var query := PhysicsRayQueryParameters3D.create(sp + Vector3(0.0, 60.0, 0.0), sp - Vector3(0.0, 30.0, 0.0), 1)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			errors.append("physics raycast found no ground below spawn point ??terrain collision missing")
		else:
			var hit_y: float = (hit["position"] as Vector3).y
			if absf(hit_y - sp.y) > 3.0:
				errors.append("ground raycast y=%.1f far from spawn y=%.1f" % [hit_y, sp.y])

	# --- POI spacing sanity ---------------------------------------------------
	var min_spacing := INF
	for i in pois.size():
		var a: Vector3 = pois[i]["position"]
		for j in range(i + 1, pois.size()):
			var b: Vector3 = pois[j]["position"]
			min_spacing = minf(min_spacing, a.distance_to(b))
	print("[world-test] POIs: %d, min centre spacing: %.1f m, enterable interiors: %d" % [pois.size(), min_spacing, interior_count])

	# --- determinism ----------------------------------------------------------
	await _check_determinism(errors)

	# --- report ---------------------------------------------------------------
	var stats: Dictionary = _world.get_generation_stats()
	print("[world-test] generation stats: %s" % JSON.stringify(stats))
	print("[world-test] node count: %d" % _world.find_children("*", "", true, false).size())
	print("[world-test] validation took %d ms" % (Time.get_ticks_msec() - t))
	return errors


## Replays the same seed on a navigation-less world and asserts identical POI
## layout (positions/order), proving generation is deterministic per seed.
func _check_determinism(errors: Array[String]) -> void:
	var replay = WorldBuilderScript.new()
	replay.name = "WorldDeterminism"
	replay.bake_navigation = false
	replay.create_environment = false
	add_child(replay)
	if ContentDB != null:
		var preset: Dictionary = ContentDB.get_map_preset(&"verdant_verge")
		if not preset.is_empty():
			replay.apply_preset(preset)
	var started := Time.get_ticks_msec()
	await replay.generate(TEST_SEED)
	var replay_ms := Time.get_ticks_msec() - started
	if not bool(replay.is_generated()):
		errors.append("determinism replay failed to generate")
	else:
		var first: Array = _world.get_pois()
		var second: Array = replay.get_pois()
		if first.is_empty() or second.is_empty():
			errors.append("determinism replay produced no POIs")
		elif (first[0]["position"] as Vector3) != (second[0]["position"] as Vector3):
			errors.append("determinism: first POI position differs between identical seeds (%s vs %s)" % [str(first[0]["position"]), str(second[0]["position"])])
		else:
			var identical := first.size() == second.size()
			if identical:
				for i in first.size():
					var a: Dictionary = first[i]
					var b: Dictionary = second[i]
					if String(a["type"]) != String(b["type"]) or (a["position"] as Vector3) != (b["position"] as Vector3):
						identical = false
						break
			if not identical:
				errors.append("determinism: POI layout differs between identical seeds")
			print("[world-test] determinism replay: %d POIs, first at %s, %d ms (no nav/env)" % [second.size(), str(first[0]["position"]), replay_ms])
	replay.queue_free()
	await get_tree().process_frame


