extends Node
## Procedural music cues and the two-player crossfade for AudioDirector.
##
## Owns nine tracks (menu, hub, deploy, combat, boss, exfil, storm, results,
## silent). Each generated track is an 8-16 s seamless mono loop built from four
## layered stems - pad chords, bass, pulse arpeggio and percussion - plus an
## optional noise texture for storm/dungeon spaces. Generation runs on a
## WorkerThreadPool task (`MusicSynth` is a stateless RefCounted) and only ever
## happens when a track is first requested (or prewarmed), so boot and the first
## frame never hitch. Headless runs skip generation entirely; logical track
## state and the `track_changed` signal still work so tests are deterministic.
##
## The crossfade uses two AudioStreamPlayers on the Music bus. A switch fades the
## outgoing player down while the incoming player ramps to the track's authored
## mix level; `fade` is the tween duration in seconds.

signal track_changed(track: StringName)

const DEFAULT_FADE := 1.6
const SILENT := &"silent"
const SILENCE_DB := -60.0

# --- Internal state ---------------------------------------------------------
var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _current: StringName = &""
var _cache: Dictionary = {}
var _tweens: Array[Tween] = []
var _last_fade: float = DEFAULT_FADE
var _task_id: int = -1
var _task_track: StringName = &""
var _task_out: Dictionary = {}
var _synth: MusicSynth = null
var _meta: MusicSynth = null
var _failed: Dictionary = {}
var _headless: bool = false


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_meta = MusicSynth.new()
	_build_players()
	if _headless:
		return
	# Warm the menu cue so the first set_track(&"menu") is (nearly) free.
	_begin(&"menu")


func _process(_delta: float) -> void:
	if _task_id < 0:
		set_process(false)
		return
	if not WorkerThreadPool.is_task_completed(_task_id):
		return
	WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1
	var track := _task_track
	var info: Dictionary = _task_out.get("info", {})
	_synth = null
	_task_out = {}
	if info.is_empty():
		_failed[String(track)] = true
	else:
		_cache[String(track)] = _make_stream(info)
		if _current == track:
			_start(track, _last_fade)
	# Serve whatever the game asked for while the worker was busy.
	if _current != &"" and not _cache.has(String(_current)) and not _failed.has(String(_current)) and _current != SILENT:
		_begin(_current)
	if _task_id < 0:
		set_process(false)


func _build_players() -> void:
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "MusicVoice%d" % i
		player.bus = "Music"
		player.volume_db = SILENCE_DB
		add_child(player)
		_players.append(player)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Logical track ids, in UI order. `silent` is a valid id that fades everything.
func track_ids() -> Array[StringName]:
	return _meta.track_ids()


## True when the id is an authored cue.
func has_track(track: StringName) -> bool:
	return _meta.has_track(track)


## Switches cue, crossfading over `fade` seconds. Repeating the current id is a
## no-op (no signal, no restart). Unknown ids are ignored; `silent` fades out.
func set_track(track: StringName, fade: float = DEFAULT_FADE) -> void:
	if not _meta.has_track(track):
		return
	if track == _current:
		return
	_last_fade = maxf(fade, 0.05)
	_current = track
	track_changed.emit(track)
	if _headless:
		return
	if track == SILENT:
		_fade_out_all(_last_fade)
		return
	var key := String(track)
	if _cache.has(key):
		_start(track, _last_fade)
	elif not _failed.has(key):
		_begin(track)


## Currently selected cue (logical state, valid on headless too).
func get_track() -> StringName:
	return _current


## Authored mix level for a cue in dB (used by the crossfade target).
func get_mix_db(track: StringName) -> float:
	return _meta.mix_db(track)


## How many cues are generated and cached so far (diagnostics/tests).
func get_cached_count() -> int:
	return _cache.size()


## True while a generation task is in flight.
func is_generating() -> bool:
	return _task_id >= 0


## True when a cue has already been generated.
func is_cached(track: StringName) -> bool:
	return _cache.has(String(track))


## Number of crossfade voices (always 2).
func get_voice_count() -> int:
	return _players.size()


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

func _begin(track: StringName) -> void:
	if _headless or _task_id >= 0:
		return
	if _cache.has(String(track)) or _failed.has(String(track)):
		return
	_synth = MusicSynth.new()
	_task_out = {}
	_task_track = track
	_task_id = WorkerThreadPool.add_task(
		Callable(_synth, "build_task").bind(track, _task_out),
		false,
		"music cue %s" % String(track)
	)


func _make_stream(info: Dictionary) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(info.get("rate", MusicSynth.RATE))
	stream.stereo = false
	stream.data = info.get("data", PackedByteArray())
	if bool(info.get("loop", true)):
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(info.get("count", stream.data.size() / 2))
	return stream


# ---------------------------------------------------------------------------
# Playback / crossfade
# ---------------------------------------------------------------------------

func _start(track: StringName, fade: float) -> void:
	var key := String(track)
	if not _cache.has(key):
		return
	_kill_tweens()
	var incoming_index := 1 - _active
	var incoming := _players[incoming_index]
	var outgoing := _players[_active]
	var duration := maxf(fade, 0.05)
	var target_db := get_mix_db(track)
	incoming.stream = _cache[key]
	incoming.volume_db = SILENCE_DB
	incoming.play()
	var fade_in := create_tween()
	fade_in.tween_property(incoming, "volume_db", target_db, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tweens.append(fade_in)
	if outgoing.playing:
		var fade_out := create_tween()
		fade_out.tween_property(outgoing, "volume_db", SILENCE_DB, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fade_out.tween_callback(outgoing.stop)
		_tweens.append(fade_out)
	_active = incoming_index


func _fade_out_all(fade: float) -> void:
	_kill_tweens()
	var duration := maxf(fade, 0.05)
	for player in _players:
		if not player.playing:
			continue
		var tween := create_tween()
		tween.tween_property(player, "volume_db", SILENCE_DB, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(player.stop)
		_tweens.append(tween)


func _kill_tweens() -> void:
	for tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()


## Stops both voices but keeps the player nodes alive. AudioDirector calls this
## first in its teardown so the audio thread can flush the stopped playbacks
## before the voices are freed.
func stop_voices() -> void:
	_kill_tweens()
	for player in _players:
		if player == null or not is_instance_valid(player):
			continue
		player.stop()


## Frees the voice nodes and drops all cached cue streams. Called by
## AudioDirector's teardown (and on exit) so force-quit suites never leave a
## playback or an AudioStreamPlayer alive.
func stop_all() -> void:
	stop_voices()
	for player in _players:
		if player != null and is_instance_valid(player):
			player.stream = null
			player.free()
	_players.clear()
	_cache.clear()
	_failed.clear()
	_current = &""
	set_process(false)


func _exit_tree() -> void:
	if _task_id >= 0:
		if not WorkerThreadPool.is_task_completed(_task_id):
			WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		_synth = null
		_task_out = {}
	# Stop only: AudioDirector's teardown frees the voices after its flush window.
	stop_voices()


# ---------------------------------------------------------------------------
# Synth. Stateless RefCounted: one instance per WorkerThreadPool task, so no
# scene tree, resource or AudioServer access happens off the main thread.
# ---------------------------------------------------------------------------

class MusicSynth extends RefCounted:
	const RATE := 16000
	## Loop-seam crossfade: the rendered tail of the pad is folded into the head.
	const WRAP_SEC := 0.6
	## Periodic stems stop before the seam so the fold only carries pad tails.
	const SEAM_GUARD_SEC := 0.35

	const ORDER: Array[StringName] = [
		&"menu", &"hub", &"deploy", &"combat", &"boss", &"exfil", &"storm", &"results", &"silent",
	]

	## Cue table. `prog` is a chord progression in semitones over `root`;
	## `mix_db` is the crossfade target on the Music bus.
	const TRACKS := {
		"menu": {
			"bpm": 72.0, "bars": 4, "root": 110.0,
			"prog": [[0.0, 3.0, 7.0, 12.0], [-4.0, 0.0, 3.0, 8.0], [3.0, 7.0, 10.0, 15.0], [-2.0, 2.0, 5.0, 10.0]],
			"pad": 0.5, "bass": 0.3, "pulse": 0.0, "perc": 0.08, "noise": 0.05,
			"kick": [0.0], "snare": [], "hat": [], "pulse_rate": 4, "mix_db": -18.0,
		},
		"hub": {
			"bpm": 84.0, "bars": 4, "root": 130.81,
			"prog": [[0.0, 4.0, 7.0, 12.0], [-5.0, -1.0, 2.0, 7.0], [-3.0, 0.0, 4.0, 9.0], [-7.0, -3.0, 0.0, 5.0]],
			"pad": 0.45, "bass": 0.28, "pulse": 0.12, "perc": 0.16, "noise": 0.04,
			"kick": [0.0, 2.0], "snare": [], "hat": [0.5, 1.5, 2.5, 3.5], "pulse_rate": 4, "mix_db": -20.0,
		},
		"deploy": {
			"bpm": 96.0, "bars": 4, "root": 98.0,
			"prog": [[0.0, 3.0, 7.0, 10.0], [0.0, 3.0, 7.0, 15.0], [-2.0, 1.0, 5.0, 10.0], [-4.0, 0.0, 3.0, 8.0]],
			"pad": 0.35, "bass": 0.38, "pulse": 0.3, "perc": 0.34, "noise": 0.07,
			"kick": [0.0, 2.0], "snare": [1.0, 3.0], "hat": [0.5, 1.5, 2.5, 3.5], "pulse_rate": 2, "mix_db": -16.0,
		},
		"combat": {
			"bpm": 128.0, "bars": 6, "root": 82.41,
			"prog": [[0.0, 3.0, 7.0, 10.0], [0.0, 5.0, 7.0, 10.0], [-4.0, 0.0, 3.0, 7.0], [-2.0, 1.0, 5.0, 8.0]],
			"pad": 0.28, "bass": 0.42, "pulse": 0.42, "perc": 0.48, "noise": 0.1,
			"kick": [0.0, 1.5, 2.0, 3.5], "snare": [1.0, 3.0], "hat": [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5], "pulse_rate": 1, "mix_db": -13.0,
		},
		"boss": {
			"bpm": 116.0, "bars": 6, "root": 73.42,
			"prog": [[0.0, 1.0, 7.0, 8.0], [0.0, 3.0, 6.0, 10.0], [-1.0, 2.0, 6.0, 9.0], [-2.0, 1.0, 6.0, 11.0]],
			"pad": 0.48, "bass": 0.4, "pulse": 0.32, "perc": 0.42, "noise": 0.16,
			"kick": [0.0, 2.0, 2.5], "snare": [1.0, 3.0], "hat": [0.5, 1.5, 2.5, 3.5], "pulse_rate": 2, "mix_db": -12.0,
		},
		"exfil": {
			"bpm": 104.0, "bars": 4, "root": 116.54,
			"prog": [[0.0, 4.0, 7.0, 11.0], [2.0, 5.0, 9.0, 12.0], [-3.0, 0.0, 4.0, 7.0], [-5.0, -1.0, 2.0, 7.0]],
			"pad": 0.45, "bass": 0.3, "pulse": 0.3, "perc": 0.28, "noise": 0.06,
			"kick": [0.0, 2.0], "snare": [3.0], "hat": [1.0, 3.0], "pulse_rate": 2, "mix_db": -15.0,
		},
		"storm": {
			"bpm": 60.0, "bars": 4, "root": 61.74,
			"prog": [[0.0, 5.0, 7.0, 10.0], [0.0, 3.0, 7.0, 10.0], [-2.0, 3.0, 5.0, 8.0], [-4.0, 0.0, 3.0, 7.0]],
			"pad": 0.4, "bass": 0.22, "pulse": 0.0, "perc": 0.06, "noise": 0.34,
			"kick": [0.0], "snare": [], "hat": [], "pulse_rate": 4, "mix_db": -17.0,
		},
		"results": {
			"bpm": 84.0, "bars": 4, "root": 109.0,
			"prog": [[0.0, 4.0, 7.0, 12.0], [-3.0, 0.0, 4.0, 9.0], [-5.0, -1.0, 2.0, 7.0], [-7.0, -3.0, 0.0, 5.0]],
			"pad": 0.5, "bass": 0.28, "pulse": 0.1, "perc": 0.18, "noise": 0.05,
			"kick": [0.0, 2.0], "snare": [], "hat": [1.0, 3.0], "pulse_rate": 4, "mix_db": -17.0,
		},
		"silent": {"silent": true, "mix_db": -60.0},
	}

	func has_track(track: StringName) -> bool:
		return TRACKS.has(String(track))

	func track_ids() -> Array[StringName]:
		var ids: Array[StringName] = []
		for id in ORDER:
			if TRACKS.has(String(id)):
				ids.append(id)
		return ids

	func mix_db(track: StringName) -> float:
		var spec: Dictionary = TRACKS.get(String(track), {})
		return float(spec.get("mix_db", -16.0))

	## Worker entry point: renders `track` into out["info"] (empty on failure).
	func build_task(track: StringName, out: Dictionary) -> void:
		var spec: Dictionary = TRACKS.get(String(track), {})
		if spec.is_empty() or bool(spec.get("silent", false)):
			out["info"] = {}
			return
		out["info"] = _render(spec)

	func _render(spec: Dictionary) -> Dictionary:
		var bpm := maxf(float(spec.get("bpm", 90.0)), 20.0)
		var bars := maxi(1, int(spec.get("bars", 4)))
		var beat_sec := 60.0 / bpm
		var loop_sec := float(bars * 4) * beat_sec
		var count := maxi(int(loop_sec * float(RATE)), 1000)
		var wrap := mini(int(WRAP_SEC * float(RATE)), count / 3)
		var total := count + wrap
		var buf := PackedFloat32Array()
		buf.resize(total)
		var root := float(spec.get("root", 110.0))
		var prog: Array = spec.get("prog", [[0.0, 3.0, 7.0, 12.0]])
		var seam := count - int(SEAM_GUARD_SEC * float(RATE))
		_pad(buf, total, count, root, prog, bars, beat_sec)
		_bass(buf, total, seam, root, prog, bars, beat_sec, float(spec.get("bass", 0.0)))
		_pulse(buf, total, seam, root, prog, bars, beat_sec, float(spec.get("pulse", 0.0)), int(spec.get("pulse_rate", 2)))
		_perc(buf, total, seam, beat_sec, bars, float(spec.get("perc", 0.0)), spec)
		_texture(buf, total, float(spec.get("noise", 0.0)), int(spec.get("seed", 7)))
		# Fold the tail into the head so the loop seam is sample-continuous.
		for i in wrap:
			var w := float(i) / float(wrap)
			buf[i] = buf[i] * w + buf[count + i] * (1.0 - w)
		# Safety peak trim only; authored stems keep their relative balance.
		var peak := 0.0
		for i in count:
			peak = maxf(peak, absf(buf[i]))
		var scale := 1.0
		if peak > 0.94:
			scale = 0.94 / peak
		var data := PackedByteArray()
		data.resize(count * 2)
		for i in count:
			data.encode_s16(i * 2, int(clampf(buf[i] * scale, -1.0, 1.0) * 32767.0))
		return {"data": data, "rate": RATE, "count": count, "loop": true}

	# --- Stem: sustained pad chords with crossfaded bar boundaries ----------
	func _pad(buf: PackedFloat32Array, total: int, count: int, root: float, prog: Array, bars: int, beat_sec: float) -> void:
		var spb := int(beat_sec * 4.0 * float(RATE))
		if spb < 64:
			return
		var attack := mini(int(WRAP_SEC * float(RATE)), spb / 3)
		var release := mini(int(WRAP_SEC * float(RATE)), spb / 3)
		for b in bars:
			var chord: Array = prog[b % prog.size()]
			var start := b * spb
			if start >= total:
				break
			var end := total if b == bars - 1 else mini(total, start + spb + release)
			var tones := mini(4, chord.size())
			var amp := 0.9 / sqrt(float(tones))
			for tone_i in tones:
				var semi := float(chord[tone_i])
				var f := root * pow(2.0, semi / 12.0)
				var detune := 1.0 + (float(tone_i) - 1.5) * 0.0022
				var w1 := TAU * f * detune / float(RATE)
				var w2 := TAU * f * (2.0 - detune) / float(RATE)
				for i in range(start, end):
					var local := float(i - start)
					var env := 1.0
					if local < float(attack):
						env = local / float(attack)
					var remaining := float(end - i)
					if remaining < float(release):
						env *= remaining / float(release)
					var t := float(i)
					buf[i] += (sin(w1 * t) + sin(w2 * t) * 0.42) * amp * env * 0.32

	# --- Stem: bass pulse on each beat --------------------------------------
	func _bass(buf: PackedFloat32Array, total: int, seam: int, root: float, prog: Array, bars: int, beat_sec: float, level: float) -> void:
		if level <= 0.0:
			return
		var beat_len := int(beat_sec * float(RATE))
		var note_len := mini(int(0.55 * float(RATE)), beat_len)
		for b in bars:
			var chord: Array = prog[b % prog.size()]
			var semi := float(chord[0]) - 12.0
			var f := root * pow(2.0, semi / 12.0)
			var w1 := TAU * f / float(RATE)
			var w2 := TAU * f * 2.0 / float(RATE)
			for beat in 4:
				var start := b * beat_len * 4 + beat * beat_len
				if start >= seam:
					break
				for i in note_len:
					var idx := start + i
					if idx >= total:
						break
					var local := float(i)
					var env := exp(-4.0 * local / float(note_len)) * minf(1.0, local / 64.0)
					buf[idx] += (sin(w1 * float(idx)) * 0.6 + sin(w2 * float(idx)) * 0.16) * env * level * 0.55

	# --- Stem: driving arpeggio pulse ---------------------------------------
	func _pulse(buf: PackedFloat32Array, total: int, seam: int, root: float, prog: Array, bars: int, beat_sec: float, level: float, rate_div: int) -> void:
		if level <= 0.0:
			return
		var step_sec := beat_sec / float(maxi(1, rate_div))
		var step_len := int(step_sec * float(RATE))
		var note_len := mini(int(0.2 * float(RATE)), step_len)
		var step_index := 0
		for b in bars:
			var chord: Array = prog[b % prog.size()]
			for beat in 4:
				for sub in rate_div:
					var start := b * int(beat_sec * 4.0 * float(RATE)) + int(float(beat) * beat_sec * float(RATE)) + sub * step_len
					step_index += 1
					if start >= seam:
						continue
					var tone: Array = chord
					var semi := float(tone[(step_index + beat) % tone.size()]) + 12.0
					var f := root * pow(2.0, semi / 12.0)
					var w1 := TAU * f / float(RATE)
					var w3 := TAU * f * 3.0 / float(RATE)
					for i in note_len:
						var idx := start + i
						if idx >= total:
							break
						var local := float(i)
						var env := exp(-9.0 * local / float(maxi(note_len, 1))) * minf(1.0, local / 48.0)
						buf[idx] += (sin(w1 * float(idx)) + sin(w3 * float(idx)) * 0.22) * env * level * 0.17

	# --- Stem: kick / snare / hat percussion --------------------------------
	func _perc(buf: PackedFloat32Array, total: int, seam: int, beat_sec: float, bars: int, level: float, spec: Dictionary) -> void:
		if level <= 0.0:
			return
		var kicks: Array = spec.get("kick", [])
		var snares: Array = spec.get("snare", [])
		var hats: Array = spec.get("hat", [])
		var beat_len := beat_sec * float(RATE)
		var rng := 0x51F7A11
		for b in bars:
			var bar_start := float(b) * 4.0 * beat_len
			for beat_pos in kicks:
				_kick(buf, total, seam, bar_start + float(beat_pos) * beat_len, level * 0.9)
			for beat_pos in snares:
				rng = _snare(buf, total, seam, bar_start + float(beat_pos) * beat_len, level * 0.34, rng)
			for beat_pos in hats:
				rng = _hat(buf, total, seam, bar_start + float(beat_pos) * beat_len, level * 0.13, rng)

	func _kick(buf: PackedFloat32Array, total: int, seam: int, start_f: float, level: float) -> void:
		var start := int(start_f)
		if start < 0 or start >= seam:
			return
		var length := mini(int(0.3 * float(RATE)), total - start)
		var phase := 0.0
		for i in length:
			var idx := start + i
			if idx >= total:
				break
			var p := float(i) / float(length)
			phase += TAU * (105.0 - 55.0 * p) / float(RATE)
			var env := exp(-9.0 * p)
			buf[idx] += sin(phase) * env * level * 0.8

	func _snare(buf: PackedFloat32Array, total: int, seam: int, start_f: float, level: float, rng: int) -> int:
		var start := int(start_f)
		if start < 0 or start >= seam:
			return rng
		var length := mini(int(0.18 * float(RATE)), total - start)
		var state := rng | 1
		for i in length:
			var idx := start + i
			if idx >= total:
				break
			var p := float(i) / float(length)
			state = (state * 1103515245 + 12345) & 0x7FFFFFFF
			var nz := float(state) * (1.0 / 1073741824.0) - 1.0
			var env := exp(-16.0 * p)
			buf[idx] += (nz * 0.85 + sin(TAU * 190.0 * float(idx) / float(RATE)) * 0.26) * env * level
		return state

	func _hat(buf: PackedFloat32Array, total: int, seam: int, start_f: float, level: float, rng: int) -> int:
		var start := int(start_f)
		if start < 0 or start >= seam:
			return rng
		var length := mini(int(0.055 * float(RATE)), total - start)
		var state := rng | 1
		var lp := 0.0
		for i in length:
			var idx := start + i
			if idx >= total:
				break
			var p := float(i) / float(length)
			state = (state * 1103515245 + 12345) & 0x7FFFFFFF
			var nz := float(state) * (1.0 / 1073741824.0) - 1.0
			lp += (nz - lp) * 0.35
			var env := exp(-34.0 * p)
			buf[idx] += (nz - lp) * env * level
		return state

	# --- Stem: noise texture bed (storm / dungeon air) ---------------------
	func _texture(buf: PackedFloat32Array, total: int, level: float, seed_value: int) -> void:
		if level <= 0.0:
			return
		var dur := float(total) / float(RATE)
		var cycles := maxi(1, int(round(0.3 * dur)))
		var lfo_hz := float(cycles) / dur
		var state := seed_value | 1
		var lp := 0.0
		var lp2 := 0.0
		for i in total:
			var t := float(i) / float(RATE)
			state = (state * 1103515245 + 12345) & 0x7FFFFFFF
			var nz := float(state) * (1.0 / 1073741824.0) - 1.0
			lp += (nz - lp) * 0.05
			lp2 += (lp - lp2) * 0.08
			var swell := 0.6 + sin(TAU * lfo_hz * t) * 0.3
			buf[i] += (lp2 * 3.0 + lp * 0.6) * swell * level
