extends Node
## RIFTWARD audio facade. Keeps the game 100 % procedural / license-clean while
## exposing one small, stable API to gameplay and UI code.
##
## Responsibilities split across `features/audio/`:
##   sfx_catalog.gd  - recipe table + PCM synth for ~113 SFX ids
##   music_director.gd - nine procedural cues, two-player crossfade, worker gen
##   audio_packs.gd  - optional CC0 overrides under res://assets/audio/cc0/**
##
## This script owns: the bus layout (Music, SFX, UI, Ambience, Vehicles + limiter
## on Master), the 2D/3D one-shot player pools, the ambience bed, volume routing,
## and the public API every other system calls:
##   get_catalog(), has_stream(), get_stream()
##   play_ui(), play_sfx(), play_3d(), play_varied(), play_loop_3d()
##   set_ambience(), set_music_track(), get_music_track(), set_music_mood()
##   set_bus_volume(), get_ui_sound_ids()
##   signal music_track_changed(track)
##
## Boot budget: SFX sample generation runs on WorkerThreadPool tasks (split by
## authored duration), so the first frame only pays for bus/pool setup. If a sound
## is requested before its batch lands, it is synthesized once on demand (small,
## bounded) and the batch merge keeps the first instance. Headless skips the
## background batches and all music generation; ids still resolve on demand and
## logical music/ambience state stays testable.

signal music_track_changed(track: StringName)
signal catalog_ready()

const SfxCatalogScript := preload("res://features/audio/sfx_catalog.gd")
const MusicDirectorScript := preload("res://features/audio/music_director.gd")
const AudioPacksScript := preload("res://features/audio/audio_packs.gd")

const POOL_2D := 10
const POOL_3D := 20
const BUS_NAMES: Array[String] = ["Music", "SFX", "UI", "Ambience", "Vehicles"]
const DEFAULT_FADE := 1.6
const AMBIENCE_VOLUME_DB := -13.0
const VEHICLE_DEFAULT_LINEAR := 0.9
const UI_IDS: Array[StringName] = [&"ui_click", &"ui_hover", &"ui_confirm", &"ui_error"]
## Legacy mood vocabulary (App/loading still call set_music_mood) -> music cue.
const MOOD_TRACKS := {
	&"menu": &"menu",
	&"hub": &"hub",
	&"deployment": &"deploy",
	&"deploy": &"deploy",
	&"combat": &"combat",
	&"boss": &"boss",
	&"exfil": &"exfil",
	&"storm": &"storm",
	&"results": &"results",
	&"silent": &"silent",
}

# --- Internal state ---------------------------------------------------------
var _catalog: RefCounted = null
var _packs: RefCounted = null
var _music: Node = null
var _streams: Dictionary = {}
var _catalog_ids: Array[StringName] = []
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
## Loop handles handed out by play_loop_3d (owned by gameplay nodes, not by us).
var _loop_players: Array[AudioStreamPlayer3D] = []
var _next_2d: int = 0
var _next_3d: int = 0
var _ambience_player: AudioStreamPlayer = null
var _ambience_id: StringName = &""
var _ambience_tween: Tween = null
var _varied_rng := RandomNumberGenerator.new()
var _jobs: Array[Dictionary] = []
var _job_workers: Array = []
var _catalog_ready: bool = false
var _headless: bool = false
var _shutting_down: bool = false
var _boot_ms: int = 0


func _ready() -> void:
	var start := Time.get_ticks_msec()
	_headless = DisplayServer.get_name() == "headless"
	_varied_rng.seed = 0x5EED2026
	_ensure_buses()
	_catalog = SfxCatalogScript.new()
	_packs = AudioPacksScript.new()
	_packs.setup(_catalog.recipe_ids())
	_packs.scan()
	_rebuild_catalog_ids()
	_build_pools()
	_build_ambience_player()
	_music = MusicDirectorScript.new()
	_music.name = "MusicDirector"
	add_child(_music)
	_music.track_changed.connect(_on_music_track_changed)
	_music.set_track(&"menu")
	if _headless:
		_catalog_ready = true
	else:
		_start_catalog_generation()
	_boot_ms = Time.get_ticks_msec() - start
	set_process(not _headless)


## Explicit teardown. Headless suites and `--quit-after` runs can quit with
## one-shots or a music cue still playing. In Godot 4.7 `AudioStreamPlayer.stop()`
## only marks the server playback FADE_OUT_TO_DELETION; the audio thread's next
## `_mix_step` erases it. Quitting in the same frame therefore leaves a leaked
## playback (and, for imported OGG cues, an OggPacketSequence "still in use").
## So: stop every voice, give the audio thread a bounded window to flush, then
## detach and free. All stream caches drop last.
const TEARDOWN_FLUSH_MS := 60

func _exit_tree() -> void:
	_teardown()


## Terminal graceful shutdown for tools/tests that must quit cleanly before the
## engine tears the scene tree down. After this call the audio system is off.
func shutdown() -> void:
	_teardown()


func _teardown() -> void:
	_shutting_down = true
	_kill_ambience_tween()
	_wait_for_jobs()
	for player in _pool_2d:
		_silence_2d_player(player, false)
	for player in _pool_3d:
		_silence_3d_player(player, false)
	if _ambience_player != null and is_instance_valid(_ambience_player):
		_ambience_player.stop()
	if _music != null and is_instance_valid(_music) and _music.has_method("stop_voices"):
		_music.call("stop_voices")
	# Loop handles live under gameplay nodes that may be freed after this autoload;
	# stopping their playbacks now lets the same flush window cover them.
	for handle in _loop_players:
		if handle != null and is_instance_valid(handle):
			handle.stop()
	# Let the audio thread run at least one mix step so stopped playbacks are
	# erased before the engine tears the server down.
	OS.delay_msec(TEARDOWN_FLUSH_MS)
	_loop_players.clear()
	for player in _pool_2d:
		_silence_2d_player(player, true)
	for player in _pool_3d:
		_silence_3d_player(player, true)
	_pool_2d.clear()
	_pool_3d.clear()
	if _ambience_player != null:
		if is_instance_valid(_ambience_player):
			_ambience_player.stream = null
			_ambience_player.free()
		_ambience_player = null
	if _music != null and is_instance_valid(_music):
		if _music.has_method("stop_all"):
			_music.call("stop_all")
	_streams.clear()
	_ambience_id = &""
	if _packs != null:
		_packs.clear()


func _silence_2d_player(player: AudioStreamPlayer, p_free: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.stop()
	if p_free:
		player.stream = null
		player.free()


func _silence_3d_player(player: AudioStreamPlayer3D, p_free: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.stop()
	if p_free:
		player.stream = null
		player.free()


func _wait_for_jobs() -> void:
	for job in _jobs:
		var task_id := int(job["task"])
		if not WorkerThreadPool.is_task_completed(task_id):
			WorkerThreadPool.wait_for_task_completion(task_id)
	_jobs.clear()
	_job_workers.clear()


## Rejects playback once the autoload has left the tree or teardown has started.
func _can_play() -> bool:
	return not _shutting_down and is_inside_tree()


func _process(_delta: float) -> void:
	if _jobs.is_empty():
		set_process(false)
		return
	var index := 0
	while index < _jobs.size():
		var job: Dictionary = _jobs[index]
		var task_id: int = int(job["task"])
		if not WorkerThreadPool.is_task_completed(task_id):
			index += 1
			continue
		WorkerThreadPool.wait_for_task_completion(task_id)
		var out: Dictionary = job["out"]
		_merge_batch(out)
		_jobs.remove_at(index)
		_job_workers.remove_at(index)
		if _jobs.is_empty() and not _catalog_ready:
			_catalog_ready = true
			catalog_ready.emit()
	if _jobs.is_empty():
		set_process(false)


# ---------------------------------------------------------------------------
# Public API - catalog and streams
# ---------------------------------------------------------------------------

## Every logical id (procedural recipes plus CC0-only ids), sorted.
func get_catalog() -> Array[StringName]:
	return _catalog_ids.duplicate()


## True when the id resolves to a procedural recipe or a CC0 pack override.
## (Cheap: does not synthesize or load anything.)
func has_stream(id: StringName) -> bool:
	if _catalog != null and _catalog.has_recipe(id):
		return true
	return _packs != null and _packs.has_override(id)


## Resolved AudioStream for an id, or null when unknown. CC0 overrides win over
## the procedural synth; a missing pack file silently falls back to the synth.
## May synthesize a missing SFX synchronously the first time (bounded cost).
func get_stream(id: StringName) -> AudioStream:
	return _resolve_stream(id)


## Logical bus for an id: Music/SFX/UI/Ambience/Vehicles (recipe authored).
func get_bus_for(id: StringName) -> String:
	if _catalog != null:
		return _catalog.bus_for(id)
	return "SFX"


## How many streams are cached right now (diagnostics).
func get_stream_count() -> int:
	return _streams.size()


## True once the background SFX batch has finished (always true when headless,
## where ids are resolved on demand instead).
func is_catalog_ready() -> bool:
	return _catalog_ready


## One-shot UI sound. Always routes to the UI bus so the UI volume slider owns it.
func play_ui(id: StringName, volume_db: float = 0.0) -> void:
	if not _can_play():
		return
	var stream := _resolve_stream(id)
	if stream == null:
		return
	_play_2d(stream, "UI", volume_db, 1.0)


## One-shot sound on the id's authored bus (SFX unless the recipe says otherwise).
func play_sfx(id: StringName, volume_db: float = -3.0) -> void:
	if not _can_play():
		return
	var stream := _resolve_stream(id)
	if stream == null:
		return
	_play_2d(stream, get_bus_for(id), volume_db, 1.0)


## One-shot positional sound at `world_position`.
func play_3d(id: StringName, world_position: Vector3, volume_db: float = -3.0) -> void:
	if not _can_play():
		return
	var stream := _resolve_stream(id)
	if stream == null:
		return
	_play_3d(stream, get_bus_for(id), world_position, volume_db, 1.0)


## One-shot with deterministic pitch/volume jitter so repeated events (gunfire,
## footsteps, impacts) do not sound machine-gunned. Pass Vector3.INF (default)
## for a 2D sound, or a world position for a positional one.
func play_varied(id: StringName, world_position: Vector3 = Vector3.INF, volume_db: float = -3.0) -> void:
	if not _can_play():
		return
	var stream := _resolve_stream(id)
	if stream == null:
		return
	var pitch := _varied_rng.randf_range(0.94, 1.06)
	var jitter_db := _varied_rng.randf_range(-1.5, 0.5)
	var bus := get_bus_for(id)
	if world_position == Vector3.INF:
		_play_2d(stream, bus, volume_db + jitter_db, pitch)
	else:
		_play_3d(stream, bus, world_position, volume_db + jitter_db, pitch)


## Starts a looping positional stream parented to `node` (engines, hoists, fires).
## Returns the player so callers can stop()/queue_free() it, or null when the id
## is unknown. The player follows the node automatically.
func play_loop_3d(id: StringName, node: Node3D) -> AudioStreamPlayer3D:
	if not _can_play():
		return null
	if node == null or not is_instance_valid(node):
		return null
	var stream := _resolve_stream(id)
	if stream == null:
		return null
	var player := AudioStreamPlayer3D.new()
	player.name = "Loop3D_%s" % String(id)
	player.bus = get_bus_for(id)
	player.stream = stream
	player.max_distance = 70.0
	player.unit_size = 10.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	node.add_child(player)
	if node.is_inside_tree():
		player.play()
	else:
		# Starts automatically once the owner enters the scene tree.
		player.autoplay = true
	_prune_loop_handles()
	_loop_players.append(player)
	return player


## Drops handles whose owner node was freed so the tracking array cannot grow.
func _prune_loop_handles() -> void:
	var live: Array[AudioStreamPlayer3D] = []
	for handle in _loop_players:
		if handle != null and is_instance_valid(handle):
			live.append(handle)
	_loop_players = live


# ---------------------------------------------------------------------------
# Public API - ambience
# ---------------------------------------------------------------------------

## Crossfades the looping ambience bed to `id` ("" stops it). Safe when headless;
## unknown ids are ignored and the current bed keeps playing.
func set_ambience(id: StringName) -> void:
	if not _can_play():
		return
	var key := StringName(id)
	if key == &"":
		_ambience_id = &""
		if not _headless:
			_stop_ambience(0.5)
		return
	if not has_stream(key):
		return
	if key == _ambience_id:
		return
	if _headless:
		_ambience_id = key
		return
	var stream := _resolve_stream(key)
	if stream == null:
		return
	_ambience_id = key
	_start_ambience(stream)


## Current ambience id ("" when none). Logical state, valid on headless.
func get_ambience() -> StringName:
	return _ambience_id


# ---------------------------------------------------------------------------
# Public API - music
# ---------------------------------------------------------------------------

## Crossfades to a music cue. Repeating the current cue is a no-op (no signal).
func set_music_track(track: StringName, fade: float = DEFAULT_FADE) -> void:
	if _music == null or not _can_play():
		return
	_music.set_track(track, fade)


## Current music cue id (logical state, valid on headless).
func get_music_track() -> StringName:
	if _music == null:
		return &"silent"
	return _music.get_track()


## Authored cue ids: menu, hub, deploy, combat, boss, exfil, storm, results, silent.
func get_music_tracks() -> Array[StringName]:
	if _music == null:
		return []
	return _music.track_ids()


## Legacy mood API kept for App/loading code: maps moods onto cues.
func set_music_mood(mood: StringName) -> void:
	if not MOOD_TRACKS.has(mood):
		return
	set_music_track(MOOD_TRACKS[mood])


## Legacy volume API: linear 0..1 -> bus dB, with mute at (almost) zero.
func set_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0, 1.0)))
	AudioServer.set_bus_mute(index, linear <= 0.001)


## Legacy UI id list (all four resolve in the catalog).
func get_ui_sound_ids() -> Array:
	return UI_IDS.duplicate()


## Diagnostics snapshot for tests and the debug overlay.
func get_stats() -> Dictionary:
	return {
		"catalog": _catalog_ids.size(),
		"recipes": _catalog.recipe_ids().size() if _catalog != null else 0,
		"streams": _streams.size(),
		"overrides": _packs.get_mapped_count() if _packs != null else 0,
		"override_files": _packs.get_file_count() if _packs != null else 0,
		"override_root": AudioPacksScript.ROOT,
		"music_tracks": get_music_tracks().size(),
		"music_generated": _music.get_cached_count() if _music != null else 0,
		"music_voices": _music.get_voice_count() if _music != null else 0,
		"track": String(get_music_track()),
		"ambience": String(_ambience_id),
		"vehicles_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Vehicles")),
		"headless": _headless,
		"catalog_ready": _catalog_ready,
		"audio_boot_ms": _boot_ms,
		"synth_jobs": _jobs.size(),
	}


## True when running the headless audio driver (music/ambience playback skipped).
func is_headless() -> bool:
	return _headless


# ---------------------------------------------------------------------------
# Bus setup
# ---------------------------------------------------------------------------

func _ensure_buses() -> void:
	for bus_name in BUS_NAMES:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
	_ensure_master_limiter(AudioServer.get_bus_index("Master"))
	# Vehicles is not exposed in the settings panel; give it a musical default.
	set_bus_volume("Vehicles", VEHICLE_DEFAULT_LINEAR)


func _ensure_master_limiter(master: int) -> void:
	if master < 0:
		return
	for effect_index in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, effect_index) is AudioEffectLimiter:
			return
	var limiter := AudioEffectLimiter.new()
	limiter.threshold_db = -3.0
	limiter.ceiling_db = -0.3
	limiter.soft_clip_db = -1.5
	limiter.soft_clip_ratio = 2.0
	AudioServer.add_bus_effect(master, limiter)


# ---------------------------------------------------------------------------
# Pools
# ---------------------------------------------------------------------------

func _build_pools() -> void:
	for i in POOL_2D:
		var player := AudioStreamPlayer.new()
		player.name = "SFX2D_%d" % i
		player.bus = "SFX"
		add_child(player)
		_pool_2d.append(player)
	for i in POOL_3D:
		var player := AudioStreamPlayer3D.new()
		player.name = "SFX3D_%d" % i
		player.bus = "SFX"
		player.max_distance = 90.0
		player.unit_size = 10.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		_pool_3d.append(player)


func _build_ambience_player() -> void:
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbienceBed"
	_ambience_player.bus = "Ambience"
	_ambience_player.volume_db = AMBIENCE_VOLUME_DB
	add_child(_ambience_player)


func _play_2d(stream: AudioStream, bus: String, volume_db: float, pitch: float) -> void:
	if _pool_2d.is_empty() or not _can_play():
		return
	var player := _pool_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _pool_2d.size()
	player.bus = bus
	player.stream = stream
	player.volume_db = clampf(volume_db, -60.0, 6.0)
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.play()


func _play_3d(stream: AudioStream, bus: String, world_position: Vector3, volume_db: float, pitch: float) -> void:
	if _pool_3d.is_empty() or not _can_play():
		return
	var player := _pool_3d[_next_3d]
	_next_3d = (_next_3d + 1) % _pool_3d.size()
	player.bus = bus
	player.global_position = world_position
	player.stream = stream
	player.volume_db = clampf(volume_db, -60.0, 6.0)
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.play()


# ---------------------------------------------------------------------------
# Ambience internals
# ---------------------------------------------------------------------------

func _start_ambience(stream: AudioStream) -> void:
	_kill_ambience_tween()
	if _ambience_player != null and _ambience_player.playing:
		var fade_out := create_tween()
		fade_out.tween_property(_ambience_player, "volume_db", -60.0, 0.45)
		fade_out.tween_callback(Callable(self, "_start_ambience_stream").bind(stream))
		_ambience_tween = fade_out
	else:
		_start_ambience_stream(stream)


func _start_ambience_stream(stream: AudioStream) -> void:
	if _ambience_player == null:
		return
	_ambience_player.stream = stream
	_ambience_player.volume_db = -60.0
	_ambience_player.play()
	_kill_ambience_tween()
	var fade_in := create_tween()
	fade_in.tween_property(_ambience_player, "volume_db", AMBIENCE_VOLUME_DB, 0.6).set_trans(Tween.TRANS_SINE)
	_ambience_tween = fade_in


func _stop_ambience(fade: float) -> void:
	_kill_ambience_tween()
	if _ambience_player == null or not _ambience_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(_ambience_player, "volume_db", -60.0, maxf(fade, 0.05))
	tween.tween_callback(_ambience_player.stop)
	_ambience_tween = tween


func _kill_ambience_tween() -> void:
	if _ambience_tween != null and _ambience_tween.is_valid():
		_ambience_tween.kill()
	_ambience_tween = null


# ---------------------------------------------------------------------------
# Music bridge
# ---------------------------------------------------------------------------

func _on_music_track_changed(track: StringName) -> void:
	music_track_changed.emit(track)


# ---------------------------------------------------------------------------
# Stream resolution and synthesis
# ---------------------------------------------------------------------------

func _resolve_stream(id: StringName) -> AudioStream:
	var key := String(id)
	var cached: Variant = _streams.get(key, null)
	if cached != null:
		return cached as AudioStream
	if _packs != null:
		var override_stream: AudioStream = _packs.resolve(id)
		if override_stream != null:
			override_stream = _apply_loop_mode(id, override_stream)
			_streams[key] = override_stream
			return override_stream
	if _catalog != null and _catalog.has_recipe(id):
		var info: Dictionary = _catalog.render_info(id)
		if not info.is_empty():
			var stream := _make_stream(info)
			if stream != null:
				_streams[key] = stream
				return stream
	return null


func _make_stream(info: Dictionary) -> AudioStreamWAV:
	var data: PackedByteArray = info.get("data", PackedByteArray())
	if data.is_empty():
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(info.get("rate", SfxCatalogScript.SAMPLE_RATE))
	stream.stereo = false
	stream.data = data
	if bool(info.get("loop", false)):
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(info.get("count", data.size() / 2))
	return stream


## CC0 pack files are single-shot samples; loop ids (engines, ambience beds) need
## the whole file repeated. Duplicate the imported resource so the shared import
## cache is not mutated.
func _apply_loop_mode(id: StringName, stream: AudioStream) -> AudioStream:
	if _catalog == null or not _catalog.is_loop(id):
		return stream
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_FORWARD:
			return stream
		var wav_copy := wav.duplicate() as AudioStreamWAV
		wav_copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav_copy.loop_begin = 0
		wav_copy.loop_end = maxi(1, int(wav_copy.get_length() * float(wav_copy.mix_rate)))
		return wav_copy
	if stream is AudioStreamOggVorbis:
		var ogg := stream as AudioStreamOggVorbis
		if ogg.loop:
			return stream
		var ogg_copy := ogg.duplicate() as AudioStreamOggVorbis
		ogg_copy.loop = true
		ogg_copy.loop_offset = 0.0
		return ogg_copy
	if stream is AudioStreamMP3:
		var mp3 := stream as AudioStreamMP3
		if mp3.loop:
			return stream
		var mp3_copy := mp3.duplicate() as AudioStreamMP3
		mp3_copy.loop = true
		mp3_copy.loop_offset = 0.0
		return mp3_copy
	return stream


func _rebuild_catalog_ids() -> void:
	var seen: Dictionary = {}
	_catalog_ids.clear()
	if _catalog != null:
		for id in _catalog.recipe_ids():
			seen[id] = true
			_catalog_ids.append(id)
	if _packs != null:
		for id in _packs.get_override_ids():
			if seen.has(id):
				continue
			seen[id] = true
			_catalog_ids.append(id)
	_catalog_ids.sort()


func _start_catalog_generation() -> void:
	if _catalog == null:
		return
	var sorted: Array = []
	for id in _catalog.recipe_ids():
		sorted.append({"id": id, "dur": _catalog.duration_for(id)})
	sorted.sort_custom(_sort_by_duration)
	var task_count := clampi(OS.get_processor_count() - 1, 2, 4)
	var buckets: Array = []
	for i in task_count:
		buckets.append({"ids": [], "load": 0.0})
	for entry in sorted:
		var target := 0
		for i in range(1, buckets.size()):
			if float(buckets[i]["load"]) < float(buckets[target]["load"]):
				target = i
		var bucket: Dictionary = buckets[target]
		(bucket["ids"] as Array).append(entry["id"])
		bucket["load"] = float(bucket["load"]) + float(entry["dur"])
	for bucket in buckets:
		var ids: Array = bucket["ids"]
		if ids.is_empty():
			continue
		var worker := SfxCatalogScript.new()
		var out := {}
		var task_id := WorkerThreadPool.add_task(
			Callable(worker, "build_batch").bind(ids, out),
			false,
			"sfx synth batch"
		)
		_jobs.append({"task": task_id, "out": out})
		_job_workers.append(worker)


func _sort_by_duration(a: Dictionary, b: Dictionary) -> bool:
	return float(a["dur"]) > float(b["dur"])


func _merge_batch(out: Dictionary) -> void:
	for key in out.keys():
		var id := String(key)
		if _streams.has(id):
			continue
		var info: Dictionary = out[key]
		if info.is_empty():
			continue
		var stream := _make_stream(info)
		if stream != null:
			_streams[id] = stream
