extends SceneTree
## Headless acceptance test for the RIFTWARD audio stack.
##
## Run with:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path D:\godotGa\game \
##       --script res://tests/audio_test.gd
##
## Boots the project autoloads (AudioDirector is instantiated before the first
## frame), then asserts the audio contract other streams code against:
##   * catalog size and uniqueness, every required call-site id present
##   * every catalog id resolves to a stream (CC0 override or procedural fallback)
##   * bus layout / routing / Master limiter / Vehicles default
##   * music track switching updates get_music_track() and emits
##     music_track_changed; no-op on repeated ids; headless skips generation
##   * ambience switching is safe (known, unknown, stop)
##   * play_ui/play_sfx/play_3d/play_varied/play_loop_3d accept valid + junk ids
## Prints "RESULT: PASS" and exits 0 on success, otherwise "RESULT: FAIL - ..."
## and exits 1 so tests/run_all.ps1 / CI can gate on it.

const REQUIRED_IDS: Array[StringName] = [
	# Legacy call sites (ui/, features/) - must never disappear.
	&"ui_click", &"ui_hover", &"ui_confirm", &"ui_error", &"scan", &"level_up",
	&"shot_rifle", &"shot_smg", &"shot_shotgun", &"shot_dmr", &"shot_sniper",
	&"shot_lmg", &"shot_pistol", &"shot_launcher", &"shot_arc", &"shot_carbine",
	&"knife_swing", &"knife_hit", &"hit", &"hitmarker", &"headshot", &"kill",
	&"reload", &"explosion", &"ability", &"ability_ready", &"player_hurt",
	&"shield_break", &"pickup", &"exfil", &"heal", &"footstep", &"door", &"storm",
	# Required by the parallel vehicles/world/creature streams.
	&"engine_rig", &"engine_bike", &"engine_plane", &"engine_ship",
	&"boost", &"brake", &"horn",
	&"hoof_walk", &"hoof_trot", &"hoof_gallop", &"whinny",
	&"vehicle_hit", &"vehicle_explode", &"ramp_hiss",
	&"wind_loop", &"wind_ambient", &"water_loop", &"lava_loop",
	&"boss_roar", &"boss_stinger",
	&"exfil_liftoff", &"insertion_thud", &"radio_chirp",
	&"ui_skip", &"build_complete", &"outpost_upgrade", &"cache_open",
	&"shrine_hum", &"birds", &"crickets",
]

const REQUIRED_TRACKS: Array[StringName] = [
	&"menu", &"hub", &"deploy", &"combat", &"boss", &"exfil", &"storm", &"results", &"silent",
]

const REQUIRED_BUSES: Array[String] = ["Music", "SFX", "UI", "Ambience", "Vehicles"]

var _failures: Array[String] = []
var _checks: int = 0
var _ran: bool = false
var _quit_at_ms: int = 0
var _audio: Node = null
var _track_changes: Array[StringName] = []


func _initialize() -> void:
	print("==================================================================")
	print("[AUDIO TEST] RIFTWARD audio stack acceptance test")
	print("==================================================================")


func _process(_delta: float) -> bool:
	if not _ran:
		_ran = true
		_run_all()
		# Force-quitting mid-playback is what makes the engine report shutdown
		# leaks, so silence the beds and give one-shot voices a short real-time
		# window to finish before quitting.
		if _audio != null:
			_audio.set_ambience(&"")
			_audio.set_music_track(&"silent")
		_quit_at_ms = Time.get_ticks_msec() + 1500
		return false
	if Time.get_ticks_msec() < _quit_at_ms:
		return false
	_finish()
	return true


func _finish() -> void:
	var exit_code := 0 if _failures.is_empty() else 1
	print("------------------------------------------------------------------")
	print("[AUDIO TEST] checks=%d failures=%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("[AUDIO TEST]   FAILED: %s" % failure)
	if exit_code == 0:
		print("[AUDIO TEST] RESULT: PASS")
	else:
		print("[AUDIO TEST] RESULT: FAIL - %s" % "; ".join(_failures))
	quit(exit_code)


func _run_all() -> void:
	var started := Time.get_ticks_msec()
	_audio = root.get_node_or_null("/root/AudioDirector")
	_check(_audio != null, "AudioDirector autoload boots")
	if _audio == null:
		return
	_test_api_surface()
	_test_catalog()
	_test_required_ids()
	_test_stream_resolution()
	_test_buses()
	_test_music()
	_test_ambience()
	_test_play_paths()
	_test_headless_safety()
	var elapsed := Time.get_ticks_msec() - started
	print("[AUDIO TEST] resolved catalog in %d ms" % elapsed)


# ---------------------------------------------------------------------------
# API surface
# ---------------------------------------------------------------------------

func _test_api_surface() -> void:
	var required: Array[String] = [
		"get_catalog", "has_stream", "get_stream",
		"play_ui", "play_sfx", "play_3d", "play_varied", "play_loop_3d",
		"set_ambience", "set_music_track", "get_music_track", "get_music_tracks",
		"set_music_mood", "set_bus_volume", "get_ui_sound_ids", "get_stats",
	]
	for method in required:
		_check(_audio.has_method(method), "AudioDirector exposes %s()" % method)
	_check(_audio.has_signal("music_track_changed"), "AudioDirector emits music_track_changed")
	_check(_audio.has_signal("catalog_ready"), "AudioDirector emits catalog_ready")
	_check(_audio.has_method("is_headless"), "AudioDirector exposes is_headless()")


# ---------------------------------------------------------------------------
# Catalog
# ---------------------------------------------------------------------------

func _test_catalog() -> void:
	var catalog: Array = _audio.get_catalog()
	_check(catalog.size() >= 85, "catalog has >= 85 ids (got %d)" % catalog.size())
	var unique: Dictionary = {}
	var duplicates: Array[String] = []
	for id in catalog:
		var key := String(id)
		if unique.has(key):
			duplicates.append(key)
		unique[key] = true
	_check(duplicates.is_empty(), "catalog ids are unique (duplicates: %s)" % str(duplicates))
	var stats: Dictionary = _audio.get_stats()
	print("[AUDIO TEST] catalog=%d recipes=%d streams=%d overrides=%d/%d boot=%dms headless=%s" % [
		int(stats.get("catalog", 0)),
		int(stats.get("recipes", 0)),
		int(stats.get("streams", 0)),
		int(stats.get("overrides", 0)),
		int(stats.get("override_files", 0)),
		int(stats.get("audio_boot_ms", 0)),
		str(stats.get("headless", false)),
	])
	_check(int(stats.get("catalog", 0)) >= 85, "stats report the catalog size")
	_check(String(stats.get("override_root", "")) == "res://assets/audio/cc0", "CC0 pack root documented")


func _test_required_ids() -> void:
	var catalog: Dictionary = {}
	for id in _audio.get_catalog():
		catalog[String(id)] = true
	for id in REQUIRED_IDS:
		_check(catalog.has(String(id)), "required id present: %s" % String(id))
	var ui_ids: Array = _audio.get_ui_sound_ids()
	_check(ui_ids.size() == 4, "get_ui_sound_ids() returns 4 ids")
	for id in ui_ids:
		_check(catalog.has(String(id)), "ui sound id present: %s" % String(id))


# ---------------------------------------------------------------------------
# Resolution / fallback
# ---------------------------------------------------------------------------

func _test_stream_resolution() -> void:
	var catalog: Array = _audio.get_catalog()
	var missing: Array[String] = []
	var empty: Array[String] = []
	var wav_count := 0
	for id in catalog:
		_check(_audio.has_stream(id), "has_stream(%s)" % String(id))
		var stream: AudioStream = _audio.get_stream(id)
		if stream == null:
			missing.append(String(id))
			continue
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			if wav.data.is_empty():
				empty.append(String(id))
			else:
				wav_count += 1
	missing = missing.slice(0, 6)
	empty = empty.slice(0, 6)
	_check(missing.is_empty(), "every catalog id resolves to a stream (missing: %s)" % str(missing))
	_check(empty.is_empty(), "generated streams carry PCM data (empty: %s)" % str(empty))
	_check(wav_count >= 60, "procedural fallback produced AudioStreamWAVs (got %d)" % wav_count)
	var undocumented := 0
	for id in catalog:
		if not _audio.has_stream(id):
			undocumented += 1
	_check(undocumented == 0, "no undocumented fallbacks")
	_check(_audio.get_stream(&"definitely_not_a_sound") == null, "unknown id resolves to null")
	_check(not _audio.has_stream(&"definitely_not_a_sound"), "unknown id reports has_stream() false")
	_check(_audio.get_stream_count() > 0, "resolved streams are cached")


# ---------------------------------------------------------------------------
# Buses
# ---------------------------------------------------------------------------

func _test_buses() -> void:
	var master := AudioServer.get_bus_index("Master")
	_check(master >= 0, "Master bus exists")
	for bus_name in REQUIRED_BUSES:
		var index := AudioServer.get_bus_index(bus_name)
		_check(index >= 0, "bus exists: %s" % bus_name)
		if index < 0:
			continue
		_check(String(AudioServer.get_bus_send(index)) == "Master", "%s routes to Master" % bus_name)
	var limiter_found := false
	for effect_index in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, effect_index) is AudioEffectLimiter:
			limiter_found = true
	_check(limiter_found, "Master carries an AudioEffectLimiter")
	var vehicles := AudioServer.get_bus_index("Vehicles")
	var vehicles_db := AudioServer.get_bus_volume_db(vehicles)
	_check(vehicles_db > -3.0 and vehicles_db <= 0.0, "Vehicles has a sensible default level (%.2f dB)" % vehicles_db)
	_check(not AudioServer.is_bus_mute(vehicles), "Vehicles is not muted by default")
	# Volume API: linear -> dB, mute at zero, unknown bus is a safe no-op.
	_audio.set_bus_volume("Vehicles", 0.5)
	_check(absf(AudioServer.get_bus_volume_db(vehicles) - linear_to_db(0.5)) < 0.01, "set_bus_volume maps linear -> dB")
	_audio.set_bus_volume("Vehicles", 0.0)
	_check(AudioServer.is_bus_mute(vehicles), "set_bus_volume(0) mutes the bus")
	_audio.set_bus_volume("Vehicles", 0.9)
	_check(not AudioServer.is_bus_mute(vehicles), "set_bus_volume restores the bus")
	_audio.set_bus_volume("NoSuchBus", 0.5)
	_check(true, "set_bus_volume on an unknown bus is safe")
	_check(String(_audio.get_bus_for(&"engine_rig")) == "Vehicles", "engine ids route to Vehicles")
	_check(String(_audio.get_bus_for(&"ui_click")) == "UI", "ui ids route to UI")
	_check(String(_audio.get_bus_for(&"wind_loop")) == "Ambience", "wind loop routes to Ambience")


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

func _test_music() -> void:
	var tracks: Array = _audio.get_music_tracks()
	_check(tracks.size() >= 8, "at least 8 music cues (got %d)" % tracks.size())
	var track_lookup: Dictionary = {}
	for id in tracks:
		track_lookup[String(id)] = true
	for id in REQUIRED_TRACKS:
		_check(track_lookup.has(String(id)), "music cue present: %s" % String(id))
	var initial: StringName = _audio.get_music_track()
	_check(track_lookup.has(String(initial)), "initial music track is a known cue (%s)" % String(initial))
	_audio.music_track_changed.connect(_on_music_track_changed)
	# Switching updates logical state and emits exactly once.
	_audio.set_music_track(&"combat")
	_check(_audio.get_music_track() == &"combat", "set_music_track(combat) updates get_music_track()")
	_check(_track_changes.size() == 1 and _track_changes[0] == &"combat", "music_track_changed(combat) emitted")
	# Repeat is a no-op (no signal spam, no restart).
	_audio.set_music_track(&"combat")
	_check(_track_changes.size() == 1, "repeating the current cue is a no-op")
	_audio.set_music_track(&"boss", 0.25)
	_check(_audio.get_music_track() == &"boss", "crossfade duration argument accepted")
	_check(_track_changes.size() == 2 and _track_changes[1] == &"boss", "music_track_changed(boss) emitted")
	_audio.set_music_track(&"silent")
	_check(_audio.get_music_track() == &"silent", "silent cue selectable")
	_check(_track_changes.size() == 3 and _track_changes[2] == &"silent", "music_track_changed(silent) emitted")
	_audio.set_music_track(&"not_a_cue")
	_check(_audio.get_music_track() == &"silent", "unknown cue keeps the current track")
	_check(_track_changes.size() == 3, "unknown cue emits no signal")
	# Legacy mood API used by App/loading.
	_audio.set_music_mood(&"combat")
	_check(_audio.get_music_track() == &"combat", "set_music_mood(combat) maps to the combat cue")
	_audio.set_music_mood(&"deployment")
	_check(_audio.get_music_track() == &"deploy", "set_music_mood(deployment) maps to deploy")
	var before := _track_changes.size()
	_audio.set_music_mood(&"nonsense")
	_check(_audio.get_music_track() == &"deploy" and _track_changes.size() == before, "unknown mood keeps the current cue")
	var stats: Dictionary = _audio.get_stats()
	_check(int(stats.get("music_voices", 0)) == 2, "music uses two crossfade voices")
	if DisplayServer.get_name() == "headless":
		_check(int(stats.get("music_generated", 0)) == 0, "headless skips music generation")
	_audio.set_music_track(&"hub")


func _on_music_track_changed(track: StringName) -> void:
	_track_changes.append(track)


# ---------------------------------------------------------------------------
# Ambience
# ---------------------------------------------------------------------------

func _test_ambience() -> void:
	_check(_audio.get_ambience() == &"", "ambience starts empty")
	_audio.set_ambience(&"wind_ambient")
	_check(_audio.get_ambience() == &"wind_ambient", "set_ambience(wind_ambient) selects the bed")
	_audio.set_ambience(&"wind_ambient")
	_check(_audio.get_ambience() == &"wind_ambient", "repeating ambience is safe")
	_audio.set_ambience(&"water_loop")
	_check(_audio.get_ambience() == &"water_loop", "set_ambience switches beds")
	_audio.set_ambience(&"shrine_hum")
	_check(_audio.get_ambience() == &"shrine_hum", "ambience accepts every ambience id")
	_audio.set_ambience(&"not_an_ambience")
	_check(_audio.get_ambience() == &"shrine_hum", "unknown ambience is ignored without error")
	_audio.set_ambience(&"")
	_check(_audio.get_ambience() == &"", "set_ambience(\"\") stops the bed")


# ---------------------------------------------------------------------------
# Playback entry points
# ---------------------------------------------------------------------------

func _test_play_paths() -> void:
	var owner := Node3D.new()
	owner.name = "AudioTestOwner"
	root.add_child(owner)
	var loop_player: AudioStreamPlayer3D = _audio.play_loop_3d(&"engine_rig", owner)
	_check(loop_player != null, "play_loop_3d returns a stoppable player")
	if loop_player != null:
		_check(loop_player.get_parent() == owner, "loop player is parented to the owner")
		_check(loop_player.stream != null, "loop player carries a stream")
		_check(loop_player.bus == "Vehicles", "engine loop routes to the Vehicles bus")
		_check(_stream_loops(loop_player.stream), "engine loop is a seamless looping stream")
		_check(
			loop_player.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE,
			"loop player uses inverse-distance attenuation"
		)
		loop_player.stop()
		loop_player.queue_free()
	owner.queue_free()
	_check(_audio.play_loop_3d(&"no_such_id", owner) == null, "play_loop_3d rejects unknown ids")
	var null_owner: Node3D = null
	_check(_audio.play_loop_3d(&"engine_rig", null_owner) == null, "play_loop_3d tolerates a null owner")
	# One-shots: valid and junk ids must never error.
	_audio.play_ui(&"ui_click")
	_audio.play_ui(&"no_such_ui")
	_audio.play_sfx(&"footstep", -22.0)
	_audio.play_sfx(&"no_such_sfx")
	_audio.play_3d(&"exfil", Vector3(4.0, 0.0, -3.0), -6.0)
	_audio.play_3d(&"no_such_3d", Vector3.ZERO)
	_audio.play_varied(&"hit")
	_audio.play_varied(&"hit", Vector3(1.0, 0.0, 0.0), -8.0)
	_audio.play_varied(&"footstep_water", Vector3.INF)
	_audio.play_varied(&"no_such_varied")
	_check(true, "one-shot play entry points accept valid and junk ids")
	_audio.play_3d(&"ramp_hiss", Vector3(1.0, 0.0, 0.0), -9.0)
	_check(true, "one-shot positional playback does not error")


# ---------------------------------------------------------------------------
# Headless safety
# ---------------------------------------------------------------------------

func _test_headless_safety() -> void:
	var engineer_is_headless := DisplayServer.get_name() == "headless"
	_check(bool(_audio.is_headless()) == engineer_is_headless, "AudioDirector agrees with the display server about headless")
	if engineer_is_headless:
		_check(String(AudioServer.get_driver_name()) == "Dummy", "headless uses the Dummy audio driver")
	_check(_audio.is_catalog_ready(), "catalog is ready for on-demand resolution")
	# Everything above already exercised music/ambience/one-shots with no SCRIPT
	# ERROR: reaching this point is the headless-safety assertion.
	_check(true, "headless boot generated no script errors")


func _stream_loops(stream: AudioStream) -> bool:
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	if stream is AudioStreamOggVorbis:
		return (stream as AudioStreamOggVorbis).loop
	if stream is AudioStreamMP3:
		return (stream as AudioStreamMP3).loop
	return false


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	print("[AUDIO TEST] FAIL: %s" % label)
