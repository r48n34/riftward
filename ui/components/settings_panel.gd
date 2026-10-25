class_name UISettingsPanel
extends VBoxContainer
## Reusable settings surface, used by both the Settings screen and the pause
## menu. Every control writes straight through App.set_setting and persists via
## App.save_settings, so there is no hidden apply step.

signal back_pressed

const QUALITY_VALUES := ["low", "medium", "high", "ultra"]
const KEYBIND_ACTIONS := [
	{"id": &"move_forward", "label": "Move Forward", "group": "Movement"},
	{"id": &"move_back", "label": "Move Back", "group": "Movement"},
	{"id": &"move_left", "label": "Move Left", "group": "Movement"},
	{"id": &"move_right", "label": "Move Right", "group": "Movement"},
	{"id": &"sprint", "label": "Sprint", "group": "Movement"},
	{"id": &"crouch", "label": "Crouch", "group": "Movement"},
	{"id": &"crouch_alt", "label": "Crouch (Alternate)", "group": "Movement"},
	{"id": &"jump", "label": "Jump", "group": "Movement"},
	{"id": &"fire", "label": "Fire", "group": "Combat"},
	{"id": &"aim", "label": "Aim Down Sights", "group": "Combat"},
	{"id": &"reload", "label": "Reload", "group": "Combat"},
	{"id": &"interact", "label": "Interact", "group": "Combat"},
	{"id": &"revive", "label": "Revive / Self-Revive", "group": "Combat"},
	{"id": &"ability_1", "label": "Ability 1", "group": "Combat"},
	{"id": &"ability_2", "label": "Ability 2", "group": "Combat"},
	{"id": &"ultimate", "label": "Ultimate", "group": "Combat"},
	{"id": &"grenade", "label": "Frag Grenade", "group": "Combat"},
	{"id": &"melee", "label": "Quick Melee (Knife)", "group": "Combat"},
	{"id": &"weapon_1", "label": "Weapon Slot 1", "group": "Weapons"},
	{"id": &"weapon_2", "label": "Weapon Slot 2", "group": "Weapons"},
	{"id": &"weapon_3", "label": "Weapon Slot 3", "group": "Weapons"},
	{"id": &"weapon_4", "label": "Weapon Slot 4 (Knife)", "group": "Weapons"},
	{"id": &"weapon_swap", "label": "Cycle Weapon", "group": "Weapons"},
	{"id": &"inventory", "label": "Inventory / Satchel", "group": "Interface"},
	{"id": &"call_exfil", "label": "Call Exfil Ship", "group": "Interface"},
	{"id": &"map", "label": "Tactical Map", "group": "Interface"},
	{"id": &"pause", "label": "Pause", "group": "Interface"},
	{"id": &"squad_command", "label": "Squad Command", "group": "Squad"},
	{"id": &"pet_command", "label": "Driftling Command", "group": "Squad"},
]
const ACTION_INPUTS := {
	&"fire": "Mouse Left",
	&"aim": "Mouse Right",
	&"weapon_swap": "Wheel Up",
}

var compact := false
var show_back := true

var _capturing_action: StringName = &""
var _capture_button: Button = null
var _save_pending := false
var _control_rows: Dictionary = {}
## Settings rows by key. `_setting_controls` holds the interactive leaf
## (OptionButton/CheckButton/HSlider) so tests and tooling can drive it.
var _setting_rows: Dictionary = {}
var _setting_controls: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", UIPalette.SP4)
	_build()


func _build() -> void:
	UIFactory.clear_children(self)
	_add_section_header("Audio", &"sound", "Master mix and interface feedback.")
	_build_audio()

	_add_section_header("Display", &"display", "Window mode, resolution, sync, rendering and interface scale.")
	_build_display()

	_add_section_header("Gameplay", &"crosshair", "How the Reach feels in your hands.")
	_build_gameplay()

	_add_section_header("Accessibility", &"accessibility", "Readability, motion and feedback options.")
	_build_accessibility()

	if not compact:
		_add_section_header("Controls", &"gamepad", "Click a binding, then press a key or button.")
		_build_controls()
	else:
		var note := UIFactory.panel("CardInset")
		note.add_child(UIFactory.help_note(
			"Rebind from Settings",
			"Full control rebinding is available from the main menu Settings screen.",
			&"info"
		))
		add_child(note)


# ---------------------------------------------------------------------------
# Section helpers
# ---------------------------------------------------------------------------

## Section title only; the explanatory line lives in the header tooltip.
func _add_section_header(title: String, icon_name: StringName, description: String) -> void:
	var row := UIFactory.hbox(UIPalette.SP3)
	row.tooltip_text = description
	var glyph := UIFactory.icon_or_null(icon_name, 18, UIPalette.mint)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
	row.add_child(UIFactory.heading(title, "H3"))
	add_child(row)


func _start_card() -> VBoxContainer:
	var card := UIFactory.panel("Card")
	add_child(card)
	var box := UIFactory.vbox(UIPalette.SP2)
	card.add_child(box)
	return box


func _build_audio() -> void:
	var box := _start_card()
	box.add_child(_slider_row("Master volume", "master_volume", 0.0, 1.0, 0.01, "percent"))
	box.add_child(_slider_row("Music volume", "music_volume", 0.0, 1.0, 0.01, "percent"))
	box.add_child(_slider_row("Effects volume", "sfx_volume", 0.0, 1.0, 0.01, "percent"))
	box.add_child(_slider_row("Interface volume", "ui_volume", 0.0, 1.0, 0.01, "percent"))


func _build_display() -> void:
	var box := _start_card()
	# Live monitor summary: the who/what/where line for the whole section.
	box.add_child(_display_summary_row())
	box.add_child(_option_row_options(
		"Window mode",
		"window_mode",
		App.get_window_mode_options(),
		"Windowed runs in a bordered resizable window. Borderless fills the screen with no chrome. Fullscreen takes exclusive display control and applies at the monitor's native resolution."
	))
	box.add_child(_option_row_options(
		"Resolution",
		"resolution",
		App.get_resolution_options(),
		"Windowed mode applies the chosen render resolution and centres the window. Borderless and fullscreen always fill the monitor; the resolution is kept for when you return to windowed mode."
	))
	box.add_child(_switch_row("V-Sync", "vsync", "Synchronise frame delivery to the display. Disable for lower input latency and uncapped frame rates."))
	box.add_child(_slider_row(
		"Render scale",
		"render_scale",
		0.5,
		1.0,
		0.05,
		"percent",
		"Internal 3D render resolution. Lower values raise frame rate at the cost of sharpness; the interface stays crisp."
	))
	box.add_child(_option_row_options(
		"Anti-aliasing",
		"anti_aliasing",
		App.get_aa_options(),
		"Edge smoothing. FXAA is cheapest, MSAA multiplies geometry samples, TAA reprojects across frames for the cleanest motion at a small cost."
	))
	box.add_child(_option_row_options(
		"Frame rate limit",
		"fps_limit",
		App.get_fps_options(),
		"Cap the frame rate to stabilise frame pacing and reduce heat. Unlimited lets the display and V-Sync decide."
	))
	box.add_child(_option_row(
		"Quality preset",
		"quality",
		["Low", "Medium", "High", "Ultra"],
		QUALITY_VALUES,
		"Shadow and LOD preset. Higher levels raise shadow atlas resolution and keep mesh detail at distance."
	))
	box.add_child(_slider_row(
		"Interface scale",
		"ui_scale",
		0.8,
		1.4,
		0.05,
		"scale",
		"Scale all interface text, spacing and controls. Useful on high-density displays or at a distance."
	))


func _display_summary_row() -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP2)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var monitor := UIFactory.icon_or_null(&"display", 18, UIPalette.mint)
	if monitor != null:
		monitor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(monitor)
	var summary_text := String(App.get_display_summary())
	var summary := UIFactory.label(summary_text, "MonoSmall", UIPalette.ivory)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(summary)
	row.tooltip_text = "Current display: %s" % summary_text
	var preset := UIFactory.label("DISPLAY", "Micro", UIPalette.muted_dim)
	preset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(preset)
	return row


func _build_gameplay() -> void:
	var box := _start_card()
	box.add_child(_slider_row("Field of view", "fov", 65.0, 110.0, 1.0, "degrees"))
	box.add_child(_slider_row("Mouse sensitivity", "mouse_sensitivity", 0.0005, 0.008, 0.0001, "sensitivity"))
	box.add_child(_slider_row("ADS sensitivity", "ads_sensitivity_scale", 0.3, 1.0, 0.05, "percent"))
	box.add_child(_slider_row("Camera shake", "camera_shake", 0.0, 1.0, 0.05, "percent"))
	box.add_child(_switch_row("Invert vertical look", "invert_y", "Reverse mouse Y axis."))
	box.add_child(_switch_row("Show minimap", "minimap", "Display the top-left tactical minimap during deployment."))
	box.add_child(_switch_row("Show performance meter", "show_fps", "Display frame rate during deployment."))


func _build_accessibility() -> void:
	var box := _start_card()
	box.add_child(_switch_row("Reduce motion", "reduce_motion", "Disable animated transitions and drifting scenery."))
	box.add_child(_switch_row("High contrast", "high_contrast", "Raise interface contrast and brighten text."))
	box.add_child(_switch_row("Damage numbers", "damage_numbers", "Show floating damage numbers in combat."))
	box.add_child(_switch_row("Subtitles", "subtitles", "Show radio dialogue and mission subtitles."))


func _build_controls() -> void:
	var card := UIFactory.panel("Card")
	add_child(card)
	var box := UIFactory.vbox(UIPalette.SP2)
	card.add_child(box)

	var current_group := ""
	for entry in KEYBIND_ACTIONS:
		var group: String = entry.group
		if group != current_group:
			current_group = group
			var group_label := UIFactory.eyebrow(group, UIPalette.muted)
			group_label.add_theme_constant_override("line_spacing", 2)
			box.add_child(UIFactory.pad(group_label, 0, UIPalette.SP2, 0, 0))
		box.add_child(_binding_row(entry))

	var divider := UIFactory.divider(UIPalette.line_soft)
	box.add_child(UIFactory.pad(divider, 0, UIPalette.SP2, 0, UIPalette.SP2))
	var footer := UIFactory.hbox(UIPalette.SP3)
	var note := UIFactory.label("Bindings must be unique. Click a binding, then press a key, mouse button or pad input. Escape cancels.", "Micro", UIPalette.muted_dim)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(note)
	var reset := UIFactory.ghost_button("Reset Controls", &"refresh")
	reset.tooltip_text = "Restore every gameplay action to its default binding."
	reset.pressed.connect(_on_reset_bindings)
	footer.add_child(reset)
	box.add_child(footer)


func _binding_row(entry: Dictionary) -> HBoxContainer:
	var action_id: StringName = entry.id
	var row := UIFactory.hbox(UIPalette.SP3)
	var label_text := UIFactory.label(String(entry.label), "Body")
	label_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label_text)
	var binding := UIFactory.button(_binding_text(action_id), "ChipButton", &"", &"ui_click")
	binding.toggle_mode = false
	binding.custom_minimum_size = Vector2(150, 32)
	binding.pressed.connect(func() -> void: _begin_capture(action_id, binding))
	_control_rows[action_id] = binding
	row.add_child(binding)
	return row


# ---------------------------------------------------------------------------
# Input rows
# ---------------------------------------------------------------------------

func _slider_row(label_text: String, key: String, min_value: float, max_value: float, step: float, format_mode: String, description: String = "") -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP4)
	if not description.is_empty():
		row.tooltip_text = description
	var name_label := UIFactory.label(label_text, "Body")
	name_label.custom_minimum_size = Vector2(210, 0)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)

	var slider := UIFactory.slider(min_value, max_value, step, float(App.get_setting(key)))
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value_label := UIFactory.label(_format_value(float(App.get_setting(key)), format_mode), "MonoSmall", UIPalette.ivory)
	value_label.custom_minimum_size = Vector2(74, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = _format_value(value, format_mode)
		_commit(key, snappedf(value, step), false)
	)
	slider.drag_ended.connect(func(_changed: bool) -> void: _save())
	row.add_child(slider)
	row.add_child(value_label)
	_register_setting_row(key, row, slider)
	return row


## Label only; the explanatory line lives in the row tooltip.
func _switch_row(label_text: String, key: String, description: String) -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP4)
	row.tooltip_text = description
	var name_label := UIFactory.label(label_text, "Body")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	var toggle := CheckButton.new()
	toggle.theme_type_variation = "SwitchRow"
	toggle.button_pressed = bool(App.get_setting(key))
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.toggled.connect(func(pressed: bool) -> void:
		_commit(key, pressed, true)
	)
	row.add_child(toggle)
	_register_setting_row(key, row, toggle)
	return row


func _option_row(label_text: String, key: String, labels: Array, values: Array, description: String = "") -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP4)
	if not description.is_empty():
		row.tooltip_text = description
	var name_label := UIFactory.label(label_text, "Body")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	var option := UIFactory.option_button(labels, 0)
	# Match the raw typed value (int fps caps, String resolution ids, ...). String
	# coercion would silently mis-select integer-valued options.
	var selected := values.find(App.get_setting(key))
	if selected >= 0:
		option.select(selected)
	option.custom_minimum_size = Vector2(190, 38)
	option.item_selected.connect(func(index: int) -> void:
		if index >= 0 and index < values.size():
			_commit(key, values[index], true)
	)
	row.add_child(option)
	_register_setting_row(key, row, option)
	return row


## Option row sourced from one of App's display option getters. Entries may be
## {label, value} dictionaries or plain values; plain values label themselves.
func _option_row_options(label_text: String, key: String, options: Array, description: String = "") -> HBoxContainer:
	var labels: Array = []
	var values: Array = []
	for entry in options:
		if entry is Dictionary:
			var value: Variant = entry.get("value", entry.get("id", entry.get("label", "")))
			values.append(value)
			labels.append(String(entry.get("label", str(value))))
		else:
			values.append(entry)
			labels.append(str(entry))
	return _option_row(label_text, key, labels, values, description)


## Register a settings row for meta lookup and the public test accessors.
func _register_setting_row(key: String, row: Control, control: Control) -> void:
	row.set_meta("setting_key", key)
	if control != null:
		control.set_meta("setting_key", key)
	_setting_rows[key] = row
	_setting_controls[key] = control


# ---------------------------------------------------------------------------
# Test / automation accessors
# ---------------------------------------------------------------------------

## Interactive leaf for a settings key (OptionButton, CheckButton or HSlider).
## Returns null for unknown keys.
func get_control(key: String) -> Control:
	return _setting_controls.get(key) as Control


## Typed convenience for OptionButton-backed settings.
func get_option_control(key: String) -> OptionButton:
	return _setting_controls.get(key) as OptionButton


## The full row (label + control) that carries meta("setting_key", key).
func get_setting_row(key: String) -> Control:
	return _setting_rows.get(key) as Control


func _format_value(value: float, mode: String) -> String:
	match mode:
		"percent":
			return "%d%%" % int(round(value * 100.0))
		"scale":
			return "%.0f%%" % (value * 100.0)
		"degrees":
			return "%d°" % int(round(value))
		"sensitivity":
			return "%.4f" % value
		_:
			return str(snappedf(value, 0.01))


func _commit(key: String, value: Variant, save_now: bool) -> void:
	if App == null:
		return
	App.set_setting(key, value)
	if save_now:
		_save()
	else:
		_save_pending = true


func _save() -> void:
	_save_pending = false
	if App != null:
		App.save_settings()


func _process(_delta: float) -> void:
	if _save_pending:
		_save_pending = false
		_save()


# ---------------------------------------------------------------------------
# Key rebinding
# ---------------------------------------------------------------------------

func _begin_capture(action_id: StringName, button: Button) -> void:
	if _capture_button != null and is_instance_valid(_capture_button):
		_capture_button.text = _binding_text(_capturing_action)
	_capturing_action = action_id
	_capture_button = button
	button.text = "PRESS INPUT…"
	button.button_pressed = false


func _cancel_capture() -> void:
	if _capture_button != null and is_instance_valid(_capture_button):
		_capture_button.text = _binding_text(_capturing_action)
	_capturing_action = &""
	_capture_button = null


func _input(event: InputEvent) -> void:
	if _capturing_action == &"":
		return
	if not is_visible_in_tree():
		_cancel_capture()
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_ESCAPE:
			_cancel_capture()
			get_viewport().set_input_as_handled()
			return
		_apply_binding(key_event)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		_apply_binding(mouse_event)
	elif event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		if not joy_event.pressed:
			return
		_apply_binding(joy_event)
	elif event is InputEventJoypadMotion:
		var axis_event := event as InputEventJoypadMotion
		if absf(axis_event.axis_value) < 0.6:
			return
		_apply_binding(axis_event)


func _apply_binding(event: InputEvent) -> void:
	if App == null:
		return
	var action_id := _capturing_action
	var conflict := App.find_binding_conflict(event, action_id)
	if conflict != &"":
		AudioDirector.play_ui(&"ui_error")
		EventBus.notification_requested.emit(
			"Binding in use",
			"That input is already bound to %s. Pick another input." % String(conflict).replace("_", " ").capitalize(),
			&"warning"
		)
		if _capture_button != null and is_instance_valid(_capture_button):
			_capture_button.text = "IN USE — TRY AGAIN"
		get_viewport().set_input_as_handled()
		return
	if App.rebind_action(action_id, event):
		_capturing_action = &""
		_capture_button = null
		if _control_rows.has(action_id):
			var button: Button = _control_rows[action_id]
			if is_instance_valid(button):
				button.text = _binding_text(action_id)
		AudioDirector.play_ui(&"ui_confirm")
	get_viewport().set_input_as_handled()


func _on_reset_bindings() -> void:
	if App == null:
		return
	App.reset_bindings()
	_cancel_capture()
	for key in _control_rows.keys():
		var button: Button = _control_rows[key]
		if is_instance_valid(button):
			button.text = _binding_text(key)
	AudioDirector.play_ui(&"ui_confirm")


func _binding_text(action_id: StringName) -> String:
	if not InputMap.has_action(action_id):
		return "Unbound"
	for event in InputMap.action_get_events(action_id):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			var code: int = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
			return OS.get_keycode_string(code)
		if event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			return ACTION_INPUTS.get(action_id, "Mouse %d" % mouse_event.button_index)
		if event is InputEventJoypadButton:
			return "Pad %s" % _joy_button_name((event as InputEventJoypadButton).button_index)
		if event is InputEventJoypadMotion:
			var axis_event := event as InputEventJoypadMotion
			return "Pad Axis %d" % axis_event.axis
	return "Unbound"


func _joy_button_name(button_index: int) -> String:
	match button_index:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_LEFT_STICK:
			return "LS"
		JOY_BUTTON_RIGHT_STICK:
			return "RS"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_BACK:
			return "Back"
		JOY_BUTTON_DPAD_UP:
			return "D-Pad Up"
		JOY_BUTTON_DPAD_DOWN:
			return "D-Pad Down"
		JOY_BUTTON_DPAD_LEFT:
			return "D-Pad Left"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-Pad Right"
		_:
			return str(button_index)
