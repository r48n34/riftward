extends Control
## Headless acceptance test for the cut-scene layer.
##
## Exercises CinematicOverlay + CutsceneDirector with NO 3D world present (the
## 2D-card fallback path), plus one instantiated-3D-rig pass and the loading
## cinema insertion insert. Run with:
##   godot --headless --path . res://tests/cutscene_test.tscn

const TIMEOUT_SECONDS := 75.0
const CUTSCENE_IDS: Array[StringName] = [&"deployment", &"insertion", &"exfil", &"boss"]

var _checks := 0
var _failures: Array[String] = []
var _done := false
var _overlay: CinematicOverlay = null
var _bus_started: Array[StringName] = []
var _bus_ended: Array[StringName] = []
var _finished_ids: Array[StringName] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("[CUTSCENE-TEST] PASS: %s" % label)
	else:
		var suffix := "" if detail.is_empty() else " — %s" % detail
		_failures.append(label + suffix)
		push_error("[CUTSCENE-TEST] FAIL: %s%s" % [label, suffix])
		print("[CUTSCENE-TEST] FAIL: %s%s" % [label, suffix])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _run() -> void:
	print("[CUTSCENE-TEST] starting")
	var timeout := Timer.new()
	timeout.wait_time = TIMEOUT_SECONDS
	timeout.one_shot = true
	timeout.timeout.connect(func() -> void:
		if not _done:
			push_error("[CUTSCENE-TEST] TIMEOUT after %.0fs" % TIMEOUT_SECONDS)
			print("[CUTSCENE-TEST] RESULT: FAIL - timeout")
			get_tree().quit(1)
	)
	add_child(timeout)
	timeout.start()
	# Deterministic accessibility state for the loading-cinema check.
	App.set_setting("reduce_motion", false)
	await _frames(2)

	_overlay = CinematicOverlay.new()
	_overlay.name = "CinematicOverlay"
	add_child(_overlay)
	await _frames(3)
	_overlay.finished.connect(func(cutscene_id: StringName) -> void:
		_finished_ids.append(cutscene_id)
	)
	_connect_bus()

	var director := _overlay.get_director()
	_check(director != null, "overlay hosts a CutsceneDirector")
	if director == null:
		_finish()
		return

	# --- registration ------------------------------------------------------
	var ids := director.get_cutscene_ids()
	_check(ids.size() == 4, "director registers four cut-scenes (%d)" % ids.size())
	for cutscene_id in CUTSCENE_IDS:
		_check(ids.has(cutscene_id), "cut-scene registered: %s" % String(cutscene_id))
		_check(director.has_cutscene(cutscene_id), "has_cutscene true: %s" % String(cutscene_id))
	_check(_overlay.get_skip_button() != null, "overlay exposes the skip button")
	_check(not _overlay.is_playing(), "overlay starts idle")
	_check(not _overlay.visible, "overlay starts hidden")

	# --- unknown id --------------------------------------------------------
	var unknown := _overlay.play(&"not_a_cutscene", {})
	_check(not unknown, "unknown cut-scene id returns false")
	_check(not _overlay.is_playing(), "unknown id leaves the director idle")
	_check(not _overlay.visible, "unknown id leaves the overlay hidden")
	await _frames(2)

	# --- insertion playback (no 3D world -> 2D card fallback) --------------
	director.set_speed_scale(1.0)
	var started := _overlay.play(&"insertion", {"emit_bus": true})
	_check(started, "insertion plays without a 3D world")
	_check(_overlay.is_playing(), "is_playing true during insertion")
	_check(_overlay.visible, "overlay becomes visible")
	_check(director.get_active_id() == &"insertion", "active id is insertion")
	_check(director.get_beat_count() == 3, "insertion authored as three beats (%d)" % director.get_beat_count())
	_check(not _overlay.get_caption_text().is_empty(), "first beat carries a caption")
	_check(director.get_elapsed() >= 0.0, "director exposes elapsed time")
	await _frames(2)
	_check(director.get_elapsed() > 0.0, "elapsed clock advances")
	_check(not _overlay.get_caption_text().is_empty(), "caption stays populated")

	# Beats advance over time (sped up so the suite stays quick).
	director.set_speed_scale(4.0)
	await get_tree().create_timer(0.45).timeout
	_check(director.get_beat_index() >= 1, "beats advance over time (index %d)" % director.get_beat_index())
	_check(not _overlay.get_caption_text().is_empty(), "later beats keep captions")

	# --- skip ends within a frame and emits finished once ------------------
	var finished_before := _finished_ids.size()
	_overlay.skip()
	_check(not _overlay.is_playing(), "skip() ends playback immediately")
	await _frames(2)
	_check(not _overlay.visible, "skip hides the overlay")
	_check(_finished_ids.size() == finished_before + 1, "skip emits finished exactly once")
	_check(director.get_active_id() == &"", "skip clears the active id")
	if _has_cinematic_signal():
		_check(_bus_started.has(&"insertion"), "EventBus cinematic start emitted")
		_check(_bus_ended.has(&"insertion"), "EventBus cinematic end emitted")

	# --- natural completion -------------------------------------------------
	director.set_speed_scale(6.0)
	var natural := _overlay.play(&"exfil", {})
	_check(natural, "exfil plays without a ship node")
	_check(director.get_beat_count() == 4, "exfil authored as four beats")
	var waited := 0.0
	while _overlay.is_playing() and waited < 6.0:
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	_check(not _overlay.is_playing(), "exfil finishes on its own")
	_check(waited < 6.0, "exfil finished without an external skip")
	_check(not _overlay.visible, "natural finish hides the overlay")
	_check(director.get_speed_scale() > 0.0, "speed hook remains readable")

	# --- 12 s hard cap ------------------------------------------------------
	director.set_speed_scale(0.25)
	var capped := _overlay.play(&"exfil", {})
	_check(capped, "exfil restarts for the hard-cap probe")
	_check(director.get_hard_cap() == 12.0, "director declares the 12 s hard cap")
	director.advance_for(3600.0)
	_check(not _overlay.is_playing(), "hard cap finishes a stalled cut-scene")
	_check(director.get_elapsed() <= director.get_hard_cap() + 0.001,
		"elapsed is clamped to the hard cap (%.2f)" % director.get_elapsed())
	await _frames(2)
	_check(not _overlay.visible, "hard cap hides the overlay")
	director.set_speed_scale(1.0)

	# --- reduce motion: single 1.2 s card carrying the captions ------------
	var reduce_world := Node3D.new()
	reduce_world.name = "ReduceWorld"
	add_child(reduce_world)
	var reduce_player := Node3D.new()
	reduce_player.name = "ReducePlayer"
	reduce_world.add_child(reduce_player)
	_overlay.set_reduce_motion(true)
	var reduced_started := _overlay.play(&"insertion", {"world": reduce_world, "player": reduce_player})
	_check(reduced_started, "reduce-motion insertion plays")
	_check(_overlay.get_camera_rig() == null, "reduce motion never steals the 3D camera")
	_check(director.is_reduced_motion(), "director reports reduce motion")
	_check(director.get_beat_count() == 1, "reduce motion collapses to one card")
	var card := director.get_current_beat()
	_check(is_equal_approx(float(card.get("duration", 0.0)), 1.2),
		"static card runs 1.2 s (%.2f)" % float(card.get("duration", 0.0)))
	var card_caption := String(card.get("caption", ""))
	_check(card_caption.contains("RAMP DOWN"), "static card carries the first caption")
	_check(card_caption.contains("THE REACH IS HOSTILE"), "static card carries every caption")
	_check(not _overlay.get_caption_text().is_empty(), "static card exposes caption text")
	director.set_speed_scale(5.0)
	waited = 0.0
	while _overlay.is_playing() and waited < 3.0:
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	_check(not _overlay.is_playing(), "static card ends by itself")
	_overlay.set_reduce_motion(false)
	director.set_speed_scale(1.0)

	# --- boss dossier + clean abort when the boss dies mid-shot ------------
	var boss := Node3D.new()
	boss.name = "FakeBoss"
	boss.set_meta("enemy_name", "WARDEN OF THE FOLD")
	boss.set_meta("faction", "ashen")
	boss.set_meta("phase", 2)
	add_child(boss)
	var boss_started := _overlay.play(&"boss", {"boss": boss, "emit_bus": true})
	_check(boss_started, "boss shot plays against a boss node")
	_check(director.get_beat_count() == 3, "boss shot authored as three beats")
	_check(director.get_dossier().get("name", "") == "WARDEN OF THE FOLD", "dossier resolves the boss name")
	_check(int(director.get_dossier().get("phase", 0)) == 2, "dossier resolves the boss phase")
	var dossier := _overlay.get_dossier_text()
	_check(bool(dossier.get("visible", false)), "dossier card chrome is visible")
	_check("WARDEN OF THE FOLD" in String(dossier.get("name", "")), "dossier card shows the boss name")
	boss.queue_free()
	waited = 0.0
	while _overlay.is_playing() and waited < 1.0:
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	_check(not _overlay.is_playing(), "boss shot aborts when the boss becomes invalid")
	_check(not _overlay.visible, "invalid boss hides the overlay")
	if _has_cinematic_signal():
		_check(_bus_ended.has(&"boss"), "EventBus cinematic end emitted for the aborted boss shot")

	# --- 3D rig attach + clean hand-back ----------------------------------
	var world := Node3D.new()
	world.name = "FakeWorld"
	add_child(world)
	var fake_player := Node3D.new()
	fake_player.name = "FakePlayer"
	fake_player.position = Vector3(12.0, 0.0, 24.0)
	world.add_child(fake_player)
	director.set_speed_scale(1.0)
	var rig_started := _overlay.play(&"insertion", {"world": world, "player": fake_player})
	_check(rig_started, "insertion plays against a 3D world")
	var rig := _overlay.get_camera_rig()
	_check(rig != null, "overlay attaches a Camera3D rig")
	_check(rig != null and rig.current, "cut-scene camera becomes current")
	if rig != null:
		_check(rig.global_position.distance_to(fake_player.global_position) < 12.0,
			"camera rig starts near the shot anchor")
	_overlay.skip()
	await _frames(2)
	_check(_overlay.get_camera_rig() == null, "skip tears the rig down")
	_check(not _overlay.is_playing(), "rig pass ends cleanly")

	# --- loading cinema: insertion insert lives in the drop feed ----------
	var loading := LoadingScreen.new()
	loading.name = "LoadingCinema"
	add_child(loading)
	await _frames(2)
	loading.present("Preparing the Reach", 0.05, LoadingBrief.build())
	await _frames(2)
	_check(loading.get_act_titles().size() == 4, "loading cinema still declares four acts")
	var insert_shot := loading.get_shot(&"insertion")
	_check(insert_shot != null, "loading cinema owns a CinemaInsertionShot")
	_check(insert_shot is CinemaInsertionShot, "insertion shot is the authored type")
	loading.set_act_id(&"descent")
	await _frames(1)
	loading.update_loading(0.99, "Printing drop pod")
	waited = 0.0
	while not loading.is_insert_active() and waited < 4.0:
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	_check(loading.get_active_act() == &"touchdown", "feed reaches touchdown naturally")
	_check(loading.is_insert_active(), "insertion insert plays at the head of touchdown")
	_check(loading.get_active_shot_id() == &"insertion", "active shot id is insertion")
	_check(insert_shot != null and insert_shot.visible, "insertion shot is on screen")
	waited = 0.0
	while loading.is_insert_active() and waited < 3.0:
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	_check(not loading.is_insert_active(), "insert hands back to the touchdown shot")
	_check(loading.get_active_shot_id() == &"touchdown", "touchdown shot resumes after the insert")
	loading.skip_cinematic()
	await _frames(1)
	_check(loading.is_cinematic_skipped(), "skip still collapses the loading cinema")

	_finish()


func _connect_bus() -> void:
	if not _has_cinematic_signal():
		return
	EventBus.connect(&"cinematic_state_changed", func(active: bool, cutscene_id: StringName) -> void:
		if active:
			_bus_started.append(cutscene_id)
		else:
			_bus_ended.append(cutscene_id)
	)


func _has_cinematic_signal() -> bool:
	return EventBus != null and EventBus.has_signal(&"cinematic_state_changed")


func _finish() -> void:
	_done = true
	print("[CUTSCENE-TEST] checks=%d failures=%d" % [_checks, _failures.size()])
	var passed := _failures.is_empty()
	if passed:
		print("[CUTSCENE-TEST] RESULT: PASS")
	else:
		for failure in _failures:
			print("[CUTSCENE-TEST]  - %s" % failure)
		print("[CUTSCENE-TEST] RESULT: FAIL - %s" % "; ".join(_failures))
	# Deterministic teardown so object leaks cannot mask a real failure.
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.dismiss()
	for child in get_children():
		if child is Timer:
			continue
		child.queue_free()
	await _frames(3)
	get_tree().quit(0 if passed else 1)
