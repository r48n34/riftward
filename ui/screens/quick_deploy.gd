class_name QuickDeployScreen
extends UIScreen
## Visual-first Quick Deploy preflight. The left column scopes difficulty, planet,
## map, game mode and forecast; the right deployment panel previews the exact drop
## and commits it through the same App.start_deployment(...) path as the Hub.

const DEPLOY_PANEL_WIDTH := 388

var _difficulty_id: StringName = &""
var _mode_id: StringName = &"normal"
var _map_id: StringName = &""
var _planet_id: StringName = &""

var _body: HBoxContainer = null
var _scroll: ScrollContainer = null
var _difficulty_grid: GridContainer = null
var _planet_grid: GridContainer = null
var _map_host: VBoxContainer = null
var _map_grid: GridContainer = null
var _mode_grid: GridContainer = null
var _weather_strip: HFlowContainer = null
var _deploy_panel: PanelContainer = null
var _title: Label = null
var _difficulty_group: ButtonGroup = null
var _planet_group: ButtonGroup = null
var _map_group: ButtonGroup = null
var _mode_group: ButtonGroup = null
var _deploy_button: Button = null
var _map_card_count := 0


func _compose() -> void:
	_ensure_selection()
	var backdrop := UIBackdrop.new()
	backdrop.configure(UIBackdrop.Mood.HUB)
	add_child(backdrop)

	var page := build_page(UIPalette.SP4, UIPalette.SP4, UIPalette.SP3)

	# --- Top bar -----------------------------------------------------------
	var top := UIFactory.hbox(UIPalette.SP3)
	var back := UIFactory.icon_button(&"chevron-left", "Back to menu")
	back.pressed.connect(func() -> void: go(&"main_menu"))
	top.add_child(back)
	top.add_child(UIFactory.spacer_h())
	top.add_child(wallet_row())
	var settings := UIFactory.icon_button(&"settings", "Settings")
	settings.pressed.connect(func() -> void: go(&"settings"))
	top.add_child(settings)
	page.add_child(top)

	page.add_child(_build_header())

	# --- Two-column body: scrolling picker | fixed deployment panel --------
	_body = UIFactory.hbox(UIPalette.SP4)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll = UIFactory.vscroll()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_scroll)
	var left := UIFactory.scroll_content(_scroll)
	left.add_theme_constant_override("separation", UIPalette.SP4)
	left.add_child(_build_difficulty_section())
	left.add_child(_build_planet_section())
	left.add_child(_build_mode_section())
	left.add_child(_build_forecast_section())
	_body.add_child(_build_deploy_panel())
	page.add_child(_body)


func _build_header() -> VBoxContainer:
	var header := UIFactory.vbox(UIPalette.SP2)
	var eyebrow := UIFactory.hbox(6)
	var play_glyph := UIFactory.icon_or_null(&"play", 13, UIPalette.mint)
	if play_glyph != null:
		eyebrow.add_child(play_glyph)
	eyebrow.add_child(UIFactory.eyebrow("Preflight", UIPalette.mint))
	header.add_child(eyebrow)
	_title = UIFactory.display_text("QUICK DEPLOY", UIPalette.FONT_H1)
	header.add_child(_title)
	var overview := UIFactory.hbox(UIPalette.SP5)
	overview.add_child(UIFactory.icon_value(&"layers", "%d MAPS" % ContentDB.get_map_presets().size(), UIPalette.mint))
	overview.add_child(UIFactory.icon_value(&"planet", "%d PLANETS" % ContentDB.get_planets().size(), UIPalette.violet))
	overview.add_child(UIFactory.icon_value(&"timer", "%d MODES" % ContentDB.get_game_modes().size(), UIPalette.amber))
	overview.add_child(UIFactory.icon_value(&"skull", "T1–T4", UIPalette.danger))
	header.add_child(overview)
	return header


func _section_header(icon_name: StringName, accent: Color, title_text: String, note: String = "") -> HBoxContainer:
	var head := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon_or_null(icon_name, 14, accent)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(glyph)
	head.add_child(UIFactory.eyebrow(title_text, accent))
	head.add_child(UIFactory.spacer_h())
	if not note.is_empty():
		head.add_child(UIFactory.label(note, "Micro", UIPalette.muted_dim))
	return head


# ---------------------------------------------------------------------------
# Selection state
# ---------------------------------------------------------------------------

func _ensure_selection() -> void:
	if _difficulty_id == &"" or ContentDB.get_difficulty(_difficulty_id).is_empty():
		_difficulty_id = ProfileState.get_last_difficulty()
		if ContentDB.get_difficulty(_difficulty_id).is_empty():
			var difficulties := ContentDB.get_difficulties()
			_difficulty_id = StringName(difficulties[0].get("id", &"patrol")) if not difficulties.is_empty() else &"patrol"
	if _mode_id == &"" or ContentDB.get_game_mode(_mode_id).is_empty():
		_mode_id = ProfileState.get_last_mode()
	if ContentDB.get_game_mode(_mode_id).is_empty():
		var modes := ContentDB.get_game_modes()
		_mode_id = StringName(modes[0].get("id", &"normal")) if not modes.is_empty() else &"normal"
	if _map_id == &"" or ContentDB.get_map_preset(_map_id).is_empty():
		_map_id = ProfileState.get_last_map()
		if _map_id == &"" or ContentDB.get_map_preset(_map_id).is_empty():
			_map_id = ContentDB.get_default_map_for_difficulty(_difficulty_id)
	var preset := ContentDB.get_map_preset(_map_id)
	_planet_id = StringName(preset.get("planet_id", &""))
	if _planet_id == &"":
		var planets := ContentDB.get_planets()
		_planet_id = StringName(planets[0].get("id", &"meridian_9")) if not planets.is_empty() else &"meridian_9"


func _selected_preset() -> Dictionary:
	var preset := ContentDB.get_map_preset(_map_id)
	if preset.is_empty():
		preset = ContentDB.get_map_preset(ContentDB.get_default_map_for_difficulty(_difficulty_id))
	return preset


func _select_difficulty(difficulty_id: StringName) -> void:
	if difficulty_id == _difficulty_id or ContentDB.get_difficulty(difficulty_id).is_empty():
		return
	_difficulty_id = difficulty_id
	# Selecting a difficulty restores its featured map unless the player picks
	# another one afterwards.
	_map_id = ContentDB.get_default_map_for_difficulty(difficulty_id)
	var preset := ContentDB.get_map_preset(_map_id)
	_planet_id = StringName(preset.get("planet_id", _planet_id))
	refresh()


func _select_mode(mode_id: StringName) -> void:
	if mode_id == _mode_id or ContentDB.get_game_mode(mode_id).is_empty():
		return
	_mode_id = mode_id
	refresh()


func _select_planet(planet_id: StringName) -> void:
	if planet_id == _planet_id:
		return
	var maps := ContentDB.get_map_presets_for_planet(planet_id)
	if maps.is_empty():
		return
	_planet_id = planet_id
	_map_id = StringName(maps[0].get("id", _map_id))
	refresh()


func _select_map(map_id: StringName) -> void:
	if map_id == _map_id or ContentDB.get_map_preset(map_id).is_empty():
		return
	_map_id = map_id
	_planet_id = StringName(ContentDB.get_map_preset(map_id).get("planet_id", _planet_id))
	refresh()


# ---------------------------------------------------------------------------
# Difficulty
# ---------------------------------------------------------------------------

func _build_difficulty_section() -> VBoxContainer:
	var section := UIFactory.vbox(UIPalette.SP2)
	section.add_child(_section_header(&"shield", UIPalette.amber, "Difficulty", "DENSITY · ELITES · OBJECTIVES · REWARD"))
	_difficulty_grid = GridContainer.new()
	_difficulty_grid.add_theme_constant_override("h_separation", UIPalette.SP2)
	_difficulty_grid.add_theme_constant_override("v_separation", UIPalette.SP2)
	_difficulty_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_difficulty_group = ButtonGroup.new()
	for difficulty in ContentDB.get_difficulties():
		_difficulty_grid.add_child(_build_difficulty_card(difficulty))
	section.add_child(_difficulty_grid)
	return section


func _build_difficulty_card(difficulty: Dictionary) -> Button:
	var difficulty_id := StringName(difficulty.get("id", &"patrol"))
	var accent: Color = difficulty.get("color", UIPalette.mint)
	var preset := ContentDB.get_map_preset(StringName(difficulty.get("map_preset", &"")))
	var card := UIFactory.card_button(true)
	card.button_group = _difficulty_group
	card.button_pressed = difficulty_id == _difficulty_id
	card.custom_minimum_size = Vector2(0, 158)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = "%s\n%s\nFeatured map: %s · T%d" % [
		String(difficulty.get("display_name", "Patrol")),
		String(difficulty.get("description", "")),
		String(preset.get("display_name", "—")),
		int(difficulty.get("threat", 1)),
	]
	card.pressed.connect(func() -> void: _select_difficulty(difficulty_id))
	var content := UIFactory.card_content(card)
	if content == null:
		return card
	content.add_theme_constant_override("margin_left", 14)
	content.add_theme_constant_override("margin_top", 12)
	content.add_theme_constant_override("margin_right", 14)
	content.add_theme_constant_override("margin_bottom", 12)
	var box := UIFactory.vbox(6)

	var head := UIFactory.hbox(8)
	var medallion := UIFactory.medallion(_safe_icon(StringName(difficulty.get("icon", &"shield")), &"shield"), 34, accent)
	medallion.tooltip_text = String(difficulty.get("description", ""))
	head.add_child(medallion)
	var titles := UIFactory.vbox(1)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UIFactory.display_text(String(difficulty.get("display_name", "Patrol")).to_upper(), 16, 650, UIPalette.ivory))
	var featured := UIFactory.label("T%d · %s" % [int(difficulty.get("threat", 1)), String(preset.get("display_name", "Featured"))], "Micro", accent)
	featured.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(featured)
	head.add_child(titles)
	head.add_child(UIFactory.pips(clampi(int(difficulty.get("threat", 1)), 1, 4), 4, accent, 6))
	box.add_child(head)

	var weather_row := UIFactory.hbox(4)
	var forecast := _forecast_weather(preset)
	var shown := 0
	for weather in forecast:
		if shown >= 5:
			break
		weather_row.add_child(_weather_chip(weather, false, 11))
		shown += 1
	if forecast.size() > shown:
		weather_row.add_child(UIFactory.label("+%d" % (forecast.size() - shown), "Micro", UIPalette.muted_dim))
	if weather_row.get_child_count() == 0:
		weather_row.add_child(UIFactory.label("FAIR SKIES", "Micro", UIPalette.muted_dim))
	box.add_child(weather_row)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 6)
	stats.add_theme_constant_override("v_separation", 2)
	stats.add_child(_stat_chip(&"users", "×%.2f" % float(difficulty.get("density", 1.0)), UIPalette.amber, "Enemy density"))
	stats.add_child(_stat_chip(&"star", "+%d%%" % int(round(float(difficulty.get("elite_bonus", 0.0)) * 100.0)), UIPalette.violet, "Elite chance"))
	stats.add_child(_stat_chip(&"flag", "%d OBJ" % int(difficulty.get("mission_sites", 3)), UIPalette.mint, "Contract objectives"))
	stats.add_child(_stat_chip(&"coins", "×%.2f" % float(difficulty.get("reward", 1.0)), UIPalette.sun, "Reward multiplier"))
	box.add_child(stats)

	content.add_child(box)
	UIFactory.passive_tree(content)
	return card


func _stat_chip(icon_name: StringName, value_text: String, accent: Color, tooltip: String) -> HBoxContainer:
	var row := UIFactory.icon_value(icon_name, value_text, accent, 12)
	row.tooltip_text = tooltip
	return row


# ---------------------------------------------------------------------------
# Planet & map
# ---------------------------------------------------------------------------

func _build_planet_section() -> VBoxContainer:
	var section := UIFactory.vbox(UIPalette.SP2)
	section.add_child(_section_header(&"planet", UIPalette.violet, "Planet & Map", "SELECT A LANDING ZONE"))

	_planet_grid = GridContainer.new()
	_planet_grid.add_theme_constant_override("h_separation", UIPalette.SP2)
	_planet_grid.add_theme_constant_override("v_separation", UIPalette.SP2)
	_planet_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_planet_group = ButtonGroup.new()
	for planet in ContentDB.get_planets():
		_planet_grid.add_child(_build_planet_card(planet))
	section.add_child(_planet_grid)

	_map_host = UIFactory.vbox(UIPalette.SP2)
	_map_grid = GridContainer.new()
	_map_grid.add_theme_constant_override("h_separation", UIPalette.SP2)
	_map_grid.add_theme_constant_override("v_separation", UIPalette.SP2)
	_map_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_group = ButtonGroup.new()
	_map_card_count = 0
	for preset in ContentDB.get_map_presets_for_planet(_planet_id):
		_map_grid.add_child(_build_map_card(preset))
		_map_card_count += 1
	if _map_card_count == 0:
		_map_host.add_child(UIFactory.empty_state(&"map", "No maps", "This planet has no authored map presets yet."))
	_map_host.add_child(_map_grid)
	section.add_child(_map_host)
	return section


func _build_planet_card(planet: Dictionary) -> Button:
	var planet_id := StringName(planet.get("id", &""))
	var accent: Color = planet.get("color", UIPalette.violet)
	var maps := ContentDB.get_map_presets_for_planet(planet_id)
	var card := UIFactory.card_button(true)
	card.button_group = _planet_group
	card.button_pressed = planet_id == _planet_id
	card.custom_minimum_size = Vector2(0, 88)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = "%s — %s\nHazard: %s\nBiomes: %s\n%d map presets" % [
		String(planet.get("display_name", "Planet")),
		String(planet.get("subtitle", "")),
		String(planet.get("hazard", "none")),
		", ".join(planet.get("biome_names", [])),
		maps.size(),
	]
	card.pressed.connect(func() -> void: _select_planet(planet_id))
	var content := UIFactory.card_content(card)
	if content == null:
		return card
	content.add_theme_constant_override("margin_left", 10)
	content.add_theme_constant_override("margin_top", 8)
	content.add_theme_constant_override("margin_right", 10)
	content.add_theme_constant_override("margin_bottom", 8)
	var row := UIFactory.hbox(10)
	var portrait := UIPlanetPortrait.new()
	portrait.configure(planet_id, 48, true)
	portrait.custom_minimum_size = Vector2(48, 48)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	var text := UIFactory.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var planet_name := UIFactory.display_text(String(planet.get("display_name", "Planet")), 15, 650, UIPalette.ivory)
	planet_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(planet_name)
	var subtitle := UIFactory.label(String(planet.get("subtitle", "")), "Micro", UIPalette.muted)
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(subtitle)
	var meta := UIFactory.hbox(6)
	var hazard := UIFactory.badge(String(planet.get("hazard", "none")).replace("_", " ").to_upper(), accent, _hazard_icon(String(planet.get("hazard", "none"))))
	hazard.tooltip_text = "Hazard: %s" % String(planet.get("hazard", "none"))
	meta.add_child(hazard)
	var map_chip := UIFactory.icon_value(&"map", "%d" % maps.size(), UIPalette.muted, 10)
	map_chip.tooltip_text = "%d map presets" % maps.size()
	meta.add_child(map_chip)
	text.add_child(meta)
	row.add_child(text)
	content.add_child(row)
	UIFactory.passive_tree(content)
	return card


func _build_map_card(preset: Dictionary) -> Button:
	var map_id := StringName(preset.get("id", &""))
	var card := UIFactory.card_button(true)
	card.button_group = _map_group
	card.button_pressed = map_id == _map_id
	card.custom_minimum_size = Vector2(0, 184)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = "%s — %s\nSeed salt %d · %d extra POIs · %d roadside targets" % [
		String(preset.get("display_name", "Map")),
		String(preset.get("subtitle", "")),
		int(preset.get("world_seed_salt", 0)),
		int(preset.get("extra_pois", 0)),
		int(preset.get("roadside_target", 14)),
	]
	card.pressed.connect(func() -> void: _select_map(map_id))
	var content := UIFactory.card_content(card)
	if content == null:
		return card
	content.add_theme_constant_override("margin_left", 10)
	content.add_theme_constant_override("margin_top", 10)
	content.add_theme_constant_override("margin_right", 10)
	content.add_theme_constant_override("margin_bottom", 10)
	var box := UIFactory.vbox(5)
	var thumb := UIMapThumbnail.new()
	thumb.configure(map_id, Vector2(180, 96))
	thumb.custom_minimum_size = Vector2(0, 96)
	thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(thumb)
	var title_row := UIFactory.hbox(6)
	var title := UIFactory.display_text(String(preset.get("display_name", "Map")), 14, 650, UIPalette.ivory)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_row.add_child(title)
	if map_id == _map_id:
		var check := UIFactory.icon_or_null(&"check", 13, UIPalette.mint)
		if check != null:
			title_row.add_child(check)
	box.add_child(title_row)
	var subtitle := UIFactory.label(String(preset.get("subtitle", "")), "Micro", UIPalette.muted)
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(subtitle)
	var weather_row := UIFactory.hbox(4)
	var forecast := _forecast_weather(ContentDB.get_map_preset(map_id))
	var shown := 0
	for weather in forecast:
		if shown >= 6:
			break
		weather_row.add_child(_weather_chip(weather, false, 11))
		shown += 1
	if forecast.size() > shown:
		weather_row.add_child(UIFactory.label("+%d" % (forecast.size() - shown), "Micro", UIPalette.muted_dim))
	box.add_child(weather_row)
	content.add_child(box)
	UIFactory.passive_tree(content)
	return card


# ---------------------------------------------------------------------------
# Game mode
# ---------------------------------------------------------------------------

func _build_mode_section() -> VBoxContainer:
	var section := UIFactory.vbox(UIPalette.SP2)
	section.add_child(_section_header(&"timer", UIPalette.amber, "Game Mode", "CLOCK · DENSITY · REWARD"))
	_mode_grid = GridContainer.new()
	_mode_grid.add_theme_constant_override("h_separation", UIPalette.SP2)
	_mode_grid.add_theme_constant_override("v_separation", UIPalette.SP2)
	_mode_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_group = ButtonGroup.new()
	for mode in ContentDB.get_game_modes():
		_mode_grid.add_child(_build_mode_card(mode))
	section.add_child(_mode_grid)
	return section


func _build_mode_card(mode: Dictionary) -> Button:
	var mode_id := StringName(mode.get("id", &"normal"))
	var accent: Color = mode.get("color", UIPalette.mint)
	var clock := ContentDB.get_mode_clock(mode_id)
	if clock.is_empty():
		clock = String(mode.get("clock", "--:--"))
	var card := UIFactory.card_button(true)
	card.button_group = _mode_group
	card.button_pressed = mode_id == _mode_id
	card.custom_minimum_size = Vector2(0, 116)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = String(mode.get("description", ""))
	card.pressed.connect(func() -> void: _select_mode(mode_id))
	var content := UIFactory.card_content(card)
	if content == null:
		return card
	content.add_theme_constant_override("margin_left", 14)
	content.add_theme_constant_override("margin_top", 12)
	content.add_theme_constant_override("margin_right", 14)
	content.add_theme_constant_override("margin_bottom", 12)
	var box := UIFactory.vbox(5)

	var head := UIFactory.hbox(8)
	head.add_child(UIFactory.medallion(_safe_icon(StringName(mode.get("icon", &"timer")), &"timer"), 30, accent))
	var titles := UIFactory.vbox(1)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UIFactory.display_text(_mode_name(mode), 16, 650, UIPalette.ivory))
	var tag := UIFactory.label(_mode_tag(mode), "Micro", accent)
	tag.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(tag)
	head.add_child(titles)
	var clock_label := UIFactory.label(clock, "MonoSmall", accent)
	clock_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(clock_label)
	box.add_child(head)

	var stats := UIFactory.hbox(UIPalette.SP3)
	stats.add_child(_stat_chip(&"users", "×%.2f" % float(mode.get("density_mult", 1.0)), UIPalette.amber, "Enemy density multiplier"))
	stats.add_child(_stat_chip(&"coins", "×%.2f" % float(mode.get("reward_mult", 1.0)), UIPalette.sun, "Reward multiplier"))
	stats.add_child(_stat_chip(&"star", "+%d%%" % int(round(float(mode.get("elite_bonus", 0.0)) * 100.0)), UIPalette.violet, "Elite chance"))
	box.add_child(stats)

	if card.button_pressed:
		var active := UIFactory.hbox(4)
		var check := UIFactory.icon_or_null(&"check", 11, accent)
		if check != null:
			active.add_child(check)
		active.add_child(UIFactory.label("ACTIVE DROP", "Micro", accent))
		box.add_child(active)

	content.add_child(box)
	UIFactory.passive_tree(content)
	return card


func _mode_name(mode: Dictionary) -> String:
	var out := String(mode.get("display_name", mode.get("name", ""))).strip_edges()
	return out if not out.is_empty() else "Mode"


func _mode_tag(mode: Dictionary) -> String:
	var out := String(mode.get("tag", "")).strip_edges()
	return out if not out.is_empty() else "STANDARD"


func _mode_clock_text() -> String:
	var mode := ContentDB.get_game_mode(_mode_id)
	var clock := ContentDB.get_mode_clock(_mode_id)
	if clock.is_empty():
		clock = String(mode.get("clock", "18:00"))
	var scale := float(mode.get("time_scale", 1.0))
	var text := clock
	if scale > 1.0:
		text += " · ×%.0f" % scale
	text += " · " + _mode_tag(mode)
	return text


# ---------------------------------------------------------------------------
# Weather
# ---------------------------------------------------------------------------

func _build_forecast_section() -> VBoxContainer:
	var preset := _selected_preset()
	var forecast := _forecast_weather(preset)
	var section := UIFactory.vbox(UIPalette.SP2)
	section.add_child(_section_header(&"weather-storm", UIPalette.blue, "Weather Forecast", "%d STATES · VISION · MOVE" % forecast.size()))
	_weather_strip = HFlowContainer.new()
	_weather_strip.add_theme_constant_override("h_separation", 6)
	_weather_strip.add_theme_constant_override("v_separation", 6)
	_weather_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if forecast.is_empty():
		_weather_strip.add_child(UIFactory.label("No weather pool authored for this map.", "BodySmall", UIPalette.muted_dim))
	for weather in forecast:
		_weather_strip.add_child(_weather_chip(weather, true, 15))
	section.add_child(_weather_strip)
	return section


## The map/planet pool resolved to weather definitions. get_map_preset() exposes
## every authored state in `weather_defs` (forced weather), so the forecast always
## prefers the map-specific `weather_pool`.
func _forecast_weather(preset: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pool: Array = preset.get("weather_pool", [])
	if not pool.is_empty():
		out = ContentDB.get_weather_defs_for_pool(pool)
	if out.is_empty():
		var defs = preset.get("weather_defs", [])
		if defs is Array:
			for entry in defs:
				if entry is Dictionary:
					out.append(entry)
	return out


func _weather_chip(weather: Dictionary, show_name: bool, icon_size: int = 14) -> PanelContainer:
	var accent: Color = weather.get("color", UIPalette.muted)
	var chip := UIFactory.panel("ChipPanel")
	chip.add_theme_stylebox_override(
		"panel",
		UITheme._box(UIPalette.alpha(accent, 0.08), UIPalette.alpha(accent, 0.35), UIPalette.R_CHIP, 1, Vector4(7, 3, 7, 3))
	)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.tooltip_text = _weather_tooltip(weather)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row := UIFactory.hbox(5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := UIFactory.icon_or_null(_safe_icon(StringName(weather.get("icon", &"weather-sun")), &"weather-sun"), icon_size, accent)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
	if show_name:
		row.add_child(UIFactory.label(String(weather.get("display_name", "Weather")), "Micro", accent))
	chip.add_child(row)
	return chip


func _weather_tooltip(weather: Dictionary) -> String:
	return "%s\nVision ×%.2f · Move ×%.2f\nHazard: %s" % [
		String(weather.get("display_name", "Weather")),
		float(weather.get("vision_mult", 1.0)),
		float(weather.get("move_mult", 1.0)),
		String(weather.get("hazard", "none")),
	]


# ---------------------------------------------------------------------------
# Deployment panel
# ---------------------------------------------------------------------------

func _build_deploy_panel() -> PanelContainer:
	var card := UIFactory.panel("CardRaised")
	_deploy_panel = card
	card.custom_minimum_size = Vector2(DEPLOY_PANEL_WIDTH, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_END
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.tooltip_text = "Quick Deploy commits this exact drop."
	var box := UIFactory.vbox(5)

	var head := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon_or_null(&"exfil", 16, UIPalette.mint)
	if glyph != null:
		head.add_child(glyph)
	head.add_child(UIFactory.heading("Deployment", "H3"))
	head.add_child(UIFactory.spacer_h())
	head.add_child(UIFactory.label("PREFLIGHT", "Micro", UIPalette.muted_dim))
	box.add_child(head)

	var difficulty := ContentDB.get_difficulty(_difficulty_id)
	var preset := _selected_preset()
	var map_id := StringName(preset.get("id", _map_id))
	var planet := ContentDB.get_planet(StringName(preset.get("planet_id", &"")))
	var accent: Color = preset.get("color", UIPalette.mint)

	var thumb := UIMapThumbnail.new()
	thumb.configure(map_id, Vector2(DEPLOY_PANEL_WIDTH - 44, 92))
	thumb.custom_minimum_size = Vector2(0, 92)
	thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.tooltip_text = String(preset.get("display_name", "Map"))
	box.add_child(thumb)

	var planet_row := UIFactory.hbox(8)
	var portrait := UIPlanetPortrait.new()
	portrait.configure(StringName(preset.get("planet_id", &"")), 32, false)
	portrait.custom_minimum_size = Vector2(32, 32)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	planet_row.add_child(portrait)
	var planet_text := UIFactory.vbox(1)
	planet_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var planet_name := UIFactory.display_text(String(planet.get("display_name", "Planet")), 15, 650, UIPalette.violet)
	planet_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	planet_text.add_child(planet_name)
	var map_line := UIFactory.label("%s · %s" % [String(preset.get("display_name", "Map")), String(preset.get("subtitle", ""))], "Micro", UIPalette.muted)
	map_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	planet_text.add_child(map_line)
	planet_row.add_child(planet_text)
	box.add_child(planet_row)

	box.add_child(UIFactory.divider(UIPalette.line_soft))

	var contract := _pick_contract(int(difficulty.get("threat", 1)))
	if contract == null:
		box.add_child(UIFactory.hint_row(&"warning", "No contracts available at this threat.", UIPalette.danger))
	else:
		box.add_child(_build_contract_mission(contract, accent))

	var summary_box := UIFactory.vbox(2)
	summary_box.add_child(_summary_row(&"map", "Map", String(preset.get("display_name", "Map")), UIPalette.mint))
	summary_box.add_child(_summary_row(&"planet", "Planet", String(planet.get("display_name", "Planet")), UIPalette.violet))
	summary_box.add_child(_summary_row(&"layers", "Side ops", "%d caches · %d bounties" % [int(difficulty.get("side_caches", 4)), int(difficulty.get("bounties", 1))], UIPalette.muted))
	summary_box.add_child(_summary_row(&"users", "Squad", "%d Wardens · %d Driftling" % [ProfileState.get_active_allies().size(), 1 if ProfileState.get_active_pet() != &"" else 0], UIPalette.muted))
	summary_box.add_child(_summary_row(&"timer", "Clock", _mode_clock_text(), UIPalette.amber))
	box.add_child(summary_box)

	box.add_child(_build_target_intel())
	box.add_child(UIFactory.divider(UIPalette.line_soft))

	_deploy_button = UIFactory.quick_deploy_button("DEPLOY · " + String(difficulty.get("display_name", "Patrol")).to_upper(), &"play")
	_deploy_button.custom_minimum_size = Vector2(0, 56)
	_deploy_button.disabled = contract == null
	_deploy_button.pressed.connect(_on_deploy_pressed)
	box.add_child(_deploy_button)
	box.add_child(UIFactory.help_note(
		"Drop is instant. No contract board required.",
		"Quick Deploy auto-picks the strongest contract available at this threat, keeps your last loadout and squad, and drops you near the objectives. Open the Hub to customise the contract, mutators and difficulty manually.",
		&"info"
	))
	card.add_child(box)
	return card


func _build_contract_mission(contract: ContractData, preset_accent: Color) -> PanelContainer:
	var accent: Color = contract.color if contract != null else preset_accent
	var card := UIFactory.tinted_panel(UIPalette.alpha(accent, 0.07), UIPalette.alpha(accent, 0.4), UIPalette.R_MD)
	card.tooltip_text = "%s\n%s\n%d objectives · %s salvage · %s cores" % [
		contract.display_name,
		contract.description,
		contract.objective_count(),
		UIPalette.format_int(contract.base_reward),
		UIPalette.format_int(contract.core_reward),
	]
	var row := UIFactory.hbox(8)
	row.add_child(UIFactory.medallion(_safe_icon(contract.icon, &"flag"), 34, accent))
	var text := UIFactory.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UIFactory.label("CONTRACT", "Micro", UIPalette.muted_dim))
	var title := UIFactory.display_text(contract.display_name, 15, 650, UIPalette.ivory)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(title)
	var chips := UIFactory.hbox(UIPalette.SP3)
	chips.add_child(UIFactory.icon_value(&"warning", "T%d+" % contract.required_threat, UIPalette.amber, 10))
	chips.add_child(UIFactory.icon_value(&"flag", "%d OBJ" % contract.objective_count(), UIPalette.mint, 10))
	chips.add_child(UIFactory.icon_value(&"coins", UIPalette.format_int(contract.base_reward), UIPalette.sun, 10))
	text.add_child(chips)
	row.add_child(text)
	card.add_child(row)
	return card


func _summary_row(icon_name: StringName, label_text: String, value_text: String, accent: Color) -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon_or_null(icon_name, 12, accent)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
	var name_label := UIFactory.label(label_text, "BodySmall")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value := UIFactory.label(value_text, "MonoSmall", accent)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.custom_minimum_size.x = 200
	row.add_child(value)
	return row


func _build_target_intel() -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon_or_null(&"skull", 12, UIPalette.danger)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
	row.add_child(UIFactory.label("TARGET INTEL", "Micro", UIPalette.muted_dim))
	var elites := ContentDB.get_elite_enemies()
	var bosses := ContentDB.get_boss_enemies()
	var elite_chip := UIFactory.icon_value(&"star", "%d ELITES" % elites.size(), UIPalette.violet, 10)
	elite_chip.tooltip_text = "%d elite and %d boss signatures active in the Reach" % [elites.size(), bosses.size()]
	row.add_child(elite_chip)
	row.add_child(UIFactory.spacer_h())
	for faction in _target_factions(elites, bosses):
		var sigil := UIFactory.medallion(_faction_icon(faction), 20, UIPalette.faction_color(faction))
		sigil.tooltip_text = "%s targets" % String(faction).capitalize()
		row.add_child(sigil)
	return row


func _target_factions(elites: Array, bosses: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for enemy in elites:
		if enemy == null:
			continue
		var faction := StringName(enemy.faction)
		if not (faction in out):
			out.append(faction)
	for enemy in bosses:
		if enemy == null:
			continue
		var faction := StringName(enemy.faction)
		if not (faction in out):
			out.append(faction)
	return out


func _faction_icon(faction: StringName) -> StringName:
	var icon := StringName("faction-%s" % String(faction))
	return icon if UIIcons.has_icon(icon) else &"skull"


func _hazard_icon(hazard: String) -> StringName:
	var mapping := {
		"cold": &"weather-snow",
		"heat": &"lava",
		"toxic": &"weather-toxic",
		"rift": &"riftward_icon",
		"storm": &"weather-storm",
	}
	var icon: StringName = mapping.get(hazard.to_lower(), &"shield")
	return _safe_icon(icon, &"warning")


func _safe_icon(icon_name: StringName, fallback: StringName) -> StringName:
	if UIIcons.has_icon(icon_name):
		return icon_name
	return fallback if UIIcons.has_icon(fallback) else &"bolt"


func _pick_contract(threat: int) -> ContractData:
	var contracts := ContentDB.get_contracts_for_threat(threat)
	if contracts.is_empty():
		return ContentDB.get_contract(&"salvage_sweep")
	var highest := 0
	for contract in contracts:
		highest = maxi(highest, contract.required_threat)
	var pool: Array = []
	for contract in contracts:
		if contract.required_threat == highest:
			pool.append(contract)
	if pool.is_empty():
		return contracts[0]
	var index := absi(String(_difficulty_id).hash()) % pool.size()
	return pool[index] as ContractData


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _on_deploy_pressed() -> void:
	if App == null:
		return
	var difficulty := ContentDB.get_difficulty(_difficulty_id)
	if difficulty.is_empty():
		notify("Difficulty unavailable", "The selected difficulty could not be resolved.", &"error")
		return
	var threat := int(difficulty.get("threat", 1))
	var contract := _pick_contract(threat)
	if contract == null:
		notify("No contract available", "No contract can be resolved at this threat.", &"error")
		return
	ProfileState.set_last_difficulty(_difficulty_id)
	ProfileState.set_last_mode(_mode_id)
	ProfileState.set_last_map(_map_id)
	App.start_deployment(contract.id, 0, threat, [], _difficulty_id, _mode_id, _map_id)


func first_focus_control() -> Control:
	if _deploy_button != null and is_instance_valid(_deploy_button) and _deploy_button.is_inside_tree():
		return _deploy_button
	return super.first_focus_control()


func get_selected_map_id() -> StringName:
	_ensure_selection()
	return _map_id


func get_selected_planet_id() -> StringName:
	_ensure_selection()
	return _planet_id


## Test accessors used by the UI suite.
func get_mode_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for mode in ContentDB.get_game_modes():
		out.append(StringName(mode.get("id", &"")))
	return out


func get_map_card_count() -> int:
	if _map_card_count > 0:
		return _map_card_count
	_ensure_selection()
	return ContentDB.get_map_presets_for_planet(_planet_id).size()


# ---------------------------------------------------------------------------
# Responsive + scroll behaviour
# ---------------------------------------------------------------------------

func preserve_scroll_on_refresh() -> bool:
	return true


func _layout() -> void:
	var width := viewport_width()
	if _difficulty_grid != null and is_instance_valid(_difficulty_grid):
		_difficulty_grid.columns = 4 if width >= 1500.0 else (2 if width >= 1000.0 else 1)
	if _planet_grid != null and is_instance_valid(_planet_grid):
		_planet_grid.columns = 5 if width >= 1500.0 else (3 if width >= 1000.0 else 1)
	if _map_grid != null and is_instance_valid(_map_grid):
		_map_grid.columns = 4 if width >= 1500.0 else (2 if width >= 1000.0 else 1)
	if _mode_grid != null and is_instance_valid(_mode_grid):
		_mode_grid.columns = 3 if width >= 1500.0 else (2 if width >= 1000.0 else 1)
	if _title != null and is_instance_valid(_title):
		_title.add_theme_font_size_override("font_size", clampi(int(width * 0.030), 36, 54))
