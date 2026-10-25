extends Node
## WEATHER SYSTEM — seeded weather state machine + particle layer + gameplay mods.
##
## Weather definitions are injected from ContentDB through the map preset (the
## world layer stays autoload-free). Transitions blend fog/sky/sun parameters via
## EnvironmentDirector, spawn one particle layer that follows the player, and
## expose vision/move multipliers for enemy perception and HUD.

signal weather_changed(state: Dictionary)

const APPLY_INTERVAL := 0.2
const PARTICLE_FOLLOW_INTERVAL := 0.4

var director: Node = null
var defs: Array = []
var pool: Array = []
var enabled := true

var _rng := RandomNumberGenerator.new()
var _by_id: Dictionary = {}
var _current: Dictionary = {}
var _target: Dictionary = {}
var _blend := 1.0
var _transition := 8.0
var _dwell := 90.0
var _apply_timer := 0.0
var _follow_timer := 0.0
var _lightning_timer := 6.0
var _particle_node: GPUParticles3D = null
var _particle_kind: StringName = &""
var _particle_timer := 0.0
var _player: Node3D = null


func _ready() -> void:
	add_to_group("weather")


## `p_defs` = array of weather dictionaries, `p_pool` = ordered ids for the map.
func setup(p_director: Node, p_defs: Array, p_pool: Array, seed_value: int, start_id: StringName = &"") -> void:
	director = p_director
	defs = p_defs.duplicate(true) if p_defs is Array else []
	pool = p_pool.duplicate() if p_pool is Array else []
	_rng.seed = seed_value * 7919 + 17
	_by_id.clear()
	for entry in defs:
		if entry is Dictionary and entry.has("id"):
			_by_id[StringName(entry["id"])] = entry
	if pool.is_empty():
		for entry in defs:
			if entry is Dictionary:
				pool.append(StringName(entry.get("id", &"")))
	if _by_id.is_empty() or pool.is_empty():
		enabled = false
		return
	var start := start_id
	if start == &"" or not _by_id.has(start):
		start = StringName(pool[_rng.randi_range(0, pool.size() - 1)])
	_current = (_by_id[start] as Dictionary).duplicate(true)
	_target = _current.duplicate(true)
	_blend = 1.0
	var dwell_range: Array = _current.get("dwell", [70.0, 150.0])
	_dwell = _rng.randf_range(float(dwell_range[0]), float(dwell_range[1]))
	_transition = float(_current.get("transition", 8.0))
	_apply_to_director()


func _process(delta: float) -> void:
	if not enabled or _current.is_empty():
		return
	_follow_timer -= delta
	if _follow_timer <= 0.0:
		_follow_timer = PARTICLE_FOLLOW_INTERVAL
		_follow_player()
	_update_particles(delta)
	if _blend < 1.0:
		_blend = minf(1.0, _blend + delta / maxf(0.5, _transition))
		_apply_timer -= delta
		if _apply_timer <= 0.0:
			_apply_timer = APPLY_INTERVAL
			_apply_to_director()
		if _blend >= 1.0:
			_current = _target.duplicate(true)
			var dwell_range: Array = _current.get("dwell", [70.0, 150.0])
			_dwell = _rng.randf_range(float(dwell_range[0]), float(dwell_range[1]))
			_apply_to_director()
	else:
		_dwell -= delta
		if _dwell <= 0.0:
			_pick_next()
	_update_lightning(delta)


func _pick_next() -> void:
	var candidates: Array = []
	for weather_id in pool:
		if _by_id.has(StringName(weather_id)) and (pool.size() <= 1 or StringName(weather_id) != StringName(_current.get("id", &""))):
			candidates.append(StringName(weather_id))
	if candidates.is_empty():
		return
	var next_id: StringName = candidates[_rng.randi_range(0, candidates.size() - 1)]
	_target = (_by_id[next_id] as Dictionary).duplicate(true)
	_transition = float(_target.get("transition", 8.0))
	_blend = 0.0
	_apply_timer = 0.0
	weather_changed.emit(get_state())


func _apply_to_director() -> void:
	if director == null or not is_instance_valid(director):
		return
	director.call("set_weather_state", _blended_state())
	var state := get_state()
	weather_changed.emit(state)


func _blended_state() -> Dictionary:
	var t := smoothstep(0.0, 1.0, _blend)
	var out := {
		"fog_mult": lerpf(float(_current.get("fog_mult", 1.0)), float(_target.get("fog_mult", 1.0)), t),
		"fog_color": (_current.get("fog_color", Color.WHITE) as Color).lerp(_target.get("fog_color", Color.WHITE), t),
		"sky_tint": (_current.get("sky_tint", Color.WHITE) as Color).lerp(_target.get("sky_tint", Color.WHITE), t),
		"sun_mult": lerpf(float(_current.get("sun_mult", 1.0)), float(_target.get("sun_mult", 1.0)), t),
		"ambient_mult": lerpf(float(_current.get("ambient_mult", 1.0)), float(_target.get("ambient_mult", 1.0)), t),
		"volumetric_mult": lerpf(float(_current.get("volumetric_mult", 1.0)), float(_target.get("volumetric_mult", 1.0)), t),
		"vision_mult": lerpf(float(_current.get("vision_mult", 1.0)), float(_target.get("vision_mult", 1.0)), t),
		"move_mult": lerpf(float(_current.get("move_mult", 1.0)), float(_target.get("move_mult", 1.0)), t),
	}
	return out


func _update_particles(_delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var kind := StringName(_current.get("particle", &"none"))
	if kind == _particle_kind and _particle_node != null:
		return
	_particle_kind = kind
	if _particle_node != null and is_instance_valid(_particle_node):
		_particle_node.queue_free()
		_particle_node = null
	if kind == &"none":
		return
	_particle_node = _make_particles(kind, int(_current.get("particle_amount", 600)), _current.get("particle_color", Color.WHITE))
	add_child(_particle_node)
	_follow_player()


func _make_particles(kind: StringName, amount: int, color: Color) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "WeatherParticles"
	particles.amount = clampi(amount, 50, 2000)
	particles.lifetime = 4.0
	particles.preprocess = 1.5
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-70.0, -40.0, -70.0), Vector3(140.0, 80.0, 140.0))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(34.0, 12.0, 34.0)
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 12.0
	process.gravity = Vector3(0.0, -6.0, 0.0)
	process.scale_min = 0.6
	process.scale_max = 1.2
	var mesh := QuadMesh.new()
	match kind:
		&"rain":
			process.initial_velocity_min = 22.0
			process.initial_velocity_max = 30.0
			process.gravity = Vector3(0.0, -18.0, 0.0)
			mesh.size = Vector2(0.015, 0.55)
		&"ash":
			process.initial_velocity_min = 1.0
			process.initial_velocity_max = 2.4
			process.gravity = Vector3(0.4, -1.1, 0.2)
			mesh.size = Vector2(0.05, 0.05)
		&"embers":
			process.initial_velocity_min = 1.2
			process.initial_velocity_max = 3.0
			process.gravity = Vector3(0.3, 0.7, 0.1)
			mesh.size = Vector2(0.06, 0.06)
		&"spores":
			process.initial_velocity_min = 0.4
			process.initial_velocity_max = 1.2
			process.gravity = Vector3(0.2, -0.2, 0.1)
			mesh.size = Vector2(0.07, 0.07)
		&"snow":
			process.initial_velocity_min = 0.6
			process.initial_velocity_max = 1.8
			process.gravity = Vector3(0.35, -0.9, 0.2)
			process.spread = 22.0
			mesh.size = Vector2(0.06, 0.06)
		&"sparks":
			process.initial_velocity_min = 9.0
			process.initial_velocity_max = 17.0
			process.direction = Vector3(0.0, -0.45, 0.0)
			process.gravity = Vector3(0.0, -2.0, 0.0)
			process.spread = 38.0
			mesh.size = Vector2(0.025, 0.24)
		_:
			process.initial_velocity_min = 2.0
			process.initial_velocity_max = 4.0
			process.gravity = Vector3(1.4, -0.4, 0.3)
			mesh.size = Vector2(0.08, 0.08)
	particles.process_material = process
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(color.r, color.g, color.b, 0.65)
	if kind in [&"embers", &"spores", &"sparks"]:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 3.0 if kind == &"sparks" else 2.0
	mesh.material = material
	particles.draw_pass_1 = mesh
	return particles


func _follow_player() -> void:
	if _particle_node == null or not is_instance_valid(_particle_node):
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player != null:
		_particle_node.global_position = _player.global_position + Vector3(0.0, 10.0, 0.0)


func _update_lightning(delta: float) -> void:
	var chance := float(_current.get("lightning", 0.0))
	if chance <= 0.0:
		return
	_lightning_timer -= delta
	if _lightning_timer > 0.0:
		return
	_lightning_timer = _rng.randf_range(2.5, 9.0)
	if _rng.randf() > chance:
		return
	if director != null and is_instance_valid(director):
		director.call("flash", 1.2 + _rng.randf() * 1.6)
	var audio := get_node_or_null("/root/AudioDirector")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", &"storm", -12.0)


## Current weather snapshot (blended display identity uses the target while the
## transition runs so the HUD changes promptly).
func get_state() -> Dictionary:
	var identity: Dictionary = _target if _blend < 0.5 else _current
	var blended := _blended_state()
	return {
		"id": StringName(identity.get("id", &"clear")),
		"display_name": String(identity.get("display_name", "Clear")),
		"icon": StringName(identity.get("icon", &"weather-sun")),
		"color": identity.get("color", Color("ffc16b")),
		"particle": StringName(identity.get("particle", &"none")),
		"hazard": StringName(identity.get("hazard", &"none")),
		"vision_mult": float(blended.get("vision_mult", 1.0)),
		"move_mult": float(blended.get("move_mult", 1.0)),
		"fog_mult": float(blended.get("fog_mult", 1.0)),
		"blend": _blend,
	}


func get_vision_multiplier() -> float:
	return float(get_state().get("vision_mult", 1.0))


func get_move_multiplier() -> float:
	return float(get_state().get("move_mult", 1.0))


func get_hazard() -> StringName:
	return StringName(get_state().get("hazard", &"none"))


func set_enabled(value: bool) -> void:
	enabled = value


func force_weather(weather_id: StringName) -> bool:
	if not _by_id.has(weather_id):
		return false
	_target = (_by_id[weather_id] as Dictionary).duplicate(true)
	_transition = float(_target.get("transition", 8.0))
	_blend = 0.0
	return true
