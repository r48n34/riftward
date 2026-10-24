extends Node
## Original, procedurally generated audio. Keeps the project self-contained and
## license-clean while giving weapons, UI and abilities real weight.

const SAMPLE_RATE := 22050
const POOL_2D := 8
const POOL_3D := 16

var _streams: Dictionary = {}
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _next_2d: int = 0
var _next_3d: int = 0
var _music_player: AudioStreamPlayer = null


func _ready() -> void:
	_ensure_buses()
	_build_streams()
	_build_pools()
	_build_music()


func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX", "UI", "Ambience"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)


func _build_pools() -> void:
	for i in POOL_2D:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_pool_2d.append(player)
	for i in POOL_3D:
		var player := AudioStreamPlayer3D.new()
		player.bus = "SFX"
		player.max_distance = 90.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 10.0
		add_child(player)
		_pool_3d.append(player)


func _build_streams() -> void:
	var defs := {
		"ui_click": {"type": "click", "freq": 980.0, "dur": 0.055, "vol": 0.32},
		"ui_hover": {"type": "tone", "freq": 1240.0, "dur": 0.035, "vol": 0.12},
		"ui_confirm": {"type": "chime", "freq": 680.0, "dur": 0.22, "vol": 0.26},
		"ui_error": {"type": "buzz", "freq": 160.0, "dur": 0.18, "vol": 0.25},
		"shot_rifle": {"type": "shot", "freq": 130.0, "dur": 0.20, "vol": 0.62},
		"shot_smg": {"type": "shot", "freq": 180.0, "dur": 0.11, "vol": 0.48},
		"shot_shotgun": {"type": "boom", "freq": 85.0, "dur": 0.34, "vol": 0.72},
		"shot_dmr": {"type": "shot", "freq": 100.0, "dur": 0.31, "vol": 0.66},
		"shot_sniper": {"type": "rail", "freq": 72.0, "dur": 0.55, "vol": 0.7},
		"shot_lmg": {"type": "shot", "freq": 115.0, "dur": 0.17, "vol": 0.55},
		"shot_pistol": {"type": "shot", "freq": 210.0, "dur": 0.12, "vol": 0.42},
		"shot_launcher": {"type": "thump", "freq": 70.0, "dur": 0.30, "vol": 0.62},
		"shot_arc": {"type": "zap", "freq": 420.0, "dur": 0.22, "vol": 0.45},
		"shot_carbine": {"type": "shot", "freq": 160.0, "dur": 0.15, "vol": 0.46},
		"reload": {"type": "reload", "freq": 320.0, "dur": 0.52, "vol": 0.28},
		"knife_swing": {"type": "click", "freq": 720.0, "dur": 0.12, "vol": 0.18},
		"knife_hit": {"type": "hit", "freq": 320.0, "dur": 0.08, "vol": 0.3},
		"hit": {"type": "click", "freq": 1600.0, "dur": 0.045, "vol": 0.23},
		"hitmarker": {"type": "chime", "freq": 1450.0, "dur": 0.08, "vol": 0.22},
		"headshot": {"type": "chime", "freq": 2100.0, "dur": 0.15, "vol": 0.32},
		"kill": {"type": "kill", "freq": 520.0, "dur": 0.18, "vol": 0.25},
		"explosion": {"type": "boom", "freq": 55.0, "dur": 0.65, "vol": 0.82},
		"ability": {"type": "rise", "freq": 420.0, "dur": 0.35, "vol": 0.36},
		"ability_ready": {"type": "chime", "freq": 940.0, "dur": 0.18, "vol": 0.18},
		"player_hurt": {"type": "thump", "freq": 90.0, "dur": 0.22, "vol": 0.5},
		"shield_break": {"type": "glass", "freq": 1800.0, "dur": 0.4, "vol": 0.42},
		"pickup": {"type": "chime", "freq": 880.0, "dur": 0.2, "vol": 0.26},
		"level_up": {"type": "fanfare", "freq": 523.25, "dur": 0.9, "vol": 0.38},
		"exfil": {"type": "alarm", "freq": 620.0, "dur": 0.8, "vol": 0.34},
		"heal": {"type": "soft", "freq": 640.0, "dur": 0.45, "vol": 0.25},
		"footstep": {"type": "step", "freq": 100.0, "dur": 0.07, "vol": 0.12},
		"door": {"type": "thump", "freq": 65.0, "dur": 0.26, "vol": 0.3},
		"scan": {"type": "rise", "freq": 760.0, "dur": 0.5, "vol": 0.24},
		"storm": {"type": "rumble", "freq": 42.0, "dur": 1.2, "vol": 0.3},
	}
	for id in defs.keys():
		_streams[id] = _synth(defs[id])


func _synth(def: Dictionary) -> AudioStreamWAV:
	var dur: float = float(def.get("dur", 0.2))
	var freq: float = float(def.get("freq", 440.0))
	var vol: float = float(def.get("vol", 0.3))
	var kind: String = String(def.get("type", "tone"))
	var count := maxi(1, int(dur * SAMPLE_RATE))
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind + str(freq))
	var state := 0.0
	for i in count:
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / count
		var env := _env_for(kind, progress)
		var sample := 0.0
		var noise := rng.randf_range(-1.0, 1.0)
		match kind:
			"click":
				sample = sin(TAU * freq * t) * env * 0.8 + noise * env * 0.2
			"shot":
				var pitch := freq * (1.0 - progress * 0.35)
				sample = sin(TAU * pitch * t) * env * 0.55 + noise * env * 0.45 + sin(TAU * 55.0 * t) * env * 0.35
			"boom":
				var low := sin(TAU * freq * t) * (1.0 - progress * 0.2)
				sample = low * env * 0.7 + noise * env * 0.5
			"rail":
				sample = sin(TAU * freq * t) * env * 0.5 + sin(TAU * freq * 2.01 * t) * env * 0.25 + noise * env * 0.15
			"zap":
				var buzz := signf(sin(TAU * (freq + sin(TAU * 18.0 * t) * 90.0) * t)) * 0.22
				sample = (buzz + noise * 0.35) * env
			"thump":
				sample = sin(TAU * freq * t) * env * 0.8 + noise * env * 0.12
			"reload":
				var click1 := 1.0 if progress > 0.15 and progress < 0.22 else 0.0
				var click2 := 1.0 if progress > 0.55 and progress < 0.61 else 0.0
				sample = (click1 + click2) * (sin(TAU * 1200.0 * t) * 0.4 + noise * 0.6)
			"chime":
				sample = sin(TAU * freq * t) * env * 0.7 + sin(TAU * freq * 1.5 * t) * env * 0.3
			"kill":
				sample = sin(TAU * freq * t) * env * 0.6 + noise * env * 0.15
			"rise":
				var rise := freq * (1.0 + progress * 1.2)
				sample = sin(TAU * rise * t) * env * 0.65 + sin(TAU * rise * 0.5 * t) * env * 0.2
			"fanfare":
				var notes := [523.25, 659.25, 783.99, 1046.5]
				var idx: int = clampi(int(progress * notes.size()), 0, notes.size() - 1)
				sample = sin(TAU * float(notes[idx]) * t) * env * 0.7
			"alarm":
				var pulse := 1.0 if fmod(t, 0.4) < 0.2 else 0.0
				sample = sin(TAU * freq * t) * env * pulse * 0.7
			"soft":
				sample = (sin(TAU * freq * t) * 0.5 + sin(TAU * freq * 1.25 * t) * 0.25) * env
			"step":
				sample = noise * env * 0.8 + sin(TAU * 75.0 * t) * env * 0.3
			"glass":
				sample = noise * env * 0.65 + sin(TAU * (freq + progress * 400.0) * t) * env * 0.3
			"rumble":
				state += noise * 0.2
				state *= 0.995
				sample = (state + sin(TAU * freq * t) * 0.2) * env
			"buzz":
				sample = signf(sin(TAU * freq * t)) * env * 0.4 + sin(TAU * 50.0 * t) * env * 0.3
			"tone":
				sample = sin(TAU * freq * t) * env * 0.6
			_:
				sample = sin(TAU * freq * t) * env * 0.5 + noise * env * 0.1
		sample = clampf(sample * vol, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


func _env_for(kind: String, p: float) -> float:
	match kind:
		"click", "hit", "footstep":
			return pow(1.0 - p, 4.0)
		"shot", "boom", "rail", "zap", "thump", "buzz":
			return exp(-6.0 * p) * (1.0 - p * 0.3)
		"reload", "alarm":
			return clampf(1.0 - p * 0.6, 0.0, 1.0)
		"rise":
			return sin(p * PI) * 0.9
		"fanfare":
			return sin(p * PI) * 0.8
		"rumble":
			return (1.0 - p) * 0.8
		_:
			return exp(-4.0 * p)


func get_stream(id: StringName) -> AudioStream:
	return _streams.get(String(id))


func play_ui(id: StringName, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _streams.get(String(id))
	if stream == null:
		return
	var player := _pool_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _pool_2d.size()
	player.bus = "UI"
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func play_sfx(id: StringName, volume_db: float = -3.0) -> void:
	var stream: AudioStream = _streams.get(String(id))
	if stream == null:
		return
	var player := _pool_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _pool_2d.size()
	player.bus = "SFX"
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func play_3d(id: StringName, world_position: Vector3, volume_db: float = -3.0) -> void:
	var stream: AudioStream = _streams.get(String(id))
	if stream == null:
		return
	var player := _pool_3d[_next_3d]
	_next_3d = (_next_3d + 1) % _pool_3d.size()
	player.global_position = world_position
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func set_music_mood(mood: StringName) -> void:
	if _music_player == null:
		return
	match mood:
		&"deployment":
			_music_player.volume_db = -15.0
			_music_player.pitch_scale = 1.0
		&"combat":
			_music_player.volume_db = -11.0
			_music_player.pitch_scale = 1.03
		&"hub":
			_music_player.volume_db = -21.0
			_music_player.pitch_scale = 0.98
		_:
			_music_player.volume_db = -23.0
			_music_player.pitch_scale = 1.0


func _build_music() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var duration := 12.0
	var mix := 16000
	var count := int(duration * mix)
	var data := PackedByteArray()
	data.resize(count * 2)
	var chords := [
		[110.0, 130.81, 164.81, 220.0],
		[98.0, 123.47, 146.83, 196.0],
		[87.31, 110.0, 130.81, 174.61],
		[98.0, 123.47, 164.81, 196.0],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x51F7A11
	var noise_state := 0.0
	for i in count:
		var t := float(i) / mix
		var chord_index := mini(3, int(t / 3.0))
		var chord: Array = chords[chord_index]
		var local := fmod(t, 3.0)
		var chord_env := minf(1.0, local / 0.8) * minf(1.0, (3.0 - local) / 1.1)
		var sample := 0.0
		for j in chord.size():
			var f: float = chord[j]
			var detune := 1.0 + (float(j) - 1.5) * 0.0015
			sample += sin(TAU * f * detune * t + float(j) * 0.4) * 0.045
			sample += sin(TAU * f * 0.5 * t + float(j) * 0.2) * 0.018
		noise_state += rng.randf_range(-1.0, 1.0) * 0.002
		noise_state *= 0.995
		sample = (sample * chord_env) + noise_state * 0.25
		# Soft global fade so the loop edge is gentle.
		var edge := minf(1.0, t / 0.4) * minf(1.0, (duration - t) / 0.4)
		sample *= edge * 0.55
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "AmbientMusic"
	_music_player.bus = "Music"
	_music_player.stream = stream
	_music_player.volume_db = -21.0
	add_child(_music_player)
	_music_player.play()


func get_ui_sound_ids() -> Array:
	return ["ui_click", "ui_hover", "ui_confirm", "ui_error"]
