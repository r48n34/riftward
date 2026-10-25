class_name PauseScreen
extends Control
## In-deployment pause menu. Resume / settings / abandon / quit, layered above
## the HUD and processing while the SceneTree is paused.

var _menu_box: VBoxContainer = null
var _settings_host: VBoxContainer = null
var _settings_panel: UISettingsPanel = null
var _identity_host: HBoxContainer = null
var _run_stats: HBoxContainer = null
var _abandon_button: Button = null
var _abandon_armed := false
var _resume_button: Button = null
var _skip_training_button: Button = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = UIPalette.alpha(UIPalette.ink, 0.68)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	var card := UIFactory.panel("ModalPanel")
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)

	var host := VBoxContainer.new()
	host.add_theme_constant_override("separation", UIPalette.SP4)
	card.add_child(host)

	_menu_box = UIFactory.vbox(UIPalette.SP4)
	host.add_child(_menu_box)

	# One title, one icon. The run identity below carries the detail.
	var title_row := UIFactory.hbox(UIPalette.SP3)
	var pause_glyph := UIFactory.icon_or_null(&"pause", 22, UIPalette.amber)
	if pause_glyph != null:
		pause_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(pause_glyph)
	title_row.add_child(UIFactory.heading("Deployment Paused", "H1"))
	_menu_box.add_child(title_row)

	_identity_host = UIFactory.hbox(UIPalette.SP4)
	_menu_box.add_child(_identity_host)

	_run_stats = UIFactory.hbox(UIPalette.SP5)
	_menu_box.add_child(_run_stats)

	_menu_box.add_child(UIFactory.divider(UIPalette.line_soft))

	var buttons := UIFactory.vbox(UIPalette.SP2)
	_resume_button = UIFactory.primary_button("Resume", &"play")
	_resume_button.pressed.connect(_on_resume)
	buttons.add_child(_resume_button)

	var settings_button := UIFactory.secondary_button("Settings", &"settings")
	settings_button.pressed.connect(_open_settings)
	buttons.add_child(settings_button)

	_abandon_button = UIFactory.danger_button("Abandon", &"exit")
	_abandon_button.tooltip_text = "Progress is saved on extraction. Dying or abandoning keeps your outpost."
	_abandon_button.pressed.connect(_on_abandon)
	buttons.add_child(_abandon_button)

	_skip_training_button = UIFactory.secondary_button("Skip Training", &"training")
	_skip_training_button.tooltip_text = "Finish onboarding immediately. Field Training can be replayed from the main menu."
	_skip_training_button.visible = false
	_skip_training_button.pressed.connect(_on_skip_training)
	buttons.add_child(_skip_training_button)

	var menu_button := UIFactory.ghost_button("Quit", &"home")
	menu_button.tooltip_text = "Leave the run and return to the main menu."
	menu_button.pressed.connect(_on_quit_to_menu)
	buttons.add_child(menu_button)
	_menu_box.add_child(buttons)

	_settings_host = UIFactory.vbox(UIPalette.SP3)
	host.add_child(_settings_host)
	_settings_host.visible = false


# ---------------------------------------------------------------------------
# API
# ---------------------------------------------------------------------------

func present() -> void:
	visible = true
	_abandon_armed = false
	if _abandon_button != null:
		_abandon_button.text = "Abandon"
	if _skip_training_button != null:
		_skip_training_button.visible = RunState.is_tutorial()
	_menu_box.visible = true
	_settings_host.visible = false
	_refresh()
	if _resume_button != null:
		_resume_button.focus_mode = Control.FOCUS_ALL
		_resume_button.grab_focus()


func _on_skip_training() -> void:
	if App != null:
		App.skip_tutorial()
	dismiss()


func dismiss() -> void:
	visible = false
	_menu_box.visible = true
	_settings_host.visible = false


func _refresh() -> void:
	var contract := ContentDB.get_contract(RunState.contract_id)
	var contract_name := contract.display_name if contract != null else String(RunState.contract_id).capitalize()
	if _identity_host != null:
		UIFactory.clear_children(_identity_host)
		_identity_host.add_child(_meta(&"flag", contract_name, "Contract", UIPalette.ivory))
		_identity_host.add_child(_meta(&"skull", "T%d" % RunState.threat, "Threat", UIPalette.danger))
		_identity_host.add_child(_meta(&"timer", UIPalette.format_time(RunState.get_time_left()), "Time remaining", UIPalette.amber))
	if _run_stats != null:
		UIFactory.clear_children(_run_stats)
		_run_stats.add_child(UIFactory.stat_block(&"target", "Kills", str(RunState.kills), UIPalette.ivory, 18))
		_run_stats.add_child(UIFactory.stat_block(&"grid", "Objectives", "%d/%d" % [RunState.completed_objectives, RunState.objectives.size()], UIPalette.mint, 18))
		_run_stats.add_child(UIFactory.stat_block(&"coins", "Satchel", UIPalette.format_int(RunState.satchel_salvage), UIPalette.amber, 18))
		_run_stats.add_child(UIFactory.stat_block(&"users", "Revives", str(RunState.revives_used), UIPalette.blue, 18))


func _meta(icon_name: StringName, value_text: String, tooltip: String, accent: Color) -> HBoxContainer:
	var row := UIFactory.icon_value(icon_name, value_text, accent, 13)
	row.tooltip_text = tooltip
	return row


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _on_resume() -> void:
	if App != null:
		App.set_pause(false)


func _open_settings() -> void:
	_menu_box.visible = false
	_settings_host.visible = true
	UIFactory.clear_children(_settings_host)
	var header := UIFactory.hbox(UIPalette.SP3)
	var glyph := UIFactory.icon_or_null(&"settings", 16, UIPalette.mint)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(glyph)
	header.add_child(UIFactory.eyebrow("Settings", UIPalette.mint))
	header.add_child(UIFactory.spacer_h())
	var back := UIFactory.ghost_button("Back", &"chevron-left")
	back.pressed.connect(_close_settings)
	header.add_child(back)
	_settings_host.add_child(header)
	var scroll := UIFactory.vscroll()
	scroll.custom_minimum_size = Vector2(620, 520)
	_settings_host.add_child(scroll)
	_settings_panel = UISettingsPanel.new()
	_settings_panel.compact = true
	_settings_panel.show_back = true
	_settings_panel.back_pressed.connect(_close_settings)
	scroll.add_child(_settings_panel)


func _close_settings() -> void:
	_settings_host.visible = false
	_menu_box.visible = true
	_abandon_armed = false
	if _abandon_button != null:
		_abandon_button.text = "Abandon"
	if _resume_button != null:
		_resume_button.grab_focus()


func _on_abandon() -> void:
	if not _abandon_armed:
		_abandon_armed = true
		_abandon_button.text = "Confirm Abandon — salvage will be lost"
		return
	if App != null:
		App.set_pause(false)
	if RunState.active:
		RunState.end_run(false, "Deployment abandoned. The Reach keeps what it takes.")
	else:
		if App != null:
			App.show_hub()


func _on_quit_to_menu() -> void:
	if App != null:
		App.set_pause(false)
		App.show_main_menu()
