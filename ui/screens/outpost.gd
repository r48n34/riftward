class_name OutpostScreen
extends UIScreen
## Outpost construction: a visual-first 8x8 diorama of Waystation Kestrel with
## per-module 2.5D art, module dossiers and real upgrades through
## ProfileState.can_upgrade_base_module / upgrade_base_module.

const MODULE_ICONS := {
	&"command_nexus": &"outpost",
	&"foundry": &"bolt",
	&"armory": &"target",
	&"infirmary": &"heart-pulse",
	&"barracks": &"users",
	&"drift_den": &"paw",
	&"reactor": &"core",
	&"signal_array": &"radio",
}

const DIORAMA_MIN_WIDTH := 560
const SIDE_MIN_WIDTH := 430
const LIST_MIN_HEIGHT := 140
const LAYOUT_VERSION_LABEL := "LAYOUT v2"

var _selected_module: StringName = &"command_nexus"
var _diorama: UIOutpostDiorama = null
var _diorama_card: PanelContainer = null
var _side: VBoxContainer = null
var _detail_host: VBoxContainer = null
var _list_host: VBoxContainer = null
var _summary_host: VBoxContainer = null
var _selected_row: Button = null


## Selecting a module or upgrading rebuilds the screen; keep the list where the
## player left it instead of snapping back to the top.
func preserve_scroll_on_refresh() -> bool:
	return true


## Keyboard/gamepad focus starts on the inspected module, not on whichever list
## row happens to be first.
func first_focus_control() -> Control:
	if _selected_row != null and is_instance_valid(_selected_row) and _selected_row.visible:
		return _selected_row
	return super()


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

	_diorama_card = _build_diorama_card()
	body.add_child(_diorama_card)
	_side = _build_side()
	body.add_child(_side)
	_refresh()


# ---------------------------------------------------------------------------
# Composition
# ---------------------------------------------------------------------------

func _build_diorama_card() -> PanelContainer:
	var card := UIFactory.panel("Card")
	card.custom_minimum_size = Vector2(DIORAMA_MIN_WIDTH, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := UIFactory.vbox(UIPalette.SP2)

	var header := UIFactory.hbox(UIPalette.SP2)
	header.add_child(UIFactory.icon(&"grid", 14, UIPalette.mint))
	header.add_child(UIFactory.eyebrow("Waystation Layout", UIPalette.mint))
	header.add_child(_layout_badge())
	var hint := UIFactory.help_note(
		"Click a pad to inspect",
		"Click any module pad - built or planned - to open its dossier. Dashed walkways are still under construction; solid walkways are online.",
		&"info"
	)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hint)
	box.add_child(header)

	_diorama = UIOutpostDiorama.new()
	_diorama.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diorama.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_diorama.tooltip_text = "Click a module on the map or in the list to inspect it."
	_diorama.module_selected.connect(_on_module_selected)
	box.add_child(_diorama)
	box.add_child(_build_legend())
	card.add_child(box)
	return card


func _build_side() -> VBoxContainer:
	var side := UIFactory.vbox(UIPalette.SP3)
	side.custom_minimum_size.x = SIDE_MIN_WIDTH
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
	scroll.custom_minimum_size.y = LIST_MIN_HEIGHT
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_host = UIFactory.vbox(UIPalette.SP2)
	_list_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_host)
	side.add_child(scroll)
	return side


func _layout_badge() -> PanelContainer:
	var badge := UIFactory.badge(LAYOUT_VERSION_LABEL, UIPalette.blue, &"grid")
	badge.tooltip_text = (
		"Plan v2 - the outpost uses a rebuilt 8x8 board: a 3x3 Command Nexus at (3,2), wide Barracks along the south edge and a tall Reactor on the east edge. "
		+ "Every module footprint is validated against the board and walkways are drawn to the Nexus. Older or invalid layouts are re-seated automatically without losing module tiers."
	)
	return badge


func _build_legend() -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_legend_item("BUILT", UIPalette.mint, 0, "A constructed, powered module."))
	row.add_child(_legend_item("PLANNED", UIPalette.muted_dim, 1, "A blueprint pad waiting for construction."))
	row.add_child(_legend_item("ROAD", UIPalette.mint_dim, 2, "Connector roads and walkways link every module to the Command Nexus."))
	row.add_child(UIFactory.spacer_h())
	row.add_child(UIFactory.icon(&"grid", 11, UIPalette.muted_dim))
	row.add_child(UIFactory.label("%d / 8 ONLINE" % _built_count(), "Micro", UIPalette.muted))
	return row


func _legend_item(text: String, color: Color, style: int, tooltip: String) -> HBoxContainer:
	var row := UIFactory.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.tooltip_text = tooltip
	var swatch: Control = null
	if style == 2:
		var line := ColorRect.new()
		line.color = UIPalette.alpha(color, 0.9)
		line.custom_minimum_size = Vector2(16, 2)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch = line
	elif style == 1:
		var outlined := PanelContainer.new()
		outlined.custom_minimum_size = Vector2(10, 10)
		outlined.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outlined.add_theme_stylebox_override(
			"panel",
			UITheme._box(Color.TRANSPARENT, UIPalette.alpha(color, 0.85), 2, 1, Vector4.ZERO)
		)
		swatch = outlined
	else:
		var filled := ColorRect.new()
		filled.color = UIPalette.alpha(color, 0.85)
		filled.custom_minimum_size = Vector2(10, 10)
		filled.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch = filled
	if swatch != null:
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
	row.add_child(UIFactory.label(text, "Micro", UIPalette.muted))
	return row


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


# ---------------------------------------------------------------------------
# Policy helpers
# ---------------------------------------------------------------------------

func _built_count() -> int:
	var count := 0
	for module_id in ProfileState.get_base_modules().keys():
		if ProfileState.get_base_tier(StringName(module_id)) > 0:
			count += 1
	return count


func _ordered_module_ids() -> Array:
	var layout := ProfileState.get_base_layout()
	var module_ids: Array = layout.keys()
	module_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var pa: Vector2i = layout.get(a, Vector2i(8, 8))
		var pb: Vector2i = layout.get(b, Vector2i(8, 8))
		return pa.y < pb.y if pa.y != pb.y else pa.x < pb.x
	)
	return module_ids


func _module_icon(module: BaseModuleData) -> StringName:
	if module != null:
		var data_icon: StringName = module.icon
		if not String(data_icon).is_empty() and UIIcons.has_icon(data_icon):
			return data_icon
		return MODULE_ICONS.get(module.id, &"grid")
	return &"grid"


func _with_tooltip(child: Control, tooltip: String) -> MarginContainer:
	var holder := MarginContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.tooltip_text = tooltip
	holder.add_child(child)
	return holder


func get_diorama() -> UIOutpostDiorama:
	return _diorama


# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

func _build_summary() -> void:
	var card := UIFactory.panel("CardInset")
	card.tooltip_text = _bonus_summary()
	var row := UIFactory.hbox(UIPalette.SP4)
	row.add_child(UIFactory.stat_block(&"outpost", "Base power", str(ProfileState.get_base_power()), UIPalette.mint, 20))
	row.add_child(UIFactory.v_divider(UIPalette.line))
	row.add_child(UIFactory.stat_block(&"grid", "Modules online", "%d/8" % _built_count(), UIPalette.ivory, 20))
	row.add_child(UIFactory.v_divider(UIPalette.line))
	row.add_child(UIFactory.stat_block(&"coins", "Salvage", UIPalette.format_int(ProfileState.get_salvage()), UIPalette.amber, 20))
	row.add_child(UIFactory.v_divider(UIPalette.line))
	row.add_child(UIFactory.stat_block(&"core", "Cores", UIPalette.format_int(ProfileState.get_cores()), UIPalette.violet, 20))
	row.add_child(UIFactory.v_divider(UIPalette.line))
	row.add_child(UIFactory.stat_block(&"shield-check", "Nexus tier", "%d/3" % ProfileState.get_base_tier(&"command_nexus"), UIPalette.blue, 20))
	row.add_child(UIFactory.v_divider(UIPalette.line))
	row.add_child(_module_medallion_strip())
	row.add_child(UIFactory.spacer_h())
	var bonus_glyph := UIFactory.icon(&"star", 14, UIPalette.violet)
	bonus_glyph.tooltip_text = _bonus_summary()
	row.add_child(bonus_glyph)
	card.add_child(row)
	_summary_host.add_child(card)


func _module_medallion_strip() -> VBoxContainer:
	var strip := UIFactory.vbox(3)
	var head := UIFactory.hbox(6)
	head.add_child(UIFactory.eyebrow("Module status", UIPalette.muted_dim))
	head.add_child(UIFactory.spacer_h())
	head.add_child(UIFactory.label("%d/8" % _built_count(), "MonoSmall", UIPalette.muted))
	strip.add_child(head)
	var row := UIFactory.hbox(5)
	for module_id in _ordered_module_ids():
		var module := ContentDB.get_base_module(module_id)
		if module == null:
			continue
		var tier := ProfileState.get_base_tier(module_id)
		var accent: Color = module.accent if tier > 0 else UIPalette.muted_dim
		var medallion := UIFactory.medallion(_module_icon(module), 26, accent, 0.52, tier > 0)
		medallion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var state := "Tier %d" % tier if tier > 0 else "Planned"
		row.add_child(_with_tooltip(medallion, "%s - %s" % [module.display_name, state]))
	strip.add_child(row)
	return strip


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


# ---------------------------------------------------------------------------
# Detail dossier
# ---------------------------------------------------------------------------

func _build_detail() -> void:
	var module := ContentDB.get_base_module(_selected_module)
	if module == null:
		_detail_host.add_child(UIFactory.empty_state(&"warning", "Module data missing", "ContentDB could not resolve this module."))
		return
	var tier := ProfileState.get_base_tier(module.id)
	var accent: Color = module.accent

	var head := UIFactory.hbox(UIPalette.SP3)
	head.tooltip_text = module.description
	var avatar := UIFactory.medallion(_module_icon(module), 44, accent, 0.50, tier > 0)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(avatar)

	var title_box := UIFactory.vbox(2)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title_row := UIFactory.hbox(UIPalette.SP2)
	title_row.add_child(UIFactory.display_text(module.display_name, 22, 650, UIPalette.ivory))
	title_box.add_child(title_row)
	var state := "ONLINE" if tier > 0 else "PLANNED"
	if tier >= module.max_tier:
		state = "MAX TIER"
	title_box.add_child(UIFactory.label(
		"POWER %d  //  %s" % [module.power, state],
		"MonoSmall",
		accent if tier > 0 else UIPalette.muted_dim
	))
	head.add_child(title_box)

	var hero_art := UIModuleArt.new()
	hero_art.configure(module.id, tier, accent, false, false, false)
	hero_art.custom_minimum_size = Vector2(128, 112)
	hero_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hero_frame := UIFactory.art_frame(hero_art, accent, tier > 0)
	hero_frame.custom_minimum_size = Vector2(140, 124)
	hero_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero_frame.tooltip_text = module.description
	head.add_child(hero_frame)
	_detail_host.add_child(head)

	var tier_row := UIFactory.hbox(UIPalette.SP2)
	tier_row.add_child(UIFactory.pips(tier, module.max_tier, accent, 9))
	tier_row.add_child(UIFactory.label("TIER %d / %d" % [tier, module.max_tier], "MonoSmall", UIPalette.muted))
	if tier >= module.max_tier:
		tier_row.add_child(UIFactory.badge("MAX", UIPalette.mint))
	tier_row.add_child(UIFactory.spacer_h())
	var layout_pos: Vector2i = ProfileState.get_base_layout().get(module.id, Vector2i.ZERO)
	tier_row.add_child(UIFactory.label("GRID %d,%d" % [layout_pos.x, layout_pos.y], "MonoSmall", UIPalette.muted_dim))
	tier_row.tooltip_text = "Module tier %d / %d" % [tier, module.max_tier]
	_detail_host.add_child(tier_row)
	_detail_host.add_child(UIFactory.divider(UIPalette.line_soft))
	for effect in module.effects:
		_detail_host.add_child(UIFactory.hint_row(&"check", String(effect), accent))
	_detail_host.add_child(UIFactory.divider(UIPalette.line_soft))

	if tier >= module.max_tier:
		var max_note := UIFactory.hint_row(&"shield-check", "Fully upgraded. All %d tiers online." % module.max_tier, UIPalette.mint)
		max_note.tooltip_text = module.description
		_detail_host.add_child(max_note)
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


# ---------------------------------------------------------------------------
# Module list
# ---------------------------------------------------------------------------

func _build_list() -> void:
	_selected_row = null
	for module_id in _ordered_module_ids():
		var module := ContentDB.get_base_module(module_id)
		if module == null:
			continue
		var tier := ProfileState.get_base_tier(module_id)
		var accent: Color = module.accent
		var row := UIFactory.button("", "GhostButton", &"", &"ui_click")
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(0, 66)
		row.tooltip_text = "%s - %s" % [module.display_name, "Tier %d" % tier if tier > 0 else "Planned"]
		if module_id == _selected_module:
			_selected_row = row
			row.add_theme_stylebox_override(
				"normal",
				UITheme._box(
					UIPalette.alpha(accent, 0.10),
					UIPalette.alpha(accent, 0.45),
					UIPalette.R_MD,
					1,
					Vector4(12, 10, 12, 10)
				)
			)
		var content := UIFactory.hbox(UIPalette.SP2)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var medallion := UIFactory.medallion(
			_module_icon(module),
			26,
			accent if tier > 0 else UIPalette.muted_dim,
			0.52,
			tier > 0
		)
		medallion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(medallion)
		var name_box := UIFactory.vbox(1)
		name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_box.add_child(UIFactory.label(module.display_name, "BodySmall", UIPalette.ivory if tier > 0 else UIPalette.muted))
		name_box.add_child(UIFactory.label(
			"POWER %d" % module.power if tier > 0 else "Not built",
			"Micro",
			UIPalette.muted_dim
		))
		content.add_child(name_box)
		var mini := UIModuleArt.new()
		mini.configure(module.id, tier, accent, false, false, true)
		mini.custom_minimum_size = Vector2(58, 50)
		mini.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(mini)
		content.add_child(UIFactory.label(
			"T%d" % tier if tier > 0 else "—",
			"MonoSmall",
			accent if tier > 0 else UIPalette.muted_dim
		))
		row.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 12
		content.offset_right = -12
		UIFactory.passive_tree(content)
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
		notify(
			"Module upgraded",
			"%s reached tier %d." % [module.display_name if module != null else String(module_id), tier],
			&"success"
		)
	else:
		AudioDirector.play_ui(&"ui_error")
		notify("Upgrade failed", "Requirements not met.", &"error")
	refresh()


# ---------------------------------------------------------------------------
# Responsive layout
# ---------------------------------------------------------------------------

func _layout() -> void:
	if _nav_rail != null and is_instance_valid(_nav_rail):
		_nav_rail.custom_minimum_size.x = UIPalette.rail_width(viewport_width())
	if _side != null and is_instance_valid(_side):
		_side.custom_minimum_size.x = SIDE_MIN_WIDTH
	if _diorama_card != null and is_instance_valid(_diorama_card):
		# On narrow displays the diorama card surrenders its authored minimum and
		# expands into whatever remains beside the fixed-width dossier column.
		_diorama_card.custom_minimum_size.x = 0 if UIPalette.is_compact(viewport_width()) else DIORAMA_MIN_WIDTH
