class_name OutpostScreen
extends UIScreen
## Outpost construction: a code-drawn diorama of the Waystation plus real module
## upgrades through ProfileState.can_upgrade_base_module / upgrade_base_module.

const MODULE_ICONS := {
	&"command_nexus": &"outpost",
	&"foundry": &"bolt",
	&"armory": &"target",
	&"infirmary": &"heart-pulse",
	&"barracks": &"users",
	&"drift_den": &"paw",
	&"reactor": &"bolt",
	&"signal_array": &"radio",
}

var _selected_module: StringName = &"command_nexus"
var _diorama: UIOutpostDiorama = null
var _detail_host: VBoxContainer = null
var _list_host: VBoxContainer = null
var _summary_host: VBoxContainer = null


func _compose() -> void:
	var backdrop := UIBackdrop.new()
	backdrop.configure(UIBackdrop.Mood.HUB)
	add_child(backdrop)

	var shell := build_hub_shell(&"outpost", "Outpost", "")
	var content: VBoxContainer = shell.content

	_summary_host = UIFactory.vbox(UIPalette.SP3)
	content.add_child(_summary_host)

	var body := UIFactory.hbox(UIPalette.SP4)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)

	var diorama_card := UIFactory.panel("Card")
	diorama_card.custom_minimum_size = Vector2(560, 0)
	diorama_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var diorama_box := UIFactory.vbox(UIPalette.SP2)
	var layout_head := UIFactory.hbox(UIPalette.SP2)
	layout_head.add_child(UIFactory.icon(&"grid", 14, UIPalette.mint))
	layout_head.add_child(UIFactory.eyebrow("Waystation Layout", UIPalette.mint))
	diorama_box.add_child(layout_head)
	_diorama = UIOutpostDiorama.new()
	_diorama.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diorama.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_diorama.tooltip_text = "Click a module on the map or in the list to inspect it."
	_diorama.module_selected.connect(_on_module_selected)
	diorama_box.add_child(_diorama)
	diorama_card.add_child(diorama_box)
	body.add_child(diorama_card)

	var side := UIFactory.vbox(UIPalette.SP3)
	side.custom_minimum_size.x = 430
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var detail_card := UIFactory.panel("CardRaised")
	_detail_host = UIFactory.vbox(UIPalette.SP2)
	detail_card.add_child(_detail_host)
	side.add_child(detail_card)
	var list_header := UIFactory.hbox(UIPalette.SP2)
	list_header.add_child(UIFactory.icon(&"grid", 13, UIPalette.amber))
	list_header.add_child(UIFactory.eyebrow("Modules", UIPalette.amber))
	list_header.add_child(UIFactory.spacer_h())
	var online := UIFactory.icon_value(&"check", "%d/8" % _built_count(), UIPalette.muted, 12)
	online.tooltip_text = "Modules online"
	list_header.add_child(online)
	side.add_child(list_header)
	var scroll := UIFactory.vscroll()
	scroll.custom_minimum_size.y = 150
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_host = UIFactory.vbox(UIPalette.SP2)
	_list_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_host)
	side.add_child(scroll)
	body.add_child(side)
	_refresh()


func _built_count() -> int:
	var count := 0
	for module_id in ProfileState.get_base_modules().keys():
		if ProfileState.get_base_tier(StringName(module_id)) > 0:
			count += 1
	return count


func _refresh() -> void:
	if _detail_host == null:
		return
	UIFactory.clear_children(_summary_host)
	UIFactory.clear_children(_detail_host)
	UIFactory.clear_children(_list_host)
	_build_summary()
	_build_detail()
	_build_list()
	if _diorama != null:
		_diorama.selected_module = _selected_module
		_diorama.refresh()
	_layout()


func _build_summary() -> void:
	var card := UIFactory.panel("CardInset")
	card.tooltip_text = _bonus_summary()
	var row := UIFactory.hbox(UIPalette.SP5)
	row.add_child(UIFactory.stat_block(&"outpost", "Base power", str(ProfileState.get_base_power()), UIPalette.mint, 20))
	row.add_child(UIFactory.v_divider(UIPalette.line))
	row.add_child(UIFactory.stat_block(&"grid", "Modules online", "%d/8" % _built_count(), UIPalette.ivory, 20))
	row.add_child(UIFactory.v_divider(UIPalette.line))
	row.add_child(UIFactory.stat_block(&"coins", "Salvage", UIPalette.format_int(ProfileState.get_salvage()), UIPalette.amber, 20))
	row.add_child(UIFactory.v_divider(UIPalette.line))
	row.add_child(UIFactory.stat_block(&"core", "Cores", UIPalette.format_int(ProfileState.get_cores()), UIPalette.violet, 20))
	row.add_child(UIFactory.v_divider(UIPalette.line))
	row.add_child(UIFactory.stat_block(&"shield-check", "Nexus tier", "%d/3" % ProfileState.get_base_tier(&"command_nexus"), UIPalette.blue, 20))
	row.add_child(UIFactory.spacer_h())
	var bonus_glyph := UIFactory.icon(&"star", 14, UIPalette.violet)
	bonus_glyph.tooltip_text = _bonus_summary()
	row.add_child(bonus_glyph)
	card.add_child(row)
	_summary_host.add_child(card)


func _bonus_summary() -> String:
	var modifiers := ProfileState.get_stat_modifiers()
	var parts: PackedStringArray = []
	for modifier in modifiers:
		if String(modifier.get("source", "")) != "base":
			continue
		parts.append(UIPalette.format_stat_value(StringName(modifier.get("stat", "")), float(modifier.get("value", 0.0))))
	if parts.is_empty():
		return "No outpost bonuses active. Upgrade modules to strengthen every deployment."
	return "Outpost bonuses: " + "  ·  ".join(parts)


func _module_icon(module_id: StringName) -> StringName:
	var icon_name: StringName = MODULE_ICONS.get(module_id, &"grid")
	return icon_name


func _build_detail() -> void:
	var module := ContentDB.get_base_module(_selected_module)
	if module == null:
		_detail_host.add_child(UIFactory.empty_state(&"warning", "Module data missing", "ContentDB could not resolve this module."))
		return
	var tier := ProfileState.get_base_tier(module.id)
	var accent := module.accent

	var head := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon_or_null(_module_icon(module.id), 20, accent)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(glyph)
	head.add_child(UIFactory.display_text(module.display_name, 24, 600, UIPalette.ivory))
	head.add_child(UIFactory.spacer_h())
	if tier >= module.max_tier:
		head.add_child(UIFactory.badge("MAX", UIPalette.mint))
	head.tooltip_text = module.description
	_detail_host.add_child(head)

	var tier_row := UIFactory.hbox(UIPalette.SP2)
	var pips := UIFactory.pips(tier, module.max_tier, accent, 9)
	tier_row.add_child(pips)
	tier_row.tooltip_text = "Module tier %d / %d" % [tier, module.max_tier]
	_detail_host.add_child(tier_row)
	_detail_host.add_child(UIFactory.divider(UIPalette.line_soft))
	for effect in module.effects:
		_detail_host.add_child(UIFactory.hint_row(&"check", String(effect), accent))
	_detail_host.add_child(UIFactory.divider(UIPalette.line_soft))

	if tier >= module.max_tier:
		return
	var cost := module.cost_for_tier(tier)
	var core_cost := module.core_cost_for_tier(tier)
	var cost_row := UIFactory.hbox(UIPalette.SP4)
	cost_row.tooltip_text = "Upgrade cost for tier %d" % (tier + 1)
	cost_row.add_child(UIFactory.icon_value(&"coins", UIPalette.format_int(cost), UIPalette.amber, 13))
	cost_row.add_child(UIFactory.icon_value(&"core", str(core_cost), UIPalette.violet, 13))
	cost_row.add_child(UIFactory.spacer_h())
	cost_row.add_child(UIFactory.icon_value(&"arrow-up", "T%d → %d" % [tier, tier + 1], UIPalette.muted, 12))
	_detail_host.add_child(cost_row)

	var can_upgrade := ProfileState.can_upgrade_base_module(module.id)
	var upgrade := UIFactory.primary_button("Upgrade", &"plus")
	upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade.disabled = not can_upgrade
	upgrade.tooltip_text = "Upgrade %s to tier %d." % [module.display_name, tier + 1]
	upgrade.pressed.connect(func() -> void: _upgrade_module(module.id))
	_detail_host.add_child(upgrade)
	if not can_upgrade:
		_detail_host.add_child(UIFactory.hint_row(&"lock", _blocked_reason(module, tier), UIPalette.amber))


func _blocked_reason(module: BaseModuleData, tier: int) -> String:
	if module.id != &"command_nexus":
		var nexus := ProfileState.get_base_tier(&"command_nexus")
		if tier + 1 > nexus:
			return "Nexus tier %d required." % (tier + 1)
	if ProfileState.get_salvage() < module.cost_for_tier(tier):
		return "Not enough salvage."
	if ProfileState.get_cores() < module.core_cost_for_tier(tier):
		return "Not enough cores."
	return "Locked."


func _build_list() -> void:
	var module_ids: Array = ProfileState.get_base_layout().keys()
	module_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var pa: Vector2i = ProfileState.get_base_layout()[a]
		var pb: Vector2i = ProfileState.get_base_layout()[b]
		return pa.y < pb.y if pa.y != pb.y else pa.x < pb.x
	)
	for module_id in module_ids:
		var module := ContentDB.get_base_module(module_id)
		if module == null:
			continue
		var tier := ProfileState.get_base_tier(module_id)
		var row := UIFactory.button("", "GhostButton", &"", &"ui_click")
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(0, 44)
		row.tooltip_text = module.display_name
		if module_id == _selected_module:
			row.add_theme_stylebox_override(
				"normal",
				UITheme._box(UIPalette.alpha(module.accent, 0.10), UIPalette.alpha(module.accent, 0.45), UIPalette.R_MD, 1, Vector4(12, 10, 12, 10))
			)
		var content := UIFactory.hbox(UIPalette.SP2)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var glyph := UIFactory.icon_or_null(_module_icon(module_id), 15, module.accent if tier > 0 else UIPalette.muted_dim)
		if glyph != null:
			glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			content.add_child(glyph)
		var name_label := UIFactory.label(module.display_name, "Body")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(name_label)
		content.add_child(UIFactory.label("T%d" % tier if tier > 0 else "—", "MonoSmall", module.accent if tier > 0 else UIPalette.muted_dim))
		row.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 14
		content.offset_right = -14
		row.pressed.connect(func() -> void: _on_module_selected(module_id))
		_list_host.add_child(row)


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _on_module_selected(module_id: StringName) -> void:
	_selected_module = module_id
	refresh()


func _upgrade_module(module_id: StringName) -> void:
	var module := ContentDB.get_base_module(module_id)
	if ProfileState.upgrade_base_module(module_id):
		AudioDirector.play_ui(&"ui_confirm")
		var tier := ProfileState.get_base_tier(module_id)
		notify("Module upgraded", "%s reached tier %d." % [module.display_name if module != null else String(module_id), tier], &"success")
	else:
		AudioDirector.play_ui(&"ui_error")
		notify("Upgrade failed", "Requirements not met.", &"error")
	refresh()


func _layout() -> void:
	if _nav_rail != null and is_instance_valid(_nav_rail):
		_nav_rail.custom_minimum_size.x = UIPalette.rail_width(viewport_width())
