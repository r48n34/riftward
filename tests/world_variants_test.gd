extends Node3D
## Headless world-variants acceptance test: generates one world per planet
## (Meridian-9 / Cinder-4 / Thalassa-2 / Frost-9 / Nyx-12) through the real
## ContentDB presets and validates planet identity, fluid basins, enterable
## interiors, navmesh and the day/night + weather systems.
##
## Run with:
##   godot --headless --path . res://tests/world_variants_test.tscn

const WorldBuilderScript := preload("res://features/world/world_builder.gd")
const TIMEOUT_SECONDS := 300.0
const PRESETS: Array[StringName] = [
	&"verdant_verge", &"cinder_caldera", &"tidal_shelf",
	&"glacier_shelf", &"white_expanse", &"null_steppe", &"echo_basin",
]

var _checks := 0
var _failures: Array[String] = []
var _done := false


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[VARIANTS-TEST] PASS: ", label)
	else:
		_failures.append(label)
		push_error("[VARIANTS-TEST] FAIL: " + label)


func _run() -> void:
	print("[VARIANTS-TEST] starting planet world validation")
	var timeout := Timer.new()
	timeout.wait_time = TIMEOUT_SECONDS
	timeout.one_shot = true
	timeout.timeout.connect(func() -> void:
		if not _done:
			push_error("[VARIANTS-TEST] TIMEOUT after %.0fs" % TIMEOUT_SECONDS)
			get_tree().quit(1)
	)
	add_child(timeout)
	timeout.start()
	await get_tree().process_frame
	var seed_base := 424242
	for preset_id in PRESETS:
		var preset: Dictionary = ContentDB.get_map_preset(preset_id)
		_check(not preset.is_empty(), "preset resolves: %s" % preset_id)
		if preset.is_empty():
			continue
		var planet: Dictionary = preset.get("planet", {})
		_check(not planet.is_empty(), "preset carries a planet: %s" % preset_id)
		_check((preset.get("weather_defs", []) as Array).size() == 18,
			"preset receives all 18 weather defs: %s" % preset_id)
		var world = WorldBuilderScript.new()
		world.name = "World_%s" % String(preset_id)
		add_child(world)
		world.apply_preset(preset)
		var started := Time.get_ticks_msec()
		await world.generate(seed_base ^ int(preset.get("world_seed_salt", 0)))
		var elapsed := Time.get_ticks_msec() - started
		_check(bool(world.is_generated()), "world generated: %s" % preset_id)
		_check(elapsed < 6000, "generation under 6s: %s (%dms)" % [preset_id, elapsed])
		_validate_world(world, preset, planet, preset_id)
		world.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_done = true
	timeout.queue_free()
	if _failures.is_empty():
		print("[VARIANTS-TEST] checks=%d failures=0" % _checks)
		print("[VARIANTS-TEST] RESULT: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			print("[VARIANTS-TEST] Failure: ", failure)
		print("[VARIANTS-TEST] checks=%d failures=%d" % [_checks, _failures.size()])
		print("[VARIANTS-TEST] RESULT: FAIL")
		get_tree().quit(1)


func _validate_world(world: Node3D, preset: Dictionary, planet: Dictionary, preset_id: StringName) -> void:
	var names: Array = planet.get("biome_names", [])
	var world_names: Array = world.get_biome_names()
	_check(world_names.size() == 3, "world exposes 3 biome names: %s" % preset_id)
	if names.size() == 3 and world_names.size() == 3:
		_check(String(world_names[0]) == String(names[0]), "biome 0 is planet-authored: %s" % preset_id)
		_check(String(world_names[2]) == String(names[2]), "biome 2 is planet-authored: %s" % preset_id)
	var pois: Array = world.get_pois()
	_check(pois.size() >= 17, "world has 17+ POIs: %s (%d)" % [preset_id, pois.size()])
	var types: Dictionary = {}
	var interiors := 0
	for poi in pois:
		var type := String(poi.get("type", ""))
		types[type] = int(types.get(type, 0)) + 1
		if not (poi.get("interior", {}) as Dictionary).is_empty():
			interiors += 1
	_check(types.has("derelict_ship"), "derelict ship POI exists: %s" % preset_id)
	_check(interiors >= 4, "enterable interiors exist: %s (%d)" % [preset_id, interiors])
	var basins: Array = world.get_fluid_basins()
	_check(not basins.is_empty(), "fluid basins generated: %s" % preset_id)
	var water := 0
	var lava := 0
	for basin in basins:
		if int(basin.get("type", 0)) == 2:
			lava += 1
		elif int(basin.get("type", 0)) == 1:
			water += 1
	var planet_id := StringName(planet.get("id", &""))
	if planet_id == &"cinder_4":
		_check(lava > 0 and water == 0, "Cinder-4 has lava but no water: %s" % preset_id)
	elif planet_id == &"thalassa_2":
		_check(water > 0 and lava == 0, "Thalassa-2 has water but no lava: %s" % preset_id)
	elif planet_id == &"frost_9":
		_check(water > 0 and lava == 0, "Frost-9 has water but no lava: %s" % preset_id)
	elif planet_id == &"nyx_12":
		_check(lava > 0 and water == 0, "Nyx-12 has lava but no water: %s" % preset_id)
	else:
		_check(water > 0, "Meridian-9 has water: %s" % preset_id)
	var fluid_root = world.get_fluid_root()
	_check(fluid_root != null and fluid_root.get_child_count() > 0, "fluid surfaces built: %s" % preset_id)
	var nav: NavigationRegion3D = world.get_nav_region()
	_check(nav != null and nav.navigation_mesh != null and nav.navigation_mesh.get_polygon_count() > 100,
		"navmesh baked: %s" % preset_id)
	var director = world.get_environment_director()
	var day_night = world.get_day_night_cycle()
	var weather = world.get_weather_system()
	_check(director != null, "environment director exists: %s" % preset_id)
	_check(day_night != null, "day/night cycle exists: %s" % preset_id)
	_check(weather != null, "weather system exists: %s" % preset_id)
	if day_night != null:
		var clock := String(day_night.call("get_clock_text"))
		_check(clock.length() == 5, "clock text valid: %s (%s)" % [preset_id, clock])
	if weather != null:
		var state: Dictionary = weather.call("get_state")
		_check(not String(state.get("display_name", "")).is_empty(), "weather state valid: %s" % preset_id)
		_check(float(state.get("vision_mult", 0.0)) > 0.0, "weather exposes a vision multiplier: %s" % preset_id)
	if director != null:
		var env_state: Dictionary = director.call("get_state")
		_check(env_state.has("sun_dir"), "environment state exposes the sun: %s" % preset_id)
	var map_texture: Texture2D = world.get_map_texture()
	_check(map_texture != null, "tactical map texture exists: %s" % preset_id)
	# Fluid sampling is analytic and must agree with the basin list.
	if not basins.is_empty():
		var center: Vector2 = basins[0].get("center", Vector2.ZERO)
		var sample: Dictionary = world.sample_fluid(center)
		_check(int(sample.get("type", 0)) != 0, "sample_fluid resolves basin centre: %s" % preset_id)
