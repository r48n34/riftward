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
	_check(content_db.map_presets.size() == 4, "4 map presets authored")
	_check(content_db.enemies.size() == 23, "23 enemy entries authored")
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
	for enemy_id in [&"ashen_sapper", &"ashen_hound", &"bloom_lasher", &"bloom_seeder", &"choir_wisp", &"choir_weaver", &"ashen_warlord", &"bloom_hydra", &"choir_herald", &"rift_colossus"]:
		_check(content_db.get_enemy(enemy_id) != null, "new enemy exists: %s" % enemy_id)
	var sapper = content_db.get_enemy(&"ashen_sapper")
	_check(sapper != null and "volatile_death" in sapper.behavior_flags, "Ashen Sapper has volatile death")

	# --- quick mode clock and run identity ------------------------------------
	run_state.start_run(&"salvage_sweep", 999, 1, [], &"patrol", &"quick")
	_check(String(run_state.mode_id) == "quick", "quick mode is stored on the run")
	_check(is_equal_approx(float(run_state.time_scale), 2.0), "quick mode doubles the run clock")
	_check(String(run_state.map_preset_id) == "verdant_verge", "patrol maps to the Verdant Verge preset")
	var quick_elapsed_before := float(run_state.elapsed)
	run_state.tick(1.0)
	_check(is_equal_approx(float(run_state.elapsed) - quick_elapsed_before, 2.0), "one real second advances two run seconds")
	_check(is_equal_approx(float(run_state.get_time_left()), 1080.0 - 2.0), "quick clock consumes the run timer at 2x")
	_check(is_equal_approx(float(run_state.get_exfil_hold_total()), 75.0), "exfil hold uses the run game clock")
	run_state.end_run(false, "quick mode test")

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
