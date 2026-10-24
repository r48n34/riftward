extends Node
## WORLD SELF-TEST ??headless validation of the procedural frontier.
##
## Run with:
##   godot --headless --path <project> res://features/world/world_test.tscn
##
## Exits with code 0 on success, 1 on any failed assertion. Prints generation
## timing and content statistics so regressions are visible in CI logs.

const WorldBuilderScript := preload("res://features/world/world_builder.gd")
const TEST_SEED := 12345
const TIMEOUT_SECONDS := 180.0

var _world = null
var _done := false


func _ready() -> void:
	print("[world-test] starting world generation (seed %d)" % TEST_SEED)
	_world = WorldBuilderScript.new()
	_world.name = "World"
	add_child(_world)
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
	if pois.size() != 16:
		errors.append("get_pois() returned %d entries, expected 16" % pois.size())
	var type_counts: Dictionary = {}
	var biomes: Dictionary = {}
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
	for required in [
		"faction_camp", "relay_spire", "crash_site", "vault", "warden_outpost",
		"anomaly", "ruin_field", "ashen_stockade", "bloom_hive", "choir_post",
		"colony_ruins", "exfil_pad",
	]:
		if not type_counts.has(required) or int(type_counts[required]) < 1:
			errors.append("POI type '%s' missing from layout" % required)
	if biomes.size() < 2:
		errors.append("POIs only landed in %d biome(s); expected at least 2" % biomes.size())

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
	elif structures_root.get_child_count() < 28:
		errors.append("structures root has %d children, expected >= 28 (16 POIs + 2 drop zones + roadside)" % structures_root.get_child_count())
	var scatter_root: Node3D = _world.get_scatter_root()
	if scatter_root == null:
		errors.append("scatter root missing")
	else:
		var multimesh_instances := 0
		var prop_instances := 0
		for child in scatter_root.get_children():
			if child is MultiMeshInstance3D and child.multimesh != null:
				multimesh_instances += 1
				prop_instances += child.multimesh.instance_count
		if multimesh_instances < 4:
			errors.append("only %d MultiMesh scatter batches; expected >= 4" % multimesh_instances)
		if prop_instances < 1000:
			errors.append("only %d scattered props; expected >= 1000" % prop_instances)
		print("[world-test] scatter batches: %d, instances: %d" % [multimesh_instances, prop_instances])

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

	# --- report ---------------------------------------------------------------
	var stats: Dictionary = _world.get_generation_stats()
	print("[world-test] generation stats: %s" % JSON.stringify(stats))
	print("[world-test] node count: %d" % _world.find_children("*", "", true, false).size())
	print("[world-test] validation took %d ms" % (Time.get_ticks_msec() - t))
	return errors


