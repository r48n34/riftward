class_name DeploymentHud
extends Control
## In-deployment heads-up display. Binds to the Player's documented signals when
## present, falls back to 10 Hz get_hud_snapshot() polling, and renders a calm,
## minimal HUD: vitals, weapon, abilities, compass, objectives, squad, boss bar,
## notifications, radio subtitles, interaction prompts and directional damage.

const PANEL_PAD := 24
const UIHudMinimapScript := preload("res://ui/hud/hud_minimap.gd")
const UIHudScopeScript := preload("res://ui/hud/hud_scope.gd")
const UIHudAimSightScript := preload("res://ui/hud/hud_aim_sight.gd")
const MINIMAP_SIZE := 216.0
const WORLD_EVENT_HOLD := 7.0
const WORLD_EVENT_MAX_QUEUE := 4

var _player_ref: WeakRef = null
var _bound_player: Node = null
var _connections: Array = []
var _has_hud_signal := false
var _poll_accum := 0.0
var _heading_accum := 0.0
var _fallback_accum := 0.0
var _fps_accum := 0.0
var _objective_signature := ""
var _snapshot: Dictionary = {}
var _downed := false
var _storm_active := false
var _subtitles_enabled := true
var _damage_numbers_enabled := true
var _show_fps := false
var _subtitle_token := 0
var _boss_active := false
var _squad_signature := ""
var _companion_manager: Node = null
var _companion_accum := 0.0
var _companion_signature := ""
var _cloaked := false
var _hyperfocused := false
var _crouching := false
var _kia := false
var _minimap_enabled := true
var _map_open := false
var _tactical_accum := 0.0
var _tactical_data: Dictionary = {}
var _mission_trackers: Array = []
var _tracker_box: VBoxContainer = null
var _tracker_divider: ColorRect = null
var _tracker_rows: VBoxContainer = null
var _world_chip: Control = null
var _weather_icon: TextureRect = null
var _weather_label: Label = null
var _clock_label: Label = null
var _dungeon_panel: PanelContainer = null
var _dungeon_label: Label = null
var _tutorial_panel: PanelContainer = null
var _tutorial_title: Label = null
var _tutorial_body: Label = null
var _tutorial_hint: Label = null
var _tutorial_bar: ProgressBar = null
var _hazard_overlay: ColorRect = null
var _hazard_label: Label = null
var _hazard_state: StringName = &"none"

# Reach Event banner (EventBus.world_event): compact, queued, auto-hiding.
var _world_event_panel: PanelContainer = null
var _world_event_icon: TextureRect = null
var _world_event_title: Label = null
var _world_event_body: Label = null
var _world_event_queue: Array[Dictionary] = []
var _world_event_active := false
var _world_event_token := 0

var _minimap: Control = null
var _map_overlay: Control = null
var _scope: Control = null

# Custom-drawn widgets.
var _edge: UIHudEdge = null
var _damage_numbers: UIHudDamageNumbers = null
var _crosshair: UIHudCrosshair = null
var _aim_sight: Control = null
var _inventory_hint: HBoxContainer = null
var _compass: UIHudCompass = null
var _vitals: UIHudVitals = null
var _weapon: UIHudWeapon = null
var _abilities: UIHudAbilities = null

# Structured panels.
var _timer_panel: PanelContainer = null
var _timer_label: Label = null
var _timer_caption: Label = null
var _fps_label: Label = null
var _status_label: Label = null
var _exfil_panel: PanelContainer = null
var _exfil_label: Label = null
var _exfil_detail: Label = null
var _exfil_bar: ProgressBar = null
var _objective_panel: PanelContainer = null
var _objective_contract: Label = null
var _objective_rows: VBoxContainer = null
var _squad_panel: PanelContainer = null
var _squad_rows: VBoxContainer = null
var _notify_box: VBoxContainer = null
var _subtitle_panel: PanelContainer = null
var _subtitle_speaker: Label = null
var _subtitle_line: Label = null
var _interaction_panel: PanelContainer = null
var _interaction_text: Label = null
var _interaction_key: Label = null
var _boss_panel: PanelContainer = null
var _boss_name: Label = null
var _boss_bar: ProgressBar = null
var _downed_panel: PanelContainer = null
var _bleedout_bar: ProgressBar = null
var _bleedout_label: Label = null
var _revive_bar: ProgressBar = null
var _revive_charges_label: Label = null
var _kia_label: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_settings_early()
	_build()
	_connect_bus()
	_refresh_objectives(true)
	_refresh_timer(RunState.get_time_left())


func _apply_settings_early() -> void:
	if App == null:
		return
	_subtitles_enabled = bool(App.get_setting("subtitles", true))
	_damage_numbers_enabled = bool(App.get_setting("damage_numbers", true))
	_show_fps = bool(App.get_setting("show_fps", false))
	_minimap_enabled = bool(App.get_setting("minimap", true))


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _anchored(control: Control, preset: int, left: float, top: float, right: float, bottom: float) -> void:
	add_child(control)
	control.set_anchors_preset(preset)
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom


func _build() -> void:
	_edge = UIHudEdge.new()
	_anchored(_edge, Control.PRESET_FULL_RECT, 0, 0, 0, 0)

	_damage_numbers = UIHudDamageNumbers.new()
	_damage_numbers.enabled = _damage_numbers_enabled
	_anchored(_damage_numbers, Control.PRESET_FULL_RECT, 0, 0, 0, 0)

	_scope = UIHudScopeScript.new()
	_anchored(_scope, Control.PRESET_FULL_RECT, 0, 0, 0, 0)

	_minimap = UIHudMinimapScript.new()
	_anchored(_minimap, Control.PRESET_TOP_LEFT, PANEL_PAD, PANEL_PAD, PANEL_PAD + MINIMAP_SIZE, PANEL_PAD + MINIMAP_SIZE)
	_minimap.visible = _minimap_enabled

	_crosshair = UIHudCrosshair.new()
	_anchored(_crosshair, Control.PRESET_CENTER, -120, -120, 120, 120)

	_aim_sight = UIHudAimSightScript.new()
	_anchored(_aim_sight, Control.PRESET_FULL_RECT, 0, 0, 0, 0)

	_compass = UIHudCompass.new()
	_anchored(_compass, Control.PRESET_CENTER_TOP, -240, 16, 240, 46)

	_build_timer_panel()
	_build_tutorial_panel()
	_build_dungeon_panel()
	_build_hazard_overlay()
	_build_exfil_panel()
	_build_boss_panel()
	_build_objective_panel()
	_build_squad_panel()
	_build_notifications()
	_build_world_event_banner()
	_build_vitals()
	_build_weapon()
	_build_inventory_hint()
	_build_abilities()
	_build_subtitle()
	_build_interaction()
	_build_downed()
	_build_kia()

	_map_overlay = UIHudMinimapScript.new()
	_map_overlay.expanded = true
	_anchored(_map_overlay, Control.PRESET_FULL_RECT, 0, 0, 0, 0)
	_map_overlay.visible = false
	_map_overlay.z_index = 50


func _make_hud_panel(preset: int, left: float, top: float, right: float, bottom: float) -> PanelContainer:
	var panel := UIFactory.panel("HudPanel")
	_anchored(panel, preset, left, top, right, bottom)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _build_timer_panel() -> void:
	_timer_panel = _make_hud_panel(Control.PRESET_CENTER_TOP, -160, 52, 160, 118)
	var box := UIFactory.vbox(1)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_timer_label = UIFactory.number_text("--:--", 26, UIPalette.ivory)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_timer_label)
	_timer_caption = UIFactory.label("—", "Micro", UIPalette.muted)
	_timer_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_timer_caption)
	# Weather + local clock live under the run timer so they never compete with
	# the squad panel or the notification feed.
	var world_row := UIFactory.hbox(6, BoxContainer.ALIGNMENT_CENTER)
	_weather_icon = UIFactory.icon(&"weather-sun", 12, UIPalette.amber)
	world_row.add_child(_weather_icon)
	_weather_label = UIFactory.label("CLEAR", "Micro", UIPalette.ivory)
	world_row.add_child(_weather_label)
	world_row.add_child(UIFactory.label("·", "Micro", UIPalette.muted_dim))
	_clock_label = UIFactory.label("--:--", "MonoSmall", UIPalette.muted)
	world_row.add_child(_clock_label)
	box.add_child(world_row)
	_world_chip = world_row
	_fps_label = UIFactory.label("", "Micro", UIPalette.muted_dim)
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fps_label.visible = _show_fps
	box.add_child(_fps_label)
	_status_label = UIFactory.label("", "Micro", UIPalette.mint)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.visible = false
	box.add_child(_status_label)
	_timer_panel.add_child(box)


func _build_dungeon_panel() -> void:
	_dungeon_panel = _make_hud_panel(Control.PRESET_CENTER_TOP, -250, 104, 250, 148)
	_dungeon_label = UIFactory.label("UNDER-REACH", "Eyebrow", UIPalette.violet)
	_dungeon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dungeon_panel.add_child(_dungeon_label)
	_dungeon_panel.visible = false


func _build_tutorial_panel() -> void:
	_tutorial_panel = _make_hud_panel(Control.PRESET_CENTER_TOP, -280, 156, 280, 360)
	var box := UIFactory.vbox(UIPalette.SP2)
	_tutorial_title = UIFactory.label("FIELD TRAINING", "Eyebrow", UIPalette.mint)
	box.add_child(_tutorial_title)
	_tutorial_body = UIFactory.label("", "BodySmall", UIPalette.ivory)
	_tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_tutorial_body)
	_tutorial_bar = UIFactory.progress(0.0, 100.0, "BarMint", 5)
	box.add_child(_tutorial_bar)
	_tutorial_hint = UIFactory.label("", "Micro", UIPalette.amber)
	box.add_child(_tutorial_hint)
	_tutorial_panel.add_child(box)
	_tutorial_panel.visible = false


func _build_hazard_overlay() -> void:
	_hazard_overlay = ColorRect.new()
	_hazard_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_hazard_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hazard_overlay.z_index = -5
	_anchored(_hazard_overlay, Control.PRESET_FULL_RECT, 0, 0, 0, 0)
	_hazard_label = UIFactory.label("", "Eyebrow", UIPalette.ivory)
	_hazard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchored(_hazard_label, Control.PRESET_CENTER_BOTTOM, -140, -118, 140, -88)
	_hazard_label.visible = false


func _update_world_chip() -> void:
	if _world_chip == null:
		return
	if _tactical_data.is_empty():
		_world_chip.visible = false
		return
	var in_dungeon := bool(_tactical_data.get("in_dungeon", false))
	_world_chip.visible = not in_dungeon
	var weather: Dictionary = _tactical_data.get("weather", {}) if _tactical_data.get("weather", {}) is Dictionary else {}
	var icon_name := StringName(weather.get("icon", &"weather-sun"))
	var texture := UIIcons.get_icon(icon_name)
	if texture == null:
		texture = UIIcons.get_icon(&"weather-sun")
	if _weather_icon != null:
		_weather_icon.texture = texture
	if _weather_label != null:
		_weather_label.text = String(weather.get("display_name", "Clear")).to_upper()
		_weather_label.add_theme_color_override("font_color", weather.get("color", UIPalette.amber))
	if _clock_label != null:
		_clock_label.text = String(_tactical_data.get("clock_text", "--:--"))
	if in_dungeon and _clock_label != null:
		_clock_label.text = "UNDER-REACH"
	if _world_chip != null:
		_world_chip.visible = not in_dungeon
	if _minimap != null:
		_minimap.visible = _minimap_enabled and not _kia and not in_dungeon
	if in_dungeon and _dungeon_panel != null:
		_dungeon_panel.visible = true
		_dungeon_label.text = "UNDER-REACH · " + String(_tactical_data.get("dungeon_name", "")).to_upper()


func _on_hazard_state_changed(state: StringName) -> void:
	_hazard_state = state
	if _hazard_overlay == null:
		return
	match state:
		&"water":
			_hazard_overlay.color = Color(0.05, 0.22, 0.32, 0.20)
			if _hazard_label != null:
				_hazard_label.text = "UNDERWATER"
				_hazard_label.visible = true
		&"lava":
			_hazard_overlay.color = Color(0.72, 0.14, 0.04, 0.26)
			if _hazard_label != null:
				_hazard_label.text = "LAVA — MOVE"
				_hazard_label.visible = true
		_:
			_hazard_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
			if _hazard_label != null:
				_hazard_label.visible = false


func _on_tutorial_stage_changed(stage: Dictionary) -> void:
	if _tutorial_panel == null:
		return
	if stage.is_empty() or bool(stage.get("complete", false)):
		_tutorial_panel.visible = false
		return
	_tutorial_panel.visible = true
	_tutorial_title.text = "FIELD TRAINING %d/%d · %s" % [
		int(stage.get("index", 0)) + 1,
		int(stage.get("total", 5)),
		String(stage.get("title", "")),
	]
	_tutorial_body.text = String(stage.get("body", ""))
	_tutorial_hint.text = String(stage.get("hint", ""))
	if _tutorial_bar != null:
		_tutorial_bar.value = clampf(float(stage.get("progress", 0.0)), 0.0, 1.0) * 100.0


func _on_dungeon_state_changed(active: bool, dungeon_name: String) -> void:
	if _dungeon_panel != null:
		_dungeon_panel.visible = active
		if active:
			_dungeon_label.text = "UNDER-REACH · " + dungeon_name.to_upper()
	if _world_chip != null:
		_world_chip.visible = not active
	if _minimap != null:
		_minimap.visible = _minimap_enabled and not _kia and not active


func _build_exfil_panel() -> void:
	_exfil_panel = _make_hud_panel(Control.PRESET_CENTER_TOP, -178, 156, 178, 212)
	var box := UIFactory.vbox(4)
	var head := UIFactory.hbox(UIPalette.SP2, BoxContainer.ALIGNMENT_CENTER)
	head.add_child(UIFactory.icon(&"exfil", 16, UIPalette.amber))
	_exfil_label = UIFactory.label("EXFIL HOLD", "Eyebrow", UIPalette.amber)
	head.add_child(_exfil_label)
	box.add_child(head)
	_exfil_bar = UIFactory.progress(100.0, 100.0, "BarAmber", 6)
	box.add_child(_exfil_bar)
	_exfil_detail = UIFactory.label("", "Micro", UIPalette.muted)
	_exfil_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_exfil_detail)
	_exfil_panel.add_child(box)
	_exfil_panel.visible = false


func _build_boss_panel() -> void:
	_boss_panel = _make_hud_panel(Control.PRESET_CENTER_TOP, -300, 220, 300, 276)
	var box := UIFactory.vbox(4)
	var head := UIFactory.hbox(UIPalette.SP2)
	head.add_child(UIFactory.icon(&"warning", 15, UIPalette.danger))
	_boss_name = UIFactory.label("BOSS", "Eyebrow", UIPalette.danger)
	head.add_child(_boss_name)
	box.add_child(head)
	_boss_bar = UIFactory.progress(100.0, 100.0, "BarDanger", 8)
	box.add_child(_boss_bar)
	_boss_panel.add_child(box)
	_boss_panel.visible = false


func _objective_top() -> float:
	return PANEL_PAD + (MINIMAP_SIZE + 14.0 if _minimap_enabled else 0.0)


func _build_objective_panel() -> void:
	var top := _objective_top()
	_objective_panel = _make_hud_panel(Control.PRESET_TOP_LEFT, PANEL_PAD, top, PANEL_PAD + 356, top + 10)
	_objective_panel.grow_vertical = Control.GROW_DIRECTION_END
	_objective_panel.custom_minimum_size.x = 356
	var box := UIFactory.vbox(UIPalette.SP2)
	var head := UIFactory.hbox(UIPalette.SP2)
	head.add_child(UIFactory.icon(&"target", 14, UIPalette.mint))
	head.add_child(UIFactory.eyebrow("Objective", UIPalette.mint))
	box.add_child(head)
	_objective_contract = UIFactory.label("—", "TitleLabel")
	box.add_child(_objective_contract)
	_objective_rows = UIFactory.vbox(4)
	box.add_child(_objective_rows)
	# Compact Field Ops tracker block (fed by Deployment.set_mission_trackers).
	_tracker_divider = UIFactory.divider(UIPalette.line_soft)
	box.add_child(_tracker_divider)
	_tracker_box = UIFactory.vbox(3)
	var tracker_head := UIFactory.hbox(6)
	var tracker_glyph := UIFactory.icon_or_null(&"flag", 12, UIPalette.amber)
	if tracker_glyph != null:
		tracker_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tracker_head.add_child(tracker_glyph)
	tracker_head.add_child(UIFactory.label("FIELD OPS", "EyebrowMuted"))
	_tracker_box.add_child(tracker_head)
	_tracker_rows = UIFactory.vbox(3)
	_tracker_box.add_child(_tracker_rows)
	box.add_child(_tracker_box)
	_tracker_divider.visible = false
	_tracker_box.visible = false
	_objective_panel.add_child(box)


func _build_squad_panel() -> void:
	_squad_panel = _make_hud_panel(Control.PRESET_TOP_RIGHT, -PANEL_PAD - 300, PANEL_PAD, -PANEL_PAD, PANEL_PAD + 10)
	_squad_panel.grow_vertical = Control.GROW_DIRECTION_END
	_squad_panel.custom_minimum_size.x = 300
	var box := UIFactory.vbox(6)
	var head := UIFactory.hbox(UIPalette.SP2)
	head.add_child(UIFactory.icon(&"users", 14, UIPalette.mint))
	head.add_child(UIFactory.eyebrow("Squad", UIPalette.mint))
	box.add_child(head)
	_squad_rows = UIFactory.vbox(4)
	box.add_child(_squad_rows)
	_squad_panel.add_child(box)


func _build_notifications() -> void:
	_notify_box = UIFactory.vbox(UIPalette.SP2)
	_notify_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchored(_notify_box, Control.PRESET_TOP_RIGHT, -PANEL_PAD - 320, 196, -PANEL_PAD, 204)


## Compact Reach Event banner. Sits above the subtitle/ability tray, never
## competes with gameplay panels, and queues events so rapid-fire world events
## are all readable.
func _build_world_event_banner() -> void:
	_world_event_panel = _make_hud_panel(Control.PRESET_CENTER_BOTTOM, -320, -PANEL_PAD - 252, 320, -PANEL_PAD - 174)
	_world_event_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_event_panel.visible = false
	var box := UIFactory.vbox(3)
	var head := UIFactory.hbox(UIPalette.SP2, BoxContainer.ALIGNMENT_CENTER)
	_world_event_icon = UIFactory.icon(&"bolt", 16, UIPalette.amber)
	_world_event_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_world_event_icon)
	_world_event_title = UIFactory.label("REACH EVENT", "Eyebrow", UIPalette.amber)
	head.add_child(_world_event_title)
	box.add_child(head)
	_world_event_body = UIFactory.wrapped("", "BodySmall", UIPalette.ivory)
	_world_event_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_world_event_body)
	_world_event_panel.add_child(box)


func _build_vitals() -> void:
	_vitals = UIHudVitals.new()
	_anchored(_vitals, Control.PRESET_BOTTOM_LEFT, PANEL_PAD, -PANEL_PAD - 108, PANEL_PAD + 330, -PANEL_PAD)


func _build_weapon() -> void:
	_weapon = UIHudWeapon.new()
	_anchored(_weapon, Control.PRESET_BOTTOM_RIGHT, -PANEL_PAD - 336, -PANEL_PAD - 150, -PANEL_PAD, -PANEL_PAD)


func _build_inventory_hint() -> void:
	_inventory_hint = UIFactory.hbox(UIPalette.SP2)
	_inventory_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchored(_inventory_hint, Control.PRESET_BOTTOM_RIGHT, -PANEL_PAD - 336, -PANEL_PAD - 184, -PANEL_PAD, -PANEL_PAD - 156)
	_inventory_hint.alignment = BoxContainer.ALIGNMENT_END
	_inventory_hint.add_child(UIFactory.label("PACK", "Micro", UIPalette.muted_dim))
	_inventory_hint.add_child(UIFactory.key_hint(_inventory_key_text()))
	_refresh_inventory_hint()


func _inventory_key_text() -> String:
	if App == null:
		return "I"
	return String(App.get_action_binding_text(&"inventory", "I"))


func _refresh_inventory_hint() -> void:
	if _inventory_hint == null:
		return
	for child in _inventory_hint.get_children():
		if child is PanelContainer and child.has_method("get_child"):
			var inner := child.get_child(0) as Label
			if inner != null:
				inner.text = _inventory_key_text()
				return


func _build_abilities() -> void:
	_abilities = UIHudAbilities.new()
	_anchored(_abilities, Control.PRESET_CENTER_BOTTOM, -180, -PANEL_PAD - 108, 180, -PANEL_PAD)
	_abilities.visible = false


func _build_subtitle() -> void:
	_subtitle_panel = _make_hud_panel(Control.PRESET_CENTER_BOTTOM, -410, -PANEL_PAD - 142, 410, -PANEL_PAD - 110)
	_subtitle_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var row := UIFactory.hbox(UIPalette.SP3, BoxContainer.ALIGNMENT_CENTER)
	_subtitle_speaker = UIFactory.label("KESTREL", "Eyebrow", UIPalette.mint)
	_subtitle_speaker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_subtitle_speaker)
	_subtitle_line = UIFactory.label("", "Body")
	_subtitle_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subtitle_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_subtitle_line)
	_subtitle_panel.add_child(row)
	_subtitle_panel.visible = false


func _build_interaction() -> void:
	_interaction_panel = _make_hud_panel(Control.PRESET_CENTER, -220, 78, 220, 124)
	var row := UIFactory.hbox(UIPalette.SP3, BoxContainer.ALIGNMENT_CENTER)
	var key_cap := UIFactory.key_hint("E")
	_interaction_key = key_cap.get_child(0) as Label
	row.add_child(key_cap)
	_interaction_text = UIFactory.label("Interact", "Body")
	row.add_child(_interaction_text)
	_interaction_panel.add_child(row)
	_interaction_panel.visible = false


func _build_downed() -> void:
	_downed_panel = _make_hud_panel(Control.PRESET_CENTER, -320, -92, 320, 92)
	var box := UIFactory.vbox(UIPalette.SP2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := UIFactory.display_text("DOWNED", 42, 700, UIPalette.danger)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_bleedout_label = UIFactory.label("Bleedout --", "MonoSmall", UIPalette.amber)
	_bleedout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_bleedout_label)
	_bleedout_bar = UIFactory.progress(100.0, 100.0, "BarDanger", 8)
	box.add_child(_bleedout_bar)
	_revive_bar = UIFactory.progress(0.0, 100.0, "BarMint", 6)
	_revive_bar.visible = false
	box.add_child(_revive_bar)
	_revive_charges_label = UIFactory.label("", "Micro", UIPalette.mint)
	_revive_charges_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_revive_charges_label.visible = false
	box.add_child(_revive_charges_label)
	_downed_panel.add_child(box)
	_downed_panel.visible = false


func _build_kia() -> void:
	_kia_label = UIFactory.display_text("SIGNAL LOST", 54, 700, UIPalette.danger)
	_kia_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchored(_kia_label, Control.PRESET_CENTER, -400, -70, 400, 20)
	_kia_label.visible = false


# ---------------------------------------------------------------------------
# Player binding
# ---------------------------------------------------------------------------

func bind_player(player: Node) -> void:
	_unbind_player()
	_bound_player = player
	_kia = false
	if player == null:
		_has_hud_signal = false
		_mission_trackers.clear()
		_refresh_mission_trackers()
		return
	_player_ref = weakref(player)
	_has_hud_signal = player.has_signal("hud_updated")
	_safe_connect(player, "hud_updated", Callable(self, "_on_hud_updated"))
	_safe_connect(player, "hitmarker", Callable(self, "_on_hitmarker"))
	_safe_connect(player, "damage_indicator", Callable(self, "_on_damage_indicator"))
	_safe_connect(player, "downed_changed", Callable(self, "_on_downed_changed"))
	_safe_connect(player, "died", Callable(self, "_on_died"))
	var snapshot = _read_snapshot()
	if snapshot is Dictionary and not snapshot.is_empty():
		_apply_snapshot(snapshot)
	_refresh_squad()
	_refresh_objectives(true)
	_refresh_timer(RunState.get_time_left())
	_refresh_companion_manager(true)


func _unbind_player() -> void:
	for entry in _connections:
		var node = entry.get("node")
		if node != null and is_instance_valid(node):
			var signal_name: String = entry.get("signal", "")
			var callable: Callable = entry.get("callable")
			if node.is_connected(signal_name, callable):
				node.disconnect(signal_name, callable)
	_connections.clear()
	_bound_player = null
	_player_ref = null


func _safe_connect(player: Node, signal_name: String, callable: Callable) -> void:
	if player == null or not player.has_signal(signal_name):
		return
	if player.is_connected(signal_name, callable):
		return
	player.connect(signal_name, callable)
	_connections.append({"node": player, "signal": signal_name, "callable": callable})


func _player() -> Node:
	if _player_ref == null:
		return null
	var player = _player_ref.get_ref()
	if player == null or not is_instance_valid(player):
		return null
	return player


func _read_snapshot() -> Variant:
	var player := _player()
	if player == null:
		return null
	if not player.has_method("get_hud_snapshot"):
		return null
	return player.call("get_hud_snapshot")


# ---------------------------------------------------------------------------
# Event bus
# ---------------------------------------------------------------------------

func _connect_bus() -> void:
	if EventBus == null:
		return
	EventBus.timer_updated.connect(_on_timer_updated)
	EventBus.objective_updated.connect(_on_objective_updated)
	EventBus.storm_changed.connect(_on_storm_changed)
	EventBus.extraction_state_changed.connect(_on_extraction_state_changed)
	EventBus.notification_requested.connect(_on_notification_requested)
	EventBus.radio_message.connect(_on_radio_message)
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.hazard_state_changed.connect(_on_hazard_state_changed)
	EventBus.tutorial_stage_changed.connect(_on_tutorial_stage_changed)
	EventBus.dungeon_state_changed.connect(_on_dungeon_state_changed)
	EventBus.world_event.connect(_on_world_event)


func _exit_tree() -> void:
	if EventBus == null:
		return
	if EventBus.timer_updated.is_connected(_on_timer_updated):
		EventBus.timer_updated.disconnect(_on_timer_updated)
	if EventBus.objective_updated.is_connected(_on_objective_updated):
		EventBus.objective_updated.disconnect(_on_objective_updated)
	if EventBus.storm_changed.is_connected(_on_storm_changed):
		EventBus.storm_changed.disconnect(_on_storm_changed)
	if EventBus.extraction_state_changed.is_connected(_on_extraction_state_changed):
		EventBus.extraction_state_changed.disconnect(_on_extraction_state_changed)
	if EventBus.notification_requested.is_connected(_on_notification_requested):
		EventBus.notification_requested.disconnect(_on_notification_requested)
	if EventBus.radio_message.is_connected(_on_radio_message):
		EventBus.radio_message.disconnect(_on_radio_message)
	if EventBus.game_paused.is_connected(_on_game_paused):
		EventBus.game_paused.disconnect(_on_game_paused)
	if EventBus.hazard_state_changed.is_connected(_on_hazard_state_changed):
		EventBus.hazard_state_changed.disconnect(_on_hazard_state_changed)
	if EventBus.tutorial_stage_changed.is_connected(_on_tutorial_stage_changed):
		EventBus.tutorial_stage_changed.disconnect(_on_tutorial_stage_changed)
	if EventBus.dungeon_state_changed.is_connected(_on_dungeon_state_changed):
		EventBus.dungeon_state_changed.disconnect(_on_dungeon_state_changed)
	if EventBus.world_event.is_connected(_on_world_event):
		EventBus.world_event.disconnect(_on_world_event)
	_unbind_player()


# ---------------------------------------------------------------------------
# Snapshot handling
# ---------------------------------------------------------------------------

func _on_hud_updated(snapshot: Variant) -> void:
	if snapshot is Dictionary:
		_apply_snapshot(snapshot)


func _apply_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	_snapshot = snapshot
	var max_health := maxf(1.0, float(snapshot.get("max_health", 100.0)))
	var health := clampf(float(snapshot.get("health", max_health)), 0.0, max_health)
	var max_shield := maxf(0.0, float(snapshot.get("max_shield", 0.0)))
	var shield := clampf(float(snapshot.get("shield", 0.0)), 0.0, max_shield if max_shield > 0.0 else 0.0)
	var armor := float(snapshot.get("armor", 0.0))
	var previous_shield := _vitals.shield if _vitals != null else shield
	_vitals.set_values(health, max_health, shield, max_shield, armor)
	var ratio := health / max_health
	if snapshot.has("health_fraction"):
		ratio = clampf(float(snapshot.get("health_fraction", ratio)), 0.0, 1.0)
	_edge.set_health_ratio(ratio)
	if previous_shield > 0.0 and shield <= 0.01 and not bool(snapshot.get("downed", false)):
		_edge.flash_shield(0.7)

	_weapon.set_weapon(snapshot)
	_abilities.set_abilities(_normalise_abilities(snapshot.get("abilities", [])))

	var downed := bool(snapshot.get("downed", false))
	if downed != _downed:
		_set_downed(downed)
	if downed:
		var bleedout = snapshot.get("bleedout", null)
		if bleedout != null:
			_update_bleedout(float(bleedout))
		var revive := clampf(float(snapshot.get("revive_progress", 0.0)), 0.0, 1.0)
		_update_revive(revive)
		var revive_charges = snapshot.get("revive_charges", null)
		if revive_charges != null and _revive_charges_label != null:
			var charges := int(revive_charges)
			_revive_charges_label.text = "SELF-REVIVE CHARGES  %d" % charges if charges > 0 else "NO REVIVE CHARGES"
			_revive_charges_label.add_theme_color_override("font_color", UIPalette.mint if charges > 0 else UIPalette.danger)
			_revive_charges_label.visible = true

	_cloaked = bool(snapshot.get("cloaked", false))
	_hyperfocused = bool(snapshot.get("hyperfocused", false))
	_crouching = bool(snapshot.get("crouching", false))
	_update_scope(snapshot, downed)
	_update_status_chips()

	var yaw = snapshot.get("yaw", snapshot.get("rotation_y", null))
	if yaw != null:
		_compass.set_heading(-rad_to_deg(float(yaw)))

	var boss = snapshot.get("boss", null)
	if boss is Dictionary and not (boss as Dictionary).is_empty():
		var boss_name := String(boss.get("name", boss.get("display_name", "BOSS")))
		show_boss(boss_name, float(boss.get("health", 1.0)), float(boss.get("max_health", 1.0)))
	elif _boss_active:
		hide_boss()

	if _get_companion_manager() == null:
		var squad_data = snapshot.get("squad", null)
		if squad_data is Array:
			_render_squad_rows(squad_data)

	var interact = snapshot.get("interact_prompt", snapshot.get("interaction_prompt", null))
	if interact != null and not String(interact).is_empty():
		show_interaction(String(interact))
	else:
		hide_interaction()


func _update_scope(snapshot: Dictionary, downed: bool) -> void:
	var ads := float(snapshot.get("ads_amount", 0.0))
	var zoom := float(snapshot.get("ads_zoom", 0.82))
	var range_m := float(snapshot.get("weapon_range", 120.0))
	var melee := bool(snapshot.get("is_melee", false))
	var style := String(snapshot.get("weapon_style", "rifle"))
	var accent: Color = snapshot.get("weapon_accent", Color("62e6c3"))
	var scoped_weapon := zoom <= 0.60
	var scope_target := 0.0
	if not downed and not _kia and not melee and scoped_weapon and ads > 0.35:
		scope_target = clampf((ads - 0.35) / 0.45, 0.0, 1.0)
	if _scope != null:
		_scope.set_scope(scope_target, zoom, range_m)
	# Style-specific ADS reticle for everything that is not using the scope.
	var sight_target := 0.0
	if not downed and not _kia and not melee and not scoped_weapon:
		sight_target = clampf((ads - 0.12) / 0.55, 0.0, 1.0)
	if _aim_sight != null:
		_aim_sight.call("set_sight", sight_target, style, accent)
	if _crosshair != null:
		if _kia:
			_crosshair.visible = false
		elif downed:
			_crosshair.visible = true
		elif scope_target > 0.0:
			_crosshair.visible = scope_target < 0.5
		else:
			_crosshair.visible = sight_target < 0.2


func _normalise_abilities(raw: Variant) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for entry in raw as Array:
		if not (entry is Dictionary):
			continue
		var ability: Dictionary = entry
		out.append({
			"name": String(ability.get("name", "Ability")),
			"icon": StringName(ability.get("icon", &"bolt")),
			"cooldown": float(ability.get("cooldown", 0.0)),
			"cooldown_total": maxf(0.001, float(ability.get("cooldown_total", ability.get("cooldown", 1.0)))),
			"ready": bool(ability.get("ready", float(ability.get("cooldown", 0.0)) <= 0.0)),
			"is_ultimate": bool(ability.get("is_ultimate", false)),
			"charges": int(ability.get("charges", 0)),
		})
		if out.size() >= 3:
			break
	return out


# ---------------------------------------------------------------------------
# Player signals
# ---------------------------------------------------------------------------

func _on_hitmarker(killed: Variant = false, crit: Variant = false) -> void:
	_crosshair.ping(bool(killed), bool(crit))


func _on_damage_indicator(world_direction: Vector3) -> void:
	var angle := 0.0
	var player := _player()
	if player is Node3D:
		var local := (player as Node3D).global_transform.basis.inverse() * world_direction
		angle = atan2(local.x, -local.z)
	else:
		angle = atan2(world_direction.x, -world_direction.z)
	_crosshair.add_damage_direction(angle)
	_edge.flash_damage(0.6)


func _on_downed_changed(is_downed: Variant = false, bleedout: Variant = -1.0) -> void:
	_set_downed(bool(is_downed))
	if bool(is_downed) and float(bleedout) >= 0.0:
		_update_bleedout(float(bleedout))


func _on_died() -> void:
	_kia = true
	_set_downed(false)
	if _kia_label != null:
		_kia_label.visible = true
	if _crosshair != null:
		_crosshair.visible = false
	if _scope != null:
		_scope.set_scope(0.0)
	if _minimap != null:
		_minimap.visible = false
	if _map_open:
		_set_map_open(false)


# ---------------------------------------------------------------------------
# Event bus callbacks
# ---------------------------------------------------------------------------

func _on_timer_updated(seconds_left: float) -> void:
	_refresh_timer(seconds_left)


func _on_objective_updated(_id: StringName, _title: String, _progress: int, _total: int) -> void:
	_refresh_objectives(true)


func _on_storm_changed(active: bool, _safe_radius: float) -> void:
	if active and not _storm_active:
		_add_notification("THE COLLAPSE HAS BEGUN", "The Reach is folding. Reach an exfil pad before the timer runs out.", &"warning")
	_storm_active = active
	_refresh_timer(RunState.get_time_left())


func _on_extraction_state_changed(state: StringName, seconds_left: float) -> void:
	if _exfil_panel == null:
		return
	if state == &"holding":
		_exfil_panel.visible = true
		if _tutorial_panel != null:
			_tutorial_panel.visible = false
		_exfil_label.text = "EXFIL SHIP INBOUND  %s" % UIPalette.format_time(seconds_left)
		var total := maxf(1.0, RunState.get_exfil_hold_total())
		_exfil_bar.value = clampf(1.0 - seconds_left / total, 0.0, 1.0) * 100.0
		if _exfil_detail != null:
			var records := ProfileState.get_records()
			_exfil_detail.text = "SECURED %d ITEMS · %s SALVAGE · EXTRACTIONS %d" % [
				RunState.satchel_items.size(),
				UIPalette.format_int(RunState.satchel_salvage),
				int(records.get("extractions", 0)),
			]
	else:
		_exfil_panel.visible = false


func _on_notification_requested(title: String, message: String, severity: StringName) -> void:
	_add_notification(title, message, severity)


func _on_radio_message(speaker: String, line: String) -> void:
	show_subtitle(speaker, line)


func _on_world_event(title: String, description: String, icon: StringName, color: Color) -> void:
	if _world_event_panel == null:
		return
	_world_event_queue.append({
		"title": title,
		"description": description,
		"icon": icon,
		"color": color,
	})
	while _world_event_queue.size() > WORLD_EVENT_MAX_QUEUE:
		_world_event_queue.pop_front()
	if not _world_event_active:
		_show_next_world_event()


func _show_next_world_event() -> void:
	if _world_event_panel == null or not is_instance_valid(_world_event_panel) or _world_event_queue.is_empty():
		_world_event_active = false
		return
	_world_event_active = true
	_world_event_token += 1
	var token := _world_event_token
	var event: Dictionary = _world_event_queue.pop_front()
	var accent: Color = event.get("color", UIPalette.amber)
	_world_event_panel.add_theme_stylebox_override(
		"panel",
		UITheme._box(UIPalette.alpha(UIPalette.ink, 0.86), UIPalette.alpha(accent, 0.6), UIPalette.R_MD, 1, Vector4(14, 10, 14, 10))
	)
	_world_event_title.text = String(event.get("title", "Reach Event")).to_upper()
	_world_event_title.add_theme_color_override("font_color", accent)
	_world_event_body.text = String(event.get("description", ""))
	var icon_name := _safe_hud_icon(StringName(event.get("icon", &"bolt")), &"bolt")
	var texture := UIIcons.get_icon(icon_name)
	if texture == null:
		texture = UIIcons.get_icon(&"bolt")
	if _world_event_icon != null:
		_world_event_icon.texture = texture
		_world_event_icon.modulate = accent
	_world_event_panel.visible = true
	_world_event_panel.modulate.a = 1.0
	if not UIPalette.reduce_motion:
		UIFactory.animate_in(_world_event_panel)
	await get_tree().create_timer(WORLD_EVENT_HOLD).timeout
	if not is_inside_tree() or token != _world_event_token:
		return
	if _world_event_panel == null or not is_instance_valid(_world_event_panel):
		return
	if UIPalette.reduce_motion:
		_world_event_panel.visible = false
	else:
		var tween := _world_event_panel.create_tween()
		tween.tween_property(_world_event_panel, "modulate:a", 0.0, UIPalette.motion(0.25))
		await tween.finished
	if _world_event_panel == null or not is_instance_valid(_world_event_panel):
		return
	_world_event_panel.visible = false
	_world_event_panel.modulate.a = 1.0
	_world_event_active = false
	_show_next_world_event()


func _safe_hud_icon(icon_name: StringName, fallback: StringName) -> StringName:
	if UIIcons.has_icon(icon_name):
		return icon_name
	return fallback if UIIcons.has_icon(fallback) else &"bolt"


# ---------------------------------------------------------------------------
# Data refresh
# ---------------------------------------------------------------------------

func _refresh_timer(seconds_left: float) -> void:
	if _timer_label == null:
		return
	var remaining := maxf(0.0, seconds_left)
	_timer_label.text = UIPalette.format_time(remaining)
	var color := UIPalette.ivory
	if remaining <= 120.0 or _storm_active:
		color = UIPalette.danger if remaining <= 120.0 else UIPalette.amber
	_timer_label.add_theme_color_override("font_color", color)
	if _timer_caption != null:
		_timer_caption.text = _run_identity_text()
		_timer_caption.add_theme_color_override("font_color", UIPalette.amber if _storm_active else UIPalette.muted)
	if _timer_panel != null:
		_timer_panel.tooltip_text = _run_identity_tooltip()


func _refresh_objectives(force: bool = false) -> void:
	var signature := _objective_signature_string()
	if not force and signature == _objective_signature:
		return
	_objective_signature = signature
	if _objective_rows == null:
		return
	UIFactory.clear_children(_objective_rows)
	var contract := ContentDB.get_contract(RunState.contract_id)
	if _objective_contract != null:
		_objective_contract.text = contract.display_name if contract != null else String(RunState.contract_id).capitalize()
	var objectives := RunState.get_objectives()
	if objectives.is_empty():
		_objective_rows.add_child(UIFactory.label("No active objectives.", "BodySmall", UIPalette.muted_dim))
		return
	for objective in objectives:
		if not (objective is Dictionary):
			continue
		var row := UIFactory.hbox(UIPalette.SP2)
		var complete := bool(objective.get("complete", false))
		var icon_name: StringName = &"check" if complete else &"target"
		var glyph := UIFactory.icon_or_null(icon_name, 13, UIPalette.mint if complete else UIPalette.muted)
		if glyph != null:
			glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(glyph)
		var title := UIFactory.label(String(objective.get("title", "Objective")), "BodySmall", UIPalette.muted if complete else UIPalette.ivory)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(title)
		var progress := int(objective.get("progress", 0))
		var total := maxi(1, int(objective.get("total", 1)))
		row.add_child(UIFactory.label("%d/%d" % [progress, total], "MonoSmall", UIPalette.mint if complete else UIPalette.muted))
		_objective_rows.add_child(row)


func _objective_signature_string() -> String:
	var parts: PackedStringArray = [String(RunState.contract_id), str(RunState.objectives.size())]
	for objective in RunState.get_objectives():
		if objective is Dictionary:
			parts.append("%s:%s:%s" % [objective.get("id", ""), objective.get("progress", 0), objective.get("complete", false)])
	return "|".join(parts)


# ---------------------------------------------------------------------------
# Field ops mission trackers
# ---------------------------------------------------------------------------

## Deployment feed (~2 Hz): [{title, icon, color, world_position, progress, total, kind}].
func set_mission_trackers(entries: Array) -> void:
	_mission_trackers.clear()
	for entry in entries:
		if entry is Dictionary:
			_mission_trackers.append((entry as Dictionary).duplicate(false))
			if _mission_trackers.size() >= 12:
				break
	_refresh_mission_trackers()


func get_mission_trackers() -> Array:
	return _mission_trackers.duplicate(false)


func _refresh_mission_trackers() -> void:
	if _tracker_rows == null or _tracker_box == null:
		return
	UIFactory.clear_children(_tracker_rows)
	var player := _player()
	var has_player := player is Node3D and is_instance_valid(player)
	var shown := 0
	if has_player:
		for entry in _mission_trackers:
			if shown >= 4:
				break
			if not (entry is Dictionary):
				continue
			var row := _mission_tracker_row(entry as Dictionary, player as Node3D)
			if row == null:
				continue
			_tracker_rows.add_child(row)
			shown += 1
	var overflow := _mission_trackers.size() - shown
	if overflow > 0 and has_player:
		_tracker_rows.add_child(UIFactory.chip("+%d" % overflow, UIPalette.muted))
	var has_rows := shown > 0
	_tracker_box.visible = has_rows
	if _tracker_divider != null:
		_tracker_divider.visible = has_rows


func _mission_tracker_row(entry: Dictionary, player: Node3D) -> HBoxContainer:
	var row := UIFactory.hbox(6)
	var color: Color = entry.get("color", UIPalette.mint)
	var world = entry.get("world_position", null)
	var arrow := UIFactory.icon_or_null(&"arrow-up", 12, UIPalette.alpha(color, 0.9))
	if arrow != null:
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		arrow.pivot_offset = Vector2(6, 6)
		if world is Vector3:
			var to_target: Vector3 = (world as Vector3) - player.global_position
			var world_bearing := rad_to_deg(atan2(to_target.x, -to_target.z))
			var relative := wrapf(world_bearing + rad_to_deg(player.global_rotation.y), -180.0, 180.0)
			arrow.rotation = deg_to_rad(relative)
		row.add_child(arrow)
	var icon_name := StringName(entry.get("icon", &"flag"))
	var glyph := UIFactory.icon_or_null(icon_name, 12, color)
	if glyph == null:
		var alias: StringName = &"bolt" if icon_name == &"rift" else &"flag"
		glyph = UIFactory.icon_or_null(alias, 12, color)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
	var title := UIFactory.label(String(entry.get("title", "Field op")), "Micro", UIPalette.ivory)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(title)
	var total := int(entry.get("total", 0))
	if total > 1:
		var progress := clampi(int(entry.get("progress", 0)), 0, total)
		var done := progress >= total
		row.add_child(UIFactory.label("%d/%d" % [progress, total], "MonoSmall", UIPalette.mint if done else UIPalette.muted))
	if world is Vector3:
		var distance := player.global_position.distance_to(world as Vector3)
		row.add_child(UIFactory.label("%d m" % int(round(distance)), "MonoSmall", UIPalette.muted))
	return row


# ---------------------------------------------------------------------------
# Run identity (timer caption)
# ---------------------------------------------------------------------------

func _run_identity_text() -> String:
	var mode_name := _run_mode_name().to_upper()
	if _run_is_quick():
		mode_name += " ×2"
	return "%s · T%d · %s" % [_run_map_name().to_upper(), _run_threat(), mode_name]


func _run_identity_tooltip() -> String:
	var difficulty_name := String(ContentDB.get_difficulty(ProfileState.get_last_difficulty()).get("display_name", "Patrol"))
	if RunState.active:
		difficulty_name = RunState.get_difficulty_name()
	var mode := _run_mode_data()
	var mode_name := _run_mode_name()
	var tag := _run_mode_tag()
	var clock := _run_mode_clock()
	var scale := float(mode.get("time_scale", 1.0)) if not mode.is_empty() else (2.0 if _run_is_quick() else 1.0)
	var mode_descriptor := mode_name.to_lower()
	if scale > 1.0:
		mode_descriptor += " ×%.0f" % scale
	if not tag.is_empty() and tag.to_upper() != "STANDARD":
		mode_descriptor += " · " + tag
	var storm := UIPalette.format_time(RunState.get_storm_start_time()) if RunState.active else "12:00"
	return "Run identity: %s · %s (T%d) · %s mode, %s clock. Collapse begins after %s of run time." % [
		_run_map_name(),
		difficulty_name,
		_run_threat(),
		mode_descriptor,
		clock,
		storm,
	]


func _run_mode_data() -> Dictionary:
	if RunState.active:
		var active_mode = RunState.get_mode()
		if active_mode is Dictionary and not (active_mode as Dictionary).is_empty():
			return active_mode as Dictionary
		return ContentDB.get_game_mode(RunState.get_mode_id())
	return ContentDB.get_game_mode(ProfileState.get_last_mode())


func _run_mode_clock() -> String:
	if RunState.active:
		var run_clock := RunState.get_mode_clock()
		if not run_clock.is_empty():
			return run_clock
	var mode := _run_mode_data()
	var mode_id := StringName(mode.get("id", &""))
	var clock := ContentDB.get_mode_clock(mode_id)
	if clock.is_empty():
		clock = String(mode.get("clock", "18:00"))
	return clock


func _run_mode_tag() -> String:
	var mode := _run_mode_data()
	return String(mode.get("tag", "")).strip_edges()


func _run_is_quick() -> bool:
	if RunState.active:
		return RunState.is_quick_mode()
	return ProfileState.get_last_mode() == &"quick"


func _run_map_name() -> String:
	if RunState.active:
		return RunState.get_map_preset_name()
	var difficulty := ContentDB.get_difficulty(ProfileState.get_last_difficulty())
	var preset := ContentDB.get_map_preset(StringName(difficulty.get("map_preset", &"")))
	if preset.is_empty():
		var presets := ContentDB.get_map_presets()
		preset = presets[0] if not presets.is_empty() else {}
	return String(preset.get("display_name", "Verdant Verge"))


func _run_mode_name() -> String:
	var mode := _run_mode_data()
	var mode_name := String(mode.get("display_name", mode.get("name", ""))).strip_edges()
	if not mode_name.is_empty():
		return mode_name
	if RunState.active:
		return RunState.get_mode_name()
	return "Normal"


func _run_threat() -> int:
	if RunState.active:
		return clampi(RunState.threat, 1, 4)
	var difficulty := ContentDB.get_difficulty(ProfileState.get_last_difficulty())
	return clampi(int(difficulty.get("threat", 1)), 1, 4)


func _refresh_squad() -> void:
	_render_squad_rows([])


func _render_squad_rows(squad_data: Array) -> void:
	if _squad_rows == null:
		return
	var signature := _squad_signature_string(squad_data)
	if signature == _squad_signature:
		return
	_squad_signature = signature
	UIFactory.clear_children(_squad_rows)
	var has_live := not squad_data.is_empty()
	if has_live:
		for entry in squad_data:
			if not (entry is Dictionary):
				continue
			_squad_rows.add_child(_squad_row(
				String(entry.get("name", "Warden")),
				String(entry.get("role", "squad")),
				float(entry.get("health", 0.0)),
				float(entry.get("max_health", 0.0)),
				bool(entry.get("downed", false)),
				UIPalette.mint
			))
		return
	# Static fallback from profile (pre-deployment data).
	for ally_id in ProfileState.get_active_allies():
		var ally := ContentDB.get_ally(ally_id)
		if ally != null:
			_squad_rows.add_child(_squad_row(ally.display_name, String(ally.role), -1.0, -1.0, false, ally.color))
	var pet := ContentDB.get_pet(ProfileState.get_active_pet())
	if pet != null:
		_squad_rows.add_child(_squad_row(pet.display_name, "driftling", -1.0, -1.0, false, pet.color))
	if _squad_rows.get_child_count() == 0:
		_squad_rows.add_child(UIFactory.label("No squad linked.", "BodySmall", UIPalette.muted_dim))


func _squad_signature_string(squad_data: Array) -> String:
	var parts: PackedStringArray = []
	if not squad_data.is_empty():
		for entry in squad_data:
			if entry is Dictionary:
				parts.append("%s|%s|%s|%s|%s" % [
					entry.get("name", ""),
					entry.get("role", ""),
					int(entry.get("health", 0)),
					bool(entry.get("downed", false)),
					int(entry.get("max_health", 0)),
				])
	else:
		parts.append("profile")
		for ally_id in ProfileState.get_active_allies():
			parts.append(String(ally_id))
		parts.append(String(ProfileState.get_active_pet()))
	return "|".join(parts)


func _squad_row(name_text: String, role_text: String, health: float, max_health: float, downed: bool, accent: Color) -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP2)
	var dot := ColorRect.new()
	dot.color = UIPalette.danger if downed else accent
	dot.custom_minimum_size = Vector2(6, 6)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot)
	var text_box := UIFactory.vbox(1)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_child(UIFactory.label(name_text, "BodySmall", UIPalette.ivory))
	text_box.add_child(UIFactory.label(String(role_text).capitalize(), "Micro", UIPalette.muted_dim))
	row.add_child(text_box)
	if health >= 0.0 and max_health > 0.0:
		row.add_child(UIFactory.label("%d" % int(ceil(health)), "MonoSmall", UIPalette.ivory))
	elif downed:
		row.add_child(UIFactory.label("DOWN", "Micro", UIPalette.danger))
	else:
		row.add_child(UIFactory.label("LINK", "Micro", UIPalette.mint))
	return row


# ---------------------------------------------------------------------------
# Companion manager (provided by the deployment once it exists)
# ---------------------------------------------------------------------------

func _get_companion_manager() -> Node:
	if _companion_manager != null and is_instance_valid(_companion_manager):
		return _companion_manager
	_companion_manager = null
	if App == null:
		return null
	var deployment = App.get_deployment()
	if deployment == null or not is_instance_valid(deployment):
		return null
	if not deployment.has_method("get_companion_manager"):
		return null
	var manager = deployment.call("get_companion_manager")
	if manager is Node and is_instance_valid(manager):
		_companion_manager = manager
		return manager
	return null


func _refresh_companion_manager(force: bool = false) -> void:
	var manager := _get_companion_manager()
	if manager == null or not manager.has_method("get_squad_status"):
		return
	var status = manager.call("get_squad_status")
	if not (status is Array):
		return
	_render_companion_rows(status)


func _render_companion_rows(entries: Array) -> void:
	if _squad_rows == null:
		return
	var parts: PackedStringArray = []
	for entry in entries:
		if entry is Dictionary:
			parts.append("%s|%s|%s|%s|%s|%s|%s|%s" % [
				entry.get("kind", ""),
				entry.get("name", ""),
				int(entry.get("rank", 1)),
				int(entry.get("health", 0)),
				int(entry.get("shield", 0)),
				bool(entry.get("downed", false)),
				bool(entry.get("disabled", false)),
				entry.get("command", ""),
			])
	var signature := "companions|" + "|".join(parts)
	if signature == _companion_signature:
		return
	_companion_signature = signature
	UIFactory.clear_children(_squad_rows)
	for entry in entries:
		if not (entry is Dictionary):
			continue
		_squad_rows.add_child(_companion_row(entry))
	if _squad_rows.get_child_count() == 0:
		_squad_rows.add_child(UIFactory.label("No companions linked.", "BodySmall", UIPalette.muted_dim))


func _companion_row(entry: Dictionary) -> HBoxContainer:
	var is_pet := String(entry.get("kind", "ally")) == "pet"
	var accent := UIPalette.amber if is_pet else UIPalette.mint
	var downed := bool(entry.get("downed", false))
	var disabled := bool(entry.get("disabled", false))
	var row := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon(&"paw" if is_pet else &"users", 13, UIPalette.alpha(accent, 0.75))
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
	var text_box := UIFactory.vbox(1)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := UIFactory.label(String(entry.get("name", "Companion")), "BodySmall", UIPalette.muted_dim if disabled else UIPalette.ivory)
	text_box.add_child(name_label)
	var role := String(entry.get("role", "")).capitalize()
	var command := String(entry.get("command", ""))
	if not command.is_empty():
		role += "  ·  " + command.to_upper()
	text_box.add_child(UIFactory.label(role, "Micro", UIPalette.muted_dim))
	row.add_child(text_box)
	row.add_child(UIFactory.label("R%d" % int(entry.get("rank", 1)), "Micro", UIPalette.muted_dim))
	if disabled:
		row.add_child(UIFactory.label("OUT", "Micro", UIPalette.muted_dim))
	elif downed:
		row.add_child(UIFactory.label("DOWN", "Micro", UIPalette.danger))
	else:
		var health := float(entry.get("health", -1.0))
		var shield := float(entry.get("shield", 0.0))
		if health >= 0.0:
			var color := UIPalette.mint
			if health < 30.0:
				color = UIPalette.danger
			elif health < 60.0:
				color = UIPalette.amber
			row.add_child(UIFactory.label("%d" % int(ceil(health)), "MonoSmall", color))
		elif shield > 0.0:
			row.add_child(UIFactory.label("%d" % int(ceil(shield)), "MonoSmall", UIPalette.blue))
		else:
			row.add_child(UIFactory.label("LINK", "Micro", UIPalette.mint))
	return row


func _update_status_chips() -> void:
	if _status_label == null:
		return
	var parts: PackedStringArray = []
	if _cloaked:
		parts.append("CLOAK ACTIVE")
	if _hyperfocused:
		parts.append("HYPERFOCUS")
	if _crouching:
		parts.append("CROUCHED")
	var pressure := RunState.get_pressure()
	if pressure >= 0.30:
		parts.append("REACH PRESSURE %d%%" % int(round(pressure * 100.0)))
	_status_label.text = "  ·  ".join(parts)
	_status_label.visible = not parts.is_empty()
	_status_label.add_theme_color_override("font_color", UIPalette.danger if pressure >= 0.55 else UIPalette.mint)


# ---------------------------------------------------------------------------
# Public HUD API for gameplay
# ---------------------------------------------------------------------------

func apply_settings() -> void:
	_apply_settings_early()
	if _damage_numbers != null:
		_damage_numbers.enabled = _damage_numbers_enabled
		if not _damage_numbers_enabled:
			_damage_numbers.clear_numbers()
	if not _subtitles_enabled and _subtitle_panel != null:
		_subtitle_panel.visible = false
	if _fps_label != null:
		_fps_label.visible = _show_fps
	if _minimap != null:
		_minimap.visible = _minimap_enabled and not _kia
	_refresh_inventory_hint()
	_reposition_objective_panel()


func _reposition_objective_panel() -> void:
	if _objective_panel == null or not is_instance_valid(_objective_panel):
		return
	var top := _objective_top()
	_objective_panel.offset_top = top
	_objective_panel.offset_bottom = top + 10.0


func get_minimap() -> Control:
	return _minimap


func get_world_chip() -> Control:
	return _world_chip


func get_tutorial_panel() -> Control:
	return _tutorial_panel


func get_world_event_panel() -> Control:
	return _world_event_panel


func get_dungeon_panel() -> Control:
	return _dungeon_panel


func get_hazard_overlay() -> Control:
	return _hazard_overlay


func get_map_overlay() -> Control:
	return _map_overlay


func get_scope() -> Control:
	return _scope


func get_aim_sight() -> Control:
	return _aim_sight


func _set_map_open(open: bool) -> void:
	_map_open = open
	if _map_overlay != null:
		_map_overlay.visible = open
	AudioDirector.play_ui(&"ui_click")
	if open and _tactical_data.is_empty():
		_refresh_tactical_data()


func _toggle_map() -> void:
	if _kia or _downed:
		return
	if not ProfileState.is_mechanic_unlocked(&"tactical_map"):
		EventBus.notification_requested.emit("TACTICAL MAP LOCKED", "Unlocks at Warden level 2.", &"warning")
		return
	_set_map_open(not _map_open)


func _on_game_paused(_is_paused: bool) -> void:
	if _map_open:
		_map_open = false
		if _map_overlay != null:
			_map_overlay.visible = false


func set_tactical_data(payload: Dictionary) -> void:
	var data := payload.duplicate(false)
	if String(data.get("map_name", "")).is_empty():
		data["map_name"] = _run_map_name()
	if String(data.get("mode_name", "")).is_empty():
		data["mode_name"] = _run_mode_name()
	_tactical_data = data
	if _minimap != null:
		_minimap.call("set_data", _tactical_data)
	if _map_overlay != null:
		_map_overlay.call("set_data", _tactical_data)


func _refresh_tactical_data() -> void:
	var deployment = App.get_deployment() if App != null else null
	if deployment == null or not is_instance_valid(deployment) or not deployment.has_method("get_tactical_data"):
		_tactical_data = {}
	else:
		_tactical_data = deployment.call("get_tactical_data")
	set_tactical_data(_tactical_data)


func refresh() -> void:
	_refresh_objectives(true)
	_refresh_timer(RunState.get_time_left())
	_refresh_squad()
	_refresh_mission_trackers()
	apply_settings()


func show_interaction(text: String, key_hint: String = "E") -> void:
	if _interaction_panel == null:
		return
	_interaction_text.text = text
	if _interaction_key != null:
		_interaction_key.text = key_hint
	_interaction_panel.visible = true


func hide_interaction() -> void:
	if _interaction_panel != null:
		_interaction_panel.visible = false


func set_compass_markers(entries: Array) -> void:
	if _compass != null:
		_compass.set_markers(entries)


func clear_compass_markers() -> void:
	if _compass != null:
		_compass.clear_markers()


func show_subtitle(speaker: String, line: String, duration: float = 5.0) -> void:
	if _subtitle_panel == null:
		return
	_subtitles_enabled = true if App == null else bool(App.get_setting("subtitles", true))
	if not _subtitles_enabled:
		return
	_subtitle_speaker.text = speaker.to_upper() if not speaker.is_empty() else "KESTREL"
	_subtitle_line.text = line
	_subtitle_panel.visible = true
	_subtitle_token += 1
	var token := _subtitle_token
	await get_tree().create_timer(maxf(1.5, duration)).timeout
	if is_instance_valid(_subtitle_panel) and token == _subtitle_token:
		_subtitle_panel.visible = false


## Public bridge used by UIRoot to replay notifications buffered while loading.
func notify(title: String, message: String, severity: StringName = &"info") -> void:
	_add_notification(title, message, severity)


func show_damage_number(amount: int, world_position: Vector3, crit: bool = false, killed: bool = false) -> void:
	if _damage_numbers == null or not _damage_numbers_enabled:
		return
	var screen_position := get_viewport_rect().size * Vector2(0.5, 0.42)
	var camera := get_viewport().get_camera_3d()
	if camera != null and not camera.is_position_behind(world_position):
		screen_position = camera.unproject_position(world_position)
	_damage_numbers.show_number(screen_position, amount, crit, killed)


func show_boss(boss_name: String, health: float, max_health: float) -> void:
	if _boss_panel == null:
		return
	_boss_active = true
	_boss_panel.visible = true
	_boss_name.text = boss_name.to_upper()
	_boss_bar.max_value = maxf(1.0, max_health)
	_boss_bar.value = clampf(health, 0.0, max_health)


func update_boss(health: float, max_health: float = -1.0) -> void:
	if _boss_bar == null:
		return
	if max_health > 0.0:
		_boss_bar.max_value = max_health
	_boss_bar.value = clampf(health, 0.0, _boss_bar.max_value)


func hide_boss() -> void:
	_boss_active = false
	if _boss_panel != null:
		_boss_panel.visible = false


func _set_downed(is_downed: bool) -> void:
	_downed = is_downed
	if _scope != null and is_downed:
		_scope.set_scope(0.0)
	if is_downed and _map_open:
		_set_map_open(false)
	if _downed_panel == null:
		return
	_downed_panel.visible = is_downed
	if is_downed:
		if _kia_label != null:
			_kia_label.visible = false
		if _crosshair != null:
			_crosshair.visible = true
	else:
		_revive_bar.visible = false
		if _revive_charges_label != null:
			_revive_charges_label.visible = false


func _update_bleedout(bleedout: float) -> void:
	if _bleedout_bar == null:
		return
	_bleedout_bar.value = clampf(bleedout / 60.0, 0.0, 1.0) * 100.0
	_bleedout_label.text = "BLEEDOUT  %.1fs" % maxf(0.0, bleedout)


func _update_revive(progress: float) -> void:
	if _revive_bar == null:
		return
	_revive_bar.visible = progress > 0.0
	_revive_bar.value = progress * 100.0


# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------

func _add_notification(title: String, message: String, severity: StringName) -> void:
	if _notify_box == null:
		return
	while _notify_box.get_child_count() >= 3:
		var oldest := _notify_box.get_child(0)
		_notify_box.remove_child(oldest)
		oldest.queue_free()
	var accent := UIPalette.severity_color(severity)
	var icon_name: StringName = &"info"
	match severity:
		&"error", &"danger":
			icon_name = &"warning"
		&"success":
			icon_name = &"shield-check"
		&"warning":
			icon_name = &"warning"
		&"loot":
			icon_name = &"star"
		&"rift":
			icon_name = &"bolt"
	var panel := UIFactory.panel("HudPanel")
	panel.add_theme_stylebox_override(
		"panel",
		UITheme._box(UIPalette.alpha(UIPalette.ink, 0.8), UIPalette.alpha(accent, 0.55), UIPalette.R_MD, 1, Vector4(12, 8, 12, 8))
	)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(UIFactory.toast_row(icon_name, title, message, accent))
	_notify_box.add_child(panel)
	UIFactory.animate_in(panel)
	_expire_notification(panel)


func _expire_notification(panel: Control) -> void:
	await get_tree().create_timer(3.0).timeout
	if not is_instance_valid(panel):
		return
	if UIPalette.reduce_motion:
		panel.queue_free()
		return
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(panel.queue_free)


# ---------------------------------------------------------------------------
# Frame update
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	var player := _player()

	if Input.is_action_just_pressed("map") and not get_tree().paused:
		_toggle_map()

	# Tactical map data is polled at 5 Hz, never every frame.
	_tactical_accum += delta
	if _tactical_accum >= 0.2:
		_tactical_accum = 0.0
		_refresh_tactical_data()
		_update_status_chips()
		_update_world_chip()

	# Snapshot polling fallback (max 10 Hz) when the player has no signal.
	if not _has_hud_signal and player != null:
		_poll_accum += delta
		if _poll_accum >= 0.1:
			_poll_accum = 0.0
			var snapshot = _read_snapshot()
			if snapshot is Dictionary:
				_apply_snapshot(snapshot)

	# Heading from the player's yaw if the snapshot doesn't carry one.
	_heading_accum += delta
	if _heading_accum >= 0.05:
		_heading_accum = 0.0
		if player is Node3D and not _snapshot.has("yaw") and not _snapshot.has("rotation_y"):
			_compass.set_heading(-rad_to_deg((player as Node3D).global_rotation.y))

	# Timer + objectives remain live even if no player signals arrive.
	_fallback_accum += delta
	if _fallback_accum >= 0.25:
		_fallback_accum = 0.0
		if RunState.active:
			_refresh_timer(RunState.get_time_left())
			_refresh_objectives()
		_fps_accum += 0.25
		if _fps_accum >= 0.75 and _fps_label != null:
			_fps_accum = 0.0
			_fps_label.text = "%d FPS" % Engine.get_frames_per_second()

	# Companion status is polled from the deployment's CompanionManager.
	_companion_accum += delta
	if _companion_accum >= 0.5:
		_companion_accum = 0.0
		if _get_companion_manager() != null:
			_refresh_companion_manager(true)
