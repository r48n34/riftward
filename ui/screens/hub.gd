class_name HubScreen
extends UIScreen
## Contract board and operations hub. Selection, named difficulty (each one owns
## a map preset), normal/quick mode and risk mutators all feed the real
## App.start_deployment(...) call; squad/outpost/records strips probe live
## ProfileState data.

const MODES := [
	{
		"id": &"normal", "name": "Normal", "sub": "18:00 RUN", "icon": &"timer",
		"tip": "Standard run clock: 18 minutes of Reach time. Movement and combat stay real-time.",
	},
	{
		"id": &"quick", "name": "Quick", "sub": "09:00 · ×2", "icon": &"bolt",
		"tip": "Everything runs twice as fast. Rewards are unchanged, but a quick clock doubles pressure per minute.",
	},
]

var _selected_contract: StringName = &""
var _difficulty_id: StringName = &""
var _mode_id: StringName = &""
var _mutators: Dictionary = {}
var _grid: GridContainer = null
var _hero_host: VBoxContainer = null
var _deploy_button: Button = null
var _board_host: VBoxContainer = null


func _compose() -> void:
	var backdrop := UIBackdrop.new()
	backdrop.configure(UIBackdrop.Mood.HUB)
	add_child(backdrop)

	var shell := build_hub_shell(&"hub", "Contract Board", "Waystation Kestrel — accept a contract, pick your risk, drop into the Reach.")
	var content: VBoxContainer = shell.content

	var scroll := UIFactory.vscroll()
	content.add_child(scroll)
	var body := UIFactory.scroll_content(scroll)
	body.add_theme_constant_override("separation", UIPalette.SP4)

	if _selected_contract == &"" or ContentDB.get_contract(_selected_contract) == null:
		_selected_contract = _default_contract_id()
	if _difficulty_id == &"" or ContentDB.get_difficulty(_difficulty_id).is_empty():
		_difficulty_id = ProfileState.get_last_difficulty()
		if ContentDB.get_difficulty(_difficulty_id).is_empty():
			_difficulty_id = &"patrol"
	if not (_mode_id in [&"normal", &"quick"]):
		_mode_id = ProfileState.get_last_mode()
	if not (_mode_id in [&"normal", &"quick"]):
		_mode_id = &"normal"

	_hero_host = UIFactory.vbox(0)
	body.add_child(_hero_host)
	_build_hero()

	_board_host = UIFactory.vbox(UIPalette.SP3)
	body.add_child(_board_host)
	_build_board()

	body.add_child(_build_strip())
	body.add_child(UIFactory.fixed_spacer(0, UIPalette.SP2))


# ---------------------------------------------------------------------------
# Hero / deploy console
# ---------------------------------------------------------------------------

func _build_hero() -> void:
	UIFactory.clear_children(_hero_host)
	var contract := ContentDB.get_contract(_selected_contract)
	if contract == null:
		_hero_host.add_child(UIFactory.empty_state(&"warning", "No contract data", "ContentDB returned no contracts. The contract board will populate once content is authored."))
		return

	var card := UIFactory.panel("CardRaised")
	var row := UIFactory.hbox(UIPalette.SP5)
	card.add_child(row)

	var left := UIFactory.vbox(UIPalette.SP2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UIFactory.hbox(UIPalette.SP2)
	top.add_child(UIFactory.eyebrow("Featured Contract", UIPalette.mint))
	top.add_child(UIFactory.divider(UIPalette.line, 1))
	top.add_child(UIFactory.label(String(contract.id).to_upper(), "Micro", UIPalette.muted_dim))
	left.add_child(top)

	var title := UIFactory.heading(contract.display_name, "H2")
	title.tooltip_text = _contract_tooltip(contract)
	left.add_child(title)

	var desc := UIFactory.label(contract.description, "BodySmall", UIPalette.muted)
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.tooltip_text = _contract_tooltip(contract)
	left.add_child(desc)

	var tags := UIFactory.hbox(UIPalette.SP2)
	tags.add_child(UIFactory.badge(contract.objective_label if not contract.objective_label.is_empty() else "Objective", UIPalette.blue, &"target"))
	tags.add_child(UIFactory.badge("THREAT %d+" % contract.required_threat, UIPalette.amber, &"warning"))
	if contract.gear_rolls > 0:
		tags.add_child(UIFactory.badge("%d GEAR ROLL%s" % [contract.gear_rolls, "" if contract.gear_rolls == 1 else "S"], UIPalette.violet, &"backpack"))
	left.add_child(tags)

	var rewards := UIFactory.hbox(UIPalette.SP5)
	rewards.add_child(UIFactory.stat_block(&"coins", "Salvage", UIPalette.format_int(contract.base_reward), UIPalette.amber, 18))
	rewards.add_child(UIFactory.stat_block(&"core", "Cores", str(contract.core_reward), UIPalette.violet, 18))
	rewards.add_child(UIFactory.stat_block(&"arrow-up", "Contract XP", str(contract.xp_reward), UIPalette.mint, 18))
	rewards.add_child(UIFactory.stat_block(&"flag", "Objectives", str(contract.objective_count()), UIPalette.ivory, 18))
	left.add_child(rewards)
	row.add_child(left)

	row.add_child(UIFactory.v_divider(UIPalette.line, 1))

	row.add_child(_build_deploy_console(contract))
	_hero_host.add_child(card)


func _contract_tooltip(contract: ContractData) -> String:
	var parts: PackedStringArray = []
	if not contract.description.is_empty():
		parts.append(contract.description)
	if not contract.flavor.is_empty():
		parts.append(contract.flavor)
	parts.append("Requires threat %d · %d objectives · %d gear roll%s" % [
		contract.required_threat,
		contract.objective_count(),
		contract.gear_rolls,
		"" if contract.gear_rolls == 1 else "s",
	])
	return "\n".join(parts)


func _build_deploy_console(contract: ContractData) -> VBoxContainer:
	var console := UIFactory.vbox(UIPalette.SP2)
	console.custom_minimum_size = Vector2(352, 0)

	console.add_child(UIFactory.eyebrow("Deployment Console"))
	console.add_child(UIFactory.label("DIFFICULTY & MAP", "StatLabel"))
	var difficulty_grid := GridContainer.new()
	difficulty_grid.columns = 2
	difficulty_grid.add_theme_constant_override("h_separation", 6)
	difficulty_grid.add_theme_constant_override("v_separation", 6)
	var difficulty_group := ButtonGroup.new()
	for difficulty in ContentDB.get_difficulties():
		difficulty_grid.add_child(_build_difficulty_card(difficulty, difficulty_group))
	console.add_child(difficulty_grid)

	console.add_child(UIFactory.label("GAME MODE", "StatLabel"))
	var mode_grid := GridContainer.new()
	mode_grid.columns = 2
	mode_grid.add_theme_constant_override("h_separation", 6)
	mode_grid.add_theme_constant_override("v_separation", 6)
	var mode_group := ButtonGroup.new()
	for mode in MODES:
		mode_grid.add_child(_build_mode_card(mode, mode_group))
	console.add_child(mode_grid)

	console.add_child(UIFactory.label("RISK MODIFIERS", "StatLabel"))
	var mutator_grid := GridContainer.new()
	mutator_grid.columns = 2
	mutator_grid.add_theme_constant_override("h_separation", 6)
	mutator_grid.add_theme_constant_override("v_separation", 5)
	var mutator_ids := ContentDB.mutators.keys()
	mutator_ids.sort()
	var shown := 0
	for mutator_id in mutator_ids:
		if shown >= 4:
			break
		var mutator: MutatorData = ContentDB.get_mutator(mutator_id)
		if mutator == null:
			continue
		shown += 1
		mutator_grid.add_child(_build_mutator_chip(mutator))
	console.add_child(mutator_grid)

	console.add_child(UIFactory.divider(UIPalette.line_soft))
	console.add_child(_build_console_summary())

	var deploy := UIFactory.deploy_button("DEPLOY TO THE REACH", &"exfil")
	_deploy_button = deploy
	deploy.custom_minimum_size = Vector2(0, 52)
	deploy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deploy.pressed.connect(_on_deploy_pressed)
	console.add_child(deploy)

	var lock_note := UIFactory.label(
		"Requires T%d · %s · %s" % [
			contract.required_threat,
			String(_difficulty().get("display_name", "Patrol")),
			_mode_clock_text(),
		],
		"Micro",
		UIPalette.muted_dim
	)
	lock_note.tooltip_text = "The selected contract needs at least threat %d. Deploying raises your threat if needed." % contract.required_threat
	console.add_child(lock_note)
	return console


func _build_difficulty_card(difficulty: Dictionary, group: ButtonGroup) -> Button:
	var difficulty_id := StringName(difficulty.get("id", &"patrol"))
	var accent: Color = difficulty.get("color", UIPalette.mint)
	var preset := ContentDB.get_map_preset(StringName(difficulty.get("map_preset", &"")))
	var card := UIFactory.card_button(true)
	card.button_group = group
	card.button_pressed = difficulty_id == _difficulty_id
	card.custom_minimum_size = Vector2(0, 96)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = String(difficulty.get("description", "")) + "\n" + String(preset.get("subtitle", ""))
	card.pressed.connect(func() -> void: _set_difficulty(difficulty_id))

	var content := UIFactory.card_content(card)
	if content == null:
		return card
	content.add_theme_constant_override("margin_left", 14)
	content.add_theme_constant_override("margin_top", 10)
	content.add_theme_constant_override("margin_right", 14)
	content.add_theme_constant_override("margin_bottom", 10)
	var box := UIFactory.vbox(3)

	var head := UIFactory.hbox(6)
	var glyph := UIFactory.icon_or_null(StringName(difficulty.get("icon", &"shield")), 16, accent)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(glyph)
	var name_label := UIFactory.display_text(String(difficulty.get("display_name", "Patrol")).to_upper(), 15, 650, UIPalette.ivory)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(name_label)
	head.add_child(UIFactory.label("T%d" % int(difficulty.get("threat", 1)), "Micro", accent))
	box.add_child(head)

	var map_row := UIFactory.hbox(5)
	var map_glyph := UIFactory.icon_or_null(&"map", 11, UIPalette.muted_dim)
	if map_glyph != null:
		map_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		map_row.add_child(map_glyph)
	var map_label := UIFactory.label(String(preset.get("display_name", "Verdant Verge")), "Micro", UIPalette.muted)
	map_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	map_row.add_child(map_label)
	map_row.add_child(UIFactory.pips(clampi(int(difficulty.get("threat", 1)), 1, 4), 4, accent, 4))
	box.add_child(map_row)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 6)
	stats.add_theme_constant_override("v_separation", 2)
	stats.add_child(_difficulty_stat(
		&"users",
		"×%.2f" % float(difficulty.get("density", 1.0)),
		UIPalette.amber,
		"Enemy density ×%.2f" % float(difficulty.get("density", 1.0))
	))
	stats.add_child(_difficulty_stat(
		&"star",
		"+%d%%" % int(round(float(difficulty.get("elite_bonus", 0.0)) * 100.0)),
		UIPalette.violet,
		"Elite chance +%d%%" % int(round(float(difficulty.get("elite_bonus", 0.0)) * 100.0))
	))
	stats.add_child(_difficulty_stat(
		&"flag",
		str(int(difficulty.get("mission_sites", 3))),
		UIPalette.mint,
		"%d contract objectives" % int(difficulty.get("mission_sites", 3))
	))
	stats.add_child(_difficulty_stat(
		&"coins",
		"×%.2f" % float(difficulty.get("reward", 1.0)),
		UIPalette.sun,
		"Reward multiplier ×%.2f" % float(difficulty.get("reward", 1.0))
	))
	box.add_child(stats)

	content.add_child(box)
	UIFactory.passive_tree(content)
	return card


func _difficulty_stat(icon_name: StringName, value_text: String, accent: Color, tooltip: String) -> HBoxContainer:
	var chip := UIFactory.icon_value(icon_name, value_text, accent, 11)
	chip.tooltip_text = tooltip
	return chip


func _build_mode_card(mode: Dictionary, group: ButtonGroup) -> Button:
	var mode_id := StringName(mode.get("id", &"normal"))
	var quick := mode_id == &"quick"
	var accent := UIPalette.amber if quick else UIPalette.mint
	var card := UIFactory.card_button(true)
	card.button_group = group
	card.button_pressed = mode_id == _mode_id
	card.custom_minimum_size = Vector2(0, 54)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = String(mode.get("tip", ""))
	card.pressed.connect(func() -> void: _set_mode(mode_id))
	var content := UIFactory.card_content(card)
	if content == null:
		return card
	content.add_theme_constant_override("margin_left", 12)
	content.add_theme_constant_override("margin_top", 8)
	content.add_theme_constant_override("margin_right", 12)
	content.add_theme_constant_override("margin_bottom", 8)
	var box := UIFactory.vbox(1)
	var head := UIFactory.hbox(6)
	var glyph := UIFactory.icon_or_null(StringName(mode.get("icon", &"timer")), 15, accent)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(glyph)
	head.add_child(UIFactory.display_text(String(mode.get("name", "Normal")), 14, 650, UIPalette.ivory))
	head.add_child(UIFactory.spacer_h())
	head.add_child(UIFactory.label("ACTIVE" if card.button_pressed else "", "Micro", accent))
	box.add_child(head)
	box.add_child(UIFactory.label(String(mode.get("sub", "")), "Micro", UIPalette.muted))
	content.add_child(box)
	UIFactory.passive_tree(content)
	return card


func _build_mutator_chip(mutator: MutatorData) -> Button:
	var mutator_id := mutator.id
	var chip := UIFactory.chip_button(mutator.display_name, bool(_mutators.get(mutator_id, false)))
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.custom_minimum_size = Vector2(0, 30)
	chip.tooltip_text = "%s\n+%d%% reward bonus" % [mutator.description, int(round(mutator.reward_bonus * 100.0))]
	var icon_name := _mutator_icon(mutator_id)
	var texture := UIIcons.get_icon(icon_name)
	if texture != null:
		chip.icon = texture
		chip.expand_icon = true
		chip.set("icon_max_width", 13)
	chip.toggled.connect(func(pressed: bool) -> void: _toggle_mutator(mutator_id, pressed))
	return chip


func _mutator_icon(mutator_id: StringName) -> StringName:
	var icons := {
		&"overcharged": &"bolt",
		&"ironhide": &"shield",
		&"hunter_season": &"skull",
		&"no_second_chances": &"warning",
		&"rich_reach": &"coins",
		&"low_gravity": &"arrow-up",
		&"early_storm": &"timer",
		&"swarm": &"users",
	}
	var icon_name: StringName = icons.get(StringName(mutator_id), &"warning")
	if not UIIcons.has_icon(icon_name):
		return &"warning"
	return icon_name


func _build_console_summary() -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP3)
	var difficulty := _difficulty()
	var reward_chip := UIFactory.icon_value(&"coins", "×%.2f" % float(difficulty.get("reward", 1.0)), UIPalette.amber, 12)
	reward_chip.tooltip_text = "Difficulty reward multiplier"
	row.add_child(reward_chip)
	var bonus := _reward_bonus_total()
	if bonus > 0.0:
		var bonus_chip := UIFactory.icon_value(&"bolt", "+%d%%" % int(round(bonus * 100.0)), UIPalette.mint, 12)
		bonus_chip.tooltip_text = "Risk modifier reward bonus"
		row.add_child(bonus_chip)
	var quick := _mode_id == &"quick"
	var mode_icon: StringName = &"bolt" if quick else &"timer"
	var mode_chip := UIFactory.icon_value(mode_icon, _mode_clock_text(), UIPalette.amber if quick else UIPalette.muted, 12)
	mode_chip.tooltip_text = "Run clock for the selected mode"
	row.add_child(mode_chip)
	row.add_child(UIFactory.spacer_h())
	row.add_child(UIFactory.label("RISK REWARD", "Micro", UIPalette.muted_dim))
	return row


func _mode_clock_text() -> String:
	return "09:00 · ×2" if _mode_id == &"quick" else "18:00"


func _difficulty() -> Dictionary:
	var difficulty := ContentDB.get_difficulty(_difficulty_id)
	if difficulty.is_empty():
		difficulty = ContentDB.get_difficulty_for_threat(1)
	return difficulty


func _difficulty_threat() -> int:
	return int(_difficulty().get("threat", 1))


# ---------------------------------------------------------------------------
# Contract board
# ---------------------------------------------------------------------------

func _build_board() -> void:
	UIFactory.clear_children(_board_host)
	var header := UIFactory.hbox(UIPalette.SP3)
	var text_box := UIFactory.vbox(2)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_child(UIFactory.eyebrow("Available Work", UIPalette.amber))
	text_box.add_child(UIFactory.heading("Select a Contract", "H2"))
	header.add_child(text_box)
	header.add_child(UIFactory.spacer_h())
	header.add_child(UIFactory.label("%d contracts · %d available" % [_contracts().size(), _available_contracts()], "BodySmall"))
	_board_host.add_child(header)

	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", UIPalette.SP3)
	_grid.add_theme_constant_override("v_separation", UIPalette.SP3)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_host.add_child(_grid)

	var group := ButtonGroup.new()
	for contract in _contracts():
		_grid.add_child(_build_contract_card(contract, group))


func _contracts() -> Array:
	var out: Array = ContentDB.get_contracts_for_threat(99)
	if out.is_empty():
		out = ContentDB.contracts.values()
	return out


func _available_contracts() -> int:
	var count := 0
	for contract in _contracts():
		if contract.required_threat <= _difficulty_threat():
			count += 1
	return count


func _build_contract_card(contract: ContractData, group: ButtonGroup) -> Button:
	var locked := contract.required_threat > _difficulty_threat()
	var selected := contract.id == _selected_contract
	var card := UIFactory.card_button(true)
	card.button_group = group
	card.button_pressed = selected
	card.custom_minimum_size = Vector2(0, 104)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = _contract_tooltip(contract)
	card.pressed.connect(func() -> void: _select_contract(contract.id))

	var content := UIFactory.card_content(card)
	if content == null:
		return card
	content.add_theme_constant_override("margin_left", 16)
	content.add_theme_constant_override("margin_top", 12)
	content.add_theme_constant_override("margin_right", 16)
	content.add_theme_constant_override("margin_bottom", 12)
	var box := UIFactory.vbox(UIPalette.SP2)

	var head := UIFactory.hbox(UIPalette.SP2)
	var title := UIFactory.heading(contract.display_name, "H3")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title)
	head.add_child(UIFactory.badge("T%d" % contract.required_threat, UIPalette.amber if not locked else UIPalette.muted_dim, &"warning"))
	box.add_child(head)

	var objective_row := UIFactory.hbox(6)
	var glyph := UIFactory.icon_or_null(&"target", 12, UIPalette.blue if not locked else UIPalette.muted_dim)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		objective_row.add_child(glyph)
	var objective_label := UIFactory.label(
		contract.objective_label.to_upper() if not contract.objective_label.is_empty() else "OBJECTIVE",
		"Micro",
		UIPalette.muted
	)
	objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objective_row.add_child(objective_label)
	objective_row.add_child(UIFactory.label("%d OBJ" % contract.objective_count(), "Micro", UIPalette.muted_dim))
	box.add_child(objective_row)

	var footer := UIFactory.hbox(UIPalette.SP3)
	footer.add_child(UIFactory.icon_value(&"coins", UIPalette.format_int(contract.base_reward), UIPalette.amber, 12))
	footer.add_child(UIFactory.icon_value(&"core", str(contract.core_reward), UIPalette.violet, 12))
	footer.add_child(UIFactory.icon_value(&"arrow-up", str(contract.xp_reward), UIPalette.mint, 12))
	footer.add_child(UIFactory.spacer_h())
	if locked:
		footer.add_child(UIFactory.icon_value(&"lock", "T%d+" % contract.required_threat, UIPalette.amber, 11))
	elif selected:
		footer.add_child(UIFactory.icon_value(&"check", "SELECTED", UIPalette.mint, 11))
	else:
		footer.add_child(UIFactory.label("SELECT", "Micro", UIPalette.muted_dim))
	box.add_child(footer)

	content.add_child(box)
	UIFactory.passive_tree(content)
	return card


# ---------------------------------------------------------------------------
# Bottom strip: squad / outpost / records live probes
# ---------------------------------------------------------------------------

func _build_strip() -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Squad
	var squad_rows: Array = []
	for ally_id in ProfileState.get_active_allies():
		var ally := ContentDB.get_ally(ally_id)
		if ally != null:
			squad_rows.append([ally.display_name, String(ally.role).capitalize()])
	var pet_id := ProfileState.get_active_pet()
	var pet := ContentDB.get_pet(pet_id)
	if pet != null:
		squad_rows.append([pet.display_name, "Driftling · " + String(pet.role).capitalize()])
	if squad_rows.is_empty():
		squad_rows.append(["No squad assigned", "Manage in Squad"])
	row.add_child(_strip_card(&"users", "Squad", "Field Team", UIPalette.mint, squad_rows, &"squad"))

	# Outpost
	var built := 0
	var modules := ProfileState.get_base_modules()
	for module_id in modules.keys():
		if int(modules[module_id]) > 0:
			built += 1
	var outpost_rows := [
		["Base power", str(ProfileState.get_base_power())],
		["Modules online", "%d / %d" % [built, modules.size()]],
		["Nexus tier", str(ProfileState.get_base_tier(&"command_nexus")) + " / 3"],
	]
	row.add_child(_strip_card(&"outpost", "Outpost", "Waystation Kestrel", UIPalette.amber, outpost_rows, &"outpost"))

	# Records
	var records := ProfileState.get_records()
	var record_rows := [
		["Deployments", str(int(records.get("deployments", 0)))],
		["Extractions", str(int(records.get("extractions", 0)))],
		["Best haul", UIPalette.format_int(int(records.get("best_extraction", 0)))],
	]
	row.add_child(_strip_card(&"book", "Records", "Warden Ledger", UIPalette.violet, record_rows, &"codex"))
	return row


func _strip_card(icon_name: StringName, eyebrow_text: String, title: String, accent: Color, rows: Array, target: StringName) -> Button:
	var card := UIFactory.card_button(false)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 140)
	card.pressed.connect(func() -> void: go(target))
	var content := UIFactory.card_content(card)
	if content == null:
		return card
	content.add_theme_constant_override("margin_left", 16)
	content.add_theme_constant_override("margin_top", 14)
	content.add_theme_constant_override("margin_right", 16)
	content.add_theme_constant_override("margin_bottom", 14)
	var box := UIFactory.vbox(7)
	var head := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon_or_null(icon_name, 15, accent)
	if glyph != null:
		head.add_child(glyph)
	head.add_child(UIFactory.label(eyebrow_text.to_upper(), "EyebrowMuted"))
	head.add_child(UIFactory.spacer_h())
	head.add_child(UIFactory.label("OPEN →", "Micro", accent))
	box.add_child(head)
	box.add_child(UIFactory.heading(title, "H3"))
	box.add_child(UIFactory.divider(UIPalette.line_soft))
	for entry in rows:
		var line := UIFactory.hbox(UIPalette.SP2)
		var name_label := UIFactory.label(String(entry[0]), "BodySmall")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.add_child(name_label)
		line.add_child(UIFactory.label(String(entry[1]), "MonoSmall", UIPalette.ivory))
		box.add_child(line)
	content.add_child(box)
	UIFactory.passive_tree(content)
	return card


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _default_contract_id() -> StringName:
	var contracts := _contracts()
	for contract in contracts:
		if contract.required_threat <= _difficulty_threat():
			return contract.id
	if not contracts.is_empty():
		return contracts[0].id
	return &"salvage_sweep"


func _select_contract(contract_id: StringName) -> void:
	if contract_id == _selected_contract:
		return
	_selected_contract = contract_id
	var contract := ContentDB.get_contract(contract_id)
	if contract != null and contract.required_threat > _difficulty_threat():
		var raised := ContentDB.get_difficulty_for_threat(contract.required_threat)
		if not raised.is_empty():
			_difficulty_id = StringName(raised.get("id", _difficulty_id))
	refresh()


func _set_difficulty(difficulty_id: StringName) -> void:
	if difficulty_id == _difficulty_id or ContentDB.get_difficulty(difficulty_id).is_empty():
		return
	_difficulty_id = difficulty_id
	refresh()


func _set_mode(mode_id: StringName) -> void:
	if mode_id == _mode_id or not (mode_id in [&"normal", &"quick"]):
		return
	_mode_id = mode_id
	ProfileState.set_last_mode(mode_id)
	refresh()


func _toggle_mutator(mutator_id: StringName, pressed: bool) -> void:
	_mutators[mutator_id] = pressed
	refresh()


func _reward_bonus_total() -> float:
	var total := 0.0
	for mutator_id in _mutators.keys():
		if not bool(_mutators[mutator_id]):
			continue
		var mutator: MutatorData = ContentDB.get_mutator(StringName(mutator_id))
		if mutator != null:
			total += mutator.reward_bonus
	return total


func _on_deploy_pressed() -> void:
	if App == null:
		return
	var contract := ContentDB.get_contract(_selected_contract)
	if contract == null:
		notify("Contract unavailable", "That contract could not be resolved from ContentDB.", &"error")
		return
	if _difficulty_threat() < contract.required_threat:
		var raised := ContentDB.get_difficulty_for_threat(contract.required_threat)
		if not raised.is_empty():
			_difficulty_id = StringName(raised.get("id", _difficulty_id))
	var threat := maxi(_difficulty_threat(), contract.required_threat)
	var mutator_ids: Array = []
	for mutator_id in _mutators.keys():
		if bool(_mutators[mutator_id]):
			mutator_ids.append(StringName(mutator_id))
	ProfileState.set_last_difficulty(_difficulty_id)
	ProfileState.set_last_mode(_mode_id)
	App.start_deployment(_selected_contract, 0, threat, mutator_ids, _difficulty_id, _mode_id)


func first_focus_control() -> Control:
	if _deploy_button != null and is_instance_valid(_deploy_button) and _deploy_button.is_inside_tree():
		return _deploy_button
	return super.first_focus_control()


# ---------------------------------------------------------------------------
# Responsive
# ---------------------------------------------------------------------------

func _layout() -> void:
	if _nav_rail != null and is_instance_valid(_nav_rail):
		_nav_rail.custom_minimum_size.x = UIPalette.rail_width(viewport_width())
	_layout_grid()


func _layout_grid() -> void:
	if _grid == null or not is_instance_valid(_grid):
		return
	var width := viewport_width()
	var columns := 3
	if width < 1480.0:
		columns = 2
	if width < 1120.0:
		columns = 1
	_grid.columns = columns
