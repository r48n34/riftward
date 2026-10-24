class_name ResultsScreen
extends Control
## Extraction / death summary. Reads the result dictionary produced by RunState,
## which App records into ProfileState before showing this screen.

var _content: VBoxContainer = null
var _scrim: ColorRect = null
var _result: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var backdrop := UIBackdrop.new()
	backdrop.configure(UIBackdrop.Mood.HUB)
	add_child(backdrop)
	_scrim = ColorRect.new()
	_scrim.color = UIPalette.alpha(UIPalette.ink, 0.62)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", UIPalette.SP6)
	margin.add_theme_constant_override("margin_right", UIPalette.SP6)
	margin.add_theme_constant_override("margin_top", UIPalette.SP5)
	margin.add_theme_constant_override("margin_bottom", UIPalette.SP5)
	add_child(margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)
	_content = UIFactory.vbox(UIPalette.SP4)
	_content.custom_minimum_size = Vector2(900, 0)
	center.add_child(_content)


# ---------------------------------------------------------------------------
# API
# ---------------------------------------------------------------------------

func present(result: Dictionary) -> void:
	_result = result if result != null else {}
	visible = true
	_rebuild()
	UIFactory.animate_in(self)
	var progression: Dictionary = _result.get("progression", {})
	if int(progression.get("levels_gained", 0)) > 0:
		AudioDirector.play_ui(&"level_up")


func _rebuild() -> void:
	if _content == null:
		return
	UIFactory.clear_children(_content)
	var extracted := bool(_result.get("extracted", false))
	var accent := UIPalette.mint if extracted else UIPalette.danger
	# Single outcome headline. The seal, subtitle and summary duplicate are gone.
	var headline := "EXTRACTION CONFIRMED" if extracted else "SIGNAL LOST"
	var icon_name: StringName = &"exfil" if extracted else &"warning"

	var header := UIFactory.hbox(UIPalette.SP4)
	var glyph := UIFactory.icon_or_null(icon_name, 36, accent)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(glyph)
	var text_box := UIFactory.vbox(2)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_child(UIFactory.display_text(headline, 44, 650, UIPalette.ivory))
	header.add_child(text_box)
	header.tooltip_text = String(_result.get("reason", "Deployment ended."))
	_content.add_child(header)

	_content.add_child(_meta_row(accent))
	_content.add_child(_body_row(extracted, accent))
	_content.add_child(_progression_card(accent))
	_content.add_child(UIFactory.divider(UIPalette.line_soft))
	_content.add_child(_ledger_row())
	_content.add_child(_actions_row())


# ---------------------------------------------------------------------------
# Run identity
# ---------------------------------------------------------------------------

func _meta_row(accent: Color) -> PanelContainer:
	var card := UIFactory.tone_panel(accent, UIPalette.R_MD)
	card.add_theme_stylebox_override(
		"panel",
		UITheme._box(UIPalette.alpha(accent, 0.06), UIPalette.alpha(accent, 0.4), UIPalette.R_MD, 1, Vector4(18, 12, 18, 12))
	)
	var row := UIFactory.hbox(UIPalette.SP4)
	var contract := ContentDB.get_contract(StringName(_result.get("contract_id", "")))
	row.add_child(_meta(
		&"flag",
		contract.display_name if contract != null else String(_result.get("contract_id", "Unknown")),
		"Contract",
		UIPalette.ivory
	))
	row.add_child(UIFactory.v_divider(UIPalette.alpha(accent, 0.35)))
	row.add_child(_meta(&"map", _map_name(), "Map", accent))
	row.add_child(UIFactory.v_divider(UIPalette.alpha(accent, 0.35)))
	row.add_child(_meta(
		&"skull",
		"T%d · %s" % [int(_result.get("threat", 1)), String(_result.get("difficulty_name", "Patrol"))],
		"Threat and difficulty",
		UIPalette.danger
	))
	row.add_child(UIFactory.v_divider(UIPalette.alpha(accent, 0.35)))
	row.add_child(_meta(&"target", str(int(_result.get("objectives", 0))), "Objectives completed", UIPalette.mint))
	row.add_child(UIFactory.v_divider(UIPalette.alpha(accent, 0.35)))
	row.add_child(_meta(&"timer", UIPalette.format_time(float(_result.get("elapsed", 0.0))), "Time in the field", UIPalette.ivory))
	row.add_child(UIFactory.v_divider(UIPalette.alpha(accent, 0.35)))
	row.add_child(_meta(&"bolt", _mode_text(), "Game mode and clock speed", UIPalette.amber))
	card.add_child(row)
	return card


func _map_name() -> String:
	var map_name := String(_result.get("map_name", ""))
	if not map_name.is_empty():
		return map_name
	# Older/demo result payloads predate map_name: derive it from the difficulty.
	var difficulty := ContentDB.get_difficulty(StringName(_result.get("difficulty_id", &"")))
	var preset := ContentDB.get_map_preset(StringName(difficulty.get("map_preset", &"")))
	var preset_name := String(preset.get("display_name", ""))
	if not preset_name.is_empty():
		return preset_name
	return RunState.get_map_preset_name()


func _mode_text() -> String:
	var mode_name := String(_result.get("mode_name", ""))
	var mode_id := StringName(_result.get("mode_id", &""))
	if mode_name.is_empty():
		mode_name = "Quick" if mode_id == &"quick" else RunState.get_mode_name()
	var scale := float(_result.get("time_scale", 0.0))
	if scale <= 0.0:
		scale = 2.0 if (mode_id == &"quick" or mode_name.to_lower() == "quick") else 1.0
	if scale > 1.0:
		return "%s ×%.0f" % [mode_name.to_upper(), scale]
	return mode_name.to_upper()


func _meta(icon_name: StringName, value_text: String, tooltip: String, accent: Color) -> HBoxContainer:
	var row := UIFactory.icon_value(icon_name, value_text, accent, 13)
	row.tooltip_text = tooltip
	return row


# ---------------------------------------------------------------------------
# Body
# ---------------------------------------------------------------------------

func _body_row(extracted: bool, accent: Color) -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP4)
	row.add_child(_rewards_card(extracted, accent))
	row.add_child(_summary_card())
	return row


func _progression_card(accent: Color) -> PanelContainer:
	var progression: Dictionary = _result.get("progression", {})
	var card := UIFactory.panel("Card")
	var box := UIFactory.vbox(UIPalette.SP2)
	var head := UIFactory.hbox(UIPalette.SP2)
	head.add_child(UIFactory.icon(&"arrow-up", 15, UIPalette.mint))
	head.add_child(UIFactory.eyebrow("Warden Progress", UIPalette.mint))
	head.add_child(UIFactory.spacer_h())
	var levels_gained := int(progression.get("levels_gained", 0))
	if levels_gained > 0:
		head.add_child(UIFactory.badge("LEVEL UP", UIPalette.mint))
	box.add_child(head)
	var level_after := int(progression.get("level_after", ProfileState.get_level()))
	var xp_after := int(progression.get("xp_after", ProfileState.get_xp()))
	var xp_next := int(progression.get("xp_next", ProfileState.get_xp_for_next_level()))
	if levels_gained > 0:
		box.add_child(UIFactory.display_text(
			"LEVEL %d  →  LEVEL %d" % [int(progression.get("level_before", level_after - levels_gained)), level_after],
			22, 650, UIPalette.mint
		))
	var xp_row := UIFactory.hbox(UIPalette.SP3)
	xp_row.add_child(UIFactory.label("LEVEL %d" % level_after, "TitleLabel", accent))
	var bar := UIFactory.progress(0.0 if xp_next <= 0 else clampf(float(xp_after) / float(xp_next), 0.0, 1.0) * 100.0, 100.0, "BarMint", 7)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_row.add_child(bar)
	var xp_text := "MAX LEVEL" if xp_next <= 0 else "%d / %d XP" % [xp_after, xp_next]
	xp_row.add_child(UIFactory.label(xp_text, "MonoSmall", UIPalette.muted))
	box.add_child(xp_row)

	var gains := UIFactory.hbox(UIPalette.SP4)
	gains.add_child(_meta(&"arrow-up", "+%s XP" % UIPalette.format_int(int(_result.get("xp", 0))), "Experience gained", UIPalette.mint))
	var skill_gain := int(progression.get("skill_points_gained", 0))
	var attribute_gain := int(progression.get("attribute_points_gained", 0))
	if skill_gain > 0:
		gains.add_child(_meta(&"star", "+%d" % skill_gain, "Skill points gained", UIPalette.mint))
	if attribute_gain > 0:
		gains.add_child(_meta(&"shield", "+%d" % attribute_gain, "Attribute points gained", UIPalette.amber))
	box.add_child(gains)

	var unlocks: Array = progression.get("unlocks", [])
	if not unlocks.is_empty():
		var names: PackedStringArray = []
		for entry in unlocks:
			if entry is Dictionary:
				names.append(String(entry.get("name", "Unlock")))
		var unlock_row := UIFactory.icon_row(&"star", "  ·  ".join(names), "Micro", UIPalette.violet, 12)
		unlock_row.tooltip_text = "New unlocks"
		box.add_child(unlock_row)
	card.add_child(box)
	return card


func _rewards_card(extracted: bool, accent: Color) -> PanelContainer:
	var card := UIFactory.panel("CardRaised")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UIFactory.vbox(UIPalette.SP3)
	var head := UIFactory.hbox(UIPalette.SP2)
	head.add_child(UIFactory.icon(&"trophy", 16, accent))
	head.add_child(UIFactory.eyebrow("Rewards", accent))
	box.add_child(head)

	var numbers := UIFactory.hbox(UIPalette.SP5)
	var salvage_amount := int(_result.get("salvage", 0)) if extracted else 0
	var core_amount := int(_result.get("cores", 0)) if extracted else 0
	numbers.add_child(UIFactory.stat_block(&"coins", "Salvage", UIPalette.format_int(salvage_amount), UIPalette.amber, 26))
	numbers.add_child(UIFactory.stat_block(&"core", "Cores", str(core_amount), UIPalette.violet, 26))
	numbers.add_child(UIFactory.stat_block(&"arrow-up", "Experience", "+%s" % UIPalette.format_int(int(_result.get("xp", 0))), UIPalette.mint, 26))
	box.add_child(numbers)

	var xp_breakdown = _result.get("xp_breakdown", null)
	if xp_breakdown is Dictionary and not (xp_breakdown as Dictionary).is_empty():
		var breakdown: Dictionary = xp_breakdown
		var chips := UIFactory.hbox(UIPalette.SP4)
		chips.add_child(_meta(&"flag", "+%d" % int(breakdown.get("contract", 0)), "Contract XP", UIPalette.mint))
		chips.add_child(_meta(&"crosshair", "+%d" % int(breakdown.get("kills", 0)), "Kill XP", UIPalette.ivory))
		chips.add_child(_meta(&"target", "+%d" % int(breakdown.get("objectives", 0)), "Objective XP", UIPalette.mint))
		chips.add_child(_meta(&"skull", "×%.2f" % float(breakdown.get("difficulty_mult", 1.0)), "Difficulty multiplier", UIPalette.danger))
		if float(breakdown.get("extraction_mult", 1.0)) > 1.0:
			chips.add_child(_meta(
				&"exfil",
				"+%d%%" % int(round((float(breakdown.get("extraction_mult", 1.0)) - 1.0) * 100.0)),
				"Extraction bonus",
				UIPalette.amber
			))
		box.add_child(chips)

	if not extracted:
		var lost := UIFactory.hint_row(&"warning", "Satchel lost", UIPalette.danger)
		lost.tooltip_text = "Salvage and gear did not survive the run."
		box.add_child(lost)

	var gear_head := UIFactory.icon_row(&"backpack", "RECOVERED" if extracted else "LOST", "StatLabel", UIPalette.muted, 13)
	gear_head.tooltip_text = "Recovered gear — items are delivered to your locker."
	box.add_child(gear_head)
	var items: Array = _result.get("items", [])
	if items.is_empty():
		box.add_child(UIFactory.label("No gear recovered.", "BodySmall"))
	else:
		var item_box := UIFactory.vbox(5)
		var shown := 0
		for item in items:
			if shown >= 6:
				break
			if not (item is Dictionary):
				continue
			shown += 1
			item_box.add_child(_item_row(item))
		if items.size() > shown:
			item_box.add_child(UIFactory.label("+%d more" % (items.size() - shown), "Micro", UIPalette.muted_dim))
		box.add_child(item_box)

	var rift_mods: Array = _result.get("rift_mods", [])
	if not rift_mods.is_empty():
		var mod_head := UIFactory.icon_row(&"bolt", "RIFT MODS", "StatLabel", UIPalette.violet, 13)
		mod_head.tooltip_text = "Rift mods recovered this run."
		box.add_child(mod_head)
		var mod_row := UIFactory.hbox(UIPalette.SP2)
		for mod_id in rift_mods:
			var mod := ContentDB.get_rift_mod(StringName(mod_id))
			if mod != null:
				mod_row.add_child(UIFactory.badge(mod.display_name, mod.color, &"bolt"))
		box.add_child(mod_row)

	card.add_child(box)
	return card


func _item_row(item: Dictionary) -> HBoxContainer:
	var info := ItemFactory.describe(item)
	var row := UIFactory.hbox(UIPalette.SP3)
	var rarity: Color = info.get("rarity_color", UIPalette.muted)
	var pip := ColorRect.new()
	pip.color = rarity
	pip.custom_minimum_size = Vector2(3, 22)
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pip)
	var name_label := UIFactory.label(String(info.get("display_name", "Unknown item")), "Body")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var slot_label := UIFactory.label(String(info.get("slot", "")).capitalize(), "Micro", rarity)
	slot_label.tooltip_text = String(info.get("rarity_name", "Common"))
	row.add_child(slot_label)
	var value_row := UIFactory.icon_value(&"coins", UIPalette.format_int(int(info.get("value", 0))), UIPalette.amber, 12)
	value_row.tooltip_text = "Salvage value"
	row.add_child(value_row)
	return row


func _summary_card() -> PanelContainer:
	var card := UIFactory.panel("Card")
	card.custom_minimum_size = Vector2(272, 0)
	card.tooltip_text = "Gear is safe in the locker. Outpost upgrades persist."
	var box := UIFactory.vbox(UIPalette.SP3)
	var head := UIFactory.hbox(UIPalette.SP2)
	head.add_child(UIFactory.icon(&"grid", 16, UIPalette.muted))
	head.add_child(UIFactory.eyebrow("Run Summary", UIPalette.muted))
	box.add_child(head)
	box.add_child(_stat_line(&"crosshair", "Kills", str(int(_result.get("kills", 0)))))
	box.add_child(_stat_line(&"skull", "Bosses", str(int(_result.get("bosses", 0)))))
	box.add_child(_stat_line(&"target", "Objectives", str(int(_result.get("objectives", 0)))))
	box.add_child(_stat_line(&"backpack", "Items recovered", str(int(_result.get("item_count", 0)))))
	box.add_child(_stat_line(&"coins", "Satchel value", UIPalette.format_int(int(_result.get("value", 0)))))
	card.add_child(box)
	return card


func _stat_line(icon_name: StringName, label_text: String, value_text: String) -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon_or_null(icon_name, 13, UIPalette.muted_dim)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
	var name_label := UIFactory.label(label_text, "BodySmall")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UIFactory.label(value_text, "MonoValue"))
	return row


func _ledger_row() -> HBoxContainer:
	var records := ProfileState.get_records()
	var row := UIFactory.hbox(UIPalette.SP5)
	row.add_child(_ledger_chip(&"home", UIPalette.format_int(int(records.get("deployments", 0))), "Deployments"))
	row.add_child(_ledger_chip(&"exfil", UIPalette.format_int(int(records.get("extractions", 0))), "Extractions"))
	row.add_child(_ledger_chip(&"crosshair", UIPalette.format_int(int(records.get("kills", 0))), "Kills"))
	row.add_child(_ledger_chip(&"coins", UIPalette.format_int(int(records.get("best_extraction", 0))), "Best haul"))
	row.add_child(UIFactory.spacer_h())
	return row


func _ledger_chip(icon_name: StringName, value_text: String, tooltip: String) -> HBoxContainer:
	var chip := UIFactory.icon_value(icon_name, value_text, UIPalette.muted, 12)
	chip.tooltip_text = "Ledger · " + tooltip
	return chip


func _actions_row() -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP3)
	var hub := UIFactory.primary_button("Hub", &"home")
	hub.custom_minimum_size = Vector2(0, 48)
	hub.tooltip_text = "Return to the Waystation hub."
	hub.pressed.connect(_on_return_hub)
	row.add_child(hub)
	var redeploy := UIFactory.secondary_button("Redeploy", &"refresh")
	redeploy.custom_minimum_size = Vector2(0, 48)
	redeploy.tooltip_text = "Drop again with the same contract, difficulty and mode."
	redeploy.pressed.connect(_on_redeploy)
	row.add_child(redeploy)
	row.add_child(UIFactory.spacer_h())
	var menu := UIFactory.ghost_button("Main Menu")
	menu.pressed.connect(_on_main_menu)
	row.add_child(menu)
	return row


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _on_return_hub() -> void:
	if App != null:
		App.return_to_hub()


func _on_redeploy() -> void:
	if App == null:
		return
	var contract_id := StringName(_result.get("contract_id", "salvage_sweep"))
	var threat := maxi(1, int(_result.get("threat", 1)))
	var difficulty_id := StringName(_result.get("difficulty_id", &""))
	var mode_id := StringName(_result.get("mode_id", &"normal"))
	if not (mode_id in [&"normal", &"quick"]):
		mode_id = &"normal"
	App.start_deployment(contract_id, 0, threat, [], difficulty_id, mode_id)


func _on_main_menu() -> void:
	if App != null:
		App.return_to_main_menu()
