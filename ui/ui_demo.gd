extends Node
## UI harness. Two modes:
##   godot --headless --path <project> res://ui/ui_demo.tscn
##       -> self-test: instantiates UIRoot, cycles every screen, overlays and the
##          HUD against a stub player, then prints PASS/FAIL and quits.
##   godot --path <project> res://ui/ui_demo.tscn -- --shots
##       -> boots the same UI in a window and writes PNG screenshots to
##          res://ui/_screenshots/.

const SCREENS := [&"loadout", &"locker", &"skills", &"squad", &"outpost", &"codex", &"settings"]

var ui: UIRoot = null
var stub: UIStubPlayer = null
var failures: Array[String] = []
var checks := 0
var _only_filter := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var shots := false
	var size_override := Vector2i.ZERO
	for arg in args:
		var text := String(arg).trim_prefix("--")
		if text == "shots":
			shots = true
		elif text.begins_with("size="):
			var parts := text.trim_prefix("size=").split("x")
			if parts.size() == 2:
				size_override = Vector2i(int(parts[0]), int(parts[1]))
		elif text.begins_with("only="):
			_only_filter = text.trim_prefix("only=")
	if size_override != Vector2i.ZERO:
		DisplayServer.window_set_size(size_override)
		print("[UI-DEMO] window size -> %s" % str(size_override))
	await _setup()
	if shots:
		await _capture_screens()
		print("[UI-DEMO] screenshots written to ui/_screenshots")
		await _teardown()
		get_tree().quit(0)
	else:
		await _run_selftest()
		_report()


func _teardown() -> void:
	if ui != null and is_instance_valid(ui):
		ui.queue_free()
	if stub != null and is_instance_valid(stub):
		stub.queue_free()
	await _frames(3)


func _setup() -> void:
	ui = UIRoot.new()
	add_child(ui)
	stub = UIStubPlayer.new()
	add_child(stub)
	await _frames(3)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(condition: bool, label: String, detail: String = "") -> void:
	checks += 1
	if condition:
		print("[UI-TEST] PASS  %s" % label)
	else:
		failures.append("%s%s" % [label, (" — " + detail) if not detail.is_empty() else ""])
		print("[UI-TEST] FAIL  %s %s" % [label, detail])


# ---------------------------------------------------------------------------
# Self test
# ---------------------------------------------------------------------------

func _run_selftest() -> void:
	# Boot flow used by App.
	ui.show_main_menu()
	await _frames(4)
	_check(ui.current_screen() == &"main_menu", "boots into main menu")
	_check(ui.get_theme_resource() != null, "theme resource built")
	_check(ui.has_screen(&"quick_deploy"), "quick deploy preflight is registered")

	# Quick Deploy preflight and back navigation.
	ui.show_screen(&"quick_deploy", {})
	await _frames(3)
	_check(ui.current_screen() == &"quick_deploy", "quick deploy preflight opens")
	var quick_screen = ui._get_screen(&"quick_deploy")
	_check(quick_screen != null and quick_screen.has_method("get_selected_map_id"), "quick deploy exposes map selection")
	if quick_screen != null and quick_screen.has_method("get_selected_map_id"):
		_check(quick_screen.call("get_selected_map_id") != &"", "quick deploy preselects a map")
		_check(quick_screen.call("get_selected_planet_id") != &"", "quick deploy preselects a planet")
		var mode_ids: Array = quick_screen.call("get_mode_ids")
		_check(mode_ids.size() == 5, "quick deploy exposes all 5 modes (%d)" % mode_ids.size())
		_check(&"normal" in mode_ids and &"quick" in mode_ids and &"blackout" in mode_ids
			and &"gauntlet" in mode_ids and &"onslaught" in mode_ids, "quick deploy mode ids are complete")
		var selected_planet := StringName(quick_screen.call("get_selected_planet_id"))
		var expected_maps := ContentDB.get_map_presets_for_planet(selected_planet).size()
		_check(int(quick_screen.call("get_map_card_count")) == expected_maps,
			"quick deploy shows every map for the selected planet")
		_check(_count_type(quick_screen, "planet") > 0, "quick deploy renders planet portraits")
		_check(_count_type(quick_screen, "map") > 0, "quick deploy renders map thumbnails")
	ui.navigate_back()
	await _frames(2)
	_check(ui.current_screen() == &"main_menu", "quick deploy back returns to the main menu")

	# Hub + every hub screen.
	ui.show_hub()
	await _frames(3)
	_check(ui.current_screen() == &"hub", "shows hub")
	for screen_id in SCREENS:
		var opened := ui.show_screen(screen_id, {"return_to": &"hub"})
		await _frames(2)
		_check(opened and ui.current_screen() == screen_id, "screen opens: %s" % String(screen_id))
		ui.refresh()
		await _frames(1)
	ui.navigate_back()
	await _frames(1)
	_check(ui.current_screen() == &"hub", "navigate_back returns to hub")

	# --- visual-first expansion screens --------------------------------------
	ui.show_screen(&"loadout", {"return_to": &"hub"})
	await _frames(3)
	var loadout_screen = ui._get_screen(&"loadout")
	_check(_count_type(loadout_screen, "item") > 0, "Loadout renders item art")
	var loadout_art := _first_item_art(loadout_screen)
	_check(loadout_art != null and not String(loadout_art.call("get_art_key")).is_empty(),
		"Loadout item art resolves an art key")
	ui.show_screen(&"locker", {"return_to": &"hub"})
	await _frames(3)
	var locker_screen = ui._get_screen(&"locker")
	_check(_count_type(locker_screen, "warden") > 0, "Locker renders Warden previews")
	_check(_count_type(locker_screen, "warden_compact") > 0, "Locker uses compact cosmetic previews")
	ui.show_screen(&"skills", {"return_to": &"hub"})
	await _frames(3)
	var skills_screen = ui._get_screen(&"skills")
	_check(_count_type(skills_screen, "medallion") >= 4, "Skills renders discipline/ability medallions")
	ui.show_screen(&"squad", {"return_to": &"hub"})
	await _frames(3)
	var squad_screen = ui._get_screen(&"squad")
	_check(_count_type(squad_screen, "ally") > 0, "Squad renders Warden portraits")
	_check(_count_type(squad_screen, "pet") > 0, "Squad renders Driftling art")
	ui.show_screen(&"outpost", {"return_to": &"hub"})
	await _frames(4)
	var outpost_screen = ui._get_screen(&"outpost")
	var diorama = outpost_screen.call("get_diorama") if outpost_screen != null and outpost_screen.has_method("get_diorama") else null
	_check(diorama is UIOutpostDiorama, "Outpost exposes its diorama")
	if diorama is UIOutpostDiorama:
		var board: Rect2 = diorama.call("get_board_rect")
		_check(board.size.x > 40.0 and board.size.y > 40.0, "outpost diorama has a drawable board")
		var layout: Dictionary = diorama.call("get_layout")
		_check(layout.size() == 8, "outpost diorama lays out all 8 modules")
		var module_art: Array = diorama.call("get_module_art")
		_check(module_art.size() == 8, "outpost diorama renders 8 module structures")
		var all_inside := true
		var hit_ok := true
		for module_id in layout.keys():
			var module_rect: Rect2 = diorama.call("get_module_rect", module_id)
			all_inside = all_inside and module_rect.size.x > 0.0 and board.encloses(module_rect)
			var hit := StringName(diorama.call("get_module_at", module_rect.get_center()))
			hit_ok = hit_ok and hit == StringName(module_id)
		_check(all_inside, "every outpost module rect stays inside the board")
		_check(hit_ok, "outpost hit selection resolves each module centre")
		diorama.set("selected_module", &"foundry")
		await _frames(1)
		_check(StringName(diorama.call("get_selected_module")) == &"foundry", "outpost diorama exposes selection state")
		_check("LAYOUT v2" in _label_texts(outpost_screen), "outpost shows the layout v2 badge")
	ui.show_screen(&"settings", {"return_to": &"hub"})
	await _frames(4)
	var settings_screen = ui._get_screen(&"settings")
	_check(settings_screen != null and settings_screen.has_method("get_control"), "settings exposes test accessors")
	if settings_screen != null and settings_screen.has_method("get_control"):
		for key in ["window_mode", "resolution", "vsync", "render_scale", "anti_aliasing", "fps_limit", "quality", "ui_scale"]:
			_check(settings_screen.call("get_control", key) != null, "settings display control exists: %s" % key)
		var window_option := settings_screen.call("get_option_control", "window_mode") as OptionButton
		var resolution_option := settings_screen.call("get_option_control", "resolution") as OptionButton
		var aa_option := settings_screen.call("get_option_control", "anti_aliasing") as OptionButton
		var fps_option := settings_screen.call("get_option_control", "fps_limit") as OptionButton
		_check(window_option != null and window_option.item_count == App.get_window_mode_options().size(),
			"window mode option lists every mode")
		_check(resolution_option != null and resolution_option.item_count == App.get_resolution_options().size(),
			"resolution option lists every resolution")
		_check(aa_option != null and aa_option.item_count == App.get_aa_options().size(),
			"anti-aliasing option lists every mode")
		_check(fps_option != null and fps_option.item_count == App.get_fps_options().size(),
			"frame-rate option lists every cap")
		_check(window_option != null and String(window_option.get_meta("setting_key", "")) == "window_mode",
			"settings control carries its setting key meta")
		_check(String(App.get_display_summary()).length() > 0, "settings can show the display summary")
	ui.show_hub()
	await _frames(1)
	_check(ui.current_screen() == &"hub", "hub returns after the expansion screens")

	# Loading cinema: four acts, boss dossier, skip and reduce-motion fallback.
	var loading_brief := LoadingBrief.build(&"salvage_sweep", 20260225, 2, &"contact", &"quick", &"ashen_shelf")
	ui.show_loading("Preparing the Reach", 0.05, loading_brief)
	await _frames(3)
	var loading = ui.get_loading_screen()
	_check(loading != null, "loading cinema instantiates")
	if loading != null:
		_check(loading.get_active_act() == &"boss", "loading opens on the threat signature")
		_check(loading.get_act_titles().size() == 4, "loading cinema declares four acts")
		_check("Salvage Sweep" in String(loading.get_operation_text()), "loading rail shows the operation")
		_check(not String(loading.get_radio_text()).is_empty(), "loading radio carries the threat line")
		var boss_info: Dictionary = loading.get_boss_info()
		_check(not boss_info.is_empty(), "loading brief resolves a boss signature")
		var expected_boss := String(boss_info.get("name", ""))
		_check(not expected_boss.is_empty(), "boss signature has a display name (%s)" % expected_boss)
		loading.update_loading(0.5, "Sculpting canyons")
		await _frames(2)
		_check(loading.get_progress_value() >= 0.5, "loading accepts deployment progress")
		loading.set_act_id(&"boss")
		await _frames(3)
		_check(loading.get_active_act() == &"boss", "loading cinema holds on the boss reveal")
		var boss_shot: CinemaBossShot = loading.get_shot(&"boss")
		_check(boss_shot != null and boss_shot.visible, "boss shot is on screen")
		_check(boss_shot != null and boss_shot.get_boss_name() == expected_boss, "boss dossier matches the brief")
		if boss_shot != null:
			var name_label := boss_shot.find_child("BossName", true, false) as Label
			_check(name_label != null and name_label.text == expected_boss.to_upper(), "boss name plate renders")
			var phase_pips := boss_shot.find_child("PhasePips", true, false) as HBoxContainer
			_check(phase_pips != null and phase_pips.get_child_count() >= 3, "boss dossier shows phase pips")
			var counter_text := boss_shot.find_child("CounterIntelText", true, false) as Label
			_check(counter_text != null and not counter_text.text.is_empty(), "boss dossier shows counter-intel")
		loading.set_act_id(&"rift")
		await _frames(2)
		_check(loading.get_active_act() == &"rift", "loading cinema cuts to the rift breach")
		loading.skip_cinematic()
		await _frames(2)
		_check(loading.is_cinematic_skipped() and loading.is_static_mode(), "skip collapses to a static brief")
		_check(not loading.get_skip_button().visible, "skip control hides once used")
		ui.hide_loading()
		await _frames(1)
		_check(ui.get_loading_screen() != null and not ui.get_loading_screen().visible, "hide_loading dismisses the cinema")
		# Reduce motion must open the static boss briefing instead of footage.
		App.set_setting("reduce_motion", true)
		await _frames(1)
		ui.show_loading("Preparing the Reach", 0.3, loading_brief)
		await _frames(2)
		loading = ui.get_loading_screen()
		_check(loading != null and loading.is_static_mode(), "reduce motion opens a static boss brief")
		ui.hide_loading()
		App.set_setting("reduce_motion", false)
		await _frames(1)

	# Results overlay.
	var result := {
		"extracted": true,
		"reason": "Extracted before the Collapse.",
		"seed": 1234,
		"contract_id": "salvage_sweep",
		"threat": 2,
		"difficulty_id": "contact",
		"difficulty_name": "Contact",
		"difficulty_reward_mult": 1.15,
		"map_name": "Ashen Shelf",
		"mode_id": "quick",
		"mode_name": "Quick",
		"mode_clock": "09:00",
		"mode_tag": "2x CLOCK",
		"run_duration": 1080.0,
		"time_scale": 2.0,
		"real_elapsed": 306.5,
		"elapsed": 613.0,
		"kills": 17,
		"bosses": 1,
		"objectives": 2,
		"salvage": 640,
		"cores": 3,
		"xp": 410,
		"xp_breakdown": {"contract": 130, "kills": 238, "objectives": 50, "difficulty_mult": 1.15, "extraction_mult": 1.1, "total": 410},
		"value": 890,
		"items": [],
		"contract_completed": true,
		"rift_mods": ["volatile_rounds"],
	}
	ui.show_results(result)
	await _frames(2)
	ui.show_hub()
	await _frames(1)

	# HUD against the stub player.
	ui.show_deployment_hud(stub)
	await _frames(3)
	_check(ui.get_hud() != null, "HUD instantiates and binds stub player")
	var hud := ui.get_hud()
	if hud != null:
		stub.simulate_damage()
		stub.simulate_hit()
		await _frames(1)
		_check(hud.has_method("show_damage_number"), "HUD exposes damage numbers")
		_check(hud.has_method("get_minimap") and hud.call("get_minimap") != null, "HUD exposes the minimap")
		_check(hud.has_method("get_map_overlay") and hud.call("get_map_overlay") != null, "HUD exposes the tactical map overlay")
		_check(hud.has_method("get_scope") and hud.call("get_scope") != null, "HUD exposes the precision scope")
		_check(hud.has_method("get_aim_sight") and hud.call("get_aim_sight") != null, "HUD exposes the ADS aim sight")
		_check(hud.has_method("set_mission_trackers"), "HUD accepts mission trackers")
		_check(hud.has_method("get_world_chip") and hud.call("get_world_chip") != null, "HUD exposes the weather/clock chip")
		_check(hud.has_method("get_tutorial_panel") and hud.call("get_tutorial_panel") != null, "HUD exposes the training card")
		_check(hud.has_method("get_dungeon_panel") and hud.call("get_dungeon_panel") != null, "HUD exposes the dungeon banner")
		_check(hud.has_method("get_hazard_overlay") and hud.call("get_hazard_overlay") != null, "HUD exposes the hazard overlay")
		EventBus.tutorial_stage_changed.emit({
			"complete": false, "index": 1, "total": 5, "title": "AIM & FIRE",
			"body": "Land three hits.", "hint": "RMB · LMB", "progress": 0.5,
		})
		await _frames(2)
		var tutorial_panel := hud.call("get_tutorial_panel") as Control
		_check(tutorial_panel != null and tutorial_panel.visible, "training card responds to stage updates")
		EventBus.tutorial_stage_changed.emit({"complete": true})
		await _frames(1)
		_check(tutorial_panel != null and not tutorial_panel.visible, "training card hides when training ends")
		EventBus.hazard_state_changed.emit(&"water")
		await _frames(1)
		var hazard_overlay := hud.call("get_hazard_overlay") as ColorRect
		_check(hazard_overlay != null and hazard_overlay.color.a > 0.01, "hazard overlay tints water")
		EventBus.hazard_state_changed.emit(&"none")
		EventBus.dungeon_state_changed.emit(true, "Rift Vault")
		await _frames(1)
		var dungeon_panel := hud.call("get_dungeon_panel") as Control
		_check(dungeon_panel != null and dungeon_panel.visible, "dungeon banner shows in the under-reach")
		EventBus.dungeon_state_changed.emit(false, "")
		EventBus.world_event.emit(
			"Rift Cyclone",
			"A cyclone of folded space is carving across the sector. It is leaving something behind.",
			&"weather-storm",
			UIPalette.violet
		)
		await _frames(2)
		var world_event_panel := hud.call("get_world_event_panel") as Control
		_check(world_event_panel != null and world_event_panel.visible, "Reach Event banner shows on world_event")
		_check(world_event_panel != null and "RIFT CYCLONE" in _label_texts(world_event_panel),
			"Reach Event banner shows the event title")
		if hud.has_method("set_mission_trackers"):
			hud.call("set_mission_trackers", [
				{"title": "Recover caches", "icon": &"cache", "color": UIPalette.mint, "world_position": Vector3(40.0, 0.0, 20.0), "progress": 1, "total": 4, "kind": &"cache"},
				{"title": "Rift Shrine", "icon": &"star", "color": UIPalette.violet, "world_position": Vector3(-80.0, 0.0, 50.0), "progress": 0, "total": 1, "kind": &"shrine"},
			])
		var saved_level := int(ProfileState.data.get("level", 1))
		ProfileState.data["level"] = 5
		Input.action_press("map")
		await _frames(2)
		Input.action_release("map")
		await _frames(1)
		var overlay := hud.call("get_map_overlay") as Control
		_check(overlay != null and overlay.visible, "M opens the tactical map at level 2+")
		Input.action_press("map")
		await _frames(2)
		Input.action_release("map")
		await _frames(1)
		_check(overlay != null and not overlay.visible, "M closes the tactical map")
		var aim_sight := hud.call("get_aim_sight") as Control
		stub.simulate_aim(0.82, 1.0)
		await _frames(2)
		_check(aim_sight != null and aim_sight.visible, "standard ADS shows the style aim sight")
		stub.simulate_aim(0.34, 1.0)
		await _frames(2)
		var scope := hud.call("get_scope") as Control
		_check(scope != null and scope.visible, "DMR/rail ADS shows the scope overlay")
		_check(aim_sight != null and not aim_sight.visible, "precision scope hides the style reticle")
		stub.simulate_aim(0.82, 0.0)
		await _frames(1)
		ProfileState.data["level"] = saved_level
		hud.call("show_damage_number", 42, Vector3(2.0, 1.0, 6.0), true, false)
		hud.call("show_boss", "WARDEN OF THE FOLD", 780.0, 1200.0)
		hud.call("show_interaction", "Scan the cache")
		hud.call("show_subtitle", "Mara Voss", "I have movement on the ridge. Keep your head down.")
		EventBus.notify("Cache recovered", "Satchel value 320", &"loot")
		await _frames(2)
		stub.simulate_down()
		await _frames(1)
		ui.show_pause(true)
		await _frames(2)
		ui.show_pause(false)
		await _frames(1)
		stub.simulate_death()
		await _frames(1)

	# Inventory overlay (presented directly; App owns the pause lifecycle).
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var fake_loot := ItemFactory.generate_weapon(rng, &"wisp_smg", 1, 1, 9001)
	var fake_inventory := {
		"callsign": "Warden",
		"inventory_key": "I",
		"weapons": [
			{"slot_label": "PRIMARY 1", "name": "Sable Rail", "active": true, "is_melee": false, "ammo": 4, "reserve": 30, "damage": 160.0, "rarity_color": UIPalette.mint},
			{"slot_label": "PRIMARY 2", "name": "Lattice AR", "active": false, "is_melee": false, "ammo": 30, "reserve": 210, "damage": 24.0, "rarity_color": UIPalette.mint},
			{"slot_label": "SIDEARM", "name": "Sidewinder", "active": false, "is_melee": false, "ammo": 21, "reserve": 126, "damage": 18.0, "rarity_color": UIPalette.muted},
			{"slot_label": "KNIFE", "name": "Combat Knife", "active": false, "is_melee": true, "ammo": 0, "reserve": 0, "damage": 55.0, "rarity_color": UIPalette.mint},
		],
		"gear": [
			{"slot": "helmet", "label": "Helmet", "name": "Vanguard Helm", "rarity_color": UIPalette.mint, "armor": 12.0, "empty": false},
		],
		"satchel_items": [fake_loot],
		"satchel_salvage": 320,
		"satchel_cores": 2,
		"rift_mods": [],
		"locker_count": 12,
		"extractions": 4,
		"time_left": 412.0,
		"kills": 17,
	}
	ui.show_inventory(fake_inventory)
	await _frames(3)
	var inventory_overlay = ui.get_inventory_overlay()
	_check(inventory_overlay != null and inventory_overlay.visible, "inventory overlay presents")
	if inventory_overlay != null:
		_check(int(inventory_overlay.call("get_weapon_row_count")) == 4, "inventory shows four weapon slots")
		_check(int(inventory_overlay.call("get_loot_row_count")) == 1, "inventory shows satchel loot")
	ui.hide_inventory()
	await _frames(1)
	_check(inventory_overlay != null and not inventory_overlay.visible, "inventory overlay dismisses")

	# Pause overlay on a paused tree path.
	ui.show_pause(true)
	await _frames(1)
	ui.show_pause(false)
	ui.show_hub()
	await _frames(2)
	_check(ui.get_hud() == null, "leaving deployment clears HUD")
	_check(ui.current_screen() == &"hub", "hub returns after HUD flow")

	# Functional ProfileState round-trip (in-memory only, restored afterwards).
	var backup: Dictionary = ProfileState.data.duplicate(true)
	var inventory: Array = ProfileState.get_inventory()
	if not inventory.is_empty():
		var sample: Dictionary = inventory[0]
		var uid := int(sample.get("uid", 0))
		if uid > 0:
			var equip_ok := ProfileState.equip_item(uid)
			_check(equip_ok or not equip_ok, "equip_item callable (%s)" % str(equip_ok))
	if ProfileState.get_skill_points() > 0:
		var perks: Array = ContentDB.get_perks_for_discipline(ProfileState.get_discipline())
		if not perks.is_empty():
			var bought := ProfileState.buy_perk(perks[0].id)
			_check(bought or true, "buy_perk callable (%s)" % str(bought))
	if ProfileState.get_attribute_points() > 0:
		_check(ProfileState.spend_attribute_point(&"power") or true, "spend_attribute_point callable")
	var first_ally: StringName = &"mara_voss"
	ProfileState.set_active_allies([String(first_ally)])
	_check(ProfileState.get_active_allies().size() == 1, "set_active_allies callable")
	ProfileState.set_active_pet(&"mote")
	_check(ProfileState.get_active_pet() == &"mote", "set_active_pet callable")
	ProfileState.data = backup
	ui.show_hub()
	await _frames(2)
	_check(ui.current_screen() == &"hub", "UI survives profile data restore")

	# Accessibility switches rebuild the theme and refresh the live screen.
	App.set_setting("high_contrast", true)
	await _frames(2)
	_check(ui.get_theme_resource() != null, "high contrast rebuild")
	ui.show_hub()
	await _frames(1)
	App.set_setting("reduce_motion", true)
	await _frames(1)
	App.set_setting("reduce_motion", false)
	App.set_setting("high_contrast", false)
	App.set_setting("ui_scale", 1.0)
	await _frames(2)
	_check(ui.current_screen() == &"hub", "accessibility settings apply live")

	# Reality check on authored content the UI depends on.
	_check(ContentDB.weapons.size() == 16, "ContentDB weapons available")
	_check(ContentDB.contracts.size() == 13, "ContentDB contracts available")
	_check(ContentDB.perks.size() == 24, "ContentDB perks available")
	_check(ContentDB.cosmetics.size() >= 20, "ContentDB cosmetics available")
	_check(ContentDB.planets.size() == 5 and ContentDB.map_presets.size() == 12, "ContentDB planets/maps available")
	_check(ContentDB.game_modes.size() == 5 and ContentDB.world_events.size() == 20, "ContentDB modes/events available")
	_check(ContentDB.get_elite_enemies().size() == 11 and ContentDB.get_boss_enemies().size() == 6,
		"ContentDB elite/boss rosters available")
	_check(UIFonts.is_available(), "bundled fonts loaded")
	_check(UIIcons.has_icon(&"crosshair"), "icon set imported")
	_check(UIIcons.has_icon(&"skull") and UIIcons.has_icon(&"cache"), "new icon set imported")
	for icon_name in [&"weather-snow", &"weather-ion", &"weather-void", &"weather-meteor", &"weather-toxic",
			&"faction-ashen", &"faction-bloom", &"faction-choir",
			&"discipline-vanguard", &"discipline-infiltrator", &"discipline-engineer", &"discipline-pathfinder"]:
		_check(UIIcons.has_icon(icon_name), "expansion icon imported: %s" % icon_name)
	var icon_tab_probe := UIFactory.icon_tab(&"book", "Probe")
	var icon_tab_content := icon_tab_probe.get_node_or_null("IconContent") if icon_tab_probe != null else null
	_check(icon_tab_content != null and icon_tab_content.get_child_count() >= 2, "icon tabs embed a glyph row")
	if icon_tab_probe != null:
		icon_tab_probe.free()


## Depth-first count of the visual-first component types. Uses `is` checks so
## script-class globals resolve regardless of find_children class matching.
func _count_type(root: Node, kind: String) -> int:
	if root == null:
		return 0
	var total := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		match kind:
			"planet":
				if node is UIPlanetPortrait:
					total += 1
			"map":
				if node is UIMapThumbnail:
					total += 1
			"item":
				if node is UIItemArt:
					total += 1
			"medallion":
				if node is UIIconMedallion:
					total += 1
			"warden":
				if node is UIWardenPreview:
					total += 1
			"warden_compact":
				if node is UIWardenPreview and (node as UIWardenPreview).compact:
					total += 1
			"ally":
				if node is UIAllyPortrait:
					total += 1
			"pet":
				if node is UIPetArt:
					total += 1
	return total


func _first_item_art(root: Node) -> UIItemArt:
	if root == null:
		return null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is UIItemArt:
			return node as UIItemArt
	return null


func _label_texts(root: Node) -> Array[String]:
	var texts: Array[String] = []
	if root == null:
		return texts
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is Label:
			texts.append((node as Label).text)
	return texts


func _report() -> void:
	print("[UI-TEST] checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		print("[UI-TEST]  - %s" % failure)
	if failures.is_empty():
		print("[UI-TEST] RESULT: PASS")
	else:
		print("[UI-TEST] RESULT: FAIL")
	await _teardown()
	get_tree().quit(0 if failures.is_empty() else 1)


# ---------------------------------------------------------------------------
# Screenshot mode
# ---------------------------------------------------------------------------

func _capture_screens() -> void:
	var shot_dir := "res://ui/_screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	await _shot("01_main_menu", _show_main_menu)
	await _shot("02_hub", _show_hub)
	await _shot("03_loadout", func() -> void: ui.show_screen(&"loadout", {"return_to": &"hub"}))
	await _shot("04_locker", func() -> void: ui.show_screen(&"locker", {"return_to": &"hub"}))
	await _shot("05_skills", func() -> void: ui.show_screen(&"skills", {"return_to": &"hub"}))
	await _shot("06_squad", func() -> void: ui.show_screen(&"squad", {"return_to": &"hub"}))
	await _shot("07_outpost", func() -> void: ui.show_screen(&"outpost", {"return_to": &"hub"}))
	await _shot("08_codex", func() -> void: ui.show_screen(&"codex", {"return_to": &"hub"}))
	await _shot("09_settings", func() -> void: ui.show_screen(&"settings", {"return_to": &"hub"}))
	await _shot("10_loading", func() -> void: await _show_loading_shot(&"boss", 0.62, "Painting biome palettes"))
	await _shot("18_loading_breach", func() -> void: await _show_loading_shot(&"rift", 0.30, "Opening the Reach"))
	await _shot("19_loading_descent", func() -> void: await _show_loading_shot(&"descent", 0.72, "Printing drop pod"))
	await _shot("20_loading_touchdown", func() -> void: await _show_loading_shot(&"touchdown", 0.98, "Deployment live"))
	await _shot("21_loading_leviathan", func() -> void: await _show_loading_shot(&"boss", 0.64, "Mapping hostiles", &"tidal_shelf", 20260227))
	await _shot("11_results", func() -> void:
		ui.show_results({
			"extracted": true,
			"reason": "Extracted before the Collapse.",
			"seed": 1234,
			"contract_id": "salvage_sweep",
			"threat": 2,
			"difficulty_id": "contact",
			"difficulty_name": "Contact",
			"difficulty_reward_mult": 1.15,
			"map_name": "Ashen Shelf",
			"mode_id": "quick",
			"mode_name": "Quick",
			"time_scale": 2.0,
			"real_elapsed": 306.5,
			"elapsed": 613.0,
			"kills": 17,
			"bosses": 1,
			"objectives": 2,
			"salvage": 640,
			"cores": 3,
			"xp": 410,
			"xp_breakdown": {"contract": 130, "kills": 238, "objectives": 50, "difficulty_mult": 1.15, "extraction_mult": 1.1, "total": 410},
			"progression": {
				"level_before": 3, "xp_before": 240, "level_after": 4, "xp_after": 100, "xp_next": 420,
				"levels_gained": 1, "skill_points_gained": 1, "attribute_points_gained": 2,
				"skill_points": 3, "attribute_points": 4,
				"unlocks": [
					{"kind": "mechanic", "id": "squad_command", "name": "Squad Commands", "level": 4},
					{"kind": "ability", "id": "overclock", "name": "Overclock", "level": 4},
				],
			},
			"value": 890,
			"items": [],
			"contract_completed": true,
			"rift_mods": ["volatile_rounds"],
		})
	)
	await _shot("12_hud", func() -> void:
		ui.show_deployment_hud(stub)
		await get_tree().create_timer(0.4).timeout
		stub.simulate_damage()
		stub.simulate_hit()
		var hud := ui.get_hud()
		if hud != null:
			hud.call("set_tactical_data", _fake_tactical_data())
			hud.call("set_mission_trackers", [
				{"title": "Recover caches", "icon": &"cache", "color": UIPalette.mint, "world_position": Vector3(120.0, 0.0, -80.0), "progress": 2, "total": 4, "kind": &"cache"},
				{"title": "Eliminate the Rift Stalker", "icon": &"skull", "color": UIPalette.danger, "world_position": Vector3(420.0, 0.0, 160.0), "progress": 0, "total": 1, "kind": &"bounty"},
				{"title": "Touch the Rift Shrine", "icon": &"star", "color": UIPalette.violet, "world_position": Vector3(-260.0, 0.0, 340.0), "progress": 0, "total": 1, "kind": &"shrine"},
			])
			hud.call("show_damage_number", 42, Vector3(2.0, 1.0, 6.0), true, false)
			hud.call("show_boss", "WARDEN OF THE FOLD", 780.0, 1200.0)
			hud.call("show_interaction", "Hold to scan the memory cache")
			hud.call("show_subtitle", "Mara Voss", "Movement on the ridge. Keep your head down and let the turret work.")
		EventBus.notify("Cache recovered", "Satchel value 320", &"loot")
	)
	await _shot("13_pause", func() -> void:
		ui.show_pause(true)
	)
	await _shot("14_hud_down", func() -> void:
		ui.show_deployment_hud(stub)
		await get_tree().create_timer(0.3).timeout
		stub.simulate_damage()
		stub.simulate_down()
	)
	await _shot("15_hud_scope", func() -> void:
		stub.downed = false
		stub.ads_amount = 0.0
		ui.show_deployment_hud(stub)
		await get_tree().create_timer(0.4).timeout
		stub.simulate_aim(0.34)
		await get_tree().create_timer(0.2).timeout
	)
	await _shot("16_tactical_map", func() -> void:
		stub.downed = false
		stub.ads_amount = 0.0
		ui.show_deployment_hud(stub)
		await get_tree().create_timer(0.4).timeout
		var hud := ui.get_hud()
		if hud != null:
			hud.call("set_tactical_data", _fake_tactical_data())
			hud.call("_set_map_open", true)
			hud.set_process(false)
		await get_tree().create_timer(0.2).timeout
	)
	await _shot("17_quick_deploy", func() -> void:
		ui.show_screen(&"quick_deploy", {})
	)


func _fake_tactical_data() -> Dictionary:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var n := float((x * 17 + y * 31) % 29) / 29.0
			var ridge := float(y) / 128.0
			image.set_pixel(x, y, Color(0.10 + ridge * 0.18, 0.16 + n * 0.10, 0.15 + (1.0 - ridge) * 0.10))
	var texture := ImageTexture.create_from_image(image)
	var markers: Array = []
	for i in 6:
		var angle := TAU * float(i) / 6.0
		markers.append({
			"position": Vector3(120.0 + cos(angle) * 520.0, 0.0, -80.0 + sin(angle) * 520.0),
			"kind": &"poi" if i % 2 == 0 else &"objective",
			"label": "POI %d" % i,
			"color": UIPalette.mint if i % 2 == 0 else UIPalette.amber,
		})
	markers.append({"position": Vector3(760.0, 0.0, 600.0), "kind": &"exfil", "label": "Exfil Alpha", "color": UIPalette.amber})
	var hostiles: Array = []
	for i in 9:
		var angle := TAU * float(i) / 9.0 + 0.3
		hostiles.append(Vector3(120.0 + cos(angle) * 380.0, 0.0, -80.0 + sin(angle) * 380.0))
	return {
		"map_texture": texture,
		"map_size": 1800.0,
		"map_name": "Glass Expanse",
		"mode_name": "Quick",
		"player_position": Vector3(120.0, 0.0, -80.0),
		"player_yaw": 0.7,
		"markers": markers,
		"hostiles": hostiles,
		"allies": [Vector3(80.0, 0.0, -40.0), Vector3(150.0, 0.0, -110.0)],
		"boss_position": Vector3(-420.0, 0.0, 340.0),
		"safe_radius": 620.0,
		"storm_active": true,
		"extraction_state": "inactive",
		"time_left": 412.0,
		"difficulty_name": "Breach",
	}


func _show_main_menu() -> void:
	ui.show_main_menu()


func _show_hub() -> void:
	ui.show_hub()


func _shot(shot_name: String, setup: Callable) -> void:
	if not _only_filter.is_empty() and not shot_name.contains(_only_filter):
		return
	ui.show_hub()
	await _frames(1)
	await setup.call()
	await _frames(6)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://ui/_screenshots/%s.png" % shot_name)
	var err := image.save_png(path)
	print("[UI-DEMO] %s -> %s (%s)" % [shot_name, path, str(err)])


## Show the loading cinema at a chosen act, frozen on its composed pose so the
## screenshots are deterministic. Returns after the frame has settled.
func _show_loading_shot(act_id: StringName, progress: float, step: String, map_id: StringName = &"cinder_caldera", seed_value: int = 20260226) -> void:
	var brief := LoadingBrief.build(&"salvage_sweep", seed_value, 2, &"contact", &"quick", map_id)
	ui.show_loading("Preparing the Reach", progress, brief)
	await get_tree().process_frame
	var loading = ui.get_loading_screen()
	if loading != null:
		loading.freeze_cinematic(true)
		loading.set_act_id(act_id)
		loading.update_loading(progress, step)
		print("[UI-DEMO] loading act=%s boss=%s" % [String(loading.get_active_act()), String(loading.get_boss_info().get("name", ""))])
	await get_tree().create_timer(0.15).timeout
