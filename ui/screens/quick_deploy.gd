class_name QuickDeployScreen
extends UIScreen
## Quick Deploy preflight. The player picks a named difficulty (each one owns a
## map preset) and a game mode, then drops straight into the Reach.

const MODES := [
	{"id": &"normal", "name": "Normal", "sub": "FULL RUN · 18 MIN", "icon": &"timer", "icon_tip": "Standard run clock"},
	{"id": &"quick", "name": "Quick", "sub": "2× CLOCK · 9 MIN", "icon": &"bolt", "icon_tip": "Everything runs twice as fast"},
]

var _difficulty_id: StringName = &""
var _mode_id: StringName = &"normal"
var _grid: GridContainer = null
var _body: GridContainer = null
var _title: Label = null
var _difficulty_group: ButtonGroup = null
var _mode_group: ButtonGroup = null
var _deploy_button: Button = null


func _compose() -> void:
	_ensure_selection()
	var backdrop := UIBackdrop.new()
	backdrop.configure(UIBackdrop.Mood.HUB)
	add_child(backdrop)

	var page := build_page(UIPalette.SP4, UIPalette.SP5, UIPalette.SP4)

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

	# --- Header ------------------------------------------------------------
	var header := UIFactory.vbox(UIPalette.SP2)
	var eyebrow := UIFactory.hbox(6)
	var play_glyph := UIFactory.icon_or_null(&"play", 13, UIPalette.mint)
	if play_glyph != null:
		eyebrow.add_child(play_glyph)
	eyebrow.add_child(UIFactory.eyebrow("Preflight", UIPalette.mint))
	header.add_child(eyebrow)
	_title = UIFactory.display_text("QUICK DEPLOY", UIPalette.FONT_H1)
	header.add_child(_title)
	var overview := UIFactory.hbox(UIPalette.SP4)
	overview.add_child(UIFactory.icon_value(&"layers", "%d MAPS" % ContentDB.get_map_presets().size(), UIPalette.mint))
	overview.add_child(UIFactory.icon_value(&"flag", "3–6 OPERATIONS", UIPalette.ivory))
	overview.add_child(UIFactory.icon_value(&"timer", "18:00 / 9:00", UIPalette.amber))
	overview.add_child(UIFactory.icon_value(&"skull", "T1–T4", UIPalette.danger))
	header.add_child(overview)
	page.add_child(header)

	# --- Difficulty / map cards -------------------------------------------
	_difficulty_group = ButtonGroup.new()
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", UIPalette.SP3)
	_grid.add_theme_constant_override("v_separation", UIPalette.SP3)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for difficulty in ContentDB.get_difficulties():
		_grid.add_child(_build_difficulty_card(difficulty))
	page.add_child(_grid)

	# --- Mode + deploy console --------------------------------------------
	_body = GridContainer.new()
	_body.add_theme_constant_override("h_separation", UIPalette.SP4)
	_body.add_theme_constant_override("v_separation", UIPalette.SP4)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_build_mode_panel())
	_body.add_child(_build_deploy_panel())
	page.add_child(_body)

	page.add_child(UIFactory.help_note(
		"Icons carry the detail. Hover a card for the full briefing.",
		"Difficulty sets enemy density, elites, mission count, map mood, hazard timing and rewards. Quick mode doubles the run clock; movement and combat stay real-time.",
		&"info"
	))


func _ensure_selection() -> void:
	if _difficulty_id == &"" or ContentDB.get_difficulty(_difficulty_id).is_empty():
		_difficulty_id = ProfileState.get_last_difficulty()
		if ContentDB.get_difficulty(_difficulty_id).is_empty():
			var difficulties := ContentDB.get_difficulties()
			_difficulty_id = StringName(difficulties[0].get("id", &"patrol")) if not difficulties.is_empty() else &"patrol"
	if not (_mode_id in [&"normal", &"quick"]):
		_mode_id = ProfileState.get_last_mode()
	if not (_mode_id in [&"normal", &"quick"]):
		_mode_id = &"normal"


# ---------------------------------------------------------------------------
# Cards
# ---------------------------------------------------------------------------

func _build_difficulty_card(difficulty: Dictionary) -> Button:
	var difficulty_id := StringName(difficulty.get("id", &"patrol"))
	var accent: Color = difficulty.get("color", UIPalette.mint)
	var preset := ContentDB.get_map_preset(StringName(difficulty.get("map_preset", &"")))
	var card := UIFactory.card_button(true)
	card.button_group = _difficulty_group
	card.button_pressed = difficulty_id == _difficulty_id
	card.custom_minimum_size = Vector2(0, 148)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = String(difficulty.get("description", "")) + "\n" + String(preset.get("subtitle", ""))
	card.pressed.connect(func() -> void: _select_difficulty(difficulty_id))

	var content := UIFactory.card_content(card)
	if content == null:
		return card
	var box := UIFactory.vbox(UIPalette.SP2)

	var head := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon_or_null(StringName(difficulty.get("icon", &"shield")), 20, accent)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(glyph)
	var name_label := UIFactory.display_text(String(difficulty.get("display_name", "Patrol")).to_upper(), 19, 650, UIPalette.ivory)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(UIFactory.label("T%d" % int(difficulty.get("threat", 1)), "Micro", accent))
	box.add_child(head)

	var map_row := UIFactory.hbox(6)
	var map_glyph := UIFactory.icon_or_null(&"map", 12, UIPalette.muted_dim)
	if map_glyph != null:
		map_row.add_child(map_glyph)
	map_row.add_child(UIFactory.label(String(preset.get("display_name", "Verdant Verge")), "BodySmall", UIPalette.muted))
	map_row.add_child(UIFactory.spacer_h())
	map_row.add_child(UIFactory.pips(clampi(int(difficulty.get("threat", 1)), 1, 4), 4, accent, 5))
	box.add_child(map_row)

	var stats := UIFactory.hbox(UIPalette.SP3)
	stats.add_child(_stat_chip(&"users", "×%.2f" % float(difficulty.get("density", 1.0)), UIPalette.amber, "Enemy density"))
	stats.add_child(_stat_chip(&"star", "+%d%%" % int(round(float(difficulty.get("elite_bonus", 0.0)) * 100.0)), UIPalette.violet, "Elite chance"))
	stats.add_child(_stat_chip(&"flag", str(int(difficulty.get("mission_sites", 3))), UIPalette.mint, "Contract objectives"))
	stats.add_child(_stat_chip(&"coins", "×%.2f" % float(difficulty.get("reward", 1.0)), UIPalette.sun, "Reward multiplier"))
	box.add_child(stats)

	var sub := UIFactory.hbox(6)
	sub.add_child(UIFactory.icon_value(&"cache", "%d" % int(difficulty.get("side_caches", 4)), UIPalette.muted, 11))
	sub.add_child(UIFactory.icon_value(&"target", "%d" % int(difficulty.get("bounties", 1)), UIPalette.danger, 11))
	sub.add_child(UIFactory.icon_value(&"timer", "%d%%" % int(round(float(difficulty.get("storm_fraction", 0.667)) * 100.0)), UIPalette.muted, 11))
	sub.add_child(UIFactory.spacer_h())
	sub.add_child(UIFactory.label("SIDE OPS · STORM", "Micro", UIPalette.muted_dim))
	box.add_child(sub)

	content.add_child(box)
	UIFactory.passive_tree(content)
	return card


func _stat_chip(icon_name: StringName, value_text: String, accent: Color, tooltip: String) -> HBoxContainer:
	var row := UIFactory.icon_value(icon_name, value_text, accent, 12)
	row.tooltip_text = tooltip
	return row


func _build_mode_panel() -> PanelContainer:
	var card := UIFactory.panel("Card")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box := UIFactory.vbox(UIPalette.SP3)

	var head := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon_or_null(&"timer", 16, UIPalette.amber)
	if glyph != null:
		head.add_child(glyph)
	head.add_child(UIFactory.heading("Game Mode", "H3"))
	head.add_child(UIFactory.spacer_h())
	head.add_child(UIFactory.label("×%.0f CLOCK" % (2.0 if _mode_id == &"quick" else 1.0), "Micro", UIPalette.amber))
	box.add_child(head)

	_mode_group = ButtonGroup.new()
	var modes := GridContainer.new()
	modes.columns = 2
	modes.add_theme_constant_override("h_separation", UIPalette.SP2)
	modes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for mode in MODES:
		modes.add_child(_build_mode_card(mode))
	box.add_child(modes)
	box.add_child(UIFactory.help_note(
		"Quick runs are twice as fast; rewards are unchanged.",
		"Quick mode doubles the run clock, storm, exfil hold and event pacing. Player movement and combat remain real-time, so a 2x clock means twice the pressure per minute.",
		&"bolt"
	))
	card.add_child(box)
	return card


func _build_mode_card(mode: Dictionary) -> Button:
	var mode_id := StringName(mode.get("id", &"normal"))
	var is_quick := mode_id == &"quick"
	var accent := UIPalette.amber if is_quick else UIPalette.mint
	var card := UIFactory.card_button(true)
	card.button_group = _mode_group
	card.button_pressed = mode_id == _mode_id
	card.custom_minimum_size = Vector2(0, 82)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.pressed.connect(func() -> void: _select_mode(mode_id))
	var content := UIFactory.card_content(card)
	if content == null:
		return card
	var box := UIFactory.vbox(3)
	var head := UIFactory.hbox(8)
	var glyph := UIFactory.icon_or_null(StringName(mode.get("icon", &"timer")), 18, accent)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(glyph)
	head.add_child(UIFactory.display_text(String(mode.get("name", "Normal")), 17, 650, UIPalette.ivory))
	head.add_child(UIFactory.spacer_h())
	head.add_child(UIFactory.label("ACTIVE" if card.button_pressed else "", "Micro", accent))
	box.add_child(head)
	box.add_child(UIFactory.label(String(mode.get("sub", "")), "Micro", UIPalette.muted))
	content.add_child(box)
	UIFactory.passive_tree(content)
	return card


func _build_deploy_panel() -> PanelContainer:
	var card := UIFactory.panel("CardRaised")
	card.custom_minimum_size = Vector2(460, 0)
	var box := UIFactory.vbox(UIPalette.SP3)

	var head := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon_or_null(&"exfil", 16, UIPalette.mint)
	if glyph != null:
		head.add_child(glyph)
	head.add_child(UIFactory.heading("Deployment", "H3"))
	box.add_child(head)

	var difficulty := ContentDB.get_difficulty(_difficulty_id)
	var preset := ContentDB.get_map_preset(StringName(difficulty.get("map_preset", &"")))
	var contract := _pick_contract(int(difficulty.get("threat", 1)))
	box.add_child(_summary_row(&"flag", "Contract", contract.display_name if contract != null else "Salvage Sweep", UIPalette.ivory))
	box.add_child(_summary_row(&"map", "Map", String(preset.get("display_name", "Verdant Verge")), UIPalette.mint))
	box.add_child(_summary_row(&"skull", "Threat", "T%d · %s" % [int(difficulty.get("threat", 1)), String(difficulty.get("display_name", "Patrol"))], difficulty.get("color", UIPalette.amber)))
	box.add_child(_summary_row(&"layers", "Side ops", "%d caches · %d bounties · shrine" % [int(difficulty.get("side_caches", 4)), int(difficulty.get("bounties", 1))], UIPalette.muted))
	box.add_child(_summary_row(&"users", "Squad", "%d Wardens · %d Driftling" % [ProfileState.get_active_allies().size(), 1 if ProfileState.get_active_pet() != &"" else 0], UIPalette.muted))
	var clock := "09:00" if _mode_id == &"quick" else "18:00"
	box.add_child(_summary_row(&"timer", "Clock", "%s · %s" % [clock, "QUICK ×2" if _mode_id == &"quick" else "NORMAL"], UIPalette.amber))

	box.add_child(UIFactory.divider(UIPalette.line_soft))
	_deploy_button = UIFactory.quick_deploy_button("DEPLOY · " + String(difficulty.get("display_name", "Patrol")).to_upper(), &"play")
	_deploy_button.custom_minimum_size = Vector2(0, 72)
	_deploy_button.pressed.connect(_on_deploy_pressed)
	box.add_child(_deploy_button)
	box.add_child(UIFactory.help_note(
		"Drop is instant. No contract board required.",
		"Quick Deploy picks the strongest contract available at this threat and drops you near the objectives. Open the Hub if you want to customise the contract, mutators and difficulty manually.",
		&"info"
	))
	card.add_child(box)
	return card


func _summary_row(icon_name: StringName, label_text: String, value_text: String, accent: Color) -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon_or_null(icon_name, 13, accent)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
	var name_label := UIFactory.label(label_text, "BodySmall")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value := UIFactory.label(value_text, "MonoSmall", accent)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return row


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

func _select_difficulty(difficulty_id: StringName) -> void:
	if difficulty_id == _difficulty_id or ContentDB.get_difficulty(difficulty_id).is_empty():
		return
	_difficulty_id = difficulty_id
	refresh()


func _select_mode(mode_id: StringName) -> void:
	if mode_id == _mode_id:
		return
	_mode_id = mode_id
	refresh()


func _on_deploy_pressed() -> void:
	if App == null:
		return
	var difficulty := ContentDB.get_difficulty(_difficulty_id)
	if difficulty.is_empty():
		notify("Difficulty unavailable", "The selected difficulty could not be resolved.", &"error")
		return
	var threat := int(difficulty.get("threat", 1))
	var contract := _pick_contract(threat)
	ProfileState.set_last_difficulty(_difficulty_id)
	ProfileState.set_last_mode(_mode_id)
	App.start_deployment(contract.id, 0, threat, [], _difficulty_id, _mode_id)


func first_focus_control() -> Control:
	if _deploy_button != null and is_instance_valid(_deploy_button) and _deploy_button.is_inside_tree():
		return _deploy_button
	return super.first_focus_control()


# ---------------------------------------------------------------------------
# Responsive
# ---------------------------------------------------------------------------

func _layout() -> void:
	var width := viewport_width()
	if _grid != null and is_instance_valid(_grid):
		if width >= 1500.0:
			_grid.columns = 4
		elif width >= 1000.0:
			_grid.columns = 2
		else:
			_grid.columns = 1
	if _body != null and is_instance_valid(_body):
		_body.columns = 2 if width >= 1100.0 else 1
	if _title != null and is_instance_valid(_title):
		_title.add_theme_font_size_override("font_size", clampi(int(width * 0.030), 36, 54))
