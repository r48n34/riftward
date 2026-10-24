class_name UIFactory
extends RefCounted
## Reusable component constructors. Screens compose layouts from these so the
## visual language stays consistent and every interactive control is wired for
## hover/press/focus audio by default.

# ---------------------------------------------------------------------------
# Text
# ---------------------------------------------------------------------------

static func label(text: String, variation: String = "Body", color: Color = Color.TRANSPARENT) -> Label:
	var node := Label.new()
	node.theme_type_variation = variation
	node.text = text
	if color.a > 0.0:
		node.add_theme_color_override("font_color", color)
	return node


static func wrapped(text: String, variation: String = "Body", color: Color = Color.TRANSPARENT) -> Label:
	var node := label(text, variation, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func heading(text: String, variation: String = "H2", color: Color = Color.TRANSPARENT) -> Label:
	return label(text, variation, color)


static func eyebrow(text: String, color: Color = Color.TRANSPARENT) -> Label:
	return label(text.to_upper(), "Eyebrow", color)


static func mono(text: String, bold: bool = false, size: int = 0, color: Color = Color.TRANSPARENT) -> Label:
	var node := label(text, "Mono", color)
	if bold:
		var font := UIFonts.mono(true)
		if font != null:
			node.add_theme_font_override("font", font)
	if size > 0:
		node.add_theme_font_size_override("font_size", size)
	return node


## Custom-sized display text (the wordmark, hero numerals, ...).
static func display_text(text: String, size: int, weight: int = 650, color: Color = Color.TRANSPARENT) -> Label:
	var node := Label.new()
	node.text = text
	var font := UIFonts.display(weight)
	if font != null:
		node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", UIPalette.ivory if color.a <= 0.0 else color)
	return node


static func number_text(text: String, size: int = 32, color: Color = Color.TRANSPARENT, bold: bool = true) -> Label:
	var node := Label.new()
	node.text = text
	var font := UIFonts.mono(bold)
	if font != null:
		node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", UIPalette.ivory if color.a <= 0.0 else color)
	return node


# ---------------------------------------------------------------------------
# Containers
# ---------------------------------------------------------------------------

static func hbox(separation: int = UIPalette.SP2, alignment: int = BoxContainer.ALIGNMENT_BEGIN) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.alignment = alignment
	return box


static func vbox(separation: int = UIPalette.SP2) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func pad(child: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	if child != null:
		margin.add_child(child)
	return margin


static func pad_all(child: Control, amount: int) -> MarginContainer:
	return pad(child, amount, amount, amount, amount)


static func spacer_h(min_width: int = 0) -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.custom_minimum_size.x = min_width
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func spacer_v(height: int = 0) -> Control:
	var node := Control.new()
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.custom_minimum_size.y = height
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func fixed_spacer(width: int = 0, height: int = 0) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(width, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func divider(color: Color = Color.TRANSPARENT, thickness: int = 1) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = UIPalette.line_soft if color.a <= 0.0 else color
	rect.custom_minimum_size = Vector2(0, thickness)
	rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func v_divider(color: Color = Color.TRANSPARENT, thickness: int = 1) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = UIPalette.line_soft if color.a <= 0.0 else color
	rect.custom_minimum_size = Vector2(thickness, 0)
	rect.size_flags_vertical = Control.SIZE_FILL
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func vscroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return scroll


static func hscroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return scroll


static func scroll_content(scroll: ScrollContainer) -> VBoxContainer:
	var box := vbox(UIPalette.SP3)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box


# ---------------------------------------------------------------------------
# Icons
# ---------------------------------------------------------------------------

static func icon(icon_name: StringName, size: int = 18, color: Color = Color.TRANSPARENT) -> TextureRect:
	var node := TextureRect.new()
	node.texture = UIIcons.get_icon(icon_name)
	node.custom_minimum_size = Vector2(size, size)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if color.a > 0.0:
		node.modulate = color
	return node


static func icon_or_null(icon_name: StringName, size: int = 18, color: Color = Color.TRANSPARENT) -> TextureRect:
	if not UIIcons.has_icon(icon_name):
		return null
	return icon(icon_name, size, color)


static func icon_row(icon_name: StringName, text: String, variation: String = "Body", color: Color = Color.TRANSPARENT, icon_size: int = 16, icon_color: Color = Color.TRANSPARENT) -> HBoxContainer:
	var box := hbox(UIPalette.SP2, BoxContainer.ALIGNMENT_BEGIN)
	var glyph := icon(icon_name, icon_size, icon_color)
	if glyph != null:
		box.add_child(glyph)
	box.add_child(label(text, variation, color))
	return box


# ---------------------------------------------------------------------------
# Panels
# ---------------------------------------------------------------------------

static func panel(variation: String = "Card") -> PanelContainer:
	var node := PanelContainer.new()
	if not variation.is_empty():
		node.theme_type_variation = variation
	return node


static func tone_panel(accent: Color, radius: int = UIPalette.R_LG) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override(
		"panel",
		UITheme._box(UIPalette.alpha(accent, 0.08), UIPalette.alpha(accent, 0.5), radius, 1, Vector4(20, 18, 20, 18))
	)
	return node


static func tinted_panel(bg: Color, border: Color, radius: int = UIPalette.R_LG) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", UITheme._box(bg, border, radius, 1, Vector4(16, 12, 16, 12)))
	return node


static func chip(text: String, accent: Color, variation: String = "ChipPanel") -> PanelContainer:
	var node := panel(variation)
	node.add_theme_stylebox_override(
		"panel",
		UITheme._box(UIPalette.alpha(accent, 0.1), UIPalette.alpha(accent, 0.55), UIPalette.R_CHIP, 1, Vector4(10, 4, 10, 4))
	)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var text_node := label(text, "Micro", accent)
	text_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.add_child(text_node)
	return node


static func badge(text: String, accent: Color, icon_name: StringName = &"") -> PanelContainer:
	var node := chip(text, accent)
	var box := hbox(5, BoxContainer.ALIGNMENT_CENTER)
	var glyph := icon_or_null(icon_name, 12, accent)
	if glyph != null:
		box.add_child(glyph)
	for child in node.get_children():
		node.remove_child(child)
		box.add_child(child)
	node.add_child(box)
	return node


# ---------------------------------------------------------------------------
# Buttons
# ---------------------------------------------------------------------------

static func wire_button(button: Button, click_id: StringName = &"ui_click") -> Button:
	if button == null or button.has_meta("ui_wired"):
		return button
	button.set_meta("ui_wired", true)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func() -> void: _play(click_id, 0.0))
	button.mouse_entered.connect(func() -> void: _play(&"ui_hover", -9.0))
	button.focus_entered.connect(func() -> void: _play(&"ui_hover", -12.0))
	return button


static func _play(sound: StringName, volume_db: float) -> void:
	if not Engine.has_singleton("AudioServer"):
		pass
	var audio := AudioDirector
	if audio != null:
		audio.play_ui(sound, volume_db)


static func button(
	text: String,
	variation: String = "SecondaryButton",
	icon_name: StringName = &"",
	click_id: StringName = &"ui_click"
) -> Button:
	var node := Button.new()
	node.text = text
	node.theme_type_variation = variation
	node.focus_mode = Control.FOCUS_ALL
	node.custom_minimum_size = Vector2(0, 40)
	_apply_button_icon(node, icon_name)
	return wire_button(node, click_id)


static func primary_button(text: String, icon_name: StringName = &"", click_id: StringName = &"ui_confirm") -> Button:
	var node := button(text, "PrimaryButton", icon_name, click_id)
	node.custom_minimum_size = Vector2(0, 44)
	return node


static func deploy_button(text: String = "DEPLOY TO THE REACH", icon_name: StringName = &"play") -> Button:
	var node := button(text, "DeployButton", icon_name, &"ui_confirm")
	node.custom_minimum_size = Vector2(0, 56)
	return node


## Oversized hero CTA used by the main menu and the Quick Deploy preflight.
static func quick_deploy_button(text: String = "QUICK DEPLOY", icon_name: StringName = &"play") -> Button:
	var node := button(text, "QuickDeployButton", icon_name, &"ui_confirm")
	node.custom_minimum_size = Vector2(0, 74)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func secondary_button(text: String, icon_name: StringName = &"") -> Button:
	return button(text, "SecondaryButton", icon_name)


static func ghost_button(text: String, icon_name: StringName = &"") -> Button:
	return button(text, "GhostButton", icon_name)


static func inline_button(text: String, icon_name: StringName = &"") -> Button:
	var node := button(text, "InlineButton", icon_name, &"ui_click")
	node.custom_minimum_size = Vector2(0, 26)
	return node


static func danger_button(text: String, icon_name: StringName = &"") -> Button:
	var node := button(text, "DangerButton", icon_name, &"ui_error")
	node.custom_minimum_size = Vector2(0, 40)
	return node


static func icon_button(icon_name: StringName, tooltip: String = "", variation: String = "IconButton", size: int = 38) -> Button:
	var node := Button.new()
	node.theme_type_variation = variation
	node.focus_mode = Control.FOCUS_ALL
	node.custom_minimum_size = Vector2(size, size)
	node.tooltip_text = tooltip
	_apply_button_icon(node, icon_name, 20)
	return wire_button(node)


static func nav_button(text: String, icon_name: StringName, screen_id: StringName) -> Button:
	var node := button(text, "NavButton", icon_name, &"ui_click")
	node.toggle_mode = true
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.custom_minimum_size = Vector2(0, 44)
	node.set_meta("screen_id", screen_id)
	return node


static func chip_button(text: String, toggled: bool = false) -> Button:
	var node := button(text, "ChipButton", &"", &"ui_click")
	node.toggle_mode = true
	node.button_pressed = toggled
	node.custom_minimum_size = Vector2(0, 30)
	return node


static func tab_button(text: String, toggled: bool = false) -> Button:
	var node := button(text, "TabButton", &"", &"ui_click")
	node.toggle_mode = true
	node.button_pressed = toggled
	node.custom_minimum_size = Vector2(0, 36)
	return node


static func card_button(toggle: bool = false) -> Button:
	var node := Button.new()
	node.theme_type_variation = "CardButton"
	node.toggle_mode = toggle
	node.custom_minimum_size = Vector2(0, 0)
	node.focus_mode = Control.FOCUS_ALL
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var content := MarginContainer.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("margin_left", 22)
	content.add_theme_constant_override("margin_top", 18)
	content.add_theme_constant_override("margin_right", 22)
	content.add_theme_constant_override("margin_bottom", 18)
	node.add_child(content)
	return wire_button(node)


static func card_content(card: Button) -> MarginContainer:
	var content := card.get_node_or_null("Content")
	if content is MarginContainer:
		return content
	return null


## Make every descendant of a card content pass mouse events through to the card.
static func passive_tree(node: Node) -> void:
	if node is Control:
		var control := node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if control is BaseButton:
			control.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		passive_tree(child)


static func _apply_button_icon(node: Button, icon_name: StringName, size: int = 18) -> void:
	if String(icon_name).is_empty():
		return
	var texture := UIIcons.get_icon(icon_name)
	if texture == null:
		return
	node.icon = texture
	node.set("icon_max_width", size)
	node.expand_icon = true


# ---------------------------------------------------------------------------
# Inputs
# ---------------------------------------------------------------------------

static func slider(min_value: float, max_value: float, step: float, value: float) -> HSlider:
	var node := HSlider.new()
	node.min_value = min_value
	node.max_value = max_value
	node.step = step
	node.value = value
	node.custom_minimum_size = Vector2(0, 28)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func option_button(items: Array, selected: int = 0) -> OptionButton:
	var node := OptionButton.new()
	node.custom_minimum_size = Vector2(0, 38)
	node.focus_mode = Control.FOCUS_ALL
	for index in items.size():
		node.add_item(str(items[index]), index)
	if selected >= 0 and selected < items.size():
		node.select(selected)
	wire_button(node)
	return node


# ---------------------------------------------------------------------------
# Composites
# ---------------------------------------------------------------------------

static func progress(value: float, maximum: float, variation: String = "BarMint", height: int = 6) -> ProgressBar:
	var node := ProgressBar.new()
	node.theme_type_variation = variation
	node.min_value = 0.0
	node.max_value = maxf(0.001, maximum)
	node.value = clampf(value, 0.0, maximum)
	node.show_percentage = false
	node.custom_minimum_size = Vector2(0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func stat_line(label_text: String, value_text: String, value_color: Color = Color.TRANSPARENT) -> HBoxContainer:
	var row := hbox(UIPalette.SP2)
	var name_label := label(label_text, "BodySmall")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var amount := label(value_text, "MonoValue", value_color)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(amount)
	return row


## Icon + uppercase caption + figure. The shared stat block used across screens.
static func stat_block(
	icon_name: StringName,
	label_text: String,
	value_text: String,
	accent: Color = Color.TRANSPARENT,
	value_size: int = 20
) -> VBoxContainer:
	var box := vbox(3)
	var top := hbox(6)
	var glyph := icon_or_null(icon_name, 13, accent if accent.a > 0.0 else UIPalette.muted)
	if glyph != null:
		top.add_child(glyph)
	top.add_child(label(label_text.to_upper(), "StatLabel"))
	box.add_child(top)
	box.add_child(number_text(value_text, value_size, accent if accent.a > 0.0 else UIPalette.ivory))
	return box


## Compact icon + value pair for dense rows and reward strips.
static func icon_value(
	icon_name: StringName,
	value_text: String,
	accent: Color = Color.TRANSPARENT,
	icon_size: int = 13,
	value_size: int = 0
) -> HBoxContainer:
	var row := hbox(5, BoxContainer.ALIGNMENT_CENTER)
	var glyph := icon_or_null(icon_name, icon_size, accent if accent.a > 0.0 else UIPalette.muted)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
	var value := label(value_text, "MonoSmall", accent if accent.a > 0.0 else UIPalette.ivory)
	if value_size > 0:
		value.add_theme_font_size_override("font_size", value_size)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value)
	return row


## One-line explanation with the full copy in a tooltip. Replaces paragraphs.
static func help_note(short_text: String, tooltip: String = "", icon_name: StringName = &"info") -> HBoxContainer:
	var row := hbox(UIPalette.SP2)
	row.tooltip_text = tooltip if not tooltip.is_empty() else short_text
	var glyph := icon_or_null(icon_name, 13, UIPalette.muted_dim)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
	var text := label(short_text, "Micro", UIPalette.muted)
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	return row


## Icon-led tab button (used by codex/locker tab strips). The glyph lives inside
## the button as a child row instead of Button.icon so tab theme styleboxes can
## never clip or drop it.
static func icon_tab(icon_name: StringName, text: String, toggled: bool = false) -> Button:
	var node := Button.new()
	node.theme_type_variation = "TabButton"
	node.toggle_mode = true
	node.button_pressed = toggled
	node.custom_minimum_size = Vector2(0, 36)
	node.focus_mode = Control.FOCUS_ALL
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var content := HBoxContainer.new()
	content.name = "IconContent"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var accent := UIPalette.ivory if toggled else UIPalette.muted
	var glyph := icon_or_null(icon_name, 14, accent)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(glyph)
	var text_label := label(text, "BodySmall", accent)
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(text_label)
	node.add_child(content)
	passive_tree(content)
	# Button children do not feed Control minimum size, and Label metrics are not
	# available before the button enters the tree, so measure the font directly.
	var font := UIFonts.body(500)
	var text_width := 70.0
	if font != null:
		text_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIPalette.FONT_SMALL).x
	node.custom_minimum_size = Vector2(text_width + 46.0, 36.0)
	return wire_button(node)


static func section_header(
	title: String,
	eyebrow_text: String = "",
	trailing: Control = null,
	icon_name: StringName = &""
) -> HBoxContainer:
	var row := hbox(UIPalette.SP4)
	if not String(icon_name).is_empty():
		var glyph := icon_or_null(icon_name, 20, UIPalette.mint)
		if glyph != null:
			glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(glyph)
	var text_box := vbox(3)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not eyebrow_text.is_empty():
		text_box.add_child(eyebrow(eyebrow_text, UIPalette.mint))
	text_box.add_child(heading(title, "H2"))
	row.add_child(text_box)
	if trailing != null:
		trailing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(trailing)
	return row


static func key_hint(text: String) -> PanelContainer:
	var node := panel("TransparentPanel")
	node.add_theme_stylebox_override(
		"panel",
		UITheme._box(Color.TRANSPARENT, UIPalette.alpha(UIPalette.line, 0.9), UIPalette.R_SM, 1, Vector4(6, 2, 6, 2))
	)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(label(text, "MonoSmall"))
	return node


static func hint_row(icon_name: StringName, text: String, accent: Color = Color.TRANSPARENT) -> HBoxContainer:
	var row := hbox(UIPalette.SP2)
	var glyph := icon_or_null(icon_name, 14, accent if accent.a > 0.0 else UIPalette.muted)
	if glyph != null:
		row.add_child(glyph)
	row.add_child(label(text, "BodySmall"))
	return row


static func empty_state(icon_name: StringName, title: String, body: String) -> VBoxContainer:
	var box := vbox(UIPalette.SP3)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var glyph := icon_or_null(icon_name, 32, UIPalette.muted_dim)
	if glyph != null:
		glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(glyph)
	var title_label := heading(title, "H3")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)
	var body_label := wrapped(body, "BodySmall")
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body_label)
	return box


static func toast_row(icon_name: StringName, title: String, body: String, accent: Color) -> HBoxContainer:
	var row := hbox(UIPalette.SP3)
	var glyph := icon_or_null(icon_name, 18, accent)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
	var text_box := vbox(2)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_child(label(title, "TitleLabel", UIPalette.ivory))
	if not body.is_empty():
		text_box.add_child(wrapped(body, "BodySmall"))
	row.add_child(text_box)
	return row


static func pips(value: int, maximum: int, accent: Color = Color.TRANSPARENT, size: int = 7) -> HBoxContainer:
	var row := hbox(4)
	var color := accent if accent.a > 0.0 else UIPalette.mint
	for index in maximum:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(size, size)
		pip.color = color if index < value else UIPalette.alpha(UIPalette.line, 0.9)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pip)
	return row


# ---------------------------------------------------------------------------
# Behaviour helpers
# ---------------------------------------------------------------------------

static func clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


static func focus_first(root: Control) -> Control:
	if root == null:
		return null
	if root.visible and root.focus_mode != Control.FOCUS_NONE and root is BaseButton and not root.is_queued_for_deletion():
		return root
	for child in root.get_children():
		if child is Control:
			var found := focus_first(child)
			if found != null:
				return found
	return null


static func animate_in(node: CanvasItem, delay: float = 0.0) -> void:
	if node == null or not is_instance_valid(node):
		return
	var duration := UIPalette.motion(UIPalette.MOTION)
	if duration <= 0.0 or not node.is_inside_tree():
		node.modulate.a = 1.0
		return
	node.modulate.a = 0.0
	var tween := node.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(node, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func animate_children(container: Node, stagger: float = 0.035, maximum: int = 10) -> void:
	if container == null:
		return
	var index := 0
	for child in container.get_children():
		if child is CanvasItem and index < maximum:
			animate_in(child, index * stagger)
			index += 1


static func set_min_height(control: Control, height: int) -> void:
	control.custom_minimum_size.y = height
