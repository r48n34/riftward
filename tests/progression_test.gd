extends SceneTree
## Headless progression/content acceptance test for RIFTWARD.
## Run with:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##       --script res://tests/progression_test.gd
##
## Covers the expansion content, mechanic/level gates, weapon zoom data,
## kill-XP/difficulty result math and the late-run pressure curve. It never
## writes a save: ProfileState data is backed up and restored in memory.

const MechanicUnlocks := preload("res://features/player/mechanic_unlocks.gd")

var _checks := 0
var _failures: Array[String] = []
var _profile_backup: Dictionary = {}
var _ran := false


func _initialize() -> void:
	print("==================================================================")
	print("[PROGRESSION-TEST] RIFTWARD progression/content test")
	print("==================================================================")


func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run()
	return false


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[PROGRESSION-TEST] PASS: ", label)
	else:
		_failures.append(label)
		push_error("[PROGRESSION-TEST] FAIL: " + label)


func _run() -> void:
	var content_db = root.get_node_or_null("/root/ContentDB")
	var profile = root.get_node_or_null("/root/ProfileState")
	var run_state = root.get_node_or_null("/root/RunState")
	_check(content_db != null, "ContentDB autoload available")
	_check(profile != null, "ProfileState autoload available")
	_check(run_state != null, "RunState autoload available")
	if content_db == null or profile == null or run_state == null:
		_finish()
		return

	# --- content catalog ------------------------------------------------------
	_check(content_db.difficulties.size() == 4, "4 run difficulties authored")
	_check(content_db.map_presets.size() == 12, "12 map presets authored")
	_check(content_db.planets.size() == 5, "5 planets authored")
	_check(content_db.weather.size() == 18, "18 weather states authored")
	_check(content_db.dungeon_themes.size() == 3, "3 dungeon themes authored")
	_check(content_db.enemies.size() == 37, "37 enemy entries authored")
	_check(content_db.game_modes.size() == 5, "5 game modes authored")
	_check(content_db.world_events.size() == 20, "20 world events authored")
	_check(content_db.weapons.size() == 16, "16 weapons authored")
	_check(content_db.abilities.size() == 24, "24 abilities authored")
	_check(content_db.perks.size() == 24, "24 perks authored")
	_check(content_db.contracts.size() == 13, "13 contracts authored")
	_check(content_db.content_errors.is_empty(), "ContentDB reports no validation errors")

	# --- 0.3.0 content: loot cargo, tables and Codex records -------------------
	_check(content_db.items.size() == 10, "10 authored loot items")
	_check(content_db.loot_tables.size() == 3, "3 authored loot tables")
	_check(content_db.poi_codex.size() == 7, "7 POI codex records authored")
	_check(content_db.rideable_codex.size() == 5, "5 rideable codex records authored")
	var authored_rarities := {
		&"field_ration": 0, &"stim_injector": 1, &"ammo_crate": 1, &"repair_kit": 2,
		&"fuel_cell": 2, &"alloy_plate": 1, &"relic_shard": 3, &"map_intel": 2,
		&"beacon_flare": 0, &"trophy_core": 4,
	}
	for loot_id in authored_rarities.keys():
		var loot = content_db.get_item(loot_id)
		_check(loot != null, "loot item exists: %s" % loot_id)
		if loot == null:
			continue
		_check(loot.rarity == int(authored_rarities[loot_id]), "loot item rarity tier: %s" % loot_id)
		_check(loot.value > 0 and loot.get_stack_value(1) >= loot.value,
			"loot item value follows the rarity curve: %s" % loot_id)
		_check(not loot.display_name.strip_edges().is_empty(), "loot item has a display name: %s" % loot_id)
		_check(not loot.description.strip_edges().is_empty(), "loot item has a tooltip blurb: %s" % loot_id)
		_check(UIIcons.has_icon(loot.icon), "loot item icon resolves: %s" % loot_id)
	var loot_factory_script: Script = load("res://features/loot/item_factory.gd")
	var loot_tables_script: Script = load("res://features/loot/loot_tables.gd")
	_check(loot_factory_script != null, "loot factory script available")
	_check(loot_tables_script != null, "loot tables script available")
	for loot_table_id in [&"poi_common", &"poi_rare", &"vehicle_stash"]:
		var table: Dictionary = content_db.get_loot_table(loot_table_id)
		_check(not table.is_empty(), "loot table exists: %s" % loot_table_id)
		_check((table.get("entries", []) as Array).size() >= 3, "loot table is weighted: %s" % loot_table_id)
		_check(int(table.get("rarity_floor", -1)) in [0, 1, 2, 3, 4],
			"loot table declares a valid rarity floor: %s" % loot_table_id)
	var all_table_loot: Dictionary = {}
	for loot_table_id in content_db.get_loot_table_ids():
		for loot_id in content_db.get_loot_table_item_ids(loot_table_id):
			all_table_loot[loot_id] = true
	for loot_id in authored_rarities.keys():
		_check(all_table_loot.has(loot_id), "loot item is reachable from a loot table: %s" % loot_id)
	_check(loot_tables_script.call("table_for_loot_tier", 1) == &"poi_common",
		"numeric loot tier 1 maps to poi_common")
	_check(loot_tables_script.call("table_for_loot_tier", 3) == &"poi_rare",
		"numeric loot tier 3 maps to poi_rare")
	_check(loot_tables_script.call("table_for_loot_tier", &"vehicle") == &"vehicle_stash",
		"vehicle loot tier maps to vehicle_stash")
	_check(content_db.get_loot_table_for_poi(&"no_such_poi_type") == &"poi_common",
		"unknown POI loot tier falls back to poi_common")
	_check(content_db.get_loot_table_ids().has(content_db.get_loot_table_for_poi(&"comms_array")),
		"known POI resolves a real loot table")

	# Deterministic rolls: every result must describe to a named, valuable item and
	# the authored cargo must all be reachable through the weighted distribution.
	var roll_rng := RandomNumberGenerator.new()
	roll_rng.seed = 20261026
	var roll_failures := 0
	var rolled_ids: Dictionary = {}
	for loot_table_id in [&"poi_common", &"poi_rare", &"vehicle_stash"]:
		for roll_index in 400:
			var roll: Dictionary = content_db.roll_loot_table(roll_rng, loot_table_id, 0.05, 2, 5000 + roll_index)
			if roll.is_empty():
				roll_failures += 1
				continue
			var roll_info: Dictionary = loot_factory_script.call("describe", roll)
			if String(roll_info.get("display_name", "")).is_empty() or int(roll_info.get("value", 0)) <= 0:
				roll_failures += 1
			rolled_ids[StringName(roll.get("base_id", &""))] = true
	_check(roll_failures == 0, "every rolled loot table entry describes with a value")
	for loot_id in authored_rarities.keys():
		_check(rolled_ids.has(loot_id), "weighted distribution reaches loot item: %s" % loot_id)
	var det_a := RandomNumberGenerator.new()
	det_a.seed = 99
	var det_b := RandomNumberGenerator.new()
	det_b.seed = 99
	_check(
		content_db.roll_loot_table(det_a, &"poi_rare", 0.1, 3, 77)
			== content_db.roll_loot_table(det_b, &"poi_rare", 0.1, 3, 77),
		"loot table rolls are deterministic per seed"
	)
	var facade_rng := RandomNumberGenerator.new()
	facade_rng.seed = 31
	var facade_item: Dictionary = loot_factory_script.call(
		"generate_from_loot_table", facade_rng, &"poi_common", 0.0, 1, 777
	)
	_check(not facade_item.is_empty(), "ItemFactory.generate_from_loot_table facade rolls an item")

	# Loot cargo uses the normal item dictionary (save v5 untouched) but is never
	# equipment, and the cache payload contract LootCache consumes stays intact.
	var probe_loot_item: Dictionary = loot_factory_script.call("generate_loot_item", &"trophy_core", 4242, 2)
	var probe_info: Dictionary = loot_factory_script.call("describe", probe_loot_item)
	_check(String(probe_info.get("kind", "")) == "loot", "loot cargo describes with kind 'loot'")
	_check(String(probe_info.get("rarity_name", "")) == "Prototype", "trophy core describes at Prototype rarity")
	_check(int(probe_info.get("amount", 0)) == 2, "loot cargo keeps its stack amount")
	_check(int(probe_info.get("value", 0)) == int(round(120.0 * float(StatKeys.RARITY_MULT[4]))) * 2,
		"loot stack value follows the authored value + rarity curve")
	_check((loot_factory_script.call("equipment_modifiers", probe_loot_item) as Array).is_empty(),
		"loot cargo is not equipment")
	_check((loot_factory_script.call("weapon_runtime_stats", probe_loot_item) as Dictionary).is_empty(),
		"loot cargo is not a weapon")
	var cache_rng := RandomNumberGenerator.new()
	cache_rng.seed = 1234
	var cache_payload: Dictionary = content_db.build_loot_cache_payload(cache_rng, &"vehicle_stash", 2, 0.05, 900)
	for payload_key in ["salvage", "cores", "item", "rarity", "label", "item_label", "prompt", "threat", "boss"]:
		_check(cache_payload.has(payload_key), "cache payload carries '%s'" % payload_key)
	_check(not (cache_payload.get("item", {}) as Dictionary).is_empty(), "cache payload carries an item")
	_check(String(cache_payload.get("loot_table", "")) == "vehicle_stash", "cache payload records its table id")
	var locker_backup: Dictionary = profile.data.duplicate(true)
	profile.data["inventory"] = []
	profile.data["next_uid"] = 1
	var banked_uid: int = profile.add_item(probe_loot_item)
	_check(banked_uid > 0 and profile.get_inventory_size() == 1, "loot cargo banks into the locker")
	_check(not profile.equip_item(banked_uid, &"charm"), "loot cargo cannot be equipped")
	profile.data = locker_backup

	# Codex presentation records (fallbacks for the world/vehicle streams).
	for poi_id in [&"foundry_hall", &"hab_cluster", &"comms_array", &"fuel_depot",
			&"clinic_shelter", &"research_lab", &"water_works"]:
		var poi_entry: Dictionary = content_db.get_poi_codex(poi_id)
		_check(not poi_entry.is_empty(), "POI codex record exists: %s" % poi_id)
		_check(not String(poi_entry.get("display_name", "")).is_empty(), "POI codex record is named: %s" % poi_id)
		_check(not String(poi_entry.get("blurb", "")).is_empty(), "POI codex record has a blurb: %s" % poi_id)
		_check(UIIcons.has_icon(StringName(poi_entry.get("icon", &""))),
			"POI codex icon resolves: %s" % poi_id)
		_check(content_db.get_loot_table_ids().has(StringName(poi_entry.get("loot_table", &""))),
			"POI codex loot table resolves: %s" % poi_id)
	for ride_id in [&"rig", &"hoverbike", &"spaceship", &"airplane", &"horse"]:
		var ride_entry: Dictionary = content_db.get_rideable_codex(ride_id)
		_check(not ride_entry.is_empty(), "rideable codex record exists: %s" % ride_id)
		_check(not String(ride_entry.get("display_name", "")).is_empty(),
			"rideable codex record is named: %s" % ride_id)
		_check(not String(ride_entry.get("blurb", "")).is_empty(),
			"rideable codex record has a blurb: %s" % ride_id)
		_check(UIIcons.has_icon(StringName(ride_entry.get("icon", &""))),
			"rideable codex icon resolves: %s" % ride_id)
		_check(not String(ride_entry.get("kind", "")).is_empty(), "rideable codex kind authored: %s" % ride_id)
		_check(String(ride_entry.get("stash_table", "")) == "vehicle_stash",
			"rideable codex stash table authored: %s" % ride_id)
	_check(content_db.get_poi_codex_entries().size() == 7, "POI codex enumerates all 7 records")
	_check(content_db.get_rideable_codex_entries().size() == 5, "rideable codex enumerates all 5 records")

	for planet_id in [&"meridian_9", &"cinder_4", &"thalassa_2", &"frost_9", &"nyx_12"]:
		var planet: Dictionary = content_db.get_planet(planet_id)
		_check(not planet.is_empty(), "planet exists: %s" % planet_id)
		_check((planet.get("biome_names", []) as Array).size() == 3, "planet authors 3 biomes: %s" % planet_id)
		_check((planet.get("weather_pool", []) as Array).size() >= 4, "planet has 4+ weather states: %s" % planet_id)
		_check(not (planet.get("dungeon_themes", []) as Array).is_empty(), "planet has dungeon themes: %s" % planet_id)
		_check(not (planet.get("fluid", {}) as Dictionary).is_empty(), "planet declares fluid config: %s" % planet_id)
		_check(planet.get("sky", {}) is Dictionary and (planet.get("sky", {}) as Dictionary).size() == 4,
			"planet authors 4 sky keyframes: %s" % planet_id)
		_check(not String(planet.get("icon", "")).is_empty() and UIIcons.has_icon(planet.get("icon", &"")),
			"planet icon resolves: %s" % planet_id)
	_check(content_db.get_planet(&"frost_9").get("hazard", &"") == &"cold", "Frost-9 is a cold-hazard planet")
	_check(content_db.get_planet(&"nyx_12").get("hazard", &"") == &"rift", "Nyx-12 is a rift-hazard planet")
	var frost_fluid: Dictionary = content_db.get_planet(&"frost_9").get("fluid", {})
	_check(bool(frost_fluid.get("water", false)) and not bool(frost_fluid.get("lava", false)),
		"Frost-9 carries water basins and no lava")
	var nyx_fluid: Dictionary = content_db.get_planet(&"nyx_12").get("fluid", {})
	_check(bool(nyx_fluid.get("lava", false)) and not bool(nyx_fluid.get("water", false)),
		"Nyx-12 carries lava basins and no water")
	_check(&"ion_tempest" in content_db.get_planet(&"meridian_9").get("weather_pool", []),
		"Meridian-9 weather pool includes Ion Tempest")
	_check(&"meteor_shower" in content_db.get_planet(&"cinder_4").get("weather_pool", []),
		"Cinder-4 weather pool includes Meteor Shower")
	_check(&"toxic_squall" in content_db.get_planet(&"thalassa_2").get("weather_pool", []),
		"Thalassa-2 weather pool includes Toxic Squall")

	# --- expansion weather ----------------------------------------------------
	var new_weather_ids: Array[StringName] = [
		&"ion_tempest", &"meteor_shower", &"toxic_squall", &"glacier_front", &"void_whiteout", &"rift_cyclone"
	]
	for weather_id in new_weather_ids:
		var weather: Dictionary = content_db.get_weather_def(weather_id)
		_check(not weather.is_empty(), "new weather authored: %s" % weather_id)
		_check(not String(weather.get("display_name", "")).is_empty(), "weather has a name: %s" % weather_id)
		_check(weather.get("icon", &"") != &"" and UIIcons.has_icon(weather.get("icon", &"")),
			"weather icon resolves: %s" % weather_id)
		_check((weather.get("color", Color.TRANSPARENT) as Color).a > 0.0, "weather has a colour: %s" % weather_id)
		_check(float(weather.get("fog_mult", 0.0)) > 1.0, "weather thickens fog: %s" % weather_id)
		_check(float(weather.get("vision_mult", 0.0)) > 0.0 and float(weather.get("vision_mult", 1.0)) < 1.0,
			"weather cuts enemy vision: %s" % weather_id)
		_check(float(weather.get("move_mult", 1.0)) > 0.0 and float(weather.get("move_mult", 1.0)) <= 1.0,
			"weather declares a movement multiplier: %s" % weather_id)
		_check((weather.get("dwell", []) as Array).size() == 2, "weather declares a dwell window: %s" % weather_id)
		_check(weather.get("particle", &"") != &"", "weather declares a particle mode: %s" % weather_id)
	_check(content_db.get_all_weather_defs().size() == 18, "all 18 weather defs are exposed to map presets")
	for preset in content_db.get_map_presets():
		var planet_id := StringName(preset.get("planet_id", &""))
		_check(not content_db.get_planet(planet_id).is_empty(), "map preset has a valid planet: %s" % preset.get("id", "?"))
		_check(not String(preset.get("display_name", "")).is_empty(), "map preset has a name: %s" % preset.get("id", "?"))
		var enriched: Dictionary = content_db.get_map_preset(StringName(preset.get("id", &"")))
		_check(enriched.has("planet") and enriched.has("weather_defs") and enriched.has("fluid"),
			"map preset enriches planet/weather/fluid: %s" % preset.get("id", "?"))
		_check((enriched.get("weather_defs", []) as Array).size() == 18,
			"enriched preset exposes all 18 weather defs: %s" % preset.get("id", "?"))
		_check(not (enriched.get("weather_pool", []) as Array).is_empty(),
			"enriched preset keeps a map/planet weather pool: %s" % preset.get("id", "?"))
		for weather_id in enriched.get("weather_pool", []):
			_check(not content_db.get_weather_def(StringName(weather_id)).is_empty(),
				"preset weather id resolves: %s/%s" % [preset.get("id", "?"), weather_id])
		_check(enriched.has("environment") and enriched.get("environment") is Dictionary,
			"preset carries an environment override slot: %s" % preset.get("id", "?"))
		_check(not (enriched.get("fluid", {}) as Dictionary).is_empty(),
			"preset carries merged fluid config: %s" % preset.get("id", "?"))
	for preset_id in [&"glacier_shelf", &"white_expanse", &"null_steppe", &"echo_basin"]:
		var expansion_preset: Dictionary = content_db.get_map_preset(preset_id)
		_check(not expansion_preset.is_empty(), "new map preset exists: %s" % preset_id)
		_check(int(expansion_preset.get("world_seed_salt", 0)) > 0, "new map preset has a seed salt: %s" % preset_id)
		_check(int(expansion_preset.get("extra_pois", 0)) > 0, "new map preset adds POIs: %s" % preset_id)
		_check(not String(expansion_preset.get("subtitle", "")).is_empty(), "new map preset has a subtitle: %s" % preset_id)
		_check((expansion_preset.get("environment", {}) as Dictionary).size() > 0,
			"new map preset authors an environment override: %s" % preset_id)
	_check(int(content_db.get_map_preset(&"glacier_shelf").get("biome_index", -1)) == 0,
		"Glacier Shelf emphasizes biome 0")
	_check(int(content_db.get_map_preset(&"null_steppe").get("biome_index", -1)) == 0,
		"Null Steppe emphasizes biome 0")
	for contract in content_db.contracts.values():
		_check(not String(contract.display_name).is_empty(), "contract has a name: %s" % contract.id)
		_check(contract.icon != &"" and contract.color.a > 0.0, "contract carries icon/colour: %s" % contract.id)
		if contract.is_staged():
			_check(contract.stages.size() >= 2, "staged contract has 2+ stages: %s" % contract.id)
			for stage in contract.stages:
				_check(stage is Dictionary and int(stage.get("count", 0)) >= 1, "stage has a count: %s" % contract.id)
	for contract_id in [&"black_box", &"beacon_hunt", &"whiteout_run", &"sovereign_hunt"]:
		var expansion_contract = content_db.get_contract(contract_id)
		_check(expansion_contract != null, "new contract exists: %s" % contract_id)
		if expansion_contract != null:
			_check(expansion_contract.icon != &"" and expansion_contract.color.a > 0.0,
				"new contract carries icon/colour: %s" % contract_id)
	_check(content_db.get_contract(&"black_box") != null and not content_db.get_contract(&"black_box").is_staged(),
		"Black Box Recovery is a classic contract")
	_check(content_db.get_contract(&"sovereign_hunt") != null and content_db.get_contract(&"sovereign_hunt").is_staged()
		and content_db.get_contract(&"sovereign_hunt").stages.size() == 3,
		"Sovereign Hunt is a three-stage operation")
	for difficulty_id in [&"patrol", &"contact", &"breach", &"collapse"]:
		var difficulty: Dictionary = content_db.get_difficulty(difficulty_id)
		_check(not difficulty.is_empty(), "difficulty exists: %s" % difficulty_id)
		_check(float(difficulty.get("reward", 0.0)) >= 1.0, "difficulty reward >= 1.0: %s" % difficulty_id)
		_check(float(difficulty.get("density", 0.0)) >= 1.0, "difficulty density >= 1.0: %s" % difficulty_id)
		_check(float(difficulty.get("density", 0.0)) >= 1.35, "difficulty is harder than the old baseline: %s" % difficulty_id)
		_check(int(difficulty.get("mission_sites", 0)) >= 3, "difficulty has 3+ mission sites: %s" % difficulty_id)
		_check(int(difficulty.get("side_caches", 0)) >= 4, "difficulty has 4+ side caches: %s" % difficulty_id)
		_check(int(difficulty.get("max_hostiles", 0)) >= 56, "difficulty raises the hostile budget: %s" % difficulty_id)
		_check(float(difficulty.get("enemy_health_mult", 1.0)) > 1.0, "difficulty scales enemy health: %s" % difficulty_id)
		_check(float(difficulty.get("storm_fraction", 0.0)) > 0.4 and float(difficulty.get("storm_fraction", 1.0)) < 0.8, "difficulty sets a sane storm start: %s" % difficulty_id)
		var preset_id := StringName(difficulty.get("map_preset", &""))
		var preset: Dictionary = content_db.get_map_preset(preset_id)
		_check(not preset.is_empty(), "difficulty maps to a map preset: %s" % difficulty_id)
		_check(not String(preset.get("display_name", "")).is_empty(), "map preset has a name: %s" % preset_id)
		_check(int(preset.get("extra_pois", 0)) >= 0, "map preset declares extra POIs: %s" % preset_id)
	_check(String(content_db.get_difficulty_for_threat(3).get("id", "")) == "breach", "threat 3 resolves to Breach")
	for enemy_id in [&"ashen_sapper", &"ashen_hound", &"bloom_lasher", &"bloom_seeder", &"choir_wisp", &"choir_weaver", &"ashen_warlord", &"bloom_hydra", &"choir_herald", &"rift_colossus",
			&"cinder_husk", &"magma_brute", &"brine_lurker", &"reef_stalker", &"tide_sentinel", &"void_wisp", &"caldera_warlord", &"abyss_matriarch", &"cinder_titan", &"leviathan",
			&"ashen_ironjaw", &"bloom_thornmatron", &"choir_signal_warden", &"hollow_sovereign"]:
		_check(content_db.get_enemy(enemy_id) != null, "new enemy exists: %s" % enemy_id)
	var elite_count: int = content_db.get_elite_enemies().size()
	var boss_count: int = content_db.get_boss_enemies().size()
	var base_count := 0
	for enemy in content_db.enemies.values():
		if not enemy.elite and not enemy.boss:
			base_count += 1
	_check(base_count == 20 and elite_count == 11 and boss_count == 6,
		"enemy mix is 20 base / 11 elite / 6 boss (got %d/%d/%d)" % [base_count, elite_count, boss_count])
	for elite_id in [&"ashen_ironjaw", &"bloom_thornmatron", &"choir_signal_warden"]:
		var elite = content_db.get_enemy(elite_id)
		_check(elite != null and elite.elite and not elite.boss, "expansion elite is elite-only: %s" % elite_id)
	var sovereign = content_db.get_enemy(&"hollow_sovereign")
	_check(sovereign != null and sovereign.boss and sovereign.boss_phases == 3,
		"Hollow Sovereign is a three-phase boss")
	_check(sovereign != null and sovereign.faction == &"choir", "Hollow Sovereign is a Choir boss")
	var sapper = content_db.get_enemy(&"ashen_sapper")
	_check(sapper != null and "volatile_death" in sapper.behavior_flags, "Ashen Sapper has volatile death")
	_check(content_db.get_enemy(&"cinder_husk").habitat == &"lava", "Cinder Husk is a lava native")
	_check(content_db.get_enemy(&"leviathan").habitat == &"water", "Leviathan is a water native")
	_check(content_db.get_weapon(&"ember_thrower") != null, "Ember Thrower authored")
	_check(content_db.get_ability(&"ember_ward") != null, "Ember Ward authored")
	_check(content_db.get_perk(&"perk_waterborn") != null, "Waterborn perk authored")
	_check(StatKeys.HAZARD_RESIST != &"" and StatKeys.SWIM_SPEED != &"", "hazard/swim stat keys exist")

	# --- game modes -----------------------------------------------------------
	var mode_ids: Array[StringName] = []
	for mode in content_db.get_game_modes():
		mode_ids.append(StringName(mode.get("id", &"")))
		_check(bool(mode.get("selectable", false)), "game mode is selectable: %s" % mode.get("id", "?"))
		_check(not String(mode.get("display_name", "")).is_empty(), "game mode has a name: %s" % mode.get("id", "?"))
		_check(not String(mode.get("tag", "")).is_empty(), "game mode has a tag: %s" % mode.get("id", "?"))
		_check(not String(mode.get("clock", "")).is_empty(), "game mode has a clock: %s" % mode.get("id", "?"))
		_check(float(mode.get("run_duration", 0.0)) > 0.0, "game mode declares a duration: %s" % mode.get("id", "?"))
		_check(mode.get("icon", &"") != &"" and UIIcons.has_icon(mode.get("icon", &"")),
			"game mode icon resolves: %s" % mode.get("id", "?"))
		_check((mode.get("color", Color.TRANSPARENT) as Color).a > 0.0, "game mode has a colour: %s" % mode.get("id", "?"))
	_check(mode_ids == [&"normal", &"quick", &"blackout", &"gauntlet", &"onslaught"],
		"game modes are Normal/Quick/Blackout/Gauntlet/Onslaught")
	_check(content_db.get_selectable_game_mode_ids().size() == 5, "all five game modes are selectable")
	_check(content_db.get_mode_clock(&"quick") == "09:00", "Quick advertises its 09:00 clock")
	_check(content_db.get_mode_clock(&"gauntlet") == "14:00", "Gauntlet advertises its 14:00 clock")

	# --- world events ---------------------------------------------------------
	var world_event_ids: Dictionary = {}
	var new_event_ids: Array[StringName] = [
		&"meteor_strike", &"rift_cyclone", &"toxic_drift", &"whiteout",
		&"scavenger_convoy", &"bounty_broker", &"distress_beacon", &"collapse_tremor",
	]
	for event in content_db.get_world_events():
		var event_id: StringName = event.get("id", &"")
		_check(event_id != &"" and not world_event_ids.has(event_id), "world event id is unique: %s" % event_id)
		world_event_ids[event_id] = true
		_check(not String(event.get("title", "")).is_empty(), "world event has a title: %s" % event_id)
		_check(not String(event.get("text", "")).is_empty(), "world event has text: %s" % event_id)
		_check(event.get("icon", &"") != &"" and UIIcons.has_icon(event.get("icon", &"")),
			"world event icon resolves: %s" % event_id)
		_check((event.get("color", Color.TRANSPARENT) as Color).a > 0.0, "world event has a colour: %s" % event_id)
		_check(int(event.get("weight", 0)) >= 1, "world event has a positive weight: %s" % event_id)
	for event_id in new_event_ids:
		_check(world_event_ids.has(event_id), "new world event authored: %s" % event_id)

	# --- quick mode clock and run identity ------------------------------------
	run_state.start_run(&"salvage_sweep", 999, 1, [], &"patrol", &"quick")
	_check(String(run_state.mode_id) == "quick", "quick mode is stored on the run")
	_check(is_equal_approx(float(run_state.time_scale), 2.0), "quick mode doubles the run clock")
	_check(is_equal_approx(float(run_state.get_run_duration()), 1080.0), "quick mode keeps the 18-minute run duration")
	_check(run_state.get_mode_clock() == "09:00", "quick mode reports the 09:00 clock")
	_check(run_state.get_mode_tag() == "2x CLOCK", "quick mode carries the 2x CLOCK tag")
	_check(is_equal_approx(float(run_state.get_difficulty_density()), 1.35), "quick mode leaves density unchanged")
	_check(is_equal_approx(float(run_state.get_difficulty_elite_bonus()), 0.04), "quick mode leaves elite odds unchanged")
	_check(is_equal_approx(float(run_state.get_difficulty_reward_mult()), 1.0), "quick mode leaves rewards unchanged")
	_check(is_equal_approx(float(run_state.get_storm_start_time()), 0.667 * 1080.0), "quick storm follows the difficulty fraction")
	_check(is_equal_approx(float(run_state.time_of_day), 0.66), "quick mode keeps the preset start time")
	_check(String(run_state.map_preset_id) == "verdant_verge", "patrol maps to the Verdant Verge preset")
	var quick_elapsed_before := float(run_state.elapsed)
	run_state.tick(1.0)
	_check(is_equal_approx(float(run_state.elapsed) - quick_elapsed_before, 2.0), "one real second advances two run seconds")
	_check(is_equal_approx(float(run_state.get_time_left()), 1080.0 - 2.0), "quick clock consumes the run timer at 2x")
	_check(is_equal_approx(float(run_state.get_exfil_hold_total()), 75.0), "exfil hold uses the run game clock")
	run_state.end_run(false, "quick mode test")

	# --- mode math ------------------------------------------------------------
	run_state.start_run(&"salvage_sweep", 5001, 1, [], &"patrol", &"blackout")
	_check(is_equal_approx(float(run_state.get_run_duration()), 1080.0), "blackout uses the standard run duration")
	_check(is_equal_approx(float(run_state.time_scale), 1.0), "blackout runs at 1x")
	_check(is_equal_approx(float(run_state.get_mode_start_time()), 0.94), "blackout authors start_time 0.94")
	_check(is_equal_approx(float(run_state.time_of_day), 0.94), "blackout inserts the run at night")
	_check(is_equal_approx(float(run_state.get_difficulty_reward_mult()), 1.15), "blackout adds a 1.15x reward")
	_check(is_equal_approx(float(run_state.get_difficulty_loot_luck()), 0.10), "blackout adds +10% loot luck")
	_check(run_state.get_mode_tag() == "NIGHT INSERTION", "blackout carries the NIGHT INSERTION tag")
	run_state.end_run(false, "blackout mode test")

	run_state.start_run(&"salvage_sweep", 5002, 1, [], &"patrol", &"gauntlet")
	_check(is_equal_approx(float(run_state.get_run_duration()), 840.0), "gauntlet uses the 840-second run clock")
	_check(is_equal_approx(float(run_state.get_storm_start_time()), 0.45 * 840.0), "gauntlet storm starts at 45% of its clock")
	_check(is_equal_approx(float(run_state.get_difficulty_density()), 1.35 * 1.2), "gauntlet raises density by 1.2x")
	_check(is_equal_approx(float(run_state.get_difficulty_elite_bonus()), 0.04 + 0.10), "gauntlet adds +10% elites")
	_check(is_equal_approx(float(run_state.get_difficulty_reward_mult()), 1.35), "gauntlet pays 1.35x")
	_check(int(run_state.get_difficulty_max_hostiles()) == 64, "gauntlet adds 8 to the hostile budget")
	_check(run_state.get_mode_clock() == "14:00", "gauntlet reports the 14:00 clock")
	_check(run_state.get_mode_tag() == "EARLY COLLAPSE", "gauntlet carries the EARLY COLLAPSE tag")
	run_state.end_run(false, "gauntlet mode test")

	run_state.start_run(&"salvage_sweep", 5003, 1, [], &"patrol", &"onslaught")
	_check(is_equal_approx(float(run_state.get_run_duration()), 1080.0), "onslaught uses the standard run duration")
	_check(is_equal_approx(float(run_state.get_difficulty_density()), 1.35 * 1.35), "onslaught raises density by 1.35x")
	_check(is_equal_approx(float(run_state.get_difficulty_elite_bonus()), 0.04 + 0.20), "onslaught adds +20% elites")
	_check(is_equal_approx(float(run_state.get_difficulty_reward_mult()), 1.5), "onslaught pays 1.5x")
	_check(int(run_state.get_difficulty_max_hostiles()) == 68, "onslaught adds 12 to the hostile budget")
	_check(is_equal_approx(float(run_state.get_difficulty_loot_luck()), 0.05), "onslaught adds +5% loot luck")
	_check(run_state.get_mode_tag() == "ELITE SURGE", "onslaught carries the ELITE SURGE tag")
	run_state.end_run(false, "onslaught mode test")

	run_state.start_run(&"salvage_sweep", 5004, 1, [], &"patrol", &"not_a_mode")
	_check(String(run_state.mode_id) == "normal", "unknown modes fall back to Normal")
	_check(is_equal_approx(float(run_state.get_run_duration()), 1080.0), "normal mode uses the 18-minute run clock")
	_check(run_state.get_mode_tag() == "STANDARD", "normal mode carries the STANDARD tag")
	_check(is_equal_approx(float(run_state.get_mode_start_time()), -1.0), "normal mode lets the map choose its start time")
	_check(String(run_state.get_mode_start_weather()) == "", "normal mode has no forced starting weather")
	run_state.end_run(false, "normal mode test")

	# --- map override + tutorial mode ----------------------------------------
	run_state.start_run(&"salvage_sweep", 4242, 1, [], &"patrol", &"normal", &"cinder_caldera")
	_check(String(run_state.map_preset_id) == "cinder_caldera", "explicit map override reaches the run")
	_check(String(run_state.planet_id) == "cinder_4", "map override carries its planet")
	_check(run_state.get_planet_name() == "Cinder-4", "planet name resolves")
	run_state.end_run(false, "map override test")
	run_state.start_run(&"salvage_sweep", 4243, 1, [], &"patrol", &"tutorial")
	_check(run_state.is_tutorial(), "tutorial mode is stored on the run")
	_check(is_equal_approx(float(run_state.get_run_duration()), 1800.0), "tutorial uses a relaxed clock")
	_check(is_equal_approx(float(run_state.get_exfil_hold_total()), 12.0), "tutorial uses a short exfil hold")
	run_state.tick(30.0)
	_check(not run_state.storm_active, "tutorial never starts the Collapse")
	run_state.end_run(true, "tutorial mode test")
	_check(bool(run_state.get_result_preview().get("tutorial", false)), "tutorial result is flagged")

	# --- map validation on the breach run ------------------------------------
	run_state.start_run(&"salvage_sweep", 12345, 1, [], &"breach")
	_check(String(run_state.difficulty_id) == "breach", "run stores the Breach difficulty")
	_check(int(run_state.threat) == 3, "Breach raises the run threat to 3")
	_check(String(run_state.map_preset_id) == "glass_expanse", "Breach maps to the Glass Expanse preset")

	# --- weapon zoom ----------------------------------------------------------
	var ar_zoom := _weapon_zoom(content_db, &"lattice_ar")
	var dmr_zoom := _weapon_zoom(content_db, &"longview_dmr")
	var rail_zoom := _weapon_zoom(content_db, &"sable_rail")
	_check(ar_zoom > dmr_zoom and dmr_zoom > rail_zoom, "precision weapons zoom farther than the AR")
	_check(rail_zoom <= 0.35, "rail sniper reaches near-3x zoom")
	_check(dmr_zoom <= 0.55, "DMR reaches 2x zoom")

	# --- mechanic gate table --------------------------------------------------
	_check(not MechanicUnlocks.is_unlocked(&"slide", 1), "slide is locked at level 1")
	_check(MechanicUnlocks.is_unlocked(&"slide", 2), "slide unlocks at level 2")
	_check(not MechanicUnlocks.is_unlocked(&"grenade", 2), "grenade is locked at level 2")
	_check(MechanicUnlocks.is_unlocked(&"grenade", 3), "grenade unlocks at level 3")
	_check(not MechanicUnlocks.is_unlocked(&"squad_command", 3), "squad command is locked at level 3")
	_check(MechanicUnlocks.is_unlocked(&"squad_command", 4), "squad command unlocks at level 4")
	_check(MechanicUnlocks.is_unlocked(&"minimap", 1), "minimap is available at level 1")
	_check(MechanicUnlocks.is_unlocked(&"aim_zoom", 1), "ADS zoom is available at level 1")
	_check(MechanicUnlocks.is_unlocked(&"crouch", 1), "crouch is available at level 1")

	# --- input bindings -------------------------------------------------------
	_check(_action_has_key(&"crouch", KEY_CTRL), "crouch is bound to Ctrl")
	_check(_action_has_key(&"crouch_alt", KEY_C), "crouch_alt is bound to C")
	_check(_action_has_key(&"weapon_3", KEY_3), "weapon slot 3 is bound to 3")
	_check(_action_has_key(&"weapon_4", KEY_4), "weapon slot 4 is bound to 4")
	_check(_action_has_key(&"inventory", KEY_I), "inventory is bound to I")
	_check(_action_has_key(&"call_exfil", KEY_H), "call exfil is bound to H")
	var app = root.get_node_or_null("/root/App")
	_check(app != null, "App autoload available")
	if app != null:
		_check(String(app.get_action_binding_text(&"inventory", "")) == "I", "App reports the live inventory binding")
		_check(app.find_binding_conflict(_key_event(KEY_E), &"inventory") != &"", "duplicate bindings are detected")
		var rebound: bool = app.rebind_action(&"inventory", _key_event(KEY_P))
		_check(rebound, "inventory can be rebound")
		_check(String(app.get_action_binding_text(&"inventory", "")) == "P", "rebinding updates the live input map")
		app.rebind_action(&"inventory", _key_event(KEY_I))

		# --- display settings ------------------------------------------------
		var resolution_options: Array = app.get_resolution_options()
		_check(resolution_options.size() >= 5, "App exposes the standard resolution list")
		var resolution_values: Array[String] = []
		for option in resolution_options:
			_check(option is Dictionary and not String(option.get("label", "")).is_empty()
				and not String(option.get("value", "")).is_empty(), "resolution option has label/value")
			resolution_values.append(String(option.get("value", "")))
		_check("1600x900" in resolution_values, "resolution list includes 1600x900")
		var window_modes: Array = app.get_window_mode_options()
		var window_mode_values: Array[String] = []
		for option in window_modes:
			window_mode_values.append(String(option.get("value", "")))
		_check(window_mode_values == ["windowed", "borderless", "fullscreen"], "window mode options are windowed/borderless/fullscreen")
		var aa_values: Array[String] = []
		for option in app.get_aa_options():
			aa_values.append(String(option.get("value", "")))
		_check(aa_values == ["off", "fxaa", "msaa2", "msaa4", "taa"], "anti-aliasing options are authored")
		var fps_values: Array[int] = []
		for option in app.get_fps_options():
			fps_values.append(int(option.get("value", -1)))
		_check(fps_values == [0, 30, 60, 120, 144], "frame-rate options are Unlimited/30/60/120/144")
		var display_summary := String(app.get_display_summary())
		_check(not display_summary.is_empty(), "App reports a display summary")
		if DisplayServer.get_name() == "headless":
			_check(display_summary == "Headless display", "headless display summary is explicit")
		_check(app.get_setting("window_mode") != null, "window_mode setting exists")
		_check(app.get_setting("resolution") != null, "resolution setting exists")
		_check(app.get_setting("render_scale") != null, "render_scale setting exists")
		_check(app.get_setting("anti_aliasing") != null, "anti_aliasing setting exists")
		_check(app.get_setting("fps_limit") != null, "fps_limit setting exists")
		var settings_backup: Dictionary = app.settings.duplicate(true)
		app.settings["window_mode"] = "fullscreen"
		app.settings["resolution"] = "1920x1080"
		app.settings["render_scale"] = 0.75
		app.settings["anti_aliasing"] = "taa"
		app.settings["fps_limit"] = 60
		app.settings["quality"] = "low"
		app.settings["vsync"] = false
		app.apply_display_settings()
		_check(Engine.max_fps == 60, "display settings apply the frame-rate cap")
		var root_viewport := app.get_viewport()
		_check(root_viewport != null and is_equal_approx(root_viewport.scaling_3d_scale, 0.75),
			"display settings apply the render scale")
		_check(root_viewport != null and root_viewport.use_taa, "display settings apply TAA")
		_check(root_viewport == null or root_viewport.positional_shadow_atlas_size == 1024,
			"low quality preset lowers the shadow atlas")
		app.settings = settings_backup.duplicate(true)
		app.apply_display_settings()
		_check(Engine.max_fps == int(settings_backup.get("fps_limit", 0)), "frame-rate cap restores after the test")
		_check(root_viewport == null or is_equal_approx(root_viewport.scaling_3d_scale,
			clampf(float(settings_backup.get("render_scale", 1.0)), 0.5, 1.0)), "render scale restores after the test")
		_check(root_viewport == null or root_viewport.use_taa == (String(settings_backup.get("anti_aliasing", "fxaa")) == "taa"),
			"anti-aliasing restores after the test")

	# --- viewmodels (all styles + issued knife) -------------------------------
	var builder_script: Script = load("res://features/weapons/weapon_model_builder.gd")
	_check(builder_script != null, "WeaponModelBuilder script available")
	if builder_script != null:
		var built := 0
		for weapon in content_db.weapons.values():
			var stats := {"style": String(weapon.style), "color": weapon.color, "accent": weapon.accent}
			var model = builder_script.call("build", stats)
			if model is Node3D:
				built += 1
				model.free()
		_check(built == content_db.weapons.size(), "all weapon viewmodels build")
		var knife_model = builder_script.call("build", {"style": "knife", "color": Color("d9e4e3"), "accent": Color("62e6c3")})
		_check(knife_model is Node3D, "knife viewmodel builds")
		if knife_model is Node3D:
			knife_model.free()

	# --- starter kit / four-slot default --------------------------------------
	var factory_script: Script = load("res://features/loot/item_factory.gd")
	_check(factory_script != null, "ItemFactory script available")
	var kit_backup: Dictionary = profile.data.duplicate(true)
	profile.data = profile._defaults()
	profile._make_starter_kit()
	profile._ensure_valid()
	_check(StatKeys.SLOT_PRIMARY_2 in StatKeys.EQUIP_SLOTS, "equip slots include primary 2")
	_check(int(profile.get_equipped_uid(&"primary_2")) > 0, "starter kit equips a second primary")
	if factory_script != null:
		var starter_primary: Dictionary = factory_script.call("describe", profile.get_equipped_item(&"primary"))
		var starter_second: Dictionary = factory_script.call("describe", profile.get_equipped_item(&"primary_2"))
		var starter_sidearm: Dictionary = factory_script.call("describe", profile.get_equipped_item(&"sidearm"))
		_check(String(starter_primary.get("base_id", "")) == "sable_rail", "default primary is the Sable Rail sniper")
		_check(String(starter_second.get("base_id", "")) == "lattice_ar", "default second primary is the Lattice AR")
		_check(String(starter_sidearm.get("base_id", "")) == "sidewinder", "default sidearm is the Sidewinder")
		var first_uid: int = int(profile.get_equipped_uid(&"primary"))
		var second_uid: int = int(profile.get_equipped_uid(&"primary_2"))
		_check(profile.equip_item(first_uid, &"primary_2"), "a primary can be equipped into primary 2")
		_check(profile.get_equipped_uid(&"primary_2") == first_uid, "primary 2 receives the moved weapon")
		_check(profile.get_equipped_uid(&"primary") == second_uid, "moving between primary slots swaps the displaced weapon")
		_check(not profile.equip_item(first_uid, &"sidearm"), "a primary weapon cannot occupy the sidearm slot")

	# Legacy v2 profile: starter rifle gets promoted, second primary is filled.
	var legacy: Dictionary = profile._defaults()
	legacy["version"] = 2
	var legacy_rng := RandomNumberGenerator.new()
	legacy_rng.seed = 77
	if factory_script != null:
		var legacy_ar: Dictionary = factory_script.call("generate_weapon", legacy_rng, &"lattice_ar", 1, 1, 101)
		var legacy_pistol: Dictionary = factory_script.call("generate_weapon", legacy_rng, &"sidewinder", 0, 1, 102)
		legacy["inventory"] = [legacy_ar, legacy_pistol]
		legacy["equipped"] = {"primary": 101, "sidearm": 102, "helmet": 0, "chest": 0, "legs": 0, "cloak": 0, "charm": 0}
		legacy["next_uid"] = 103
		profile.data = legacy
		profile._migrate_save(2)
		profile._ensure_valid()
		var migrated_primary: Dictionary = factory_script.call("describe", profile.get_equipped_item(&"primary"))
		var migrated_second: Dictionary = factory_script.call("describe", profile.get_equipped_item(&"primary_2"))
		_check(String(migrated_primary.get("base_id", "")) == "sable_rail", "v2 save migrates the starter rifle to the sniper")
		_check(String(migrated_second.get("base_id", "")) == "lattice_ar", "v2 save receives a second primary")
	profile.data = kit_backup

	# --- profile level / points / perk gates ---------------------------------
	_profile_backup = profile.data.duplicate(true)
	profile.data["level"] = 1
	profile.data["xp"] = 0
	profile.data["skill_points"] = 4
	profile.data["attribute_points"] = 0
	profile.data["skill_ranks"] = {}
	var level_events: Array[int] = []
	var level_listener := func(new_level: int) -> void: level_events.append(new_level)
	profile.level_up.connect(level_listener)
	var needed: int = profile.get_xp_for_next_level()
	var gained: int = profile.add_xp(needed)
	_check(gained == 1 and level_events.size() == 1, "crossing an XP threshold raises one level")
	_check(profile.get_level() == 2, "profile reaches level 2")
	_check(profile.get_skill_points() == 5, "each level grants 1 skill point")
	_check(profile.get_attribute_points() == 2, "each level grants 2 attribute points")
	var tier1_perk = null
	var tier2_perk = null
	for perk in content_db.get_perks_for_discipline(profile.get_discipline()):
		if perk.tier == 1 and tier1_perk == null:
			tier1_perk = perk
		elif perk.tier == 2:
			tier2_perk = perk
	_check(tier1_perk != null and tier2_perk != null, "discipline perks available for level gate check")
	if tier1_perk != null and tier2_perk != null:
		profile.data["skill_ranks"] = {String(tier1_perk.id): 1}
		_check(not profile.can_buy_perk(tier2_perk.id), "tier 2 perk is level-gated at level 2")
		profile.data["level"] = 5
		_check(profile.can_buy_perk(tier2_perk.id), "tier 2 perk unlocks at level 4+")
	profile.level_up.disconnect(level_listener)
	profile.data = _profile_backup.duplicate(true)

	# --- outpost layout v2 and save v5 ---------------------------------------
	var layout_backup: Dictionary = profile.data.duplicate(true)
	var profile_constants: Dictionary = profile.get_script().get_script_constant_map()
	_check(int(profile_constants.get("SAVE_VERSION", 0)) == 5, "save schema is version 5")
	_check(int(profile_constants.get("BASE_LAYOUT_VERSION", 0)) == 2, "authored outpost layout is version 2")
	var authored_layout: Dictionary = profile_constants.get("BASE_LAYOUT", {})
	_check(authored_layout.size() == 8, "authored layout places all 8 modules")
	var layout_errors: PackedStringArray = profile.validate_base_layout(profile._layout_payload())
	_check(layout_errors.is_empty(), "authored layout validates cleanly")
	var base_layout: Dictionary = profile.get_base_layout()
	_check(base_layout.size() == 8, "profile exposes all 8 module positions")
	var board := Rect2i(0, 0, 8, 8)
	var module_rects: Dictionary = {}
	var layout_in_bounds := true
	for module_id in base_layout.keys():
		var module = content_db.get_base_module(module_id)
		_check(module != null, "layout module resolves: %s" % module_id)
		var footprint: Vector2i = module.footprint if module != null else Vector2i(2, 2)
		var position: Vector2i = base_layout[module_id]
		var rect := Rect2i(position, footprint)
		layout_in_bounds = layout_in_bounds and board.encloses(rect)
		_check(not module_rects.has(module_id), "layout module appears once: %s" % module_id)
		module_rects[module_id] = rect
	_check(layout_in_bounds, "every authored footprint stays inside the 8x8 board")
	var overlap := false
	var module_keys: Array = module_rects.keys()
	for i in module_keys.size():
		for j in range(i + 1, module_keys.size()):
			if (module_rects[module_keys[i]] as Rect2i).intersects(module_rects[module_keys[j]] as Rect2i):
				overlap = true
	_check(not overlap, "authored module footprints do not overlap")
	var out_of_bounds: Dictionary = profile._layout_payload()
	out_of_bounds["signal_array"] = [7, 7]
	_check(not profile.validate_base_layout(out_of_bounds).is_empty(), "out-of-bounds layouts are rejected")
	var overlapping: Dictionary = profile._layout_payload()
	overlapping["armory"] = [0, 0]
	_check(not profile.validate_base_layout(overlapping).is_empty(), "overlapping layouts are rejected")
	var missing_module: Dictionary = profile._layout_payload()
	missing_module.erase("reactor")
	_check(not profile.validate_base_layout(missing_module).is_empty(), "layouts missing a module are rejected")

	# A v4 save with a stale layout must reset only the layout payload.
	var stale: Dictionary = profile._defaults()
	stale["version"] = 4
	stale["base_layout_version"] = 1
	stale["base_layout"] = {
		"command_nexus": [0, 0], "foundry": [0, 0], "armory": [0, 0], "infirmary": [0, 0],
		"barracks": [0, 0], "drift_den": [0, 0], "reactor": [0, 0], "signal_array": [7, 7],
	}
	stale["base_modules"] = {
		"command_nexus": 3, "foundry": 2, "armory": 1, "infirmary": 1,
		"barracks": 1, "drift_den": 0, "reactor": 1, "signal_array": 0,
	}
	stale["salvage"] = 777
	stale["cores"] = 9
	stale["inventory"] = layout_backup.get("inventory", []).duplicate(true)
	profile.data = stale
	profile._migrate_save(4)
	profile._ensure_valid()
	_check(int(profile.data.get("version", 0)) == 5, "v4 save migrates to schema v5")
	_check(int(profile.data.get("base_layout_version", 0)) == 2, "v4 save receives layout version 2")
	_check(profile.validate_base_layout(profile.get_base_layout()).is_empty(), "migrated layout validates cleanly")
	_check(profile.get_base_tier(&"foundry") == 2 and profile.get_base_tier(&"command_nexus") == 3,
		"v4->v5 migration preserves module tiers")
	_check(profile.get_salvage() == 777 and profile.get_cores() == 9,
		"v4->v5 migration preserves currency")
	_check(profile.get_inventory().size() == (stale.get("inventory", []) as Array).size(),
		"v4->v5 migration preserves inventory")
	_check(profile.get_base_layout().get(&"signal_array", Vector2i(-1, -1)) != Vector2i(7, 7),
		"v4->v5 migration discards the stale layout")
	profile.data["base_layout"] = {"broken": true}
	_check(profile.get_base_layout().size() == 8, "invalid layout payload falls back to the authored plan")
	profile.data = layout_backup.duplicate(true)
	profile._ensure_valid()

	# --- mode validation on the profile --------------------------------------
	var mode_backup: Dictionary = profile.data.duplicate(true)
	for mode_id in [&"normal", &"quick", &"blackout", &"gauntlet", &"onslaught"]:
		_check(profile.set_last_mode(mode_id), "profile accepts selectable mode: %s" % mode_id)
		_check(profile.get_last_mode() == mode_id, "profile stores last mode: %s" % mode_id)
	_check(not profile.set_last_mode(&"tutorial"), "tutorial is never persisted as last mode")
	_check(not profile.set_last_mode(&"bogus_mode"), "unknown modes are rejected by the profile")
	profile.data["last_mode"] = "bogus_mode"
	profile._ensure_valid()
	_check(profile.get_last_mode() == &"normal", "invalid last mode falls back to Normal")
	profile.data = mode_backup.duplicate(true)

	# --- kill XP, difficulty rewards and pressure ----------------------------
	run_state.start_run(&"salvage_sweep", 12345, 1, [], &"breach")
	_check(String(run_state.difficulty_id) == "breach", "run stores the Breach difficulty")
	_check(int(run_state.threat) == 3, "Breach raises the run threat to 3")
	_check(String(run_state.map_preset_id) == "glass_expanse", "Breach maps to the Glass Expanse preset")
	run_state.record_kill(false, 20)
	_check(int(run_state.combat_xp) == 20, "kills add authored enemy XP to the run")
	run_state.elapsed = 900.0
	_check(run_state.get_pressure() > 0.3, "late-run pressure rises past 30%")
	_check(run_state.get_late_stage() >= 1, "late-run stage advances")
	run_state.end_run(true, "progression test")
	_check(run_state.active == false, "run ends after the result")
	_check(not run_state.difficulty.is_empty(), "difficulty survives the run")
	_check(run_state.get_difficulty_reward_mult() >= 1.3, "Breach reward multiplier is >= 1.3")
	_check(run_state.get_difficulty_mission_sites() >= 5, "Breach requests five mission sites")
	_check(run_state.get_difficulty_side_caches() >= 8, "Breach requests eight side caches")
	_check(run_state.get_difficulty_max_hostiles() >= 72, "Breach raises the hostile budget")

	# Result math is easier to verify with a fresh short run captured up front.
	var captured_result: Array[Dictionary] = []
	var listener := func(payload: Dictionary) -> void: captured_result.append(payload)
	var event_bus = root.get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.deployment_ended.connect(listener)
	run_state.start_run(&"salvage_sweep", 2222, 1, [], &"breach")
	run_state.record_kill(false, 20)
	var loot_factory: Script = load("res://features/loot/item_factory.gd")
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = 5
	var loot_item: Dictionary = loot_factory.call("generate_weapon", loot_rng, &"wisp_smg", 1, 1, 6001)
	run_state.add_loot_item(loot_item)
	run_state.end_run(true, "progression test")
	if event_bus != null:
		event_bus.deployment_ended.disconnect(listener)
	_check(not captured_result.is_empty(), "run result emitted")
	if not captured_result.is_empty():
		var payload: Dictionary = captured_result[0]
		_check(String(payload.get("difficulty_id", "")) == "breach", "result carries difficulty id")
		_check(String(payload.get("mode_id", "")) == "normal", "result carries the game mode")
		_check(String(payload.get("map_name", "")).length() > 0, "result carries the map name")
		_check(String(payload.get("mode_clock", "")) == "18:00", "result carries the mode clock")
		_check(String(payload.get("mode_tag", "")) == "STANDARD", "result carries the mode tag")
		_check(is_equal_approx(float(payload.get("run_duration", 0.0)), 1080.0), "result carries the run duration")
		_check(is_equal_approx(float(payload.get("time_scale", 0.0)), 1.0), "normal runs report a 1x clock")
		_check(payload.has("real_elapsed"), "result carries real elapsed time")
		_check(payload.has("xp_breakdown"), "result carries XP breakdown")
		_check(int(payload.get("combat_xp", 0)) == 20, "result carries combat XP")
		_check(int(payload.get("item_count", -1)) == 1, "result carries the recovered item count")
		_check((payload.get("items", []) as Array).size() == 1, "result carries recovered items")
		var breakdown: Dictionary = payload.get("xp_breakdown", {})
		var expected_total := int(round(float(int(breakdown.get("contract", 0)) + 20 + int(breakdown.get("objectives", 0))) * float(breakdown.get("difficulty_mult", 1.0)) * float(breakdown.get("extraction_mult", 1.0))))
		_check(int(payload.get("xp", 0)) == expected_total, "result XP matches the breakdown math")

	_finish()


func _weapon_zoom(content_db: Node, weapon_id: StringName) -> float:
	var weapon = content_db.get_weapon(weapon_id)
	if weapon == null:
		return 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var factory_script: Script = load("res://features/loot/item_factory.gd")
	if factory_script == null:
		return 1.0
	var item: Dictionary = factory_script.call("generate_weapon", rng, weapon_id, 0, 1, 1)
	var stats: Dictionary = factory_script.call("weapon_runtime_stats", item)
	return float(stats.get("ads_zoom", 1.0))


func _key_event(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


func _action_has_key(action: StringName, keycode: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and int(event.physical_keycode) == keycode:
			return true
	return false


func _finish() -> void:
	print("[PROGRESSION-TEST] checks=%d failures=%d" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("[PROGRESSION-TEST] RESULT: PASS")
		quit(0)
	else:
		for failure in _failures:
			print("[PROGRESSION-TEST] Failure: ", failure)
		print("[PROGRESSION-TEST] RESULT: FAIL")
		quit(1)
