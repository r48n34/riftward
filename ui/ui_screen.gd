class_name UIScreen
extends Control
## Base class for every menu screen. Screens declare their layout in `_compose()`
## and are rebuilt on refresh, which keeps them honest: they always render the
## current ProfileState/ContentDB data and can never drift out of sync.

signal navigate(screen_id: StringName)
signal toast_requested(title: String, message: String, severity: StringName)

var screen_id: StringName = &""
var _last_args: Dictionary = {}
var _built := false
var _nav_rail: UINavRail = null
var _page_margin: MarginContainer = null
var _focus_on_next_build := true
var _saved_scroll_offsets: Array[Vector2i] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	visible = false
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_resized):
		viewport.size_changed.connect(_on_viewport_resized)


func enter(args: Dictionary = {}) -> void:
	_last_args = args.duplicate(true)
	visible = true
	_focus_on_next_build = true
	_rebuild()
	UIFactory.animate_in(self)


func exit() -> void:
	visible = false


func refresh() -> void:
	if not visible:
		return
	if preserve_scroll_on_refresh():
		_capture_scroll_positions()
	else:
		_saved_scroll_offsets.clear()
	_rebuild()


func notify(title: String, message: String, severity: StringName = &"info") -> void:
	toast_requested.emit(title, message, severity)


func go(target: StringName) -> void:
	navigate.emit(target)


func _rebuild() -> void:
	_focus_on_next_build = true
	var focus_owner := get_viewport().gui_get_focus_owner()
	_clear_root()
	_nav_rail = null
	_page_margin = null
	_compose()
	_built = true
	_on_viewport_resized()
	_restore_focus(focus_owner)
	if preserve_scroll_on_refresh():
		_restore_scroll_positions()
	else:
		# Focus inside a ScrollContainer scrolls it; snap to the top on (re)build.
		# Two passes are needed because Godot applies focus scrolling on the next frame.
		_reset_scroll_positions()


func _reset_scroll_positions() -> void:
	await get_tree().process_frame
	_apply_scroll_reset()
	await get_tree().process_frame
	_apply_scroll_reset()


func _apply_scroll_reset() -> void:
	if not is_inside_tree():
		return
	for node in find_children("*", "ScrollContainer", true, false):
		var scroll := node as ScrollContainer
		if scroll == null:
			continue
		scroll.scroll_vertical = 0
		scroll.scroll_horizontal = 0


func _capture_scroll_positions() -> void:
	_saved_scroll_offsets.clear()
	for node in find_children("*", "ScrollContainer", true, false):
		var scroll := node as ScrollContainer
		if scroll == null:
			continue
		_saved_scroll_offsets.append(Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical))


func _restore_scroll_positions() -> void:
	await get_tree().process_frame
	_apply_scroll_restore()
	await get_tree().process_frame
	_apply_scroll_restore()
	_saved_scroll_offsets.clear()


func _apply_scroll_restore() -> void:
	if not is_inside_tree():
		return
	var index := 0
	for node in find_children("*", "ScrollContainer", true, false):
		var scroll := node as ScrollContainer
		if scroll == null:
			continue
		if index < _saved_scroll_offsets.size():
			var offset := _saved_scroll_offsets[index]
			scroll.scroll_horizontal = offset.x
			scroll.scroll_vertical = offset.y
		index += 1


func _clear_root() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _restore_focus(previous: Control) -> void:
	if not visible:
		return
	var target: Control = null
	if previous != null and is_instance_valid(previous) and previous.is_inside_tree() and previous.visible:
		target = previous
	if target == null:
		target = first_focus_control()
	if target != null:
		target.grab_focus()


## Screens with an obvious primary action override this so keyboard/gamepad
## users land on it instead of on a utility button in the corner.
func first_focus_control() -> Control:
	# Prefer the content column; the nav rail is offered via explicit navigation.
	for child in get_children():
		var candidate := _focus_first_excluding(child)
		if candidate != null:
			return candidate
	return UIFactory.focus_first(self)


func _focus_first_excluding(node: Node) -> Control:
	if _nav_rail != null and is_instance_valid(_nav_rail) and (node == _nav_rail or _nav_rail.is_ancestor_of(node)):
		return null
	if node is BaseButton and node is Control:
		var button := node as BaseButton
		if button.visible and button.focus_mode != Control.FOCUS_NONE and not button.disabled:
			return button
	for child in node.get_children():
		var candidate := _focus_first_excluding(child)
		if candidate != null:
			return candidate
	return null


func viewport_width() -> float:
	var viewport := get_viewport()
	return float(viewport.get_visible_rect().size.x) if viewport != null else 1600.0


func page_padding() -> int:
	return UIPalette.page_padding(viewport_width())


func _on_viewport_resized() -> void:
	if _page_margin != null:
		var pad := page_padding()
		_page_margin.add_theme_constant_override("margin_left", pad)
		_page_margin.add_theme_constant_override("margin_right", pad)
	_layout()


# --- Overridables -----------------------------------------------------------

## Screens with long scrollable content override this so background refreshes
## (profile changes, timer updates) don't throw the player back to the top.
## Off by default: every other screen keeps its existing rebuild/reset behaviour.
func preserve_scroll_on_refresh() -> bool:
	return false


func _compose() -> void:
	pass


func _layout() -> void:
	pass


# --- Shared layout shells ---------------------------------------------------

## Simple full-bleed page with responsive gutters; returns the content column.
func build_page(top: int = UIPalette.SP5, bottom: int = UIPalette.SP5, separation: int = UIPalette.SP5) -> VBoxContainer:
	_page_margin = MarginContainer.new()
	_page_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_page_margin)
	var pad := page_padding()
	_page_margin.add_theme_constant_override("margin_left", pad)
	_page_margin.add_theme_constant_override("margin_right", pad)
	_page_margin.add_theme_constant_override("margin_top", top)
	_page_margin.add_theme_constant_override("margin_bottom", bottom)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_margin.add_child(column)
	return column


## Full hub shell: nav rail on the left, a generous editorial content column on
## the right with a standard header. Returns a dictionary with the pieces.
func build_hub_shell(active_id: StringName, title: String, subtitle: String = "") -> Dictionary:
	var shell := HBoxContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("separation", 0)
	shell.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(shell)

	_nav_rail = UINavRail.new()
	_nav_rail.active_id = active_id
	_nav_rail.custom_minimum_size.x = UIPalette.rail_width(viewport_width())
	if _nav_rail.has_signal("navigate"):
		_nav_rail.connect("navigate", func(target: StringName) -> void: go(target))
	if _nav_rail.has_signal("open_menu"):
		_nav_rail.connect("open_menu", func() -> void: go(&"main_menu"))
	shell.add_child(_nav_rail)

	_page_margin = MarginContainer.new()
	_page_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_margin.size_flags_vertical = Control.SIZE_FILL
	_page_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	var pad := page_padding()
	_page_margin.add_theme_constant_override("margin_left", pad)
	_page_margin.add_theme_constant_override("margin_right", pad)
	_page_margin.add_theme_constant_override("margin_top", UIPalette.SP5)
	_page_margin.add_theme_constant_override("margin_bottom", UIPalette.SP4)
	shell.add_child(_page_margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", UIPalette.SP4 + UIPalette.SP1)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_margin.add_child(content)

	content.add_child(build_header(title, subtitle))
	return {
		"shell": shell,
		"rail": _nav_rail,
		"margin": _page_margin,
		"content": content,
	}


## Standard page header: section title on the left, wallet + level on the right.
## Long explanations ride on an info icon tooltip instead of a paragraph.
func build_header(title: String, subtitle: String = "") -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP4)
	var text_box := UIFactory.vbox(2)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var eyebrow_row := UIFactory.hbox(6)
	var home_glyph := UIFactory.icon_or_null(&"home", 12, UIPalette.mint)
	if home_glyph != null:
		eyebrow_row.add_child(home_glyph)
	eyebrow_row.add_child(UIFactory.label("REACH OPERATIONS", "Eyebrow", UIPalette.mint))
	text_box.add_child(eyebrow_row)
	var title_row := UIFactory.hbox(8)
	title_row.add_child(UIFactory.heading(title, "H1"))
	if not subtitle.is_empty():
		var info := UIFactory.icon_or_null(&"info", 14, UIPalette.muted_dim)
		if info != null:
			info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			info.tooltip_text = subtitle
			title_row.add_child(info)
	text_box.add_child(title_row)
	row.add_child(text_box)
	row.add_child(wallet_row())
	return row


func wallet_row() -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP3)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(wallet_chip(&"coins", UIPalette.format_int(ProfileState.get_salvage()), UIPalette.amber, "Salvage"))
	row.add_child(wallet_chip(&"core", UIPalette.format_int(ProfileState.get_cores()), UIPalette.violet, "Cores"))
	row.add_child(wallet_chip(&"arrow-up", "LV %d" % ProfileState.get_level(), UIPalette.mint, "Warden level"))
	return row


func wallet_chip(icon_name: StringName, value_text: String, accent: Color, tooltip: String = "") -> PanelContainer:
	var node := UIFactory.tone_panel(accent, UIPalette.R_CHIP)
	node.add_theme_stylebox_override(
		"panel",
		UITheme._box(UIPalette.alpha(accent, 0.09), UIPalette.alpha(accent, 0.4), UIPalette.R_CHIP, 1, Vector4(12, 7, 12, 7))
	)
	if not tooltip.is_empty():
		node.tooltip_text = tooltip
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UIFactory.hbox(7, BoxContainer.ALIGNMENT_CENTER)
	var glyph := UIFactory.icon_or_null(icon_name, 14, accent)
	if glyph != null:
		row.add_child(glyph)
	row.add_child(UIFactory.label(value_text, "MonoValue", accent))
	node.add_child(row)
	return node


func back_button(target: StringName = &"hub") -> Button:
	var btn := UIFactory.ghost_button("Back", &"chevron-left")
	btn.pressed.connect(func() -> void: go(target))
	return btn
