class_name CinematicOverlay
extends Control
## Full-screen cut-scene presentation layer.
##
## Owns the director, the film treatment (letterbox/scrims/grain from
## CinemaFilmOverlay), caption chrome, the skip control and an optional Camera3D
## rig attached to the 3D world. With no 3D world it renders a code-drawn 2D card
## instead, so the headless suite can exercise every cut-scene.
##
## UIRoot owns one instance (z_index 30, PROCESS_MODE_ALWAYS, mouse STOP) and
## reuses it:
##   show_cinematic(id, opts) -> bool  ==  overlay.play(id, opts)
##   hide_cinematic()                  ==  overlay.dismiss()  (silent)
## `finished(cutscene_id)` is emitted exactly once per successful play(), by the
## real completion/skip path only. dismiss() never emits it.
##
## play() opts (all optional):
##   world: Node3D        3D rig parent (falls back to the player's 3D parent)
##   player: Node         shot anchor / player camera restore
##   boss: Node           orbit anchor + dossier source
##   ship: Node3D         exfil dropship (safe to omit)
##   reduce_motion: bool  force the 1.2 s static card
##   on_finished: Callable(id) forwarded to the director
##   emit_bus: bool       opt-in director EventBus emission (App owns it: false)
##   hide_hud: bool       default true (defensive HUD hide/restore)
##   origin / brief / boss_name / boss_faction / boss_phase / callsign
## The director header documents the full contract.

signal finished(cutscene_id: StringName)

const DIRECTOR_SCRIPT := preload("res://features/cutscene/cutscene_director.gd")
const CARD_FPS := 20.0
const CAPTION_WIDTH := 780.0

var _director: CutsceneDirector = null
var _film: CinemaFilmOverlay = null
var _camera: Camera3D = null
var _player_camera: Camera3D = null

var _top_chrome: Control = null
var _eyebrow_label: Label = null
var _tag_label: Label = null
var _bottom_chrome: Control = null
var _caption_label: Label = null
var _radio_label: Label = null
var _radio_speaker: Label = null
var _hint_label: Label = null
var _skip_button: Button = null
var _dossier_panel: PanelContainer = null
var _dossier_name: Label = null
var _dossier_meta: Label = null
var _dossier_tag: Label = null
var _fade: ColorRect = null

var _cutscene_id: StringName = &""
var _opts: Dictionary = {}
var _accent := Color("62e6c3")
var _caption_text := ""
var _reduce_override := -1
var _subtitles := true
var _card_time := 0.0
var _card_accum := 0.0
var _finished_connected := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_accent = UIPalette.mint
	visible = false
	_build()
	set_process(false)


func _exit_tree() -> void:
	_teardown_rig()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Shows the overlay and starts a registered cut-scene. Returns false (leaving
## the overlay hidden and the game untouched) for an unknown/empty id.
func play(cutscene_id: StringName, opts: Dictionary = {}) -> bool:
	if _director == null:
		return false
	if cutscene_id == &"" or not _director.has_cutscene(cutscene_id):
		return false
	if _director.is_playing():
		_director.abort(true)
	_opts = opts.duplicate(true)
	_cutscene_id = cutscene_id
	if _opts.has("reduce_motion"):
		_reduce_override = 1 if bool(_opts["reduce_motion"]) else 0
	_subtitles = _resolve_subtitles()
	_accent = _accent_for(cutscene_id)
	_caption_text = ""
	_card_time = 0.0
	_card_accum = 0.0
	_reset_chrome()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_skip_button.visible = true
	_dossier_panel.visible = cutscene_id == &"boss"
	# Reduce motion is a pure 2D static card: never take the 3D camera from the
	# player for it, or the card would render as a transparent scrim.
	if not is_reduce_motion():
		_setup_rig(_opts)
	var play_opts := _opts.duplicate(true)
	play_opts["reduce_motion"] = is_reduce_motion()
	if not _finished_connected:
		_finished_connected = true
		_director.finished.connect(_on_director_finished)
		_director.beat_changed.connect(_on_beat_changed)
	var started := _director.play(cutscene_id, play_opts)
	if not started:
		visible = false
		_skip_button.visible = false
		_teardown_rig()
		return false
	# Place the rig on the first beat pose before the first rendered frame so a
	# cut never opens on the rig's staging position.
	_update_camera(1.0 / 60.0)
	_update_fade()
	set_process(true)
	queue_redraw()
	return true


## Ends the active cut-scene through the normal finish path (finished fires).
func skip() -> void:
	if _director != null and _director.is_playing():
		_director.skip()


## Silent teardown for owner-driven aborts. Restores the rig/HUD and hides the
## overlay without emitting `finished`.
func dismiss() -> void:
	if _director != null and _director.is_playing():
		_director.abort(true)
	_teardown_rig()
	visible = false
	_skip_button.visible = false
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_caption_text = ""
	_cutscene_id = &""
	_opts.clear()
	set_process(false)


func is_playing() -> bool:
	return _director != null and _director.is_playing()


func get_director() -> CutsceneDirector:
	return _director


func get_caption_text() -> String:
	return _caption_text


func get_skip_button() -> Button:
	return _skip_button


func get_camera_rig() -> Camera3D:
	return _camera


func get_cutscene_id() -> StringName:
	return _cutscene_id


func get_dossier_text() -> Dictionary:
	var info: Dictionary = _director.get_dossier() if _director != null else {}
	return {
		"name": _dossier_name.text if _dossier_name != null else "",
		"faction": String(info.get("faction", "")),
		"phase": int(info.get("phase", 0)),
		"visible": _dossier_panel.visible if _dossier_panel != null else false,
	}


## Forced reduce motion for the next play(). -1 style "unset" is not exposed;
## call again with false to go back to the global setting.
func set_reduce_motion(value: bool) -> void:
	_reduce_override = 1 if value else 0


func is_reduce_motion() -> bool:
	if _director != null and _director.is_playing():
		return _director.is_reduced_motion()
	if _reduce_override >= 0:
		return _reduce_override == 1
	if _opts.has("reduce_motion"):
		return bool(_opts["reduce_motion"])
	return UIPalette.reduce_motion


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build() -> void:
	_film = CinemaFilmOverlay.new()
	_film.name = "Film"
	add_child(_film)

	_build_top_chrome()
	_build_caption_chrome()
	_build_dossier()

	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_director = DIRECTOR_SCRIPT.new()
	_director.name = "CutsceneDirector"
	add_child(_director)


func _build_top_chrome() -> void:
	_top_chrome = Control.new()
	_top_chrome.name = "TopChrome"
	_top_chrome.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top_chrome.offset_bottom = 96.0
	_top_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_chrome)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 8)
	_top_chrome.add_child(margin)

	var row := UIFactory.hbox(UIPalette.SP4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	_eyebrow_label = UIFactory.eyebrow("CUTSCENE //", UIPalette.mint)
	_eyebrow_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_eyebrow_label)

	var rec := UIFactory.hbox(UIPalette.SP2)
	rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rec_dot := UIFactory.label("●", "Micro", UIPalette.danger)
	rec_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rec.add_child(rec_dot)
	var rec_text := UIFactory.mono("REC", true, 10, UIPalette.danger)
	rec_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rec.add_child(rec_text)
	row.add_child(rec)

	row.add_child(UIFactory.spacer_h())

	_tag_label = UIFactory.mono("", false, 10, UIPalette.muted)
	_tag_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_tag_label)


func _build_caption_chrome() -> void:
	_bottom_chrome = Control.new()
	_bottom_chrome.name = "CaptionChrome"
	_bottom_chrome.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_chrome.offset_top = -236.0
	_bottom_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bottom_chrome)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 30)
	_bottom_chrome.add_child(margin)

	var column := UIFactory.vbox(UIPalette.SP2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_END
	margin.add_child(column)

	var caption_row := UIFactory.hbox(UIPalette.SP4)
	caption_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption_row)

	var accent_bar := ColorRect.new()
	accent_bar.name = "AccentBar"
	accent_bar.color = UIPalette.alpha(UIPalette.mint, 0.85)
	accent_bar.custom_minimum_size = Vector2(3.0, 58.0)
	accent_bar.size_flags_vertical = Control.SIZE_SHRINK_END
	accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_row.add_child(accent_bar)

	var text_box := UIFactory.vbox(3)
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.custom_minimum_size.x = CAPTION_WIDTH
	caption_row.add_child(text_box)

	_radio_speaker = UIFactory.eyebrow("", UIPalette.mint)
	_radio_speaker.visible = false
	text_box.add_child(_radio_speaker)

	_caption_label = UIFactory.display_text("", 30, 600, UIPalette.ivory)
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_label.custom_minimum_size.x = CAPTION_WIDTH
	_caption_label.visible = false
	text_box.add_child(_caption_label)

	var radio_row := UIFactory.hbox(UIPalette.SP2)
	radio_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(radio_row)
	var radio_glyph := UIFactory.icon_or_null(&"radio", 14, UIPalette.mint)
	if radio_glyph != null:
		radio_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		radio_row.add_child(radio_glyph)
	_radio_label = UIFactory.label("", "BodySmall", UIPalette.ivory)
	_radio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_radio_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_radio_label.visible = false
	radio_row.add_child(_radio_label)

	var action_row := UIFactory.hbox(UIPalette.SP4)
	action_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(action_row)
	_hint_label = UIFactory.mono("ESC / SPACE  ·  SKIP", false, 10, UIPalette.muted_dim)
	_hint_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action_row.add_child(_hint_label)
	action_row.add_child(UIFactory.spacer_h())
	_skip_button = UIFactory.ghost_button("SKIP CINEMATIC", &"play")
	_skip_button.name = "SkipCinematic"
	_skip_button.tooltip_text = "Skip this cut-scene and return to the fight."
	_skip_button.pressed.connect(skip)
	action_row.add_child(_skip_button)


func _build_dossier() -> void:
	_dossier_panel = UIFactory.tinted_panel(
		UIPalette.alpha(UIPalette.ink, 0.88),
		UIPalette.alpha(UIPalette.danger, 0.55),
		UIPalette.R_LG
	)
	_dossier_panel.name = "BossDossier"
	_dossier_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_dossier_panel.offset_left = -404.0
	_dossier_panel.offset_top = 104.0
	_dossier_panel.offset_right = -40.0
	_dossier_panel.offset_bottom = 268.0
	_dossier_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dossier_panel.visible = false
	add_child(_dossier_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dossier_panel.add_child(margin)

	var column := UIFactory.vbox(5)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	_dossier_tag = UIFactory.eyebrow("THREAT DOSSIER", UIPalette.danger)
	column.add_child(_dossier_tag)

	_dossier_name = UIFactory.display_text("", 28, 650, UIPalette.ivory)
	_dossier_name.name = "DossierName"
	_dossier_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_dossier_name)

	_dossier_meta = UIFactory.mono("", false, 11, UIPalette.muted)
	_dossier_meta.name = "DossierMeta"
	_dossier_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_dossier_meta)


# ---------------------------------------------------------------------------
# Frame loop
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_playing():
		return
	_card_time += delta
	_update_camera(delta)
	_update_fade()
	if is_reduce_motion():
		return
	_card_accum += delta
	if _card_accum >= 1.0 / CARD_FPS:
		_card_accum = 0.0
		queue_redraw()


func _update_camera(delta: float) -> void:
	if _camera == null:
		return
	if not is_instance_valid(_camera):
		_camera = null
		return
	var beat := _director.get_current_beat()
	if beat.is_empty():
		return
	var t := _director.get_beat_progress()
	var pose := _camera_pose(beat, t)
	var position: Vector3 = pose.get("position", Vector3.ZERO)
	if not is_reduce_motion():
		var sway := Vector3(
			sin(_card_time * 1.37) * 0.018,
			sin(_card_time * 1.71 + 1.3) * 0.014,
			0.0
		)
		position += sway
	var look: Vector3 = pose.get("look_at", Vector3.ZERO)
	_camera.global_position = position
	if position.distance_squared_to(look) > 0.0004:
		var direction := (look - position).normalized()
		var up := Vector3.UP
		if absf(direction.dot(Vector3.UP)) > 0.995:
			up = Vector3.FORWARD
		_camera.look_at(look, up)
	_camera.fov = lerpf(_camera.fov, float(pose.get("fov", 70.0)), minf(1.0, delta * 6.0))


func _update_fade() -> void:
	var beat := _director.get_current_beat()
	var fade_target := 0.0
	if not beat.is_empty() and not is_reduce_motion():
		fade_target = float(beat.get("fade", 0.0)) * _director.get_beat_progress()
	if _fade != null:
		_fade.color = Color(0.0, 0.0, 0.0, clampf(fade_target, 0.0, 1.0))


func _camera_pose(beat: Dictionary, t: float) -> Dictionary:
	var camera: Dictionary = beat.get("camera", {})
	var mode := StringName(camera.get("mode", &"fixed"))
	var from: Vector3 = camera.get("from", Vector3.ZERO)
	var to: Vector3 = camera.get("to", Vector3.ZERO)
	var look: Vector3 = camera.get("look_at", Vector3.ZERO)
	var fov := float(camera.get("fov", 70.0))
	var eased := _ease_in_out(t)
	match mode:
		&"rail":
			return {"position": from.lerp(to, eased), "look_at": look, "fov": fov}
		&"orbit":
			var center := look
			var offset_from := from - center
			var offset_to := to - center
			var radius := Vector2(offset_from.x, offset_from.z).length()
			if radius < 0.5:
				radius = 7.0
			var start_angle := atan2(offset_from.z, offset_from.x)
			var end_angle := start_angle + TAU * 0.18
			if Vector2(offset_to.x, offset_to.z).length() > 0.5:
				end_angle = atan2(offset_to.z, offset_to.x)
			var angle := lerp_angle(start_angle, end_angle, eased)
			var position := center + Vector3(
				cos(angle) * radius,
				lerpf(offset_from.y, offset_to.y, eased),
				sin(angle) * radius
			)
			return {"position": position, "look_at": center, "fov": fov}
		_:
			return {"position": from, "look_at": look, "fov": fov}


func _ease_in_out(t: float) -> float:
	var value := clampf(t, 0.0, 1.0)
	return value * value * (3.0 - 2.0 * value)


# ---------------------------------------------------------------------------
# Camera rig
# ---------------------------------------------------------------------------

func _setup_rig(opts: Dictionary) -> void:
	_teardown_rig()
	var parent := _rig_parent(opts)
	if parent == null:
		return
	var player = opts.get("player", null)
	if player is Node and is_instance_valid(player):
		_player_camera = _find_player_camera(player)
	var rig := Camera3D.new()
	rig.name = "CutsceneCamera"
	rig.fov = 70.0
	rig.near = 0.05
	rig.far = 1200.0
	parent.add_child(rig)
	rig.global_position = parent.global_position + Vector3(0.0, 2.0, 0.0)
	rig.current = true
	_camera = rig


func _rig_parent(opts: Dictionary) -> Node3D:
	var world = opts.get("world", null)
	if world is Node3D and is_instance_valid(world):
		return world
	var player = opts.get("player", null)
	if player is Node3D and is_instance_valid(player):
		var parent: Node = (player as Node3D).get_parent()
		if parent is Node3D:
			return parent
	return null


func _find_player_camera(player: Node) -> Camera3D:
	if player.has_method("get_camera"):
		var camera = player.call("get_camera")
		if camera is Camera3D and is_instance_valid(camera):
			return camera
	var found := player.find_child("Camera", true, false)
	if found is Camera3D:
		return found
	return null


func _teardown_rig() -> void:
	if _camera != null:
		if is_instance_valid(_camera):
			_camera.current = false
			_camera.queue_free()
		_camera = null
	if _player_camera != null:
		if is_instance_valid(_player_camera):
			_player_camera.current = true
		_player_camera = null


# ---------------------------------------------------------------------------
# Director callbacks
# ---------------------------------------------------------------------------

func _on_beat_changed(index: int, beat: Dictionary) -> void:
	if _director == null:
		return
	var id := _director.get_active_id()
	if id != &"":
		_cutscene_id = id
	_caption_text = String(beat.get("caption", ""))
	_apply_caption_visibility()
	_caption_label.text = _caption_text
	_radio_speaker.text = String(beat.get("speaker", "")).to_upper()
	_radio_speaker.visible = _subtitles and not _radio_speaker.text.is_empty()
	_radio_label.text = String(beat.get("radio", ""))
	_radio_label.visible = _subtitles and not _radio_label.text.is_empty()
	var reduced := bool(beat.get("reduced", false))
	_caption_label.add_theme_font_size_override("font_size", 25 if reduced else 30)
	_eyebrow_label.text = "REDUCED MOTION · STATIC CARD" if reduced else "CUTSCENE // %s" % String(_cutscene_id).to_upper()
	_eyebrow_label.add_theme_color_override("font_color", UIPalette.amber if reduced else _accent)
	_tag_label.text = "BEAT %02d/%02d · %s" % [index + 1, _director.get_beat_count(), String(_director.get_active_id()).to_upper()]
	_dossier_panel.visible = _cutscene_id == &"boss"
	if _dossier_panel.visible:
		_refresh_dossier()
	if _film != null:
		_film.accent = _accent
		_film.queue_redraw()
	queue_redraw()


func _on_director_finished(cutscene_id: StringName) -> void:
	_teardown_rig()
	if _fade != null:
		_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	visible = false
	_skip_button.visible = false
	_caption_text = ""
	_cutscene_id = cutscene_id
	_opts.clear()
	set_process(false)
	finished.emit(cutscene_id)


# ---------------------------------------------------------------------------
# Chrome helpers
# ---------------------------------------------------------------------------

func _reset_chrome() -> void:
	_caption_label.text = ""
	_caption_label.visible = false
	_radio_label.text = ""
	_radio_label.visible = false
	_radio_speaker.text = ""
	_radio_speaker.visible = false
	_eyebrow_label.text = "CUTSCENE // %s" % String(_cutscene_id).to_upper()
	_eyebrow_label.add_theme_color_override("font_color", _accent)
	_tag_label.text = ""
	_dossier_name.text = ""
	_dossier_meta.text = ""
	_dossier_tag.text = "THREAT DOSSIER"
	if _film != null:
		_film.accent = _accent
	queue_redraw()


func _apply_caption_visibility() -> void:
	var show := _subtitles and not _caption_text.is_empty()
	_caption_label.visible = show
	_caption_label.modulate.a = 1.0


func _resolve_subtitles() -> bool:
	if App != null and App.has_method("get_setting"):
		return bool(App.get_setting("subtitles", true))
	return true


func _refresh_dossier() -> void:
	var info: Dictionary = _director.get_dossier()
	var name_text := String(info.get("name", "UNIDENTIFIED SIGNATURE")).to_upper()
	var faction := String(info.get("faction", "UNCLASSIFIED")).to_upper()
	var phase := int(info.get("phase", 1))
	_dossier_tag.text = String(info.get("tag", "THREAT DOSSIER")).to_upper()
	_dossier_name.text = name_text
	_dossier_meta.text = "%s  //  PHASE %d" % [faction, phase]


func _accent_for(cutscene_id: StringName) -> Color:
	match cutscene_id:
		&"boss":
			return UIPalette.danger
		&"insertion":
			return UIPalette.amber
		&"exfil":
			return UIPalette.mint
		_:
			return UIPalette.mint


# ---------------------------------------------------------------------------
# 2D-card fallback (no 3D world) and input
# ---------------------------------------------------------------------------

func _draw() -> void:
	if not visible:
		return
	var width := size.x
	var height := size.y
	if width < 8.0 or height < 8.0:
		return
	if _camera != null and is_instance_valid(_camera):
		# The 3D world is the picture; only a whisper of scrim for legibility.
		draw_rect(Rect2(0.0, 0.0, width, height), UIPalette.alpha(UIPalette.ink, 0.08))
		return
	# Code-drawn card: horizon gradient, perspective grid and accent glow.
	var top := UIPalette.ink_deep
	var bottom := UIPalette.mix(UIPalette.ink_deep, _accent, 0.11)
	var bands := 28
	for i in bands:
		var t := float(i) / float(bands - 1)
		draw_rect(
			Rect2(0.0, height * t, width, height / float(bands) + 1.0),
			top.lerp(bottom, t)
		)
	var horizon := height * 0.62
	draw_rect(Rect2(0.0, horizon, width, 1.0), UIPalette.alpha(_accent, 0.32))
	var glow_alpha := 0.15
	if not is_reduce_motion():
		glow_alpha += 0.035 * sin(_card_time * 0.9)
	_draw_soft_glow(Vector2(width * 0.5, horizon), height * 0.46, UIPalette.alpha(_accent, glow_alpha), 16)
	var vanish := Vector2(width * 0.5, horizon)
	for i in 9:
		draw_line(
			Vector2(width * float(i) / 8.0, height),
			vanish,
			UIPalette.alpha(_accent, 0.055),
			1.0
		)
	for i in 6:
		var t := float(i) / 5.0
		var y := horizon + (height - horizon) * pow(t, 1.7)
		draw_line(Vector2(0.0, y), Vector2(width, y), UIPalette.alpha(_accent, 0.05 * (1.0 - t)), 1.0)
	# Signal bars: reads as a telemetry card even on the static reduced frame.
	var bar_origin := Vector2(width * 0.5, horizon - 12.0)
	for i in 11:
		var bar_height := 7.0 + 5.0 * sin(float(i) * 1.7 + _card_time * 1.4)
		draw_rect(
			Rect2(bar_origin.x + float(i - 5) * 10.0, bar_origin.y - bar_height, 4.0, bar_height),
			UIPalette.alpha(_accent, 0.16)
		)


func _draw_soft_glow(center: Vector2, radius: float, color: Color, rings: int) -> void:
	for ring in range(rings, 0, -1):
		var t := float(ring) / float(rings)
		var alpha := color.a * (1.0 - t) * (1.0 - t) * 0.55
		draw_circle(center, radius * t, Color(color.r, color.g, color.b, alpha))


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not is_playing():
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"ui_accept"):
		skip()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			match key_event.keycode:
				KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
					skip()
					get_viewport().set_input_as_handled()
