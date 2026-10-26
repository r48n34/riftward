class_name CutsceneDirector
extends Node
## Data-driven in-world cut-scene director.
##
## A cut-scene is a short beat timeline: each beat carries a duration, a camera
## keyframe block, caption/radio copy, optional audio stings and HUD visibility.
## The director owns the clock, the beat cursor and the hard safety rail; the
## presentation layer (`CinematicOverlay`) owns the chrome and the optional 3D
## camera rig.
##
## ## Registration / ids
##   &"deployment"  6.0 s  drop-feed recap card (the live feed is LoadingScreen)
##   &"insertion"   4.0 s  ramp down, first-person rise, first radio traffic
##   &"exfil"       6.0 s  pad approach, dropship ramp, lift-off, fade out
##   &"boss"        4.0 s  threat dossier card, orbit keyframes, roar stinger
##
## ## play() opts (all optional; unknown ids return false, never error)
##   world: Node3D          world root; only used for the 2D/3D camera rig choice
##   player: Node           shot anchor for insertion/exfil (and validity guard)
##   boss: Node             orbit anchor + dossier source for &"boss"
##   ship: Node3D           exfil dropship; safe to omit
##   reduce_motion: bool    force the 1.2 s static card instead of footage
##   emit_bus: bool         opt-in EventBus.cinematic_state_changed emission
##                          (App owns the bus by default, so this stays false)
##   on_finished: Callable  called with the cut-scene id after finish/skip
##   origin: Vector3        shot anchor override when player is absent
##   callsign / brief / map_name / planet_name / contract_name
##   boss_name / boss_faction / boss_phase / boss_tag
##   hide_hud: bool         default true; defensive null-safe hide/restore
##   manage_mouse: bool     default false (App owns mouse/input while cinematic)
##
## ## Hard rules
##   - 12 s absolute hard cap per cut-scene; oversized timelines are compressed.
##   - Every exit path (natural end, skip, abort, lost refs, freed parent) runs
##     the same restore routine: HUD visibility, optional mouse mode, beat audio
##     is never re-entered, and `finished` fires exactly once per play().
##   - Reduce motion collapses the whole cut-scene into a single 1.2 s static
##     card that carries every caption from the full timeline.
##   - A boss shot aborts cleanly as soon as the boss node becomes invalid, and
##     the director itself never dereferences the world/player after finishing.

signal finished(cutscene_id: StringName)
## Emitted whenever the active beat changes (also once for the first beat).
signal beat_changed(index: int, beat: Dictionary)

## Absolute ceiling for one cut-scene, including reduce-motion cards.
const HARD_CAP := 12.0
## Reduce motion collapses to one card of this length.
const REDUCED_DURATION := 1.2
## Beats never run shorter than this (guards divide-by-zero in the blend math).
const MIN_BEAT_DURATION := 0.05
## Registered cut-scene ids. `deployment` is the recap card; the live drop feed
## lives in LoadingScreen so it can follow terrain progress.
const CUTSCENE_IDS: Array[StringName] = [&"deployment", &"insertion", &"exfil", &"boss"]

var _beats: Array[Dictionary] = []
var _opts: Dictionary = {}
var _active_id: StringName = &""
var _active := false
var _elapsed := 0.0
var _beat_index := 0
var _beat_elapsed := 0.0
var _beat_duration := 1.0
var _speed := 1.0
var _origin := Vector3.ZERO
var _reduced := false
var _finished_emitted := false
var _bus_opt_in := false

var _hud: CanvasItem = null
var _hud_was_visible := true
var _saved_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _mouse_touched := false

var _world_ref: Node3D = null
var _player_ref: Node = null
var _boss_ref: Node = null
var _ship_ref: Node3D = null
var _requires_world := false
var _requires_player := false
var _requires_boss := false

var _dossier: Dictionary = {}
var _on_finished: Callable = Callable()


func _ready() -> void:
	set_process(false)


## If the owner frees the director mid-shot (deployment teardown) restore the
## HUD/mouse state without emitting `finished` from a dying node.
func _exit_tree() -> void:
	if _active:
		_active = false
		set_process(false)
		_restore_state()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Starts a registered cut-scene. Returns false for an unknown id or empty
## timeline without touching any state. Replaying while active aborts the
## previous playback (with a normal finished emission) before starting.
func play(cutscene_id: StringName, opts: Dictionary = {}) -> bool:
	if cutscene_id == &"" or not CUTSCENE_IDS.has(cutscene_id):
		return false
	if _active:
		_end(true)
	_opts = opts.duplicate(true)
	_active_id = cutscene_id
	_bus_opt_in = bool(_opts.get("emit_bus", false))
	_on_finished = _opts.get("on_finished", Callable())
	_resolve_refs()
	_reduced = _resolve_reduce_motion(_opts)
	_dossier = _resolve_dossier()
	_origin = _resolve_origin(cutscene_id)
	var raw := _build_timeline(cutscene_id)
	if raw.is_empty():
		_active_id = &""
		return false
	if _reduced:
		_beats = _build_static_card(raw)
	else:
		_beats = raw
		_fit_to_cap(_beats)
	_finished_emitted = false
	_active = true
	_elapsed = 0.0
	_beat_index = 0
	_beat_elapsed = 0.0
	_beat_duration = _duration_of(0)
	_hide_hud()
	_manage_mouse(true)
	_emit_bus(true, cutscene_id)
	_apply_beat(0, true)
	set_process(true)
	return true


## Ends the current cut-scene as if the player skipped it: `finished` fires once
## and every previously hidden bit of state is restored. Safe to spam.
func skip() -> void:
	if not _active:
		return
	_play_ui(&"ui_skip", -6.0)
	_end(true)


## Drops the current cut-scene without emitting `finished`. Used by a silent
## owner teardown (UIRoot.hide_cinematic on scene change, App.abort_cinematic).
func abort(silent: bool = true) -> void:
	if not _active:
		return
	if silent:
		_end(false)
	else:
		_end(true)


func is_playing() -> bool:
	return _active


func get_active_id() -> StringName:
	return _active_id


func has_cutscene(cutscene_id: StringName) -> bool:
	return CUTSCENE_IDS.has(cutscene_id)


func get_cutscene_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(CUTSCENE_IDS)
	return ids


func get_beat_count() -> int:
	return _beats.size()


func get_beat_index() -> int:
	return _beat_index


## Total seconds of the active timeline (all beats, or 1.2 s when reduced).
func get_duration() -> float:
	var total := 0.0
	for beat in _beats:
		total += float(beat.get("duration", 0.0))
	return total


func get_elapsed() -> float:
	return _elapsed


func get_beat_progress() -> float:
	if _beat_duration <= 0.0:
		return 0.0
	return clampf(_beat_elapsed / _beat_duration, 0.0, 1.0)


## Current beat dictionary; camera vectors are absolute world positions (the
## authored offsets have already been resolved against the shot origin).
func get_current_beat() -> Dictionary:
	if _beat_index < 0 or _beat_index >= _beats.size():
		return {}
	return _beats[_beat_index]


func get_dossier() -> Dictionary:
	return _dossier.duplicate(true)


func get_hard_cap() -> float:
	return HARD_CAP


func is_reduced_motion() -> bool:
	return _reduced


func get_speed_scale() -> float:
	return _speed


## Test / capture hook: scales the simulated clock. 1.0 is real time.
func set_speed_scale(value: float) -> void:
	_speed = clampf(value, 0.01, 60.0)


## Test hook: advances the same clock `_process` drives, scaled by the speed
## setting. Lets headless suites exercise the 12 s cap without waiting.
func advance_for(seconds: float) -> void:
	if not _active or seconds <= 0.0:
		return
	_advance(seconds * _speed)


# ---------------------------------------------------------------------------
# Frame loop
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _active:
		return
	_advance(delta * _speed)


func _advance(delta: float) -> void:
	if not _active or delta <= 0.0:
		return
	_elapsed += delta
	if _elapsed >= HARD_CAP:
		_elapsed = HARD_CAP
		_end(true)
		return
	if not _required_refs_alive():
		_end(true)
		return
	_beat_elapsed += delta
	var guard := 0
	while _active and _beat_elapsed >= _beat_duration:
		guard += 1
		if guard > 128:
			_end(true)
			return
		if _beat_index >= _beats.size() - 1:
			_end(true)
			return
		_beat_elapsed -= _beat_duration
		_beat_index += 1
		_beat_duration = _duration_of(_beat_index)
		_apply_beat(_beat_index, false)


func _duration_of(index: int) -> float:
	if index < 0 or index >= _beats.size():
		return MIN_BEAT_DURATION
	return maxf(MIN_BEAT_DURATION, float(_beats[index].get("duration", MIN_BEAT_DURATION)))


func _apply_beat(index: int, initial: bool) -> void:
	var beat: Dictionary = _beats[index]
	_beat_duration = _duration_of(index)
	if not initial:
		_beat_elapsed = maxf(_beat_elapsed, 0.0)
	_set_hud_for_beat(beat)
	_play_beat_audio(beat)
	beat_changed.emit(index, beat)


# ---------------------------------------------------------------------------
# Teardown, restore, safety
# ---------------------------------------------------------------------------

func _end(emit_finished: bool) -> void:
	if not _active:
		return
	var id := _active_id
	_active = false
	set_process(false)
	_restore_state()
	if emit_finished and not _finished_emitted:
		_finished_emitted = true
		_emit_bus(false, id)
		finished.emit(id)
		var callback := _on_finished
		_on_finished = Callable()
		if callback.is_valid():
			callback.call(id)
	if not emit_finished:
		_finished_emitted = true
	# Re-entrancy guard: a finished listener may immediately start the next
	# cut-scene. Never clear the new playback's state from the old teardown.
	if _active:
		return
	_active_id = &""
	_opts.clear()
	_world_ref = null
	_player_ref = null
	_boss_ref = null
	_ship_ref = null
	_requires_world = false
	_requires_player = false
	_requires_boss = false


func _restore_state() -> void:
	_restore_hud()
	if _mouse_touched:
		_mouse_touched = false
		if DisplayServer.get_name() != "headless":
			Input.set_mouse_mode(_saved_mouse_mode)


func _resolve_refs() -> void:
	_world_ref = null
	_player_ref = null
	_boss_ref = null
	_ship_ref = null
	var world = _opts.get("world", null)
	if world is Node3D and is_instance_valid(world):
		_world_ref = world
	var player = _opts.get("player", null)
	if player is Node and is_instance_valid(player):
		_player_ref = player
	var boss = _opts.get("boss", null)
	if boss is Node and is_instance_valid(boss):
		_boss_ref = boss
	var ship = _opts.get("ship", null)
	if ship is Node3D and is_instance_valid(ship):
		_ship_ref = ship
	_requires_world = _world_ref != null
	_requires_player = _player_ref != null
	_requires_boss = _boss_ref != null


func _required_refs_alive() -> bool:
	if _requires_world and (_world_ref == null or not is_instance_valid(_world_ref)):
		return false
	if _requires_player and (_player_ref == null or not is_instance_valid(_player_ref)):
		return false
	if _requires_boss and (_boss_ref == null or not is_instance_valid(_boss_ref)):
		return false
	return true


func _resolve_reduce_motion(opts: Dictionary) -> bool:
	if opts.has("reduce_motion"):
		return bool(opts["reduce_motion"])
	return UIPalette.reduce_motion


func _resolve_origin(cutscene_id: StringName) -> Vector3:
	var origin := Vector3.ZERO
	if _boss_ref != null and cutscene_id == &"boss":
		origin = (_boss_ref as Node3D).global_position
	elif _player_ref != null and is_instance_valid(_player_ref) and _player_ref is Node3D:
		origin = (_player_ref as Node3D).global_position
	elif _opts.get("origin", null) is Vector3:
		origin = _opts["origin"]
	return origin


func _resolve_dossier() -> Dictionary:
	var name_text := String(_opts.get("boss_name", ""))
	var faction := String(_opts.get("boss_faction", ""))
	var phase := int(_opts.get("boss_phase", 0))
	var tag := String(_opts.get("boss_tag", "THREAT DOSSIER"))
	if _boss_ref != null and is_instance_valid(_boss_ref):
		if name_text.is_empty():
			name_text = String(_boss_ref.get_meta("enemy_name", ""))
		if name_text.is_empty():
			name_text = String(_boss_ref.name)
		if faction.is_empty():
			faction = String(_boss_ref.get_meta("faction", ""))
		if phase <= 0:
			phase = int(_boss_ref.get_meta("phase", 1))
	if name_text.is_empty():
		name_text = "UNIDENTIFIED SIGNATURE"
	if faction.is_empty():
		faction = "UNCLASSIFIED"
	if phase <= 0:
		phase = 1
	return {"name": name_text, "faction": faction, "phase": phase, "tag": tag}


func _resolve_hud() -> CanvasItem:
	if App == null or not App.has_method("get_ui"):
		return null
	var ui: Node = App.get_ui()
	if ui == null or not is_instance_valid(ui) or not ui.has_method("get_hud"):
		return null
	var hud = ui.get_hud()
	if hud is CanvasItem and is_instance_valid(hud):
		return hud
	return null


func _hide_hud() -> void:
	if not bool(_opts.get("hide_hud", true)):
		return
	_hud = _resolve_hud()
	if _hud == null:
		return
	_hud_was_visible = _hud.visible
	_hud.visible = false


func _set_hud_for_beat(beat: Dictionary) -> void:
	# A cut-scene always keeps the gameplay HUD out of frame. The per-beat
	# `hud_hidden` flag is authored on every beat and reserved for future
	# diegetic inserts; it is read here so the contract is honoured explicitly.
	if _hud == null or not is_instance_valid(_hud):
		return
	_hud.visible = false if bool(beat.get("hud_hidden", true)) else _hud_was_visible


func _restore_hud() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = _hud_was_visible
	_hud = null


func _manage_mouse(started: bool) -> void:
	if not bool(_opts.get("manage_mouse", false)):
		return
	if DisplayServer.get_name() == "headless":
		return
	if started:
		_saved_mouse_mode = Input.get_mouse_mode()
		_mouse_touched = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _emit_bus(active: bool, cutscene_id: StringName) -> void:
	if not _bus_opt_in:
		return
	if EventBus == null or not EventBus.has_signal(&"cinematic_state_changed"):
		return
	EventBus.emit_signal(&"cinematic_state_changed", active, cutscene_id)


# ---------------------------------------------------------------------------
# Audio (all stream ids are guarded: audio may not be authored yet)
# ---------------------------------------------------------------------------

func _has_stream(stream_id: StringName) -> bool:
	if stream_id == &"" or AudioDirector == null:
		return false
	if AudioDirector.has_method("has_stream"):
		return bool(AudioDirector.call("has_stream", stream_id))
	if AudioDirector.has_method("get_stream"):
		return AudioDirector.call("get_stream", stream_id) != null
	return false


func _play_sfx(stream_id: StringName, volume_db: float) -> void:
	if not _has_stream(stream_id):
		return
	if AudioDirector.has_method("play_sfx"):
		AudioDirector.call("play_sfx", stream_id, volume_db)


func _play_ui(stream_id: StringName, volume_db: float) -> void:
	if not _has_stream(stream_id):
		return
	if AudioDirector.has_method("play_ui"):
		AudioDirector.call("play_ui", stream_id, volume_db)


func _play_music(mood: StringName) -> void:
	if mood == &"" or AudioDirector == null:
		return
	if AudioDirector.has_method("set_music_mood"):
		AudioDirector.call("set_music_mood", mood)


func _play_beat_audio(beat: Dictionary) -> void:
	_play_sfx(StringName(beat.get("sfx", &"")), -6.0)
	_play_music(StringName(beat.get("music", &"")))


# ---------------------------------------------------------------------------
# Timeline construction
# ---------------------------------------------------------------------------

func _build_timeline(cutscene_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw := _raw_timeline(cutscene_id)
	var origin := _origin
	if cutscene_id == &"exfil":
		origin = _exfil_anchor()
	for entry in raw:
		var beat: Dictionary = (entry as Dictionary).duplicate(true)
		beat["camera"] = _resolve_camera(beat.get("camera", {}), origin)
		beat["caption"] = _fill_tokens(String(beat.get("caption", "")))
		beat["speaker"] = _fill_tokens(String(beat.get("speaker", "")))
		beat["radio"] = _fill_tokens(String(beat.get("radio", "")))
		if beat.has("title"):
			beat["title"] = _fill_tokens(String(beat["title"]))
		out.append(beat)
	return out


## The authored tables. Camera vectors are offsets from the shot origin (player
## feet, boss origin or the exfil ship/pad) and are resolved at play time.
func _raw_timeline(cutscene_id: StringName) -> Array:
	match cutscene_id:
		&"deployment":
			return [
				{
					"id": &"threat", "duration": 1.5,
					"camera": {"mode": &"fixed", "from": Vector3(0.0, 2.4, 9.0), "to": Vector3(0.0, 2.4, 9.0), "look_at": Vector3(0.0, 1.8, 0.0), "fov": 58.0},
					"caption": "THREAT SIGNATURE · {boss}", "speaker": "KESTREL",
					"radio": "Threat signature logged. You are dropping into something awake.",
					"sfx": &"boss_stinger", "music": &"deployment", "hud_hidden": true,
				},
				{
					"id": &"breach", "duration": 1.5,
					"camera": {"mode": &"fixed", "from": Vector3(0.0, 3.0, 12.0), "to": Vector3(0.0, 3.0, 12.0), "look_at": Vector3(0.0, 2.0, 0.0), "fov": 60.0},
					"caption": "RIFT BREACH · {map} // {planet}", "speaker": "KESTREL",
					"radio": "The Reach is opening. Brace for the fold.",
					"sfx": &"wind_loop", "music": &"deployment", "hud_hidden": true,
				},
				{
					"id": &"descent", "duration": 1.5,
					"camera": {"mode": &"rail", "from": Vector3(0.0, 12.0, 4.0), "to": Vector3(0.0, 2.0, 2.0), "look_at": Vector3(0.0, 0.0, -6.0), "fov": 74.0},
					"caption": "THROUGH THE FOLD", "speaker": "KESTREL",
					"radio": "Altitude dropping. Hull nominal.",
					"sfx": &"ramp_hiss", "music": &"deployment", "hud_hidden": true,
				},
				{
					"id": &"touchdown", "duration": 1.5,
					"camera": {"mode": &"rail", "from": Vector3(0.0, 1.4, 3.0), "to": Vector3(0.0, 1.65, 0.3), "look_at": Vector3(0.0, 1.5, -8.0), "fov": 80.0},
					"caption": "THE REACH IS YOURS", "speaker": "KESTREL",
					"radio": "Operation live. Good hunting, Warden.",
					"sfx": &"ui_confirm", "music": &"combat", "hud_hidden": true,
				},
			]
		&"insertion":
			return [
				{
					"id": &"ramp", "duration": 1.1,
					"camera": {"mode": &"fixed", "from": Vector3(0.0, 1.35, 2.4), "to": Vector3(0.0, 1.35, 2.4), "look_at": Vector3(0.0, 1.25, -1.0), "fov": 72.0},
					"caption": "RAMP DOWN · {map}", "speaker": "KESTREL",
					"radio": "Dropship inbound. Ramp down. Welcome to the Reach.",
					"sfx": &"ramp_hiss", "music": &"deployment", "hud_hidden": true,
				},
				{
					"id": &"rise", "duration": 1.5,
					"camera": {"mode": &"rail", "from": Vector3(0.0, 0.45, 1.4), "to": Vector3(0.0, 1.65, 0.15), "look_at": Vector3(0.0, 1.55, -7.0), "fov": 78.0},
					"caption": "FIRST CONTACT", "speaker": "KESTREL",
					"radio": "Boots on the ground. HUD is live. Weapon hot.",
					"sfx": &"insertion_thud", "music": &"deployment", "hud_hidden": true,
				},
				{
					"id": &"stand", "duration": 1.4,
					"camera": {"mode": &"rail", "from": Vector3(0.0, 1.65, 0.15), "to": Vector3(0.0, 1.68, -0.35), "look_at": Vector3(0.0, 1.5, -9.0), "fov": 82.0},
					"caption": "THE REACH IS HOSTILE", "speaker": "MARA VOSS",
					"radio": "I have movement on the ridge. Keep your head down.",
					"sfx": &"radio_chirp", "music": &"combat", "hud_hidden": true,
				},
			]
		&"exfil":
			return [
				{
					"id": &"approach", "duration": 1.6,
					"camera": {"mode": &"rail", "from": Vector3(0.0, -11.0, 17.0), "to": Vector3(0.0, -9.5, 13.0), "look_at": Vector3(0.0, 0.0, 0.0), "fov": 66.0},
					"caption": "EXFIL INBOUND", "speaker": "KESTREL",
					"radio": "Dropship on approach. Clear the pad.",
					"sfx": &"radio_chirp", "music": &"combat", "hud_hidden": true,
				},
				{
					"id": &"kestrel", "duration": 1.6,
					"camera": {"mode": &"orbit", "from": Vector3(-9.0, -9.0, 6.0), "to": Vector3(9.0, -8.5, 6.0), "look_at": Vector3(0.0, 0.0, 0.0), "fov": 68.0},
					"caption": "KESTREL EXFIL · TOUCHDOWN", "speaker": "KESTREL",
					"radio": "Ramp is dropping. Get aboard, Warden.",
					"sfx": &"wind_loop", "music": &"combat", "hud_hidden": true,
				},
				{
					"id": &"ramp", "duration": 1.4,
					"camera": {"mode": &"fixed", "from": Vector3(2.0, -8.0, 4.5), "to": Vector3(2.0, -8.0, 4.5), "look_at": Vector3(0.0, -3.0, 0.0), "fov": 70.0},
					"caption": "RAMP SECURED · ALL ABOARD", "speaker": "MARA VOSS",
					"radio": "Everyone is aboard. Punch it.",
					"sfx": &"insertion_thud", "music": &"combat", "hud_hidden": true,
				},
				{
					"id": &"liftoff", "duration": 1.4,
					"camera": {"mode": &"rail", "from": Vector3(0.0, -8.0, 6.0), "to": Vector3(0.0, 7.0, 11.0), "look_at": Vector3(0.0, 4.0, 0.0), "fov": 62.0, "fade": 1.0},
					"caption": "LIFT-OFF", "speaker": "KESTREL",
					"radio": "Good hunting, Warden. See you at the Waystation.",
					"sfx": &"exfil_liftoff", "music": &"hub", "hud_hidden": true,
				},
			]
		&"boss":
			return [
				{
					"id": &"dossier", "duration": 0.7,
					"camera": {"mode": &"fixed", "from": Vector3(7.0, 3.2, 8.0), "to": Vector3(7.0, 3.2, 8.0), "look_at": Vector3(0.0, 2.2, 0.0), "fov": 62.0},
					"caption": "THREAT SIGNATURE ACQUIRED", "speaker": "KESTREL",
					"radio": "That signature just went active. Stay mobile.",
					"sfx": &"boss_stinger", "music": &"combat", "hud_hidden": true, "dossier": true,
				},
				{
					"id": &"orbit", "duration": 2.6,
					"camera": {"mode": &"orbit", "from": Vector3(-11.0, 4.0, 6.0), "to": Vector3(10.0, 4.5, -5.0), "look_at": Vector3(0.0, 2.2, 0.0), "fov": 66.0},
					"caption": "{boss} · {faction} · PHASE {phase}", "speaker": "KESTREL",
					"radio": "It has seen you. Break the glowing seams.",
					"sfx": &"boss_roar", "music": &"combat", "hud_hidden": true, "dossier": true,
				},
				{
					"id": &"withdraw", "duration": 0.7,
					"camera": {"mode": &"rail", "from": Vector3(11.0, 5.0, 11.0), "to": Vector3(17.0, 7.0, 17.0), "look_at": Vector3(0.0, 2.0, 0.0), "fov": 58.0},
					"caption": "PHASE {phase} ENGAGED", "speaker": "MARA VOSS",
					"radio": "Hit it together. Do not let it close.",
					"sfx": &"", "music": &"combat", "hud_hidden": true, "dossier": true,
				},
			]
	return []


## Exfil camera space: the dropship (hover altitude included) when present, or a
## synthetic hover anchor above the player so a missing ship cannot bury the rig
## underground. Never touches the ship after finishing.
func _exfil_anchor() -> Vector3:
	if _ship_ref != null and is_instance_valid(_ship_ref):
		return _ship_ref.global_position
	if _player_ref != null and is_instance_valid(_player_ref) and _player_ref is Node3D:
		return (_player_ref as Node3D).global_position + Vector3(0.0, 12.0, -6.0)
	if _opts.get("origin", null) is Vector3:
		return (_opts["origin"] as Vector3) + Vector3(0.0, 12.0, -6.0)
	return Vector3(0.0, 12.0, -6.0)


func _resolve_camera(camera: Dictionary, origin: Vector3) -> Dictionary:
	var resolved: Dictionary = camera.duplicate(true)
	if not resolved.has("mode"):
		resolved["mode"] = &"fixed"
	for key in ["from", "to", "look_at"]:
		var value = resolved.get(key, Vector3.ZERO)
		if value is Vector3:
			resolved[key] = (value as Vector3) + origin
		else:
			resolved[key] = origin
	return resolved


func _fill_tokens(text: String) -> String:
	if text.is_empty():
		return text
	var brief: Dictionary = _opts.get("brief", {})
	var values := {
		"{callsign}": String(_opts.get("callsign", "Warden")),
		"{map}": String(_opts.get("map_name", brief.get("map_name", "The Reach"))).to_upper(),
		"{planet}": String(_opts.get("planet_name", brief.get("planet_name", "Meridian-9"))).to_upper(),
		"{contract}": String(_opts.get("contract_name", brief.get("contract_name", "Salvage Sweep"))).to_upper(),
		"{boss}": String(_dossier.get("name", "UNIDENTIFIED SIGNATURE")).to_upper(),
		"{faction}": String(_dossier.get("faction", "UNCLASSIFIED")).to_upper(),
		"{phase}": str(int(_dossier.get("phase", 1))),
	}
	for token in values.keys():
		text = text.replace(token, String(values[token]))
	return text


## Compresses an oversized timeline proportionally so the sum never exceeds the
## 12 s hard cap even if a future author writes a longer scene.
func _fit_to_cap(beats: Array[Dictionary]) -> void:
	var total := 0.0
	for beat in beats:
		total += float(beat.get("duration", 0.0))
	if total <= HARD_CAP:
		return
	var scale := HARD_CAP / total
	for beat in beats:
		beat["duration"] = maxf(MIN_BEAT_DURATION, float(beat.get("duration", MIN_BEAT_DURATION)) * scale)


## Reduce motion: one 1.2 s card that carries every caption and radio line from
## the full timeline, with the opening stinger preserved.
func _build_static_card(beats: Array[Dictionary]) -> Array[Dictionary]:
	var captions: Array[String] = []
	var radios: Array[String] = []
	var speakers: Array[String] = []
	for beat in beats:
		var caption := String(beat.get("caption", ""))
		if not caption.is_empty() and not captions.has(caption):
			captions.append(caption)
		var radio := String(beat.get("radio", ""))
		if not radio.is_empty() and not radios.has(radio):
			radios.append(radio)
		var speaker := String(beat.get("speaker", ""))
		if not speaker.is_empty() and not speakers.has(speaker):
			speakers.append(speaker)
	var caption_text := ""
	for line in captions:
		caption_text += ("" if caption_text.is_empty() else "\n") + line
	var radio_text := ""
	for line in radios:
		radio_text += ("" if radio_text.is_empty() else "\n") + line
	var speaker_text := speakers[0] if not speakers.is_empty() else "KESTREL"
	var card: Dictionary = {
		"id": &"static_card",
		"duration": REDUCED_DURATION,
		"camera": {"mode": &"fixed", "from": Vector3.ZERO, "to": Vector3.ZERO, "look_at": Vector3.ZERO, "fov": 60.0},
		"caption": caption_text,
		"captions": captions,
		"speaker": speaker_text,
		"radio": radio_text,
		"sfx": StringName(beats[0].get("sfx", &"")) if not beats.is_empty() else &"",
		"music": StringName(beats[0].get("music", &"")) if not beats.is_empty() else &"",
		"hud_hidden": true,
		"reduced": true,
	}
	var out: Array[Dictionary] = [card]
	return out
