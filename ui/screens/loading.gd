class_name LoadingScreen
extends Control
## Deployment loading cinema.
##
## Replaces the old "plain progress page" with a four-act drop feed:
##   01 THREAT SIGNATURE   boss dossier reveal, the centrepiece
##   02 RIFT BREACH        the Reach tears open over the drop zone
##   03 DROP DESCENT       first-person pod footage with telemetry
##   04 TOUCHDOWN          ramp down, Warden out, operation live
##
## The act clock is progress-aware but not progress-hostile: each act has a
## minimum dwell and a progress gate, with a hard cap so a stalled terrain bake
## never freezes the footage. The operations rail (progress, step label, field
## note) stays live the entire time and is the only thing gameplay depends on.
##
## `present(title, progress, brief)` is called by UIRoot; `brief` comes from
## LoadingBrief.build(). Reduce-motion and skip both collapse to a static boss
## briefing with the live progress rail.

signal cinematic_skipped

const TIPS := [
	["FIELD NOTE", "The Ashen rebuild faster than they fight. Hit relays, not patrols."],
	["FIELD NOTE", "Shield regen pauses while you take damage. Break contact, then re-engage."],
	["FIELD NOTE", "Driftlings can carry loot to exfil. Keep your pet alive out there."],
	["FIELD NOTE", "The Collapse starts after twelve minutes. Bank salvage before the storm."],
	["FIELD NOTE", "Outpost reactor tiers shave time off every ability cooldown."],
	["FIELD NOTE", "Warden medics restore squad shields, not just health. Stay in the field."],
	["FIELD NOTE", "Vault doors are sealed for a reason. Bring a squad that can open them."],
]

## Act definitions. The boss dossier opens the feed so the threat is always
## seen, even on fast machines. `progress` is the deployment progress that opens
## the next act early; `min_dwell` is the minimum screen time for the current act.
const ACTS := [
	{"id": &"boss", "label": "THREAT SIGNATURE", "min_dwell": 2.4, "progress": 0.12},
	{"id": &"rift", "label": "RIFT BREACH", "min_dwell": 1.0, "progress": 0.32},
	{"id": &"descent", "label": "DROP DESCENT", "min_dwell": 1.2, "progress": 0.60},
	{"id": &"touchdown", "label": "TOUCHDOWN", "min_dwell": 1.0, "progress": 0.92},
]
const ACT_HARD_CAP := 2.6
const CAPTION_CAP_WIDTH := 720.0

var _brief: Dictionary = {}
var _title_text := "Preparing the Reach"

var _cinema_host: Control = null
var _shots: Dictionary = {}
var _boss_shot: CinemaBossShot = null
var _film: CinemaFilmOverlay = null
var _flash: ColorRect = null
var _caption_layer: Control = null
var _caption_box: VBoxContainer = null
var _act_eyebrow: Label = null
var _caption_title: Label = null
var _caption_sub: Label = null
var _radio_speaker: Label = null
var _radio_line: Label = null
var _radio_glyph: TextureRect = null
var _static_note: Label = null

var _top_bar: Control = null
var _act_rail: HBoxContainer = null
var _act_entries: Array[Dictionary] = []
var _timecode: Label = null
var _seed_label: Label = null
var _bottom_rail: Control = null
var _operation_eyebrow: Label = null
var _operation_title: Label = null
var _operation_meta: Label = null
var _percent: Label = null
var _step_label: Label = null
var _bar: ProgressBar = null
var _tip_row: HBoxContainer = null
var _tip_line: Label = null
var _skip_button: Button = null

var _progress_target := 0.0
var _progress_shown := 0.0
var _act_index := 0
var _act_elapsed := 0.0
var _total_elapsed := 0.0
var _tip_index := 0
var _tip_accum := 0.0
var _skipped := false
var _static_mode := false
var _frozen_for_capture := false
var _timecode_accum := 0.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	set_process(false)


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = UIPalette.ink_deep
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	_cinema_host = Control.new()
	_cinema_host.name = "Cinema"
	_cinema_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cinema_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cinema_host)
	_build_shots()

	_film = CinemaFilmOverlay.new()
	_film.name = "Film"
	add_child(_film)

	_flash = ColorRect.new()
	_flash.color = Color(0, 0, 0, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_build_top_bar()
	_build_caption()
	_build_bottom_rail()


func _build_shots() -> void:
	var rift := CinemaRiftShot.new()
	var descent := CinemaDescentShot.new()
	var boss := CinemaBossShot.new()
	var touchdown := CinemaTouchdownShot.new()
	_boss_shot = boss
	var entries := [
		[&"rift", rift],
		[&"descent", descent],
		[&"boss", boss],
		[&"touchdown", touchdown],
	]
	for entry in entries:
		var shot_id: StringName = entry[0]
		var shot: UICinemaShot = entry[1]
		shot.name = "Shot_%s" % String(shot_id)
		shot.visible = false
		_cinema_host.add_child(shot)
		_shots[shot_id] = shot


func _build_top_bar() -> void:
	var margin := MarginContainer.new()
	margin.name = "TopBar"
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.offset_bottom = 64.0
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	_top_bar = margin

	var row := UIFactory.hbox(UIPalette.SP4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var brand := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon_or_null(&"outpost", 17, UIPalette.mint)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		brand.add_child(glyph)
	var wordmark := UIFactory.display_text("RIFTWARD", 16, 700, UIPalette.ivory)
	wordmark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(wordmark)
	var feed := UIFactory.mono("// DROP FEED", false, 10, UIPalette.muted)
	feed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(feed)
	row.add_child(brand)

	row.add_child(UIFactory.spacer_h())

	_act_rail = UIFactory.hbox(UIPalette.SP3)
	_act_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in ACTS.size():
		var act: Dictionary = ACTS[index]
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 5)
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var number := UIFactory.mono("%02d" % (index + 1), true, 10, UIPalette.muted_dim)
		number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		entry.add_child(number)
		var label := UIFactory.label(String(act["label"]), "Micro", UIPalette.muted_dim)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		entry.add_child(label)
		_act_rail.add_child(entry)
		if index < ACTS.size() - 1:
			var caret := UIFactory.mono("›", false, 11, UIPalette.alpha(UIPalette.muted_dim, 0.6))
			caret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_act_rail.add_child(caret)
		_act_entries.append({"entry": entry, "number": number, "label": label})
	row.add_child(_act_rail)

	row.add_child(UIFactory.spacer_h())

	var status := UIFactory.hbox(UIPalette.SP2)
	var rec := UIFactory.label("●", "Micro", UIPalette.danger)
	rec.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(rec)
	var rec_label := UIFactory.mono("REC", true, 10, UIPalette.danger)
	rec_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(rec_label)
	_timecode = UIFactory.mono("T+00:00", false, 10, UIPalette.muted)
	_timecode.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(_timecode)
	_seed_label = UIFactory.mono("SEED AUTO", false, 10, UIPalette.muted_dim)
	_seed_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(_seed_label)
	row.add_child(status)


func _build_caption() -> void:
	_caption_layer = Control.new()
	_caption_layer.name = "Caption"
	_caption_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption_layer)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 190)
	_caption_layer.add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var row := UIFactory.hbox(UIPalette.SP4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)

	_caption_box = UIFactory.vbox(3)
	_caption_box.custom_minimum_size.x = CAPTION_CAP_WIDTH
	_caption_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_caption_box)

	_act_eyebrow = UIFactory.eyebrow("ACT 01 · RIFT BREACH", UIPalette.mint)
	_caption_box.add_child(_act_eyebrow)
	_caption_title = UIFactory.display_text("Preparing the Reach", 44, 650, UIPalette.ivory)
	_caption_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_box.add_child(_caption_title)
	_caption_sub = UIFactory.label("", "BodySmall", UIPalette.muted)
	_caption_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_box.add_child(_caption_sub)
	_static_note = UIFactory.label("", "Micro", UIPalette.amber)
	_static_note.visible = false
	_caption_box.add_child(_static_note)

	row.add_child(UIFactory.spacer_h())

	var radio := UIFactory.hbox(UIPalette.SP2)
	radio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radio.alignment = BoxContainer.ALIGNMENT_END
	_caption_box.add_child(radio)
	_radio_glyph = UIFactory.icon_or_null(&"radio", 14, UIPalette.mint)
	if _radio_glyph != null:
		_radio_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		radio.add_child(_radio_glyph)
	_radio_speaker = UIFactory.label("", "Eyebrow", UIPalette.mint)
	_radio_speaker.autowrap_mode = TextServer.AUTOWRAP_OFF
	radio.add_child(_radio_speaker)
	_radio_line = UIFactory.label("", "BodySmall", UIPalette.ivory)
	_radio_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_radio_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radio.add_child(_radio_line)


func _build_bottom_rail() -> void:
	_bottom_rail = Control.new()
	_bottom_rail.name = "OperationsRail"
	_bottom_rail.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_rail.offset_top = -176.0
	_bottom_rail.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_bottom_rail)

	var accent_line := ColorRect.new()
	accent_line.color = UIPalette.alpha(UIPalette.mint, 0.45)
	accent_line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	accent_line.offset_bottom = 1.0
	accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_rail.add_child(accent_line)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_rail.add_child(margin)

	var column := UIFactory.vbox(9)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var top_row := UIFactory.hbox(UIPalette.SP5)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top_row)

	var identity := UIFactory.vbox(2)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(identity)
	_operation_eyebrow = UIFactory.eyebrow("OPERATION · SALVAGE SWEEP", UIPalette.mint)
	identity.add_child(_operation_eyebrow)
	_operation_title = UIFactory.display_text("Preparing the Reach", 24, 600, UIPalette.ivory)
	_operation_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(_operation_title)
	_operation_meta = UIFactory.mono("", false, 10, UIPalette.muted)
	_operation_meta.autowrap_mode = TextServer.AUTOWRAP_OFF
	_operation_meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(_operation_meta)

	var progress_box := UIFactory.vbox(4)
	progress_box.custom_minimum_size.x = 460.0
	progress_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(progress_box)
	var percent_row := UIFactory.hbox(UIPalette.SP2)
	percent_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	percent_row.add_child(UIFactory.mono("DEPLOYMENT", true, 9, UIPalette.muted_dim))
	percent_row.add_child(UIFactory.spacer_h())
	_percent = UIFactory.number_text("0%", 28, UIPalette.mint)
	percent_row.add_child(_percent)
	progress_box.add_child(percent_row)
	_bar = UIFactory.progress(0.0, 100.0, "BarMint", 8)
	_bar.tooltip_text = "Terrain generation, navigation baking and dungeon pre-build happen during the drop."
	progress_box.add_child(_bar)

	var info_row := UIFactory.hbox(UIPalette.SP4)
	info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(info_row)
	_step_label = UIFactory.label("Initialising deployment", "BodySmall", UIPalette.ivory)
	_step_label.custom_minimum_size.x = 330.0
	_step_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_row.add_child(_step_label)
	_tip_row = UIFactory.hbox(UIPalette.SP2)
	_tip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tip_glyph := UIFactory.icon_or_null(&"info", 12, UIPalette.amber)
	if tip_glyph != null:
		tip_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_tip_row.add_child(tip_glyph)
	_tip_line = UIFactory.label("", "Micro", UIPalette.muted)
	_tip_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_tip_line.custom_minimum_size.x = 320.0
	_tip_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tip_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tip_row.add_child(_tip_line)
	info_row.add_child(_tip_row)
	_skip_button = UIFactory.ghost_button("SPACE  SKIP CINEMATIC", &"play")
	_skip_button.tooltip_text = "Skip the cinematic feed. The deployment keeps building in the background."
	_skip_button.pressed.connect(_on_skip_pressed)
	info_row.add_child(_skip_button)


# ---------------------------------------------------------------------------
# API used by UIRoot / App
# ---------------------------------------------------------------------------

func present(title: String, progress: float = 0.0, brief: Dictionary = {}) -> void:
	_title_text = title if not title.is_empty() else "Preparing the Reach"
	_brief = brief if not brief.is_empty() else LoadingBrief.build()
	_bind_brief()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_skipped = false
	_static_mode = UIPalette.reduce_motion
	_frozen_for_capture = false
	_total_elapsed = 0.0
	_timecode_accum = 0.0
	_progress_target = clampf(progress, 0.0, 1.0)
	_progress_shown = _progress_target
	_tip_accum = 0.0
	_tip_index = randi() % TIPS.size()
	_apply_tip(_tip_index)
	_reset_shots()
	_refresh_operation_rail()
	_refresh_seed()
	_apply_progress_visuals()
	set_process(true)
	if _static_mode:
		_enter_static_brief(true)
	else:
		_enter_act(0, true)
	if AudioDirector != null:
		AudioDirector.set_music_mood(&"deployment")


func update_loading(progress: float, label: String) -> void:
	_progress_target = clampf(progress, 0.0, 1.0)
	if _step_label != null and not label.is_empty():
		_step_label.text = label
	if _boss_shot != null:
		_boss_shot.set_progress(_progress_target)
	if not _skipped and not _static_mode:
		_maybe_advance_act()


func dismiss() -> void:
	visible = false
	set_process(false)
	for shot in _shots.values():
		if shot is UICinemaShot:
			shot.set_active(false)


## Collapse the director into a static boss briefing. Used by the skip control
## and (on present) by the reduce-motion setting.
func skip_cinematic() -> void:
	if _skipped or _static_mode:
		return
	_skipped = true
	_enter_static_brief(false)
	cinematic_skipped.emit()


## Capture / test helper: freeze every shot on its composed pose.
func freeze_cinematic(value: bool) -> void:
	_frozen_for_capture = value
	for shot in _shots.values():
		if shot is UICinemaShot:
			shot.set_static_frame(value)
	if _boss_shot != null and _boss_shot.is_shot_active():
		_boss_shot.set_static_frame(value)


## Capture / test helper: jump directly to an act without waiting for progress.
func set_act(index: int) -> void:
	if _static_mode:
		return
	_enter_act(clampi(index, 0, ACTS.size() - 1), true)


func set_act_id(act_id: StringName) -> void:
	for index in ACTS.size():
		if StringName(ACTS[index]["id"]) == act_id:
			set_act(index)
			return


func get_active_act() -> StringName:
	return StringName(ACTS[clampi(_act_index, 0, ACTS.size() - 1)]["id"])


func get_brief() -> Dictionary:
	return _brief


func get_boss_info() -> Dictionary:
	return _brief.get("boss", {})


func get_progress_value() -> float:
	return _progress_target


func get_shown_progress() -> float:
	return _progress_shown


func is_cinematic_skipped() -> bool:
	return _skipped


func is_static_mode() -> bool:
	return _static_mode


func get_shot(shot_id: StringName) -> UICinemaShot:
	return _shots.get(shot_id)


func get_skip_button() -> Button:
	return _skip_button


func get_act_titles() -> Array[String]:
	var titles: Array[String] = []
	for act in ACTS:
		titles.append(String(act["label"]))
	return titles


func get_operation_text() -> String:
	return _operation_title.text if _operation_title != null else ""


func get_caption_title() -> String:
	return _caption_title.text if _caption_title != null else ""


func get_radio_text() -> String:
	return _radio_line.text if _radio_line != null else ""


# ---------------------------------------------------------------------------
# Frame loop / act state machine
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	_total_elapsed += delta
	_act_elapsed += delta
	_progress_shown = move_toward(_progress_shown, _progress_target, delta * 1.8)
	_apply_progress_visuals()
	_timecode_accum += delta
	if _timecode_accum >= 0.1:
		_timecode_accum = 0.0
		_refresh_timecode()
	if _skipped or _static_mode or _frozen_for_capture:
		return
	_maybe_advance_act()
	_tip_accum += delta
	if _tip_accum >= 6.0:
		_tip_accum = 0.0
		_apply_tip((_tip_index + 1) % TIPS.size())


func _maybe_advance_act() -> void:
	if _act_index >= ACTS.size() - 1:
		return
	var act: Dictionary = ACTS[_act_index]
	var gate := _progress_target >= float(act["progress"])
	var dwell := _act_elapsed >= float(act["min_dwell"])
	var cramped := _act_elapsed >= float(act["min_dwell"]) * ACT_HARD_CAP
	if (gate and dwell) or cramped:
		_enter_act(_act_index + 1, false)


func _enter_act(index: int, immediate: bool) -> void:
	_act_index = clampi(index, 0, ACTS.size() - 1)
	_act_elapsed = 0.0
	var active: StringName = StringName(ACTS[_act_index]["id"])
	for shot_id in _shots.keys():
		var shot: UICinemaShot = _shots[shot_id]
		shot.set_progress(_progress_target)
		shot.set_active(shot_id == active)
	if _boss_shot != null and active == &"boss":
		_boss_shot.set_static_frame(_static_mode or _frozen_for_capture)
	_refresh_act_rail()
	_refresh_caption(active)
	_refresh_radio(_act_index)
	_refresh_progress_accent(active)
	if _skip_button != null:
		_skip_button.visible = not _skipped and not _static_mode and not UIPalette.reduce_motion
	_play_act_sting(active)
	if not immediate and not _static_mode and not _frozen_for_capture:
		_flash_frame(_act_accent(active))


func _enter_static_brief(from_present: bool) -> void:
	_static_mode = true
	_act_index = 0
	for shot_id in _shots.keys():
		var shot: UICinemaShot = _shots[shot_id]
		shot.set_active(shot_id == &"boss")
		shot.set_static_frame(true)
	_refresh_act_rail()
	_refresh_caption(&"boss")
	_refresh_radio(0)
	_refresh_progress_accent(&"boss")
	_act_eyebrow.text = "THREAT INTELLIGENCE // STATIC FEED"
	_act_eyebrow.add_theme_color_override("font_color", UIPalette.danger)
	_caption_title.visible = false
	_caption_sub.visible = false
	_static_note.visible = true
	_static_note.text = "REDUCED MOTION · STATIC BRIEFING" if from_present and UIPalette.reduce_motion else "CINEMATIC SKIPPED · LIVE TELEMETRY"
	if _skip_button != null:
		_skip_button.visible = false


func _reset_shots() -> void:
	for shot in _shots.values():
		if shot is UICinemaShot:
			shot.set_static_frame(_static_mode)
			shot.set_active(false)


func _refresh_caption(active: StringName) -> void:
	if _caption_box == null:
		return
	_caption_title.visible = true
	_caption_sub.visible = true
	_static_note.visible = false
	_caption_box.modulate.a = 1.0
	match active:
		&"rift":
			_act_eyebrow.text = "ACT 02 · RIFT BREACH"
			_act_eyebrow.add_theme_color_override("font_color", _act_accent(active))
			_caption_title.text = _title_text
			_caption_sub.text = "%s  //  %s  //  %s" % [
				String(_brief.get("contract_name", "Salvage Sweep")).to_upper(),
				String(_brief.get("map_name", "The Reach")).to_upper(),
				String(_brief.get("planet_name", "Meridian-9")).to_upper(),
			]
		&"descent":
			_act_eyebrow.text = "ACT 03 · DROP DESCENT"
			_act_eyebrow.add_theme_color_override("font_color", _act_accent(active))
			_caption_title.text = "Through the Fold"
			_caption_sub.text = "%s insertion  ·  %s  ·  threat %d  ·  hull nominal" % [
				String(_brief.get("mode_name", "Normal")),
				String(_brief.get("difficulty_name", "Patrol")),
				int(_brief.get("threat", 1)),
			]
		&"boss":
			_act_eyebrow.text = "ACT 01 · THREAT SIGNATURE"
			_act_eyebrow.add_theme_color_override("font_color", UIPalette.danger)
			_caption_title.visible = false
			_caption_sub.visible = false
		&"touchdown":
			_act_eyebrow.text = "ACT 04 · TOUCHDOWN"
			_act_eyebrow.add_theme_color_override("font_color", UIPalette.mint)
			_caption_title.text = "The Reach Is Yours"
			_caption_sub.text = "Operation %s is live. Good hunting, Warden." % String(_brief.get("contract_name", "Salvage Sweep"))
	UIFactory.animate_in(_caption_box, 0.04)


func _refresh_radio(act_index: int) -> void:
	var lines: Array = _brief.get("radio", [])
	if lines.is_empty() or act_index >= lines.size():
		_radio_speaker.text = ""
		_radio_line.text = ""
		return
	var entry: Dictionary = lines[clampi(act_index, 0, lines.size() - 1)]
	_radio_speaker.text = "%s" % String(entry.get("speaker", "Kestrel")).to_upper()
	_radio_line.text = String(entry.get("line", ""))
	if _radio_glyph != null:
		_radio_glyph.modulate = _act_accent(StringName(ACTS[clampi(act_index, 0, ACTS.size() - 1)]["id"]))


func _refresh_operation_rail() -> void:
	if _operation_eyebrow == null:
		return
	var contract_name := String(_brief.get("contract_name", "Salvage Sweep"))
	var mode_tag := String(_brief.get("mode_tag", "STANDARD"))
	_operation_eyebrow.text = "OPERATION  ·  %s  ·  %s" % [contract_name.to_upper(), mode_tag]
	_operation_title.text = contract_name
	var seed_value := int(_brief.get("seed", 0))
	var seed_text := "AUTO" if seed_value == 0 else UIPalette.format_int(seed_value)
	_operation_meta.text = "%s  //  %s  //  %s (T%d)  //  SEED %s" % [
		String(_brief.get("map_name", "The Reach")).to_upper(),
		String(_brief.get("planet_name", "Meridian-9")).to_upper(),
		String(_brief.get("difficulty_name", "Patrol")).to_upper(),
		int(_brief.get("threat", 1)),
		seed_text,
	]


func _refresh_seed() -> void:
	if _seed_label == null:
		return
	var seed_value := int(_brief.get("seed", 0))
	_seed_label.text = "SEED AUTO" if seed_value == 0 else "SEED %s" % UIPalette.format_int(seed_value)


func _refresh_timecode() -> void:
	if _timecode == null:
		return
	var total := int(_total_elapsed)
	_timecode.text = "T+%02d:%02d" % [total / 60, total % 60]


func _apply_progress_visuals() -> void:
	var percent_value := int(round(_progress_shown * 100.0))
	if _bar != null:
		_bar.value = percent_value
	if _percent != null:
		_percent.text = "%d%%" % percent_value


func _refresh_progress_accent(active: StringName) -> void:
	var accent := _act_accent(active)
	if _percent != null:
		_percent.add_theme_color_override("font_color", accent)
	if _bar != null:
		_bar.add_theme_stylebox_override("fill", UITheme._box(accent, Color.TRANSPARENT, UIPalette.R_SM, 0, Vector4(0, 0, 0, 0)))
		_bar.add_theme_stylebox_override("background", UITheme._box(UIPalette.ink, UIPalette.alpha(accent, 0.22), UIPalette.R_SM, 1, Vector4(0, 0, 0, 0)))
	if _film != null:
		_film.accent = accent
		_film.queue_redraw()


func _act_accent(active: StringName) -> Color:
	match active:
		&"rift":
			return _brief.get("planet_color", UIPalette.mint)
		&"descent":
			return UIPalette.mint
		&"boss":
			return UIPalette.danger
		&"touchdown":
			return UIPalette.amber
	return UIPalette.mint


func _refresh_act_rail() -> void:
	for index in _act_entries.size():
		var entry: Dictionary = _act_entries[index]
		var number: Label = entry["number"]
		var label: Label = entry["label"]
		var active := index == _act_index
		var passed := index < _act_index
		var color := UIPalette.mint if active else (UIPalette.muted if passed else UIPalette.muted_dim)
		number.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_color", color)
		number.modulate.a = 1.0 if active or passed else 0.7
		label.modulate.a = 1.0 if active or passed else 0.7


func _apply_tip(index: int) -> void:
	_tip_index = clampi(index, 0, TIPS.size() - 1)
	var body: String = String(TIPS[_tip_index][1])
	if _tip_line != null:
		_tip_line.text = _short_tip(body)
	if _tip_row != null:
		_tip_row.tooltip_text = body


func _short_tip(text: String) -> String:
	var cut := text.find(". ")
	if cut > 0:
		return "FIELD NOTE · " + text.substr(0, cut + 1)
	if text.length() > 64:
		return "FIELD NOTE · " + text.substr(0, 61) + "…"
	return "FIELD NOTE · " + text


func _bind_brief() -> void:
	for shot in _shots.values():
		if shot is UICinemaShot and shot.has_method("set_brief"):
			shot.call("set_brief", _brief)
	_refresh_operation_rail()
	_refresh_seed()


func _play_act_sting(active: StringName) -> void:
	if AudioDirector == null:
		return
	match active:
		&"rift":
			AudioDirector.play_sfx(&"storm", -18.0)
		&"descent":
			AudioDirector.play_ui(&"scan", -10.0)
		&"boss":
			AudioDirector.play_sfx(&"storm", -12.0)
			AudioDirector.play_ui(&"ui_error", -12.0)
		&"touchdown":
			AudioDirector.play_ui(&"ui_confirm", -6.0)


func _flash_frame(color: Color) -> void:
	if _flash == null or not is_inside_tree():
		return
	_flash.color = color
	_flash.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_flash, "modulate:a", 0.20, 0.08).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_flash, "modulate:a", 0.0, 0.32).set_trans(Tween.TRANS_CUBIC)


func _on_skip_pressed() -> void:
	skip_cinematic()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _skipped or _static_mode or _frozen_for_capture:
		return
	if event.is_action_pressed("ui_accept"):
		skip_cinematic()
		get_viewport().set_input_as_handled()
