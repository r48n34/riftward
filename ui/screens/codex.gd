class_name CodexScreen
extends UIScreen
## Codex and records: career ledger, enemy catalogue, rift mods, mutators and a
## field guide. Pure read-only presentation of ContentDB + ProfileState.

const TABS := [
	{"id": &"records", "label": "Records", "icon": &"book"},
	{"id": &"enemies", "label": "Bestiary", "icon": &"skull"},
	{"id": &"planets", "label": "Planets", "icon": &"planet"},
	{"id": &"weather", "label": "Weather", "icon": &"weather-storm"},
	{"id": &"operations", "label": "Operations", "icon": &"flag"},
	{"id": &"dungeons", "label": "Dungeons", "icon": &"dungeon"},
	{"id": &"rift_mods", "label": "Rift Mods", "icon": &"bolt"},
	{"id": &"mutators", "label": "Mutators", "icon": &"warning"},
	{"id": &"sites", "label": "Sites", "icon": &"outpost"},
	{"id": &"rideables", "label": "Rideables", "icon": &"grid"},
	{"id": &"guide", "label": "Field Guide", "icon": &"map"},
]

const FACTION_ICONS := {
	&"ashen": &"faction-ashen",
	&"bloom": &"faction-bloom",
	&"choir": &"faction-choir",
}

const STAGE_ICONS := {
	&"cache": &"cache",
	&"relay": &"radio",
	&"hunt": &"crosshair",
	&"survey": &"map",
	&"rescue": &"users",
	&"vault": &"lock",
	&"dungeon": &"dungeon",
	&"dungeon_boss": &"skull",
}

const NOTES := [
	{
		"title": "The Reach",
		"icon": &"map",
		"body": "A folded frontier of canyons, bloom-choked basins and glass plains. It looks different every drop because it is. Nothing out here stays where you left it.",
	},
	{
		"title": "The Collapse",
		"icon": &"warning",
		"body": "Around the twelve-minute mark the Reach starts folding in on itself. The safe zone contracts, the storm eats the map edge-first, and exfil becomes the only objective that matters.",
	},
	{
		"title": "Salvage & Extraction",
		"icon": &"cache",
		"body": "Everything you recover rides in the satchel. Extract and it is yours; die and the Reach keeps it. Base modules like the Armory and Infirmary soften that loss.",
	},
	{
		"title": "Wardens & Driftlings",
		"icon": &"users",
		"body": "Wardens bring guns and abilities to the drop. Driftlings are small, loyal, and occasionally the reason you survive. Both rank up at the outpost.",
	},
	{
		"title": "Threat & Mutators",
		"icon": &"skull",
		"body": "Higher threat means elites, heavier reinforcements and richer contracts. Mutators stack reward bonuses on top — and change how the Reach fights back.",
	},
]

const CONTROLS := [
	{"icon": &"arrow-up", "label": "Move", "binding": "WASD"},
	{"icon": &"bolt", "label": "Sprint", "binding": "Shift"},
	{"icon": &"chevron-down", "label": "Crouch", "binding": "Ctrl"},
	{"icon": &"arrow-up-right", "label": "Jump", "binding": "Space"},
	{"icon": &"crosshair", "label": "Fire", "binding": "Mouse 1"},
	{"icon": &"target", "label": "Aim", "binding": "Mouse 2"},
	{"icon": &"refresh", "label": "Reload", "binding": "R"},
	{"icon": &"eye", "label": "Use", "binding": "E"},
	{"icon": &"shield", "label": "AB1", "binding": "Q"},
	{"icon": &"shield-check", "label": "AB2", "binding": "F"},
	{"icon": &"star", "label": "ULT", "binding": "X"},
	{"icon": &"rocket", "label": "Nade", "binding": "G"},
	{"icon": &"arrow-right", "label": "Melee", "binding": "V"},
	{"icon": &"map", "label": "Map", "binding": "M"},
	{"icon": &"pause", "label": "Pause", "binding": "Esc"},
	{"icon": &"users", "label": "Squad", "binding": "Z"},
]

var _tab: StringName = &"records"
var _tab_host: HFlowContainer = null
var _content_host: VBoxContainer = null
var _grid: GridContainer = null


func _compose() -> void:
	var backdrop := UIBackdrop.new()
	backdrop.configure(UIBackdrop.Mood.HUB)
	add_child(backdrop)

	var shell := build_hub_shell(&"codex", "Codex", "")
	var content: VBoxContainer = shell.content
	# Nine tabs must survive a 1280px window; the flow container wraps instead
	# of clipping the tail of the strip.
	_tab_host = HFlowContainer.new()
	_tab_host.add_theme_constant_override("h_separation", UIPalette.SP1)
	_tab_host.add_theme_constant_override("v_separation", UIPalette.SP1)
	_tab_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_tab_host)
	var scroll := UIFactory.vscroll()
	content.add_child(scroll)
	_content_host = UIFactory.vbox(UIPalette.SP4)
	_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content_host)
	_refresh()


func _refresh() -> void:
	if _content_host == null:
		return
	_build_tabs()
	UIFactory.clear_children(_content_host)
	match _tab:
		&"records":
			_build_records()
		&"enemies":
			_build_bestiary()
		&"planets":
			_build_planets()
		&"weather":
			_build_weather()
		&"operations":
			_build_operations()
		&"dungeons":
			_build_dungeons()
		&"rift_mods":
			_build_rift_mods()
		&"mutators":
			_build_mutators()
		&"sites":
			_build_sites()
		&"rideables":
			_build_rideables()
		_:
			_build_guide()


func _build_tabs() -> void:
	UIFactory.clear_children(_tab_host)
	for entry in TABS:
		var tab_id: StringName = entry.id
		var button := UIFactory.icon_tab(StringName(entry.icon), String(entry.label), tab_id == _tab)
		button.pressed.connect(func() -> void: _select_tab(tab_id))
		_tab_host.add_child(button)


func _select_tab(tab_id: StringName) -> void:
	if tab_id == _tab:
		return
	_tab = tab_id
	_refresh()


## Public tab selection for tests/screenshot harnesses. Unknown ids are ignored.
func select_tab(tab_id: StringName) -> void:
	for entry in TABS:
		if StringName(entry.id) == tab_id:
			_select_tab(tab_id)
			return


func get_active_tab() -> StringName:
	return _tab


# ---------------------------------------------------------------------------
# Records
# ---------------------------------------------------------------------------

func _build_records() -> void:
	var records := ProfileState.get_records()
	_content_host.add_child(UIFactory.section_header("Career Ledger", "", null, &"book"))
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", UIPalette.SP3)
	_grid.add_theme_constant_override("v_separation", UIPalette.SP3)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_host.add_child(_grid)
	_grid.columns = _grid_columns()
	_grid.add_child(_record_card(&"home", "Deployments", str(int(records.get("deployments", 0))), "Times dropped into the Reach.", UIPalette.mint))
	_grid.add_child(_record_card(&"exfil", "Extractions", str(int(records.get("extractions", 0))), "Returns through the exfil gate.", UIPalette.blue))
	_grid.add_child(_record_card(&"warning", "Deaths", str(int(records.get("deaths", 0))), "Runs lost to the Reach.", UIPalette.danger))
	_grid.add_child(_record_card(&"coins", "Best haul", UIPalette.format_int(int(records.get("best_extraction", 0))), "Highest single extraction value.", UIPalette.amber))
	_grid.add_child(_record_card(&"target", "Kills", str(int(records.get("kills", 0))), "Confirmed eliminations.", UIPalette.ivory))
	_grid.add_child(_record_card(&"skull", "Bosses", str(int(records.get("bosses", 0))), "Boss-class signatures ended.", UIPalette.violet))
	_grid.add_child(_record_card(&"star", "Total salvage", UIPalette.format_int(int(records.get("total_salvage", 0))), "Lifetime extracted value.", UIPalette.sun))
	_grid.add_child(_record_card(&"check", "Contracts", str(int(ProfileState.data.get("contracts_completed", 0))), "Contracts fully completed.", UIPalette.mint))
	_grid.add_child(_record_card(&"dungeon", "Dungeon clears", str(int(records.get("dungeons_cleared", 0))), "Under-reach guardians defeated.", UIPalette.violet))

	var level_card := UIFactory.panel("Card")
	var level_box := UIFactory.vbox(UIPalette.SP2)
	var level_row := UIFactory.hbox(UIPalette.SP3)
	level_row.add_child(UIFactory.icon(&"arrow-up", 18, UIPalette.mint))
	level_row.add_child(UIFactory.display_text("Level %d" % ProfileState.get_level(), 28, 600))
	level_row.add_child(UIFactory.spacer_h())
	var xp_target := ProfileState.get_xp_for_next_level()
	var xp_value := UIFactory.icon_value(&"timer", "MAX" if xp_target <= 0 else "%d / %d" % [ProfileState.get_xp(), xp_target], UIPalette.muted, 12)
	xp_value.tooltip_text = "Warden experience"
	level_row.add_child(xp_value)
	level_box.add_child(level_row)
	var ratio := 1.0 if xp_target <= 0 else clampf(float(ProfileState.get_xp()) / float(xp_target), 0.0, 1.0)
	level_box.add_child(UIFactory.progress(ratio * 100.0, 100.0, "BarMint", 6))
	var meta_row := UIFactory.hbox(UIPalette.SP5)
	var discipline_row := UIFactory.icon_value(&"shield", String(ProfileState.get_discipline()).capitalize(), UIPalette.mint, 13)
	discipline_row.tooltip_text = "Discipline"
	meta_row.add_child(discipline_row)
	var playtime_row := UIFactory.icon_value(&"timer", UIPalette.format_duration(ProfileState.get_playtime()), UIPalette.muted, 13)
	playtime_row.tooltip_text = "Playtime"
	meta_row.add_child(playtime_row)
	var profile_row := UIFactory.icon_value(&"info", ProfileState.get_profile_id(), UIPalette.muted_dim, 13)
	profile_row.tooltip_text = "Profile id"
	meta_row.add_child(profile_row)
	level_box.add_child(meta_row)
	level_card.add_child(level_box)
	_content_host.add_child(level_card)


func _record_card(icon_name: StringName, title: String, value_text: String, description: String, accent: Color) -> PanelContainer:
	var card := UIFactory.panel("Card")
	card.custom_minimum_size = Vector2(0, 108)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = description
	var box := UIFactory.vbox(UIPalette.SP2)
	var top := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon_or_null(icon_name, 16, accent)
	if glyph != null:
		top.add_child(glyph)
	top.add_child(UIFactory.label(title.to_upper(), "StatLabel"))
	top.add_child(UIFactory.spacer_h())
	box.add_child(top)
	box.add_child(UIFactory.number_text(value_text, 26, accent))
	card.add_child(box)
	return card


# ---------------------------------------------------------------------------
# Bestiary
# ---------------------------------------------------------------------------

func _build_bestiary() -> void:
	_content_host.add_child(UIFactory.section_header("Bestiary", "", null, &"skull"))
	var factions: Array = [&"ashen", &"bloom", &"choir"]
	for faction in factions:
		var enemies: Array = ContentDB.get_all_enemies_of_faction(faction)
		if enemies.is_empty():
			continue
		var accent := UIPalette.faction_color(faction)
		var header := UIFactory.hbox(UIPalette.SP2)
		header.add_child(UIFactory.medallion(_faction_icon(faction), 30, accent))
		header.add_child(UIFactory.heading(String(faction).capitalize(), "H3"))
		header.tooltip_text = _faction_blurb(faction)
		_content_host.add_child(header)
		var grid := GridContainer.new()
		grid.add_theme_constant_override("h_separation", UIPalette.SP3)
		grid.add_theme_constant_override("v_separation", UIPalette.SP3)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.columns = 2 if viewport_width() >= 1360.0 else 1
		_content_host.add_child(grid)
		for enemy in enemies:
			grid.add_child(_enemy_card(enemy, accent))
	# Elites and bosses.
	var specials: Array = []
	for enemy in ContentDB.enemies.values():
		if enemy.elite or enemy.boss:
			specials.append(enemy)
	if not specials.is_empty():
		_content_host.add_child(UIFactory.section_header("Elite Signatures", "", null, &"warning"))
		var special_grid := GridContainer.new()
		special_grid.add_theme_constant_override("h_separation", UIPalette.SP3)
		special_grid.add_theme_constant_override("v_separation", UIPalette.SP3)
		special_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		special_grid.columns = 2 if viewport_width() >= 1360.0 else 1
		_content_host.add_child(special_grid)
		for enemy in specials:
			special_grid.add_child(_enemy_card(enemy, UIPalette.faction_color(enemy.faction)))


# ---------------------------------------------------------------------------
# Planets and dungeons
# ---------------------------------------------------------------------------

func _build_planets() -> void:
	var planets := ContentDB.get_planets()
	_content_host.add_child(UIFactory.section_header("Planets", "%d FRONTIERS" % planets.size(), null, &"planet"))
	var grid := _make_grid(2 if viewport_width() >= 1360.0 else 1)
	_content_host.add_child(grid)
	for planet in planets:
		grid.add_child(_planet_card(planet))


func _planet_card(planet: Dictionary) -> PanelContainer:
	var planet_id := StringName(planet.get("id", &""))
	var accent: Color = planet.get("color", UIPalette.mint)
	var hazard := StringName(planet.get("hazard", &"none"))
	var card := UIFactory.panel("Card")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = "%s — %s\nHazard: %s\nBiomes: %s" % [
		String(planet.get("display_name", "Planet")),
		String(planet.get("subtitle", "")),
		_hazard_label(hazard),
		", ".join((planet.get("biome_names", []) as Array)),
	]
	var box := UIFactory.vbox(UIPalette.SP2)

	var head := UIFactory.hbox(UIPalette.SP2)
	var portrait := UIPlanetPortrait.new()
	portrait.configure(planet_id, 72, true)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(portrait)
	var title_box := UIFactory.vbox(2)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := UIFactory.hbox(UIPalette.SP2)
	name_row.add_child(UIFactory.display_text(String(planet.get("display_name", "Planet")), 22, 650, UIPalette.ivory))
	name_row.add_child(UIFactory.spacer_h())
	name_row.add_child(UIFactory.badge(_hazard_label(hazard), _hazard_color(hazard), _hazard_icon(hazard)))
	title_box.add_child(name_row)
	title_box.add_child(UIFactory.label(String(planet.get("subtitle", "")), "BodySmall", UIPalette.muted))
	var biomes := UIFactory.hbox(6)
	for biome_name in planet.get("biome_names", []):
		biomes.add_child(UIFactory.chip(String(biome_name), accent))
	title_box.add_child(biomes)
	head.add_child(title_box)
	box.add_child(head)

	var weather_row := HFlowContainer.new()
	weather_row.add_theme_constant_override("h_separation", UIPalette.SP3)
	weather_row.add_theme_constant_override("v_separation", UIPalette.SP1)
	for weather_id in planet.get("weather_pool", []):
		var weather: Dictionary = ContentDB.get_weather_def(StringName(weather_id))
		if weather.is_empty():
			continue
		var weather_chip := UIFactory.icon_value(
			StringName(weather.get("icon", &"weather-sun")),
			String(weather.get("display_name", "")),
			weather.get("color", UIPalette.muted),
			12
		)
		weather_chip.tooltip_text = _weather_tooltip(weather)
		weather_row.add_child(weather_chip)
	box.add_child(weather_row)

	var map_list := UIFactory.vbox(6)
	for preset in ContentDB.get_map_presets_for_planet(planet_id):
		map_list.add_child(_planet_map_row(preset, hazard))
	box.add_child(map_list)

	var themes := UIFactory.hbox(UIPalette.SP2)
	themes.add_child(UIFactory.icon_value(&"dungeon", "UNDER-REACH", UIPalette.violet, 12))
	for theme_id in planet.get("dungeon_themes", []):
		var theme: Dictionary = ContentDB.get_dungeon_theme(StringName(theme_id))
		if theme.is_empty():
			continue
		themes.add_child(UIFactory.chip(String(theme.get("display_name", "")), theme.get("accent", UIPalette.violet)))
	box.add_child(themes)
	card.add_child(box)
	return card


func _planet_map_row(preset: Dictionary, planet_hazard: StringName) -> HBoxContainer:
	var map_id := StringName(preset.get("id", &""))
	var hazard := _map_hazard(preset, planet_hazard)
	var row := UIFactory.hbox(UIPalette.SP2)
	row.tooltip_text = "%s — %s\nHazard: %s\nWeather pool: %s" % [
		String(preset.get("display_name", "Map")),
		String(preset.get("subtitle", "")),
		_hazard_label(hazard),
		_map_weather_text(preset),
	]
	var thumb := UIMapThumbnail.new()
	thumb.configure(map_id, Vector2(112, 63), true)
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(thumb)
	var info := UIFactory.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIFactory.label(String(preset.get("display_name", "Map")), "TitleLabel", UIPalette.ivory))
	info.add_child(UIFactory.label(String(preset.get("subtitle", "")), "Micro", UIPalette.muted))
	var chips := UIFactory.hbox(UIPalette.SP3)
	chips.add_child(_stat_icon(_hazard_icon(hazard), _hazard_label(hazard), _hazard_color(hazard), "Map hazard"))
	chips.add_child(_stat_icon(&"layers", "%d POI" % int(preset.get("extra_pois", 0)), UIPalette.muted_dim, "Extra points of interest"))
	info.add_child(chips)
	row.add_child(info)
	return row


# ---------------------------------------------------------------------------
# Weather
# ---------------------------------------------------------------------------

func _build_weather() -> void:
	var defs: Array = ContentDB.get_all_weather_defs()
	var header := UIFactory.section_header("Weather States", "%d ENVIRONMENTAL CONDITIONS" % defs.size(), null, &"weather-storm")
	header.tooltip_text = "Every authored weather state, its vision/movement modifiers, hazard tag and the planet pools it can roll in."
	_content_host.add_child(header)
	var grid := _make_grid()
	_content_host.add_child(grid)
	var planets := ContentDB.get_planets()
	for weather in defs:
		grid.add_child(_weather_card(weather, planets))


func _weather_card(weather: Dictionary, planets: Array) -> PanelContainer:
	var weather_id := StringName(weather.get("id", &""))
	var accent: Color = weather.get("color", UIPalette.mint)
	var hazard := StringName(weather.get("hazard", &"none"))
	var particle := StringName(weather.get("particle", &"none"))
	var used_on := _weather_planets(weather_id, planets)
	var card := UIFactory.panel("Card")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 148)
	card.tooltip_text = _weather_tooltip(weather) + "\nPlanet pools: " + used_on
	var box := UIFactory.vbox(UIPalette.SP2)

	var head := UIFactory.hbox(UIPalette.SP2)
	head.add_child(UIFactory.medallion(StringName(weather.get("icon", &"weather-sun")), 44, accent))
	var title_box := UIFactory.vbox(1)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_child(UIFactory.display_text(String(weather.get("display_name", "Weather")), 18, 650, accent))
	var tags := UIFactory.hbox(6)
	tags.add_child(UIFactory.badge(_hazard_label(hazard), _hazard_color(hazard), _hazard_icon(hazard)))
	tags.add_child(UIFactory.chip(String(particle).capitalize(), UIPalette.muted_dim))
	title_box.add_child(tags)
	head.add_child(title_box)
	box.add_child(head)

	var stats := UIFactory.hbox(UIPalette.SP3)
	stats.add_child(_stat_icon(&"eye", "%d%%" % int(round(float(weather.get("vision_mult", 1.0)) * 100.0)), UIPalette.mint, "Vision multiplier"))
	stats.add_child(_stat_icon(&"bolt", "%d%%" % int(round(float(weather.get("move_mult", 1.0)) * 100.0)), UIPalette.amber, "Movement multiplier"))
	stats.add_child(_stat_icon(&"weather-fog", "×%.1f" % float(weather.get("fog_mult", 1.0)), UIPalette.muted, "Fog density multiplier"))
	stats.add_child(_stat_icon(&"warning", "%d%%" % int(round(float(weather.get("lightning", 0.0)) * 100.0)), UIPalette.violet, "Lightning strike chance"))
	box.add_child(stats)

	var detail := UIFactory.hbox(UIPalette.SP3)
	detail.add_child(_stat_icon(_particle_icon(particle), "%s ×%d" % [String(particle).capitalize(), int(weather.get("particle_amount", 0))], accent, "Particle volume"))
	var planet_row := UIFactory.hbox(5)
	var planet_glyph := UIFactory.icon(&"planet", 12, UIPalette.violet)
	planet_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	planet_row.add_child(planet_glyph)
	var planet_label := UIFactory.label(used_on, "Micro", UIPalette.violet)
	planet_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	planet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	planet_row.add_child(planet_label)
	planet_row.tooltip_text = "Planet pools: " + used_on
	detail.add_child(planet_row)
	box.add_child(detail)
	card.add_child(box)
	return card


func _weather_planets(weather_id: StringName, planets: Array) -> String:
	var names: PackedStringArray = []
	for planet in planets:
		var pool: Array = planet.get("weather_pool", [])
		for pool_id in pool:
			if StringName(pool_id) == weather_id:
				names.append(String(planet.get("display_name", "Planet")))
				break
	return ", ".join(names) if not names.is_empty() else "No planet pool"


func _weather_tooltip(weather: Dictionary) -> String:
	var hazard := StringName(weather.get("hazard", &"none"))
	var particle := StringName(weather.get("particle", &"none"))
	return "Vision %d%% · Movement %d%% · Fog ×%.1f\nParticles: %s (%d) · Lightning %d%%\nHazard: %s" % [
		int(round(float(weather.get("vision_mult", 1.0)) * 100.0)),
		int(round(float(weather.get("move_mult", 1.0)) * 100.0)),
		float(weather.get("fog_mult", 1.0)),
		String(particle).capitalize(),
		int(weather.get("particle_amount", 0)),
		int(round(float(weather.get("lightning", 0.0)) * 100.0)),
		_hazard_label(hazard),
	]


func _particle_icon(particle: StringName) -> StringName:
	match particle:
		&"rain":
			return &"weather-rain"
		&"dust", &"smoke":
			return &"weather-fog"
		&"ash":
			return &"weather-ash"
		&"embers":
			return &"ember"
		&"spores":
			return &"weather-toxic"
		&"snow":
			return &"weather-snow"
		&"sparks":
			return &"weather-ion"
		_:
			return &"weather-sun"


# ---------------------------------------------------------------------------
# Operations: modes, contracts, target roster
# ---------------------------------------------------------------------------

func _build_operations() -> void:
	_build_game_modes()
	_build_contracts()
	_build_target_roster()


func _build_game_modes() -> void:
	var modes: Array = ContentDB.get_game_modes()
	var header := UIFactory.section_header("Game Modes", "%d DEPLOYMENT PACES" % modes.size(), null, &"timer")
	header.tooltip_text = "Selectable modes reshape the run clock, storm timing, enemy pressure and rewards."
	_content_host.add_child(header)
	var grid := _make_grid()
	_content_host.add_child(grid)
	for mode in modes:
		grid.add_child(_mode_card(mode))


func _mode_card(mode: Dictionary) -> PanelContainer:
	var mode_id := StringName(mode.get("id", &"normal"))
	var accent: Color = mode.get("color", UIPalette.mint)
	var card := UIFactory.panel("Card")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 148)
	var description := String(mode.get("description", ""))
	card.tooltip_text = description if not description.is_empty() else String(mode.get("tag", "Deployment mode"))
	var box := UIFactory.vbox(UIPalette.SP2)

	var head := UIFactory.hbox(UIPalette.SP2)
	head.add_child(UIFactory.medallion(StringName(mode.get("icon", &"timer")), 42, accent))
	var title_box := UIFactory.vbox(1)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_child(UIFactory.display_text(String(mode.get("display_name", "Normal")).to_upper(), 18, 650, UIPalette.ivory))
	title_box.add_child(UIFactory.label(String(mode.get("tag", "STANDARD")), "Micro", accent))
	head.add_child(title_box)
	box.add_child(head)

	var clock := ContentDB.get_mode_clock(mode_id)
	var time_row := UIFactory.hbox(UIPalette.SP4)
	time_row.add_child(_stat_icon(&"timer", clock, UIPalette.amber, "Run clock start"))
	time_row.add_child(_stat_icon(&"flag", UIPalette.format_duration(float(mode.get("run_duration", 1080.0))), UIPalette.muted, "Run duration"))
	time_row.add_child(_stat_icon(&"bolt", "×%.0f" % float(mode.get("time_scale", 1.0)), UIPalette.violet, "Clock speed"))
	box.add_child(time_row)

	var stats := UIFactory.hbox(UIPalette.SP3)
	stats.add_child(_stat_icon(&"users", "×%.2f" % float(mode.get("density_mult", 1.0)), UIPalette.amber, "Enemy density"))
	stats.add_child(_stat_icon(&"coins", "×%.2f" % float(mode.get("reward_mult", 1.0)), UIPalette.sun, "Reward multiplier"))
	stats.add_child(_stat_icon(&"star", "+%d%%" % int(round(float(mode.get("elite_bonus", 0.0)) * 100.0)), UIPalette.violet, "Elite chance"))
	box.add_child(stats)

	var extra := UIFactory.hbox(UIPalette.SP3)
	if int(mode.get("max_hostiles_delta", 0)) != 0:
		extra.add_child(_stat_icon(&"skull", "+%d" % int(mode.get("max_hostiles_delta", 0)), UIPalette.danger, "Extra simultaneous hostiles"))
	if float(mode.get("loot_bonus", 0.0)) > 0.0:
		extra.add_child(_stat_icon(&"cache", "+%d%%" % int(round(float(mode.get("loot_bonus", 0.0)) * 100.0)), UIPalette.mint, "Loot bonus"))
	if float(mode.get("storm_fraction", 0.0)) > 0.0:
		extra.add_child(_stat_icon(&"warning", "%d%% STORM" % int(round(float(mode.get("storm_fraction", 0.0)) * 100.0)), UIPalette.danger, "Storm starts at this fraction of the run"))
	if float(mode.get("start_time", -1.0)) >= 0.0:
		extra.add_child(_stat_icon(&"moon", "TOD %.2f" % float(mode.get("start_time", 0.0)), UIPalette.violet, "Start time of day"))
	if extra.get_child_count() > 0:
		box.add_child(extra)
	card.add_child(box)
	return card


func _build_contracts() -> void:
	var header := UIFactory.section_header(
		"Contracts",
		"%d OPERATION BRIEFS" % ContentDB.contracts.size(),
		null,
		&"flag"
	)
	header.tooltip_text = "Contracts define objectives, threat requirements, staged operations and reward bands."
	_content_host.add_child(header)
	var grid := _make_grid()
	_content_host.add_child(grid)
	var contracts: Array = ContentDB.contracts.values()
	contracts.sort_custom(func(a: ContractData, b: ContractData) -> bool:
		if a.required_threat == b.required_threat:
			return a.display_name < b.display_name
		return a.required_threat < b.required_threat
	)
	for contract in contracts:
		if contract is ContractData:
			grid.add_child(_contract_card(contract))


func _contract_card(contract: ContractData) -> PanelContainer:
	var accent: Color = contract.color
	var card := UIFactory.panel("Card")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 154)
	var lines: PackedStringArray = []
	if not contract.description.is_empty():
		lines.append(contract.description)
	if not contract.flavor.is_empty():
		lines.append(contract.flavor)
	lines.append("Objectives: %s" % _contract_objectives_text(contract))
	card.tooltip_text = "\n".join(lines)

	var box := UIFactory.vbox(UIPalette.SP2)
	var head := UIFactory.hbox(UIPalette.SP2)
	head.add_child(UIFactory.medallion(contract.icon, 40, accent))
	var title_box := UIFactory.vbox(1)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_child(UIFactory.display_text(contract.display_name, 18, 650, UIPalette.ivory))
	var tags := UIFactory.hbox(6)
	tags.add_child(UIFactory.badge("T%d" % contract.required_threat, _threat_color(contract.required_threat), &"skull"))
	if contract.is_staged():
		tags.add_child(UIFactory.badge("%d STAGES" % contract.stage_count(), UIPalette.mint, &"layers"))
	else:
		tags.add_child(UIFactory.badge("%d OBJECTIVES" % contract.objective_count(), UIPalette.muted, &"flag"))
	title_box.add_child(tags)
	head.add_child(title_box)
	box.add_child(head)

	var stages := UIFactory.hbox(UIPalette.SP3)
	if contract.is_staged():
		for stage in contract.stages:
			if not (stage is Dictionary):
				continue
			var stage_data := stage as Dictionary
			var stage_type := StringName(stage_data.get("type", &"cache"))
			var count := int(stage_data.get("count", 1))
			stages.add_child(_stat_icon(
				_stage_icon(stage_type),
				"×%d" % count,
				UIPalette.mint,
				String(stage_data.get("title", String(stage_type).capitalize()))
			))
	else:
		for type_name in contract.objective_types:
			var stage_type := StringName(type_name)
			stages.add_child(_stat_icon(_stage_icon(stage_type), String(stage_type).capitalize(), UIPalette.mint, "Objective"))
	box.add_child(stages)

	var rewards := UIFactory.hbox(UIPalette.SP3)
	rewards.add_child(_stat_icon(&"coins", UIPalette.format_int(contract.base_reward), UIPalette.amber, "Salvage reward"))
	rewards.add_child(_stat_icon(&"arrow-up", str(contract.xp_reward), UIPalette.mint, "XP reward"))
	if contract.core_reward > 0:
		rewards.add_child(_stat_icon(&"core", str(contract.core_reward), UIPalette.violet, "Core reward"))
	if contract.gear_rolls > 0:
		rewards.add_child(_stat_icon(&"cache", str(contract.gear_rolls), UIPalette.sun, "Gear rolls"))
	box.add_child(rewards)
	card.add_child(box)
	return card


func _build_target_roster() -> void:
	var elites: Array = ContentDB.get_elite_enemies()
	var bosses: Array = ContentDB.get_boss_enemies()
	var header := UIFactory.section_header(
		"Target Roster",
		"%d ELITES · %d BOSSES" % [elites.size(), bosses.size()],
		null,
		&"crosshair"
	)
	header.tooltip_text = "Every elite and boss signature in the Reach, tagged by faction sigil with role, health, damage and salvage."
	_content_host.add_child(header)

	if not elites.is_empty():
		_content_host.add_child(_subsection("Elite Signatures", &"star", UIPalette.amber))
		var elite_grid := _make_grid()
		_content_host.add_child(elite_grid)
		for enemy in elites:
			elite_grid.add_child(_target_card(enemy as EnemyData, false))

	if not bosses.is_empty():
		_content_host.add_child(_subsection("Boss Signatures", &"skull", UIPalette.danger))
		var boss_grid := _make_grid()
		_content_host.add_child(boss_grid)
		for enemy in bosses:
			boss_grid.add_child(_target_card(enemy as EnemyData, true))


func _target_card(enemy: EnemyData, boss: bool) -> PanelContainer:
	var accent := UIPalette.faction_color(enemy.faction)
	var card := UIFactory.panel("CardInset")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 120)
	card.tooltip_text = "%s — %s\n%s" % [
		enemy.display_name,
		String(enemy.role).capitalize(),
		_faction_blurb(enemy.faction),
	]
	var box := UIFactory.vbox(UIPalette.SP1)

	var head := UIFactory.hbox(UIPalette.SP2)
	head.add_child(UIFactory.medallion(_faction_icon(enemy.faction), 38, accent))
	var title_box := UIFactory.vbox(1)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_child(UIFactory.label(enemy.display_name, "TitleLabel", UIPalette.ivory))
	var tags := UIFactory.hbox(6)
	tags.add_child(UIFactory.badge("BOSS" if boss else "ELITE", UIPalette.danger if boss else UIPalette.amber, &"skull" if boss else &"star"))
	if boss and enemy.boss_phases > 1:
		tags.add_child(UIFactory.badge("%d PHASES" % enemy.boss_phases, UIPalette.violet, &"layers"))
	title_box.add_child(tags)
	head.add_child(title_box)
	box.add_child(head)

	var chips := UIFactory.hbox(UIPalette.SP3)
	chips.add_child(_stat_icon(&"target", String(enemy.role).capitalize(), accent, "Role"))
	chips.add_child(_stat_icon(&"heart-pulse", str(int(enemy.max_health)), UIPalette.mint, "Health"))
	chips.add_child(_stat_icon(&"crosshair", str(int(enemy.damage)), UIPalette.ivory, "Damage"))
	chips.add_child(_stat_icon(&"coins", str(enemy.salvage), UIPalette.amber, "Salvage"))
	box.add_child(chips)

	var extras := UIFactory.hbox(UIPalette.SP3)
	extras.add_child(_stat_icon(&"arrow-up", str(enemy.xp), UIPalette.mint, "XP"))
	extras.add_child(_stat_icon(&"bolt", "%.1f" % enemy.move_speed, UIPalette.muted, "Move speed"))
	if enemy.armor > 0.0:
		extras.add_child(_stat_icon(&"shield", str(int(enemy.armor)), UIPalette.blue, "Armor"))
	box.add_child(extras)
	card.add_child(box)
	return card


func _build_dungeons() -> void:
	_content_host.add_child(UIFactory.section_header("Under-Reach Dungeons", "", null, &"dungeon"))
	var grid := GridContainer.new()
	grid.add_theme_constant_override("h_separation", UIPalette.SP3)
	grid.add_theme_constant_override("v_separation", UIPalette.SP3)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = 2 if viewport_width() >= 1360.0 else 1
	_content_host.add_child(grid)
	for theme in ContentDB.get_dungeon_themes():
		var accent: Color = theme.get("accent", UIPalette.violet)
		var card := UIFactory.panel("Card")
		var box := UIFactory.vbox(UIPalette.SP2)
		var head := UIFactory.hbox(UIPalette.SP2)
		var glyph := UIFactory.icon_or_null(&"dungeon", 18, accent)
		if glyph != null:
			glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			head.add_child(glyph)
		head.add_child(UIFactory.display_text(String(theme.get("display_name", "Dungeon")), 21, 650, UIPalette.ivory))
		head.add_child(UIFactory.spacer_h())
		head.add_child(UIFactory.badge("UNDER-REACH", accent))
		box.add_child(head)
		box.add_child(UIFactory.label(String(theme.get("description", "")), "BodySmall", UIPalette.muted))
		var stats := UIFactory.hbox(UIPalette.SP4)
		stats.add_child(UIFactory.icon_value(&"layers", "%d–%d ROOMS" % [int(theme.get("room_min", 5)), int(theme.get("room_max", 8))], UIPalette.mint, 12))
		stats.add_child(UIFactory.icon_value(&"cache", "%d LOOT" % int(theme.get("loot_rolls", 3)), UIPalette.amber, 12))
		var boss: EnemyData = ContentDB.get_enemy(StringName(theme.get("boss_id", &"")))
		if boss != null:
			stats.add_child(UIFactory.icon_value(&"skull", boss.display_name.to_upper(), UIPalette.danger, 12))
		box.add_child(stats)
		var pool_names: PackedStringArray = []
		for enemy_id in theme.get("enemy_pool", []):
			var enemy: EnemyData = ContentDB.get_enemy(StringName(enemy_id))
			if enemy != null:
				pool_names.append(enemy.display_name)
		box.add_child(UIFactory.label("HOSTILES · " + ", ".join(pool_names), "Micro", UIPalette.muted_dim))
		card.add_child(box)
		grid.add_child(card)


# ---------------------------------------------------------------------------
# Shared card helpers
# ---------------------------------------------------------------------------

func _make_grid(columns: int = 0, separation: int = UIPalette.SP3) -> GridContainer:
	var grid := GridContainer.new()
	grid.add_theme_constant_override("h_separation", separation)
	grid.add_theme_constant_override("v_separation", separation)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = columns if columns > 0 else _grid_columns()
	return grid


func _subsection(title: String, icon_name: StringName, accent: Color) -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon_or_null(icon_name, 14, accent)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
	row.add_child(UIFactory.eyebrow(title, accent))
	return row


func _stat_icon(icon_name: StringName, value_text: String, accent: Color, tooltip: String) -> HBoxContainer:
	var row := UIFactory.icon_value(icon_name, value_text, accent, 12)
	row.tooltip_text = tooltip
	return row


func _stage_icon(stage_type: StringName) -> StringName:
	return STAGE_ICONS.get(stage_type, &"flag")


func _contract_objectives_text(contract: ContractData) -> String:
	var parts := PackedStringArray()
	if contract.is_staged():
		for stage in contract.stages:
			if stage is Dictionary:
				var stage_data := stage as Dictionary
				parts.append("%s ×%d" % [String(stage_data.get("type", "objective")).capitalize(), int(stage_data.get("count", 1))])
	else:
		for type_name in contract.objective_types:
			parts.append(String(type_name).capitalize())
	if parts.is_empty() and not contract.objective_label.is_empty():
		parts.append(contract.objective_label)
	return " → ".join(parts) if not parts.is_empty() else "Objective"


func _threat_color(threat: int) -> Color:
	match clampi(threat, 1, 4):
		1:
			return UIPalette.mint
		2:
			return UIPalette.blue
		3:
			return UIPalette.amber
		_:
			return UIPalette.danger


func _faction_icon(faction: StringName) -> StringName:
	return FACTION_ICONS.get(faction, &"skull")


func _faction_blurb(faction: StringName) -> String:
	match faction:
		&"ashen":
			return "Scavenger clans that strip the Reach for parts and grudges."
		&"bloom":
			return "A fast-growing alien ecology with teeth and opinions."
		&"choir":
			return "Signal-born constructs that believe the rift is a hymn."
		_:
			return ""


func _hazard_label(hazard: StringName) -> String:
	if hazard == &"none" or hazard == &"":
		return "STABLE"
	return String(hazard).replace("_", " ").to_upper()


func _hazard_color(hazard: StringName) -> Color:
	match hazard:
		&"heat":
			return UIPalette.amber
		&"cold", &"deep_water":
			return UIPalette.blue
		&"toxic":
			return UIPalette.mint
		&"rift":
			return UIPalette.violet
		_:
			return UIPalette.muted_dim


func _hazard_icon(hazard: StringName) -> StringName:
	match hazard:
		&"heat":
			return &"lava"
		&"cold":
			return &"weather-snow"
		&"toxic":
			return &"weather-toxic"
		&"deep_water":
			return &"water"
		&"rift":
			return &"weather-void"
		_:
			return &"shield-check"


func _map_hazard(preset: Dictionary, fallback: StringName) -> StringName:
	for weather_id in preset.get("weather_pool", []):
		var weather: Dictionary = ContentDB.get_weather_def(StringName(weather_id))
		var hazard := StringName(weather.get("hazard", &"none"))
		if hazard != &"none":
			return hazard
	return fallback


func _map_weather_text(preset: Dictionary) -> String:
	var pool: Array = preset.get("weather_pool", [])
	if pool.is_empty():
		pool = ContentDB.get_planet(StringName(preset.get("planet_id", &""))).get("weather_pool", [])
	var names := PackedStringArray()
	for weather_id in pool:
		var weather: Dictionary = ContentDB.get_weather_def(StringName(weather_id))
		if not weather.is_empty():
			names.append(String(weather.get("display_name", "")))
	return ", ".join(names) if not names.is_empty() else "None"


func _enemy_card(enemy: EnemyData, accent: Color) -> PanelContainer:
	var card := UIFactory.panel("CardInset")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UIFactory.vbox(UIPalette.SP2)
	var head := UIFactory.hbox(UIPalette.SP2)
	head.add_child(UIFactory.medallion(_faction_icon(enemy.faction), 28, UIPalette.faction_color(enemy.faction), 0.5, false))
	head.add_child(UIFactory.label(enemy.display_name, "TitleLabel"))
	head.add_child(UIFactory.spacer_h())
	if enemy.boss:
		head.add_child(UIFactory.badge("BOSS", UIPalette.danger))
	elif enemy.elite:
		head.add_child(UIFactory.badge("ELITE", UIPalette.amber))
	box.add_child(head)

	var stats := UIFactory.hbox(UIPalette.SP4)
	var role_row := UIFactory.icon_value(&"users", String(enemy.role).capitalize(), accent, 12)
	role_row.tooltip_text = "Role · %s" % ("ranged" if enemy.ranged else "melee")
	stats.add_child(role_row)
	var health_row := UIFactory.icon_value(&"heart-pulse", str(int(enemy.max_health)), accent, 12)
	health_row.tooltip_text = "Health"
	stats.add_child(health_row)
	var damage_row := UIFactory.icon_value(&"crosshair", str(int(enemy.damage)), UIPalette.ivory, 12)
	damage_row.tooltip_text = "Damage"
	stats.add_child(damage_row)
	box.add_child(stats)

	var rewards := UIFactory.hbox(UIPalette.SP4)
	var xp_row := UIFactory.icon_value(&"arrow-up", str(enemy.xp), UIPalette.mint, 11)
	xp_row.tooltip_text = "XP reward"
	rewards.add_child(xp_row)
	var loot_row := UIFactory.icon_value(&"coins", str(enemy.salvage), UIPalette.amber, 11)
	loot_row.tooltip_text = "Salvage"
	rewards.add_child(loot_row)
	var speed_row := UIFactory.icon_value(&"bolt", "%.1f" % enemy.move_speed, UIPalette.muted, 11)
	speed_row.tooltip_text = "Move speed"
	rewards.add_child(speed_row)
	box.add_child(rewards)
	card.add_child(box)
	return card


# ---------------------------------------------------------------------------
# Rift mods & mutators
# ---------------------------------------------------------------------------

func _build_rift_mods() -> void:
	var header := UIFactory.section_header("Rift Mods", "", null, &"bolt")
	header.tooltip_text = "Rift mods attach to a deployment and persist only for that run. Recovered mods are listed at extraction."
	_content_host.add_child(header)
	var grid := GridContainer.new()
	grid.add_theme_constant_override("h_separation", UIPalette.SP3)
	grid.add_theme_constant_override("v_separation", UIPalette.SP3)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = _grid_columns()
	_content_host.add_child(grid)
	for mod in ContentDB.rift_mods.values():
		var card := UIFactory.panel("Card")
		card.custom_minimum_size = Vector2(0, 104)
		card.tooltip_text = mod.description
		var box := UIFactory.vbox(UIPalette.SP2)
		var head := UIFactory.hbox(UIPalette.SP2)
		var glyph := UIFactory.icon(&"bolt", 15, mod.color)
		if glyph != null:
			head.add_child(glyph)
		head.add_child(UIFactory.label(mod.display_name, "TitleLabel", mod.color))
		head.add_child(UIFactory.spacer_h())
		head.add_child(UIFactory.badge(UIPalette.format_stat_value(mod.stat, mod.value), mod.color))
		box.add_child(head)
		card.add_child(box)
		grid.add_child(card)


func _build_mutators() -> void:
	var header := UIFactory.section_header("Mutators", "", null, &"warning")
	header.tooltip_text = "Mutators are optional deployment hazards. Each one raises threat and improves extraction rewards."
	_content_host.add_child(header)
	var grid := GridContainer.new()
	grid.add_theme_constant_override("h_separation", UIPalette.SP3)
	grid.add_theme_constant_override("v_separation", UIPalette.SP3)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = _grid_columns()
	_content_host.add_child(grid)
	for mutator in ContentDB.mutators.values():
		var card := UIFactory.panel("CardInset")
		card.custom_minimum_size = Vector2(0, 116)
		card.tooltip_text = mutator.description
		var box := UIFactory.vbox(UIPalette.SP2)
		var head := UIFactory.hbox(UIPalette.SP2)
		head.add_child(UIFactory.label(mutator.display_name, "TitleLabel", mutator.color))
		head.add_child(UIFactory.spacer_h())
		head.add_child(UIFactory.badge("+%d THREAT" % mutator.threat_bonus, mutator.color))
		box.add_child(head)
		var reward_line := UIFactory.hbox(UIPalette.SP4)
		var reward_row := UIFactory.icon_value(&"coins", "+%d%%" % int(round(mutator.reward_bonus * 100.0)), UIPalette.amber, 12)
		reward_row.tooltip_text = "Reward bonus"
		reward_line.add_child(reward_row)
		if mutator.enemy_health_mult > 1.0:
			var health_row := UIFactory.icon_value(&"heart-pulse", "+%d%%" % int(round((mutator.enemy_health_mult - 1.0) * 100.0)), UIPalette.danger, 12)
			health_row.tooltip_text = "Enemy health"
			reward_line.add_child(health_row)
		if mutator.enemy_damage_mult > 1.0:
			var damage_row := UIFactory.icon_value(&"crosshair", "+%d%%" % int(round((mutator.enemy_damage_mult - 1.0) * 100.0)), UIPalette.danger, 12)
			damage_row.tooltip_text = "Enemy damage"
			reward_line.add_child(damage_row)
		if mutator.elite_chance_bonus > 0.0:
			var elite_row := UIFactory.icon_value(&"star", "+%d%%" % int(round(mutator.elite_chance_bonus * 100.0)), UIPalette.violet, 12)
			elite_row.tooltip_text = "Elite chance"
			reward_line.add_child(elite_row)
		box.add_child(reward_line)
		card.add_child(box)
		grid.add_child(card)


# ---------------------------------------------------------------------------
# Field guide
# ---------------------------------------------------------------------------

func _build_guide() -> void:
	var header := UIFactory.section_header("Field Guide", "", null, &"map")
	_content_host.add_child(header)
	for note in NOTES:
		var card := UIFactory.panel("Card")
		card.tooltip_text = String(note.body)
		var row := UIFactory.hbox(UIPalette.SP3)
		var note_glyph := UIFactory.icon_or_null(StringName(note.icon), 18, UIPalette.amber)
		if note_glyph != null:
			note_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(note_glyph)
		row.add_child(UIFactory.heading(String(note.title), "H3"))
		card.add_child(row)
		_content_host.add_child(card)

	var controls_header := UIFactory.section_header("Controls", "", null, &"gamepad")
	controls_header.tooltip_text = "Default bindings. Bindings can be changed in Settings."
	_content_host.add_child(controls_header)
	var controls := UIFactory.panel("Card")
	var controls_box := UIFactory.vbox(UIPalette.SP2)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", UIPalette.SP5)
	grid.add_theme_constant_override("v_separation", UIPalette.SP2)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in CONTROLS:
		var cell := UIFactory.hbox(UIPalette.SP2)
		var glyph := UIFactory.icon_or_null(StringName(entry.icon), 13, UIPalette.muted_dim)
		if glyph != null:
			glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cell.add_child(glyph)
		cell.add_child(UIFactory.label(String(entry.label), "Micro"))
		cell.add_child(UIFactory.spacer_h())
		cell.add_child(UIFactory.label(String(entry.binding), "MonoValue"))
		grid.add_child(cell)
	controls_box.add_child(grid)
	controls.add_child(controls_box)
	_content_host.add_child(controls)


func _grid_columns() -> int:
	var width := viewport_width()
	if width >= 1900.0:
		return 4
	if width >= 1360.0:
		return 3
	return 2


func _layout() -> void:
	if _nav_rail != null and is_instance_valid(_nav_rail):
		_nav_rail.custom_minimum_size.x = UIPalette.rail_width(viewport_width())
	if _grid != null and is_instance_valid(_grid):
		_grid.columns = _grid_columns()


# ---------------------------------------------------------------------------
# Sites & rideables (0.3.0 content; ContentDB overlays live POISpecs/vehicle specs)
# ---------------------------------------------------------------------------

func _build_sites() -> void:
	var entries: Array = ContentDB.get_poi_codex_entries()
	var header := UIFactory.section_header("Points of Interest", "%d SITES" % entries.size(), null, &"outpost")
	header.tooltip_text = "Every authored POI kit: loot tier, hazard, garrison, radius, vehicle anchor and which cache table it rolls."
	_content_host.add_child(header)
	var grid := _make_grid()
	_content_host.add_child(grid)
	for entry in entries:
		grid.add_child(_site_card(entry))


func _site_card(entry: Dictionary) -> PanelContainer:
	var accent: Color = entry.get("color", UIPalette.mint)
	var card := UIFactory.panel("Card")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = String(entry.get("blurb", ""))
	var box := UIFactory.vbox(UIPalette.SP2)
	var head := UIFactory.hbox(UIPalette.SP2)
	head.add_child(UIFactory.medallion(StringName(entry.get("icon", &"outpost")), 42, accent))
	var title_box := UIFactory.vbox(1)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_child(UIFactory.display_text(String(entry.get("display_name", "Site")), 18, 650, UIPalette.ivory))
	var tags := UIFactory.hbox(6)
	tags.add_child(UIFactory.badge("%s LOOT" % String(entry.get("loot_tier_label", "Common")).to_upper(), accent, &"cache"))
	if bool(entry.get("interior", false)):
		tags.add_child(UIFactory.badge("INTERIOR", UIPalette.mint, &"home"))
	title_box.add_child(tags)
	head.add_child(title_box)
	box.add_child(head)
	box.add_child(UIFactory.label(String(entry.get("blurb", "")), "BodySmall", UIPalette.muted))
	var hazard_id := StringName(entry.get("hazard", &"none"))
	var stats := UIFactory.hbox(UIPalette.SP3)
	stats.add_child(_stat_icon(&"warning", _hazard_label(hazard_id), _hazard_color(hazard_id), "Hazard"))
	stats.add_child(_stat_icon(&"users", "%d GARRISON" % int(entry.get("garrison", 0)), UIPalette.amber, "Authored garrison"))
	stats.add_child(_stat_icon(&"layers", "%d m" % int(round(float(entry.get("radius", 0.0)))), UIPalette.muted, "POI radius"))
	var vehicle_id := StringName(entry.get("vehicle", &""))
	if vehicle_id != &"":
		stats.add_child(_stat_icon(&"bolt", String(vehicle_id).to_upper(), UIPalette.blue, "Vehicle anchor"))
	box.add_child(stats)
	box.add_child(UIFactory.label("CACHE · %s" % String(entry.get("loot_table", "poi_common")).to_upper(), "Micro", UIPalette.muted_dim))
	card.add_child(box)
	return card


func _build_rideables() -> void:
	var entries: Array = ContentDB.get_rideable_codex_entries()
	var header := UIFactory.section_header("Rideables", "%d VEHICLES" % entries.size(), null, &"grid")
	header.tooltip_text = "Rideable archetypes: seats, top speed, hull health and the stash table their cargo rolls from."
	_content_host.add_child(header)
	var grid := _make_grid()
	_content_host.add_child(grid)
	for entry in entries:
		grid.add_child(_rideable_card(entry))


func _rideable_card(entry: Dictionary) -> PanelContainer:
	var accent: Color = entry.get("color", UIPalette.mint)
	var card := UIFactory.panel("Card")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = String(entry.get("blurb", ""))
	var box := UIFactory.vbox(UIPalette.SP2)
	var head := UIFactory.hbox(UIPalette.SP2)
	head.add_child(UIFactory.medallion(StringName(entry.get("icon", &"grid")), 42, accent))
	var title_box := UIFactory.vbox(1)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_child(UIFactory.display_text(String(entry.get("display_name", "Rideable")), 18, 650, UIPalette.ivory))
	title_box.add_child(UIFactory.label(String(entry.get("kind", "vehicle")).to_upper(), "Micro", accent))
	head.add_child(title_box)
	box.add_child(head)
	box.add_child(UIFactory.label(String(entry.get("blurb", "")), "BodySmall", UIPalette.muted))
	var stats := UIFactory.hbox(UIPalette.SP3)
	stats.add_child(_stat_icon(&"users", "%d SEATS" % int(entry.get("seats", 1)), UIPalette.mint, "Seats"))
	stats.add_child(_stat_icon(&"bolt", "%d KM/H" % int(round(float(entry.get("max_speed", 0.0)) * 3.6)), UIPalette.amber, "Top speed"))
	stats.add_child(_stat_icon(&"shield", "%d HP" % int(entry.get("health", 0)), UIPalette.ivory, "Hull health"))
	box.add_child(stats)
	box.add_child(UIFactory.label("STASH · %s" % String(entry.get("stash_table", "vehicle_stash")).to_upper(), "Micro", UIPalette.muted_dim))
	card.add_child(box)
	return card
