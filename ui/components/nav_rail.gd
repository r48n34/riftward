class_name UINavRail
extends PanelContainer
## Persistent hub navigation. Reads live profile state on every rebuild so the
## rail doubles as a compact character sheet.

signal navigate(screen_id: StringName)
signal open_menu()

const NAV_ITEMS := [
	{"id": &"hub", "label": "Contracts", "icon": &"home"},
	{"id": &"loadout", "label": "Loadout", "icon": &"backpack"},
	{"id": &"locker", "label": "Locker", "icon": &"star"},
	{"id": &"skills", "label": "Skills", "icon": &"shield"},
	{"id": &"squad", "label": "Squad", "icon": &"users"},
	{"id": &"outpost", "label": "Outpost", "icon": &"outpost"},
	{"id": &"codex", "label": "Codex", "icon": &"book"},
]

var active_id: StringName = &"hub"
var _nav_buttons: Array[Button] = []
var _column: VBoxContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var style := UITheme._box(UIPalette.alpha(UIPalette.ink, 0.6), Color.TRANSPARENT, 0, 0, Vector4(0, 0, 0, 0))
	style.border_width_right = 1
	style.border_color = UIPalette.alpha(UIPalette.line, 0.85)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", UIPalette.SP2)
	margin.add_child(_column)
	_build()


func _build() -> void:
	UIFactory.clear_children(_column)
	_nav_buttons.clear()

	# Brand
	var brand := UIFactory.vbox(0)
	var wordmark := UIFactory.display_text("RIFTWARD", 22, 700)
	brand.add_child(wordmark)
	brand.add_child(UIFactory.label("WAYSTATION KESTREL", "Micro", UIPalette.mint))
	_column.add_child(UIFactory.pad(brand, 2, 0, 2, 12))

	# Profile summary (compact: name + level, bar, unspent points)
	var profile_card := UIFactory.panel("CardInset")
	profile_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var profile_box := UIFactory.vbox(6)
	var name_row := UIFactory.hbox(UIPalette.SP2)
	var callsign := UIFactory.label(ProfileState.get_callsign(), "PlayerName")
	callsign.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(callsign)
	name_row.add_child(UIFactory.badge("LV %d" % ProfileState.get_level(), UIPalette.mint))
	profile_box.add_child(name_row)
	var xp_target := ProfileState.get_xp_for_next_level()
	var ratio := 0.0
	if xp_target > 0:
		ratio = clampf(float(ProfileState.get_xp()) / float(xp_target), 0.0, 1.0)
	profile_box.add_child(UIFactory.progress(ratio * 100.0, 100.0, "BarMint", 4))
	var points := ProfileState.get_skill_points() + ProfileState.get_attribute_points()
	if points > 0:
		profile_box.add_child(UIFactory.icon_value(&"star", "%d POINTS" % points, UIPalette.amber, 12))
	profile_card.add_child(profile_box)
	_column.add_child(profile_card)
	_column.add_child(UIFactory.fixed_spacer(0, UIPalette.SP4))

	# Nav
	for item in NAV_ITEMS:
		var screen_key: StringName = item.id
		var nav := UIFactory.nav_button(String(item.label), StringName(item.icon), screen_key)
		nav.button_pressed = screen_key == active_id
		nav.pressed.connect(func() -> void: _on_nav_pressed(screen_key))
		nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_nav_buttons.append(nav)
		_column.add_child(nav)

	_column.add_child(UIFactory.spacer_v())
	_column.add_child(UIFactory.divider(UIPalette.line_soft))
	_column.add_child(UIFactory.fixed_spacer(0, UIPalette.SP2))

	# Wallet (one compact row)
	var wallet := UIFactory.hbox(UIPalette.SP3, BoxContainer.ALIGNMENT_CENTER)
	wallet.add_child(_wallet_chip(&"coins", UIPalette.format_int(ProfileState.get_salvage()), UIPalette.amber, "Salvage"))
	wallet.add_child(_wallet_chip(&"core", UIPalette.format_int(ProfileState.get_cores()), UIPalette.violet, "Cores"))
	wallet.add_child(_wallet_chip(&"users", "%d/2" % ProfileState.get_active_allies().size(), UIPalette.mint, "Squad"))
	_column.add_child(wallet)
	_column.add_child(UIFactory.fixed_spacer(0, UIPalette.SP3))

	var menu_button := UIFactory.ghost_button("Menu", &"menu")
	menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_button.pressed.connect(func() -> void: open_menu.emit())
	_column.add_child(menu_button)


func _wallet_chip(icon_name: StringName, value_text: String, accent: Color, tooltip: String) -> PanelContainer:
	var node := UIFactory.tone_panel(accent, UIPalette.R_CHIP)
	node.add_theme_stylebox_override(
		"panel",
		UITheme._box(UIPalette.alpha(accent, 0.08), UIPalette.alpha(accent, 0.35), UIPalette.R_CHIP, 1, Vector4(9, 5, 9, 5))
	)
	node.tooltip_text = tooltip
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(UIFactory.icon_value(icon_name, value_text, accent, 12))
	return node


func _on_nav_pressed(screen_key: StringName) -> void:
	navigate.emit(screen_key)
