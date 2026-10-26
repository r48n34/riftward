class_name WorldBuilder
extends Node3D
## RIFTWARD WORLD BUILDER — the runtime procedural frontier.
##
## Owns terrain, biomes, POIs, roads, scatter, sky/environment and navigation.
## Public API (used by integration):
##   signal generation_progress(value: float, label: String)
##   signal generation_finished(ok: bool)
##   @export var map_size := 1800.0
##   func apply_preset(preset: Dictionary) -> void   # optional, call before generate()
##   func get_map_preset_id() -> StringName
##   func generate(world_seed: int) -> void          # async coroutine
##   func sample_height(world_xz: Vector2) -> float
##   func get_spawn_points() -> Array[Vector3]       # 2 flat drop zones
##   func get_exfil_points() -> Array[Dictionary]    # 3 x {position, name}
##   func get_pois() -> Array[Dictionary]            # 24 base POIs (+ preset extras)
##   func get_loot_props() -> Array[Dictionary]      # POI clutter props for LootCache
##   func get_roadside_points() -> Array[Dictionary] # 10-14 roadside outbuildings
##   func get_nav_region() -> NavigationRegion3D
##   func get_map_texture() -> Texture2D
##   func get_world_seed() -> int
##
## Generation is split into pure-data worker phases (Thread + WorkerThreadPool)
## and main-thread node creation. Add this node to the scene tree before calling
## generate(); `await builder.generate(seed)` works if you want to wait for it.

signal generation_progress(value: float, label: String)
signal generation_finished(ok: bool)
## Extra signal: navigation finished baking (after generation_finished).
signal navigation_ready(ok: bool)

const Palette := preload("res://features/world/world_palette.gd")
const GenWorker := preload("res://features/world/world_gen_worker.gd")
const TerrainWorker := preload("res://features/world/world_terrain_worker.gd")
const MaterialsScript := preload("res://features/world/world_materials.gd")
const StructuresScript := preload("res://features/world/world_structures.gd")
const ScatterScript := preload("res://features/world/world_scatter.gd")
const EnvironmentScript := preload("res://features/world/world_environment.gd")
const FluidScript := preload("res://features/world/world_fluid.gd")
const DayNightScript := preload("res://features/world/day_night_cycle.gd")
const WeatherScript := preload("res://features/world/weather_system.gd")

## World size in meters (square, centered on origin).
@export var map_size := 1800.0
## Terrain is split into terrain_chunks x terrain_chunks streaming-friendly nodes.
@export var terrain_chunks := 8
## Vertex resolution per axis of the whole terrain heightmap (multiple of chunks).
@export var terrain_resolution := 320
## Multiplier for decorative scatter density.
@export var scatter_density := 1.0
## Create a WorldEnvironment + sun. Disable if the game owns its own environment.
@export var create_environment := true
## Bake navigation from terrain + POI static colliders.
@export var bake_navigation := true
## Resolution of the tactical map overlay texture.
@export var map_texture_resolution := 256

# --- Internal data (all pure data, safe to read after generation) -----------
var _world_seed := 0
var _generating := false
var _generated := false
var _nav_ready := false
var _nav_failed := false
var _gen_time_ms := 0
var _nav_time_ms := 0
var _nav_stage := 0

var _grid_res := 0
var _biome_res := 0
var _cell_size := 0.0
var _half := 0.0

var _base_heights := PackedFloat32Array()
var _heights := PackedFloat32Array()
var _path_mask := PackedFloat32Array()
var _pad_mask := PackedFloat32Array()
var _w_verdant := PackedFloat32Array()
var _w_ashen := PackedFloat32Array()
var _w_glass := PackedFloat32Array()
var _detail_a := PackedFloat32Array()
var _detail_b := PackedFloat32Array()
var _macro := PackedFloat32Array()

var _map_image: Image
var _map_texture: ImageTexture

var _spawn_points: Array[Vector3] = []
var _spawn_info: Array[Dictionary] = []
var _exfil_points: Array[Dictionary] = []
var _exfil_positions: Array[Vector2] = []
var _pois: Array[Dictionary] = []
var _poi_positions: Array[Vector2] = []
var _path_links: Array = []
var _path_segments: Array = []

var _materials = null
var _mats: Dictionary = {}

var _terrain_root: Node3D
var _structures_root: Node3D
var _scatter_root: Node3D
var _environment_root: Node3D
var _fluid_root: Node3D
var _nav_region: NavigationRegion3D
var _env_data: Dictionary = {}
var _owned_roots: Array[Node] = []
var _stats: Dictionary = {}
var _path_rng := RandomNumberGenerator.new()
var _roadside_points: Array[Dictionary] = []
## POI-local clutter props surfaced for LootCache:
## [{position: Vector3, kind: StringName, poi_index: int, poi_type: StringName}]
var _loot_props: Array[Dictionary] = []

# --- Planet / fluid / environment state --------------------------------------
var _planet: Dictionary = {}
var _planet_palette: Dictionary = {}
var _fluid_cfg: Dictionary = {}
var _weather_defs: Array = []
var _fluid_basins: Array[Dictionary] = []
var _fluid_mask := PackedFloat32Array()
var _environment_director: Node = null
var _day_night: Node = null
var _weather: Node = null
var _start_time := 0.62

# --- Map preset state (populated by apply_preset; empty = default frontier) --
var _preset: Dictionary = {}
var _roadside_target := 14
var _biome_rotation := 0.0
var _extra_poi_layout: Array = []

const POI_LAYOUT := [
	{"type": "warden_outpost", "biome": 1, "r_min": 210.0, "r_max": 430.0, "name": "Warden Outpost", "radius": 48.0, "pad": 30.0},
	{"type": "faction_camp", "biome": 0, "r_min": 250.0, "r_max": 620.0, "name": "Vanguard Camp", "radius": 42.0, "pad": 22.0},
	{"type": "faction_camp", "biome": 2, "r_min": 280.0, "r_max": 660.0, "name": "Ember Hold", "radius": 42.0, "pad": 22.0},
	{"type": "relay_spire", "biome": 1, "r_min": 320.0, "r_max": 730.0, "name": "Relay Spire Ix", "radius": 30.0, "pad": 16.0},
	{"type": "relay_spire", "biome": 0, "r_min": 320.0, "r_max": 730.0, "name": "Relay Spire Vey", "radius": 30.0, "pad": 16.0},
	{"type": "crash_site", "biome": 2, "r_min": 300.0, "r_max": 700.0, "name": "Crash Site: Kestrel", "radius": 38.0, "pad": 24.0},
	{"type": "vault", "biome": 1, "r_min": 360.0, "r_max": 750.0, "name": "Vault 07", "radius": 34.0, "pad": 22.0},
	{"type": "anomaly", "biome": 2, "r_min": 340.0, "r_max": 740.0, "name": "Rift Anomaly", "radius": 30.0, "pad": 18.0},
	{"type": "ruin_field", "biome": 0, "r_min": 300.0, "r_max": 690.0, "name": "The Ruined Archive", "radius": 32.0, "pad": 18.0},
	{"type": "ashen_stockade", "biome": 0, "r_min": 240.0, "r_max": 600.0, "name": "Ashen Stockade", "radius": 44.0, "pad": 24.0},
	{"type": "bloom_hive", "biome": 2, "r_min": 280.0, "r_max": 660.0, "name": "Bloom Hive", "radius": 42.0, "pad": 22.0},
	{"type": "choir_post", "biome": 1, "r_min": 300.0, "r_max": 700.0, "name": "Choir Listening Post", "radius": 36.0, "pad": 18.0},
	{"type": "colony_ruins", "biome": 0, "r_min": 230.0, "r_max": 620.0, "name": "Colony Ruins", "radius": 40.0, "pad": 20.0},
	{"type": "derelict_ship", "biome": 2, "r_min": 260.0, "r_max": 640.0, "name": "Derelict Freighter", "radius": 46.0, "pad": 26.0},
	# Second-wave kits. Appended after the authored 14 so existing seeds keep
	# their original POI positions; they accept a tighter 190 m spacing and a
	# relaxed flatness limit so a 1.8 km frontier can still hold all of them.
	{"type": "foundry_hall", "biome": 1, "r_min": 250.0, "r_max": 800.0, "name": "Foundry Hall", "radius": 46.0, "pad": 26.0, "spacing": 190.0, "flat_limit": 12.0, "attempts": 900},
	{"type": "hab_cluster", "biome": 0, "r_min": 235.0, "r_max": 760.0, "name": "Habitation Cluster", "radius": 44.0, "pad": 24.0, "spacing": 190.0, "flat_limit": 12.0, "attempts": 900},
	{"type": "comms_array", "biome": 2, "r_min": 300.0, "r_max": 810.0, "name": "Comms Array", "radius": 34.0, "pad": 20.0, "spacing": 190.0, "flat_limit": 12.0, "attempts": 900},
	{"type": "fuel_depot", "biome": 1, "r_min": 265.0, "r_max": 780.0, "name": "Fuel Depot", "radius": 44.0, "pad": 26.0, "spacing": 190.0, "flat_limit": 12.0, "attempts": 900},
	{"type": "clinic_shelter", "biome": 0, "r_min": 240.0, "r_max": 740.0, "name": "Field Clinic", "radius": 38.0, "pad": 22.0, "spacing": 190.0, "flat_limit": 12.0, "attempts": 900},
	{"type": "research_lab", "biome": 2, "r_min": 320.0, "r_max": 810.0, "name": "Research Lab", "radius": 40.0, "pad": 24.0, "spacing": 190.0, "flat_limit": 12.0, "attempts": 900},
	{"type": "water_works", "biome": 0, "r_min": 255.0, "r_max": 790.0, "name": "Water Works", "radius": 42.0, "pad": 24.0, "spacing": 190.0, "flat_limit": 12.0, "attempts": 900},
]

## Extra-POI kits cycled through when a map preset requests more objectives.
## Every type has an authored WorldStructures builder; radius/pad mirror the
## values used by the corresponding POI_LAYOUT entries.
const EXTRA_POI_KINDS := [
	{"type": "faction_camp", "radius": 42.0, "pad": 22.0},
	{"type": "relay_spire", "radius": 30.0, "pad": 16.0},
	{"type": "ruin_field", "radius": 32.0, "pad": 18.0},
	{"type": "derelict_ship", "radius": 46.0, "pad": 26.0},
	{"type": "foundry_hall", "radius": 46.0, "pad": 26.0},
	{"type": "hab_cluster", "radius": 44.0, "pad": 24.0},
	{"type": "comms_array", "radius": 34.0, "pad": 20.0},
	{"type": "fuel_depot", "radius": 44.0, "pad": 26.0},
	{"type": "clinic_shelter", "radius": 38.0, "pad": 22.0},
	{"type": "research_lab", "radius": 40.0, "pad": 24.0},
	{"type": "water_works", "radius": 42.0, "pad": 24.0},
]
const EXTRA_POI_FALLBACK_NAMES := [
	"Forward Camp", "Signal Relay", "Outer Ruins", "Wreck Site",
	"Foundry Spur", "Hab Ring", "Dish Field", "Fuel Spur",
	"Field Station", "Lab Outpost", "Pump Station",
]
## Base POIs keep their authored 235 m spacing; the second-wave kits and preset
## extras accept 195/190 m so they can still find room on a populated frontier.
const DEFAULT_POI_SPACING := 235.0
const EXTRA_POI_SPACING := 195.0
const DEFAULT_ROADSIDE_TARGET := 14


# =============================================================================
# PUBLIC API
# =============================================================================

## Applies a map preset dictionary (ContentDB.get_map_preset()). Call it before
## generate(); it shapes scatter density, roadside budget, extra POIs, biome
## rotation and the environment mood. The dictionary is deep-copied. An empty
## preset restores the default frontier exactly as if apply_preset was never
## called.
func apply_preset(preset: Dictionary) -> void:
	if _generating:
		push_warning("WorldBuilder.apply_preset(): ignored while generating")
		return
	_preset = preset.duplicate(true)
	map_size = float(_preset.get("map_size", 1800.0))
	scatter_density = float(_preset.get("scatter_density", 1.0))
	_roadside_target = maxi(0, int(_preset.get("roadside_target", DEFAULT_ROADSIDE_TARGET)))
	_biome_rotation = float(_preset.get("biome_rotation", 0.0))
	_extra_poi_layout = _build_extra_poi_layout(_preset)
	var planet_value = _preset.get("planet", {})
	_planet = planet_value.duplicate(true) if planet_value is Dictionary else {}
	_planet_palette = _build_planet_palette(_planet)
	var fluid_value = _preset.get("fluid", {})
	_fluid_cfg = fluid_value.duplicate(true) if fluid_value is Dictionary else {}
	var weather_value = _preset.get("weather_defs", [])
	_weather_defs = weather_value.duplicate(true) if weather_value is Array else []
	_start_time = clampf(float(_preset.get("start_time", 0.62)), 0.0, 0.999)


func _build_planet_palette(planet: Dictionary) -> Dictionary:
	if planet.is_empty():
		return {}
	var tint: Array = planet.get("terrain_tint", [])
	if tint.size() < 3:
		return {}
	return {"tint": tint, "strength": float(planet.get("tint_strength", 0.0))}


func _ready() -> void:
	add_to_group("world")


func generate(world_seed: int) -> void:
	if _generating:
		push_warning("WorldBuilder.generate(): already generating; ignoring request")
		return
	if not is_inside_tree():
		push_error("WorldBuilder.generate(): add this node to the scene tree before generating")
		generation_finished.emit(false)
		return
	_generating = true
	_generated = false
	_nav_ready = false
	_nav_failed = false
	_nav_stage = 0
	_nav_time_ms = 0
	_world_seed = world_seed
	_gen_time_ms = 0
	_stats = {}
	var t_start := Time.get_ticks_msec()
	_emit_progress(0.0, "Seeding frontier")

	# Resolve the height grid up-front: worker phases and sampling both need it.
	var chunks := maxi(1, terrain_chunks)
	_grid_res = maxi(chunks * 8, (maxi(64, int(terrain_resolution)) / chunks) * chunks)
	_biome_res = maxi(32, _grid_res / 2)
	_cell_size = float(map_size) / float(_grid_res)
	_half = float(map_size) * 0.5

	_clear_world()
	await get_tree().process_frame
	_ensure_materials()

	# --- Phase A: landforms + biome fields (worker thread, data only) --------
	var base_params := {
		"map_size": float(map_size),
		"grid_res": _grid_res,
		"biome_res": _biome_res,
		"seed": world_seed,
		"biome_rotation": _biome_rotation,
	}
	var base_worker = GenWorker.new()
	var base_thread := Thread.new()
	base_thread.start(Callable(base_worker, "build_base_fields").bind(base_params))
	var base_result: Variant = await _await_thread(base_thread, 0.03, 0.26, "Carving landforms")
	if not (base_result is Dictionary) or (base_result as Dictionary).is_empty():
		push_error("WorldBuilder.generate(): landform generation failed")
		_finish_generation(false)
		return
	_apply_base_fields(base_result)
	_stats["phase_a_ms"] = int((base_result as Dictionary).get("elapsed_ms", 0))

	# --- Placement ----------------------------------------------------------
	_emit_progress(0.27, "Surveying drop zones")
	await get_tree().process_frame
	_place_spawns()
	_emit_progress(0.30, "Charting exfil beacons")
	_place_exfils()
	_emit_progress(0.33, "Surveying points of interest")
	_place_pois()
	_build_path_network()
	_emit_progress(0.35, "Flooding the lowlands")
	_place_fluid_basins()

	# --- Phase B: pads, roads, map overlay (worker thread, data only) --------
	var pads: Array = []
	for spawn in _spawn_info:
		pads.append({"center": spawn["pos2"], "radius": 22.0, "falloff": 18.0})
	for poi in _pois:
		pads.append({"center": Vector2(poi["position"].x, poi["position"].z), "radius": float(poi["pad_radius"]), "falloff": 20.0})
	var markers: Array = []
	for poi in _pois:
		markers.append({
			"pos": Vector2(poi["position"].x, poi["position"].z),
			"kind": "exfil" if String(poi["type"]) == "exfil_pad" else "poi",
			"radius": float(poi["radius"]),
		})
	for spawn in _spawn_info:
		markers.append({"pos": spawn["pos2"], "kind": "spawn", "radius": 18.0})
	var final_params := {
		"heights": _base_heights.duplicate(),
		"grid_res": _grid_res,
		"map_size": float(map_size),
		"biome_res": _biome_res,
		"w_verdant": _w_verdant,
		"w_ashen": _w_ashen,
		"w_glass": _w_glass,
		"detail_a": _detail_a,
		"detail_b": _detail_b,
		"macro": _macro,
		"pads": pads,
		"links": _path_links,
		"markers": markers,
		"basins": _fluid_basins,
		"planet_palette": _planet_palette,
		"path_width": 8.0,
		"map_tex_res": map_texture_resolution,
	}
	var final_worker = GenWorker.new()
	var final_thread := Thread.new()
	final_thread.start(Callable(final_worker, "build_final_fields").bind(final_params))
	var final_result: Variant = await _await_thread(final_thread, 0.36, 0.46, "Grading roads")
	if not (final_result is Dictionary) or (final_result as Dictionary).is_empty():
		push_error("WorldBuilder.generate(): terrain dressing failed")
		_finish_generation(false)
		return
	_apply_final_fields(final_result)
	_finalize_ground_positions()
	_place_roadside_buildings()
	_stats["phase_b_ms"] = int((final_result as Dictionary).get("elapsed_ms", 0))

	# --- Terrain meshes + collision (data on workers, nodes on main) ---------
	_emit_progress(0.48, "Raising terrain")
	await _build_terrain()
	_emit_progress(0.60, "Filling water and lava")
	await get_tree().process_frame
	_build_fluid()

	# --- POIs ---------------------------------------------------------------
	_emit_progress(0.64, "Assembling frontier structures")
	await get_tree().process_frame
	_structures_root = _make_root("Structures")
	var structures = StructuresScript.new()
	_stats["structures"] = structures.build_all(_structures_root, _pois, _spawn_info, world_seed, _mats, _roadside_points)
	_collect_poi_structures()

	# --- Scatter ------------------------------------------------------------
	_emit_progress(0.74, "Scattering alien growth")
	await get_tree().process_frame
	_scatter_root = _make_root("Scatter")
	var scatter = ScatterScript.new()
	_stats["scatter"] = scatter.build(_scatter_root, self, _mats, world_seed, scatter_density)
	_loot_props = scatter.get_loot_props()

	# --- Environment --------------------------------------------------------
	_emit_progress(0.82, "Lighting the sun")
	await get_tree().process_frame
	if create_environment:
		_environment_root = _make_root("Environment")
		var env_builder = EnvironmentScript.new()
		var env_overrides: Dictionary = _preset.get("environment", {})
		_env_data = env_builder.setup(_environment_root, env_overrides, _planet)
		_setup_environment_systems()
	_build_bounds()

	# --- Navigation ---------------------------------------------------------
	_emit_progress(0.86, "Baking navigation")
	await get_tree().physics_frame
	await _bake_navigation()

	_gen_time_ms = Time.get_ticks_msec() - t_start
	_stats["generation_ms"] = _gen_time_ms
	_finish_generation(true)
	_emit_progress(1.0, "Frontier ready")
	navigation_ready.emit(_nav_ready)


func sample_height(world_xz: Vector2) -> float:
	if _heights.is_empty():
		return 0.0
	return GenWorker.sample_height_grid(_heights, _grid_res, map_size, world_xz.x, world_xz.y)


func get_spawn_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	out.assign(_spawn_points)
	return out


func get_exfil_points() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in _exfil_points:
		out.append({"position": e.get("position", Vector3.ZERO), "name": String(e.get("name", "Exfil"))})
	return out


func get_pois() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for poi in _pois:
		out.append({
			"position": poi.get("position", Vector3.ZERO),
			"type": String(poi.get("type", "poi")),
			"name": String(poi.get("name", "POI")),
			"radius": float(poi.get("radius", 30.0)),
			"pad_radius": float(poi.get("pad_radius", float(poi.get("radius", 30.0)) * 0.6)),
			"interior": poi.get("interior", {}),
			"dungeon_anchor": poi.get("dungeon_anchor", null),
		})
	return out


func get_biome_names() -> Array[String]:
	var out: Array[String] = []
	for i in 3:
		out.append(Palette.biome_name_for(_planet, i))
	return out


func get_planet() -> Dictionary:
	return _planet.duplicate(true)


func get_planet_palette() -> Dictionary:
	return _planet_palette.duplicate(true)


func get_fluid_basins() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for basin in _fluid_basins:
		out.append(basin.duplicate(true))
	return out


func get_fluid_root() -> Node3D:
	return _fluid_root


## Analytic fluid query: {type: 0 none / 1 water / 2 lava, level, depth, center,
## radius}. Gameplay uses this instead of physics volumes.
func sample_fluid(world_xz: Vector2) -> Dictionary:
	var out := {"type": 0, "level": 0.0, "depth": 0.0, "center": Vector2.ZERO, "radius": 0.0}
	if _fluid_basins.is_empty() or _heights.is_empty():
		return out
	var best_depth := 0.0
	for basin in _fluid_basins:
		var center: Vector2 = basin["center"]
		var radius := float(basin["radius"])
		if world_xz.distance_to(center) > radius:
			continue
		var level := float(basin["level"])
		var ground := sample_height(world_xz)
		if ground >= level:
			continue
		var depth := level - ground
		if depth > best_depth:
			best_depth = depth
			out = {
				"type": int(basin["type"]),
				"level": level,
				"depth": depth,
				"center": center,
				"radius": radius,
			}
	return out


func is_submerged(world_position: Vector3) -> bool:
	var fluid := sample_fluid(Vector2(world_position.x, world_position.z))
	return int(fluid.get("type", 0)) != 0 and world_position.y < float(fluid.get("level", 0.0))


func get_environment_director() -> Node:
	return _environment_director


func get_day_night_cycle() -> Node:
	return _day_night


func get_weather_system() -> Node:
	return _weather


func get_interior_pois() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for poi in _pois:
		if poi.has("interior") and not (poi["interior"] as Dictionary).is_empty():
			out.append(poi.duplicate(true))
	return out


func get_nav_region() -> NavigationRegion3D:
	return _nav_region


func get_map_texture() -> Texture2D:
	return _map_texture


func get_world_seed() -> int:
	return _world_seed


## StringName id of the applied preset, or &"" when running the default frontier.
func get_map_preset_id() -> StringName:
	return StringName(String(_preset.get("id", "")))


# =============================================================================
# Extra integration helpers (not required by the contract, useful for others)
# =============================================================================

func is_generating() -> bool:
	return _generating


func is_generated() -> bool:
	return _generated


func is_navigation_ready() -> bool:
	return _nav_ready


func get_biome_weights_at(world_xz: Vector2) -> Vector3:
	if _w_verdant.is_empty():
		return Vector3(1.0, 0.0, 0.0)
	return GenWorker.sample_biome(_w_verdant, _w_ashen, _w_glass, _biome_res, map_size, world_xz.x, world_xz.y)


func get_biome_at(world_xz: Vector2) -> String:
	return Palette.biome_name_for(_planet, Palette.dominant_biome(get_biome_weights_at(world_xz)))


func get_path_segments() -> Array:
	return _path_segments


func get_roadside_points() -> Array[Dictionary]:
	return _roadside_points.duplicate(true)


## POI-local clutter loot props produced by WorldScatter, ready for LootCache:
## [{position: Vector3 (ground + prop height), kind: StringName, poi_index: int,
##   poi_type: StringName}]. Empty before generation. Check `kind` against
## LootCache's prop mix; `poi_type` resolves through POISpecs.get_spec() for
## loot tier / biome context.
func get_loot_props() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for prop in _loot_props:
		out.append((prop as Dictionary).duplicate(true))
	return out


## Total decorative clutter instances (MultiMesh count) from the POI pass.
func get_clutter_piece_count() -> int:
	var scatter: Dictionary = _stats.get("scatter", {})
	return int(scatter.get("clutter_instances", 0))


## Road/path weight at a world position (0 away from roads, higher on them).
## Used by POI-local clutter to keep props out of the driving lanes.
func get_path_weight_at(world_xz: Vector2) -> float:
	if _path_mask.is_empty():
		return 0.0
	return GenWorker.sample_scalar_grid(_path_mask, _grid_res, map_size, world_xz.x, world_xz.y)


func get_terrain_root() -> Node3D:
	return _terrain_root


func get_structures_root() -> Node3D:
	return _structures_root


func get_scatter_root() -> Node3D:
	return _scatter_root


func get_environment_root() -> Node3D:
	return _environment_root


## Returns {environment: WorldEnvironment, sun: DirectionalLight3D, ...} when
## create_environment is enabled, otherwise an empty Dictionary.
func get_environment_data() -> Dictionary:
	return _env_data


func get_generation_stats() -> Dictionary:
	return _stats.duplicate(true)


## True when no POI pad, road or spawned structure occupies this spot.
func is_scatter_clear(pos: Vector2, clearance: float) -> bool:
	for poi in _pois:
		var pp := Vector2(poi["position"].x, poi["position"].z)
		if pos.distance_squared_to(pp) < pow(float(poi["radius"]) + clearance, 2.0):
			return false
	for spawn in _spawn_info:
		if pos.distance_squared_to(spawn["pos2"]) < pow(20.0 + clearance, 2.0):
			return false
	if not _path_mask.is_empty():
		var pw := GenWorker.sample_scalar_grid(_path_mask, _grid_res, map_size, pos.x, pos.y)
		if pw > 0.015:
			return false
	return true


## Stricter clearance for horizon-scale landmarks (spires, arches).
func is_landmark_clear(pos: Vector2) -> bool:
	for poi in _pois:
		var pp := Vector2(poi["position"].x, poi["position"].z)
		if pos.distance_squared_to(pp) < pow(float(poi["radius"]) + 55.0, 2.0):
			return false
	for spawn in _spawn_info:
		if pos.distance_squared_to(spawn["pos2"]) < 110.0 * 110.0:
			return false
	if not _path_mask.is_empty():
		var pw := GenWorker.sample_scalar_grid(_path_mask, _grid_res, map_size, pos.x, pos.y)
		if pw > 0.001:
			return false
	return true


# =============================================================================
# Generation internals
# =============================================================================

func _finish_generation(ok: bool) -> void:
	_generating = false
	_generated = ok
	generation_finished.emit(ok)


func _emit_progress(value: float, label: String) -> void:
	generation_progress.emit(clampf(value, 0.0, 1.0), label)


func _await_thread(thread: Thread, from_p: float, to_p: float, label: String) -> Variant:
	var t0 := Time.get_ticks_msec()
	while thread.is_alive():
		await get_tree().process_frame
		var elapsed := float(Time.get_ticks_msec() - t0)
		var frac := 1.0 - exp(-elapsed / 1100.0)
		_emit_progress(lerpf(from_p, to_p, clampf(frac, 0.0, 1.0)), label)
	var result: Variant = thread.wait_to_finish()
	_emit_progress(to_p, label)
	return result


func _ensure_materials() -> void:
	if not _mats.is_empty():
		return
	_materials = MaterialsScript.new()
	_mats = _materials.mats


func _make_root(node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	add_child(root)
	_owned_roots.append(root)
	return root


func _clear_world() -> void:
	for root in _owned_roots:
		if is_instance_valid(root):
			root.queue_free()
	_owned_roots.clear()
	_nav_region = null
	_terrain_root = null
	_structures_root = null
	_scatter_root = null
	_environment_root = null
	_fluid_root = null
	_environment_director = null
	_day_night = null
	_weather = null
	_env_data = {}
	_fluid_basins.clear()
	_fluid_mask = PackedFloat32Array()
	_base_heights = PackedFloat32Array()
	_heights = PackedFloat32Array()
	_path_mask = PackedFloat32Array()
	_pad_mask = PackedFloat32Array()
	_w_verdant = PackedFloat32Array()
	_w_ashen = PackedFloat32Array()
	_w_glass = PackedFloat32Array()
	_detail_a = PackedFloat32Array()
	_detail_b = PackedFloat32Array()
	_macro = PackedFloat32Array()
	_map_image = null
	_map_texture = null
	_spawn_points.clear()
	_spawn_info.clear()
	_exfil_points.clear()
	_exfil_positions.clear()
	_pois.clear()
	_poi_positions.clear()
	_path_links.clear()
	_path_segments.clear()
	_roadside_points.clear()
	_loot_props.clear()
	_nav_stage = 0


func _apply_base_fields(base: Dictionary) -> void:
	_base_heights = base["heights"]
	_grid_res = int(base["grid_res"])
	_biome_res = int(base["biome_res"])
	_cell_size = float(map_size) / float(_grid_res)
	_half = float(map_size) * 0.5
	_w_verdant = base["w_verdant"]
	_w_ashen = base["w_ashen"]
	_w_glass = base["w_glass"]
	_detail_a = base["detail_a"]
	_detail_b = base["detail_b"]
	_macro = base["macro"]


func _apply_final_fields(result: Dictionary) -> void:
	_heights = result["heights"]
	_path_mask = result["path_mask"]
	_pad_mask = result["pad_mask"]
	_fluid_mask = result.get("fluid_mask", PackedFloat32Array())
	_map_image = result["map_image"]
	if _map_image != null:
		_map_texture = ImageTexture.create_from_image(_map_image)


func _finalize_ground_positions() -> void:
	for i in _pois.size():
		var poi: Dictionary = _pois[i]
		var xz := Vector2(poi["position"].x, poi["position"].z)
		poi["position"] = Vector3(xz.x, sample_height(xz), xz.y)
	for i in _spawn_info.size():
		var spawn: Dictionary = _spawn_info[i]
		var xz: Vector2 = spawn["pos2"]
		spawn["position"] = Vector3(xz.x, sample_height(xz), xz.y)
	_spawn_points.clear()
	for spawn in _spawn_info:
		_spawn_points.append(spawn["position"])
	_exfil_points.clear()
	for poi in _pois:
		if String(poi["type"]) == "exfil_pad":
			_exfil_points.append({"position": poi["position"], "name": poi["name"]})


# =============================================================================
# Placement
# =============================================================================

func _sample_base_height(pos: Vector2) -> float:
	return GenWorker.sample_height_grid(_base_heights, _grid_res, map_size, pos.x, pos.y)


func _biome_weights_base(pos: Vector2) -> Vector3:
	return GenWorker.sample_biome(_w_verdant, _w_ashen, _w_glass, _biome_res, map_size, pos.x, pos.y)


## Roughness of the ground across a pad footprint (max height delta in meters).
func _flatness_at(pos: Vector2, radius: float) -> float:
	var h0 := _sample_base_height(pos)
	var max_delta := 0.0
	for k in 8:
		var ang := TAU * float(k) / 8.0
		var hp := _sample_base_height(pos + Vector2(cos(ang), sin(ang)) * radius)
		max_delta = maxf(max_delta, absf(hp - h0))
	for k in 4:
		var ang2 := TAU * float(k) / 4.0 + 0.4
		var hp2 := _sample_base_height(pos + Vector2(cos(ang2), sin(ang2)) * radius * 0.5)
		max_delta = maxf(max_delta, absf(hp2 - h0))
	return max_delta


func _place_spawns() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _world_seed * 6151 + 7
	var candidates: Array = []
	for attempt in 420:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(110.0, 390.0)
		var p := Vector2(cos(ang) * dist, sin(ang) * dist)
		var flat := _flatness_at(p, 16.0)
		var slope_rough := absf(_sample_base_height(p + Vector2(6.0, 0.0)) - _sample_base_height(p - Vector2(6.0, 0.0)))
		var score := 14.0 - flat * 5.0 - slope_rough * 1.5 - absf(dist - 240.0) * 0.012 + rng.randf() * 0.5
		candidates.append({"pos": p, "score": score})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	var picked: Array[Vector2] = []
	for cand in candidates:
		var p: Vector2 = cand["pos"]
		var ok := true
		for q in picked:
			if p.distance_to(q) < 240.0:
				ok = false
		if not ok:
			continue
		picked.append(p)
		if picked.size() >= 2:
			break
	while picked.size() < 2:
		picked.append(Vector2(-120.0 + float(picked.size()) * 260.0, 140.0))
	var names := ["Alpha", "Bravo"]
	for i in picked.size():
		var p: Vector2 = picked[i]
		var y := _sample_base_height(p)
		_spawn_info.append({"name": names[i], "pos2": p, "position": Vector3(p.x, y, p.y)})
		_spawn_points.append(Vector3(p.x, y, p.y))


func _place_exfils() -> void:
	var names := ["Exfil Alpha", "Exfil Bravo", "Exfil Charlie"]
	var base_angles := [PI * 0.88, PI * 1.52, PI * 0.30]
	var rng := RandomNumberGenerator.new()
	rng.seed = _world_seed * 313 + 29
	for i in 3:
		var best := Vector2(INF, INF)
		var best_score := -1e18
		for attempt in 260:
			var ang := float(base_angles[i]) + rng.randf_range(-0.55, 0.55)
			var dist := rng.randf_range(470.0, _half * 0.76)
			var p := Vector2(cos(ang) * dist, sin(ang) * dist)
			var ok := true
			for spawn in _spawn_info:
				if p.distance_to(spawn["pos2"]) < 290.0:
					ok = false
			for poi in _pois:
				if p.distance_to(Vector2(poi["position"].x, poi["position"].z)) < 235.0:
					ok = false
			for ep in _exfil_positions:
				if p.distance_to(ep) < 290.0:
					ok = false
			if not ok:
				continue
			var flat := _flatness_at(p, 24.0)
			if flat > 10.0:
				continue
			var score := 10.0 - flat * 0.9 - absf(dist - 560.0) * 0.006 + rng.randf() * 0.7
			if score > best_score:
				best_score = score
				best = p
		if best.x == INF:
			best = Vector2(cos(float(base_angles[i])) * 560.0, sin(float(base_angles[i])) * 560.0)
		_exfil_positions.append(best)
		_append_poi("exfil_pad", names[i], best, 38.0, 20.0, rng)


## Builds the preset's extra-POI layout entries. Kits cycle camps / relays /
## ruins, all tagged with the preset's preferred biome. Extras use a tighter
## spacing and relaxed flatness so they can land on an already populated map.
func _build_extra_poi_layout(preset: Dictionary) -> Array:
	var layout: Array = []
	var count := maxi(0, int(preset.get("extra_pois", 0)))
	if count == 0:
		return layout
	var names: Array = preset.get("extra_poi_names", [])
	var biome := clampi(int(preset.get("biome_index", 0)), 0, 2)
	for i in count:
		var kind: Dictionary = EXTRA_POI_KINDS[i % EXTRA_POI_KINDS.size()]
		var poi_name := String(EXTRA_POI_FALLBACK_NAMES[i % EXTRA_POI_FALLBACK_NAMES.size()])
		if i < names.size() and not String(names[i]).is_empty():
			poi_name = String(names[i])
		layout.append({
			"type": String(kind["type"]),
			"biome": biome,
			"r_min": 240.0,
			"r_max": 710.0,
			"name": poi_name,
			"radius": float(kind["radius"]),
			"pad": float(kind["pad"]),
			"spacing": EXTRA_POI_SPACING,
			"flat_limit": 11.0,
			"attempts": 640,
			"optional": true,
		})
	return layout


func _place_pois() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _world_seed * 1777 + 41
	for entry in POI_LAYOUT:
		_place_poi_entry(entry, rng)
	# Preset extras are appended after the authored layout so the base world
	# stays deterministic and unchanged on the no-preset path.
	for entry in _extra_poi_layout:
		_place_poi_entry(entry, rng)


func _place_poi_entry(entry: Dictionary, rng: RandomNumberGenerator) -> void:
	var biome: int = int(entry["biome"])
	var r_min: float = float(entry["r_min"])
	var r_max: float = float(entry["r_max"])
	var spacing: float = float(entry.get("spacing", DEFAULT_POI_SPACING))
	var flat_limit: float = float(entry.get("flat_limit", 8.5))
	var attempts: int = int(entry.get("attempts", 420))
	var best := Vector2(INF, INF)
	var best_score := -1e18
	for attempt in attempts:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(r_min, r_max)
		var p := Vector2(cos(ang) * dist, sin(ang) * dist)
		var ok := true
		for q in _poi_positions:
			if p.distance_to(q) < spacing:
				ok = false
		for spawn in _spawn_info:
			if p.distance_to(spawn["pos2"]) < 175.0:
				ok = false
		if not ok:
			continue
		var flat := _flatness_at(p, 20.0)
		if flat > flat_limit:
			continue
		var weights := _biome_weights_base(p)
		var biome_weight := 0.0
		if biome == 0:
			biome_weight = weights.x
		elif biome == 1:
			biome_weight = weights.y
		else:
			biome_weight = weights.z
		var score := biome_weight * 3.2 - flat * 0.45 + rng.randf() * 0.45
		if score > best_score:
			best_score = score
			best = p
	if best.x == INF:
		# Crowded frontier: retry with a relaxed footprint before falling back to
		# a blind position, so the second-wave kits keep their authored clearance.
		var relaxed := spacing * 0.72
		var relaxed_max := minf(r_max, _half * 0.92)
		for attempt in 420:
			var ang := rng.randf() * TAU
			var dist := rng.randf_range(r_min, maxf(r_min + 1.0, relaxed_max))
			var p := Vector2(cos(ang) * dist, sin(ang) * dist)
			var ok := true
			for q in _poi_positions:
				if p.distance_to(q) < relaxed:
					ok = false
					break
			if not ok:
				continue
			for spawn in _spawn_info:
				if p.distance_to(spawn["pos2"]) < 150.0:
					ok = false
					break
			if not ok:
				continue
			best = p
			_stats["poi_relaxed_placements"] = int(_stats.get("poi_relaxed_placements", 0)) + 1
			break
	if best.x == INF:
		# Preset extras are best-effort; authored POIs always land via fallback.
		if bool(entry.get("optional", false)):
			return
		_stats["poi_fallbacks"] = int(_stats.get("poi_fallbacks", 0)) + 1
		best = Vector2(cos(rng.randf() * TAU) * (r_min + r_max) * 0.5, sin(rng.randf() * TAU) * (r_min + r_max) * 0.5)
	_append_poi(String(entry["type"]), String(entry["name"]), best, float(entry["radius"]), float(entry["pad"]), rng)


func _append_poi(type: String, poi_name: String, pos: Vector2, radius: float, pad_radius: float, rng: RandomNumberGenerator) -> void:
	var to_center := (Vector2.ZERO - pos).normalized()
	var yaw := atan2(-to_center.x, -to_center.y) + rng.randf_range(-0.35, 0.35)
	var y := _sample_base_height(pos)
	_pois.append({
		"position": Vector3(pos.x, y, pos.y),
		"type": type,
		"name": poi_name,
		"radius": radius,
		"pad_radius": pad_radius,
		"yaw": yaw,
	})
	_poi_positions.append(pos)


# =============================================================================
# Roads
# =============================================================================

func _build_path_network() -> void:
	var nodes: Array[Vector2] = []
	for spawn in _spawn_info:
		nodes.append(spawn["pos2"])
	for poi in _pois:
		nodes.append(Vector2(poi["position"].x, poi["position"].z))
	if nodes.size() < 2:
		return
	_path_rng.seed = _world_seed * 199 + 3
	var n := nodes.size()
	var visited: Array[bool] = []
	visited.resize(n)
	for i in n:
		visited[i] = false
	visited[0] = true
	var edges := 0
	while edges < n - 1:
		var best_i := -1
		var best_j := -1
		var best_d := 1.0e20
		for i in n:
			if not visited[i]:
				continue
			for j in n:
				if visited[j]:
					continue
				var d := nodes[i].distance_squared_to(nodes[j])
				if d < best_d:
					best_d = d
					best_i = i
					best_j = j
		if best_j < 0:
			break
		visited[best_j] = true
		_path_links.append(_make_path_polyline(nodes[best_i], nodes[best_j]))
		edges += 1
	# A few extra loop connections keep the network from feeling like a tree.
	var extra := 0
	for i in n:
		if extra >= 6:
			break
		for j in range(i + 1, n):
			if extra >= 6:
				break
			var d := nodes[i].distance_to(nodes[j])
			if d < 260.0 and d > 90.0:
				_path_links.append(_make_path_polyline(nodes[i], nodes[j]))
				extra += 1
	_path_segments = _path_links


## Places seeded water/lava basins in low, quiet ground away from POIs, roads
## and drop zones. The height worker carves the bowls; the fluid renderer draws
## the surfaces; gameplay samples them analytically.
func _place_fluid_basins() -> void:
	_fluid_basins.clear()
	if _fluid_cfg.is_empty():
		return
	var water_range: Array = _fluid_cfg.get("water_basins", [0, 0])
	var lava_range: Array = _fluid_cfg.get("lava_basins", [0, 0])
	var rng := RandomNumberGenerator.new()
	rng.seed = _world_seed * 4099 + 71
	var water_count := _range_count(rng, water_range)
	var lava_count := _range_count(rng, lava_range)
	var total := water_count + lava_count
	if total <= 0:
		return
	var half := map_size * 0.5
	for attempt in 520:
		if _fluid_basins.size() >= total:
			break
		var fluid_type := 1 if _fluid_basins.size() < water_count else 2
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(190.0, half * 0.76)
		var center := Vector2(cos(ang) * dist, sin(ang) * dist)
		var radius := rng.randf_range(46.0, 78.0)
		var falloff := rng.randf_range(22.0, 40.0)
		if not _basin_clear(center, radius + falloff):
			continue
		var h0 := _sample_base_height(center)
		var depth := rng.randf_range(6.0, 13.0)
		var level := h0 - rng.randf_range(0.4, 1.6)
		_fluid_basins.append({
			"center": center,
			"radius": radius,
			"falloff": falloff,
			"level": level,
			"depth": depth,
			"type": fluid_type,
		})
	if _fluid_basins.is_empty():
		var fallback := Vector2(0.0, -half * 0.52)
		_fluid_basins.append({
			"center": fallback, "radius": 62.0, "falloff": 30.0,
			"level": _sample_base_height(fallback) - 0.8, "depth": 9.0,
			"type": 1 if water_count > 0 else 2,
		})
	_stats["fluid_basins"] = _fluid_basins.size()


func _range_count(rng: RandomNumberGenerator, range_value: Array) -> int:
	if range_value.size() < 2:
		return 0
	return rng.randi_range(maxi(0, int(range_value[0])), maxi(0, int(range_value[1])))


func _basin_clear(center: Vector2, radius: float) -> bool:
	var limit := _half * 0.86
	if absf(center.x) > limit or absf(center.y) > limit:
		return false
	for poi in _pois:
		var pp := Vector2(poi["position"].x, poi["position"].z)
		if center.distance_to(pp) < float(poi["radius"]) + radius + 26.0:
			return false
	for spawn in _spawn_info:
		if center.distance_to(spawn["pos2"]) < radius + 70.0:
			return false
	for roadside in _roadside_points:
		var rp: Vector3 = roadside["position"]
		if center.distance_to(Vector2(rp.x, rp.z)) < radius + 34.0:
			return false
	for existing in _fluid_basins:
		var ec: Vector2 = existing["center"]
		if center.distance_to(ec) < radius + float(existing["radius"]) + 40.0:
			return false
	if _path_distance(center) < radius * 0.75 + 24.0:
		return false
	return true


func _path_distance(pos: Vector2) -> float:
	var best := 1.0e20
	for link in _path_links:
		if not (link is PackedVector2Array):
			continue
		var pts: PackedVector2Array = link
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			var ab := b - a
			var t := clampf((pos - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			best = minf(best, pos.distance_to(a + ab * t))
	return best


func _build_fluid() -> void:
	if _fluid_basins.is_empty():
		return
	_fluid_root = _make_root("Fluid")
	var fluid = FluidScript.new()
	_stats["fluid"] = fluid.build(_fluid_root, _fluid_basins, _fluid_mask, _heights, _grid_res, map_size)


func _setup_environment_systems() -> void:
	_environment_director = _env_data.get("director")
	if _environment_director == null:
		return
	_day_night = DayNightScript.new()
	_day_night.name = "DayNightCycle"
	_environment_root.add_child(_day_night)
	if _day_night.has_method("setup"):
		_day_night.call("setup", _environment_director, _planet, _start_time)
	var pool: Array = _preset.get("weather_pool", [])
	if pool.is_empty():
		pool = _planet.get("weather_pool", [])
	_weather = WeatherScript.new()
	_weather.name = "WeatherSystem"
	_environment_root.add_child(_weather)
	if _weather.has_method("setup"):
		_weather.call("setup", _environment_director, _weather_defs, pool, _world_seed)


func _collect_poi_structures() -> void:
	if _structures_root == null:
		return
	var interiors := 0
	for i in _pois.size():
		var prefix := "POI_%02d_" % i
		var root: Node3D = null
		for child in _structures_root.get_children():
			if child is Node3D and String(child.name).begins_with(prefix):
				root = child as Node3D
				break
		if root == null:
			continue
		var spawn_markers := root.find_children("InteriorSpawn_*", "Marker3D", true, false)
		if not spawn_markers.is_empty():
			var points: Array[Vector3] = []
			for marker in spawn_markers:
				if marker is Node3D:
					points.append((marker as Node3D).global_position)
			_pois[i]["interior"] = {"spawns": points, "count": points.size()}
			interiors += 1
		var anchor := root.find_child("DungeonAnchor", true, false)
		if anchor is Node3D:
			_pois[i]["dungeon_anchor"] = (anchor as Node3D).global_position
	_stats["interiors"] = interiors


## Places a handful of small roadside buildings so the road network reads as
## inhabited rather than empty. Points are validated against POIs, spawns and
## each other, then handed to WorldStructures during node construction.
## The cap comes from the map preset (`roadside_target`, default 14).
func _place_roadside_buildings() -> void:
	_roadside_points.clear()
	if _roadside_target <= 0 or _path_links.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _world_seed * 977 + 13
	var kind := 0
	for link in _path_links:
		if not (link is PackedVector2Array):
			continue
		var pts: PackedVector2Array = link
		if pts.size() < 2:
			continue
		var next_at := rng.randf_range(120.0, 190.0)
		var travelled := 0.0
		var side := 1.0 if kind % 2 == 0 else -1.0
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			var seg_len := a.distance_to(b)
			if seg_len <= 0.05:
				continue
			var dir := (b - a) / seg_len
			while next_at <= travelled + seg_len:
				var t := next_at - travelled
				var point := a + dir * t
				var perp := Vector2(-dir.y, dir.x)
				var candidate := point + perp * rng.randf_range(9.0, 15.0) * side
				if _roadside_clear(candidate):
					var y := sample_height(candidate)
					_roadside_points.append({
						"position": Vector3(candidate.x, y, candidate.y),
						"yaw": atan2(-dir.x, -dir.y) + rng.randf_range(-0.25, 0.25),
						"kind": kind % 3,
					})
					kind += 1
					side = -side
					if _roadside_points.size() >= _roadside_target:
						return
				next_at += rng.randf_range(150.0, 230.0)
			travelled += seg_len
		if _roadside_points.size() >= _roadside_target:
			return


func _roadside_clear(pos: Vector2) -> bool:
	var limit := _half * 0.88
	if absf(pos.x) > limit or absf(pos.y) > limit:
		return false
	for poi in _pois:
		var pp := Vector2(poi["position"].x, poi["position"].z)
		if pos.distance_to(pp) < float(poi["radius"]) + 34.0:
			return false
	for spawn in _spawn_info:
		if pos.distance_to(spawn["pos2"]) < 70.0:
			return false
	for existing in _roadside_points:
		var ep: Vector3 = existing["position"]
		if pos.distance_to(Vector2(ep.x, ep.z)) < 80.0:
			return false
	for basin in _fluid_basins:
		var bc: Vector2 = basin["center"]
		if pos.distance_to(bc) < float(basin["radius"]) + 26.0:
			return false
	return true


func _make_path_polyline(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var dist := a.distance_to(b)
	var steps := maxi(3, int(dist / 55.0))
	var dir := (b - a) / maxf(dist, 0.001)
	var perp := Vector2(-dir.y, dir.x)
	var wobble := 0.0
	var limit := _half * 0.93
	pts.append(a)
	for i in range(1, steps):
		var t := float(i) / float(steps)
		wobble = lerpf(wobble, _path_rng.randf_range(-26.0, 26.0), 0.45)
		var p := a.lerp(b, t) + perp * wobble * sin(t * PI)
		p.x = clampf(p.x, -limit, limit)
		p.y = clampf(p.y, -limit, limit)
		pts.append(p)
	pts.append(b)
	return pts


# =============================================================================
# Terrain mesh + collision
# =============================================================================

func _build_terrain() -> void:
	_terrain_root = _make_root("Terrain")
	var chunk_count := terrain_chunks * terrain_chunks
	var quads := int(_grid_res / terrain_chunks)
	var common := {
		"heights": _heights,
		"grid_res": _grid_res,
		"map_size": float(map_size),
		"biome_res": _biome_res,
		"quads": quads,
		"w_verdant": _w_verdant,
		"w_ashen": _w_ashen,
		"w_glass": _w_glass,
		"detail_a": _detail_a,
		"detail_b": _detail_b,
		"macro": _macro,
		"path_mask": _path_mask,
		"pad_mask": _pad_mask,
		"planet_palette": _planet_palette,
	}
	# Pure-data chunk vertex generation on worker threads; nodes on main thread.
	var thread_count := clampi(OS.get_processor_count() - 1, 2, 8)
	var threads: Array[Thread] = []
	var workers: Array = []
	for t in thread_count:
		var coords: Array[Vector2i] = []
		var idx := t
		while idx < chunk_count:
			coords.append(Vector2i(idx % terrain_chunks, idx / terrain_chunks))
			idx += thread_count
		var worker = TerrainWorker.new()
		workers.append(worker)
		var thread := Thread.new()
		thread.start(Callable(worker, "compute_chunks_batch").bind(common, coords))
		threads.append(thread)
	var t0 := Time.get_ticks_msec()
	while true:
		var alive := 0
		for thread in threads:
			if thread.is_alive():
				alive += 1
		if alive == 0:
			break
		await get_tree().process_frame
		var elapsed := float(Time.get_ticks_msec() - t0)
		_emit_progress(lerpf(0.48, 0.61, clampf(elapsed / 1800.0, 0.0, 0.98)), "Raising terrain")
	var all_holders: Array = []
	for thread in threads:
		var result: Variant = thread.wait_to_finish()
		if result is Array:
			all_holders.append_array(result)
	for holder in all_holders:
		if holder is Dictionary:
			_instantiate_chunk(holder)
	_emit_progress(0.62, "Raising terrain")


func _instantiate_chunk(holder: Dictionary) -> void:
	if holder.is_empty():
		return
	var verts: PackedVector3Array = holder["verts"]
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = holder["norms"]
	arrays[Mesh.ARRAY_COLOR] = holder["colors"]
	arrays[Mesh.ARRAY_INDEX] = holder["indices"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _mats[&"terrain"])
	var cx: int = holder["cx"]
	var cz: int = holder["cz"]
	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [cx, cz]
	_terrain_root.add_child(chunk)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	chunk.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	chunk.add_child(body)


func _build_bounds() -> void:
	var bounds := _make_root("MapBounds")
	var body := StaticBody3D.new()
	body.name = "Bounds"
	body.collision_layer = 1
	body.collision_mask = 0
	bounds.add_child(body)
	var limit := _half - 12.0
	var height := 600.0
	var thick := 16.0
	var specs := [
		{"pos": Vector3(-limit, 180.0, 0.0), "size": Vector3(thick, height, float(map_size) + thick * 2.0)},
		{"pos": Vector3(limit, 180.0, 0.0), "size": Vector3(thick, height, float(map_size) + thick * 2.0)},
		{"pos": Vector3(0.0, 180.0, -limit), "size": Vector3(float(map_size) + thick * 2.0, height, thick)},
		{"pos": Vector3(0.0, 180.0, limit), "size": Vector3(float(map_size) + thick * 2.0, height, thick)},
	]
	for spec in specs:
		var shape := BoxShape3D.new()
		shape.size = spec["size"]
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = spec["pos"]
		body.add_child(collider)


# =============================================================================
# Navigation
# =============================================================================

func _bake_navigation() -> void:
	_nav_ready = false
	_nav_failed = false
	if not bake_navigation:
		return
	var nav_start := Time.get_ticks_msec()
	_nav_region = NavigationRegion3D.new()
	_nav_region.name = "NavigationRegion3D"
	add_child(_nav_region)
	_owned_roots.append(_nav_region)
	var nav_mesh := NavigationMesh.new()
	# 1.8 km² bake: coarse cells keep the recast raster affordable in memory/time.
	nav_mesh.cell_size = 2.0
	nav_mesh.cell_height = 1.0
	nav_mesh.agent_height = 1.9
	nav_mesh.agent_radius = 1.3
	nav_mesh.agent_max_climb = 0.9
	nav_mesh.agent_max_slope = 45.0
	nav_mesh.region_min_size = 25.0
	nav_mesh.edge_max_error = 2.0
	nav_mesh.edge_max_length = 36.0
	nav_mesh.detail_sample_distance = 4.0
	nav_mesh.detail_sample_max_error = 2.5
	nav_mesh.filter_low_hanging_obstacles = true
	nav_mesh.filter_ledge_spans = true
	nav_mesh.filter_walkable_low_height_spans = true
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = &"nav_source"
	nav_mesh.geometry_collision_mask = 1
	_nav_region.navigation_mesh = nav_mesh

	var source := NavigationMeshSourceGeometryData3D.new()
	_nav_stage = 1
	NavigationServer3D.parse_source_geometry_data(
		nav_mesh,
		source,
		self,
		Callable(self, "_on_nav_geometry_parsed").bind(nav_mesh, source)
	)
	# Wait for parse -> bake chain, with generous timeout and progress pumping.
	var timeout_ms := 26000
	var t0 := Time.get_ticks_msec()
	while _nav_stage < 3:
		await get_tree().process_frame
		var elapsed := Time.get_ticks_msec() - t0
		_emit_progress(lerpf(0.87, 0.99, clampf(float(elapsed) / 6000.0, 0.0, 0.98)), "Baking navigation")
		if elapsed > timeout_ms:
			push_warning("WorldBuilder: async navigation bake timed out (stage %d)" % _nav_stage)
			break
	# Fallback 1: parse callback never fired -> parse synchronously, bake async.
	if _nav_stage < 2:
		NavigationServer3D.parse_source_geometry_data(nav_mesh, source, self)
		_nav_stage = 2
		NavigationServer3D.bake_from_source_geometry_data_async(nav_mesh, source, Callable(self, "_on_nav_baked").bind(nav_mesh))
		var fallback_t0 := Time.get_ticks_msec()
		while _nav_stage < 3 and Time.get_ticks_msec() - fallback_t0 < 20000:
			await get_tree().process_frame
	# Fallback 2: still nothing -> blocking bake as a last resort.
	if _nav_stage < 3:
		NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source)
		if _nav_region != null:
			_nav_region.navigation_mesh = nav_mesh
		_nav_stage = 3
		_nav_ready = nav_mesh.get_polygon_count() > 0
	else:
		_nav_ready = nav_mesh.get_polygon_count() > 0
	if not _nav_ready:
		_nav_failed = true
		push_warning("WorldBuilder: navigation mesh has no walkable polygons")
	_nav_time_ms = Time.get_ticks_msec() - nav_start
	_stats["nav_ms"] = _nav_time_ms
	_stats["nav_polygons"] = nav_mesh.get_polygon_count()
	_stats["nav_vertices"] = nav_mesh.get_vertices().size()
	_emit_progress(0.99, "Navigation %s" % ("ready" if _nav_ready else "unavailable"))


func _on_nav_geometry_parsed(nav_mesh: NavigationMesh, source: NavigationMeshSourceGeometryData3D) -> void:
	_nav_stage = 2
	NavigationServer3D.bake_from_source_geometry_data_async(
		nav_mesh,
		source,
		Callable(self, "_on_nav_baked").bind(nav_mesh)
	)


func _on_nav_baked(nav_mesh: NavigationMesh) -> void:
	_nav_stage = 3
	if is_instance_valid(_nav_region):
		_nav_region.navigation_mesh = nav_mesh
	_nav_ready = true
