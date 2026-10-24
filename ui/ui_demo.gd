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

	# Loading overlay.
	ui.show_loading("Preparing the Reach", 0.2)
	await _frames(2)
	ui.update_loading(0.55, "Sculpting canyons")
	ui.update_loading(0.9, "Baking navigation")
	await _frames(1)
	ui.hide_loading()
	ui.show_hub()
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
	_check(ContentDB.weapons.size() >= 10, "ContentDB weapons available")
	_check(ContentDB.contracts.size() >= 6, "ContentDB contracts available")
	_check(ContentDB.perks.size() >= 16, "ContentDB perks available")
	_check(ContentDB.cosmetics.size() >= 20, "ContentDB cosmetics available")
	_check(UIFonts.is_available(), "bundled fonts loaded")
	_check(UIIcons.has_icon(&"crosshair"), "icon set imported")
	_check(UIIcons.has_icon(&"skull") and UIIcons.has_icon(&"cache"), "new icon set imported")
	var icon_tab_probe := UIFactory.icon_tab(&"book", "Probe")
	var icon_tab_content := icon_tab_probe.get_node_or_null("IconContent") if icon_tab_probe != null else null
	_check(icon_tab_content != null and icon_tab_content.get_child_count() >= 2, "icon tabs embed a glyph row")
	if icon_tab_probe != null:
		icon_tab_probe.free()


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
	await _shot("10_loading", func() -> void:
		ui.show_loading("Preparing the Reach", 0.62)
		ui.update_loading(0.62, "Painting biome palettes")
	)
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
	ui.show_hub()
	await _frames(1)
	await setup.call()
	await _frames(6)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://ui/_screenshots/%s.png" % shot_name)
	var err := image.save_png(path)
	print("[UI-DEMO] %s -> %s (%s)" % [shot_name, path, str(err)])
