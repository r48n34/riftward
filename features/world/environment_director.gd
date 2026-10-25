extends Node
## ENVIRONMENT DIRECTOR — the single writer for the world's sky, sun, fill light
## and fog. DayNightCycle and WeatherSystem push states here; the director merges
## them (planet keyframes + map preset overrides + weather) and applies at a low,
## throttled rate. Keeping one writer prevents the two systems fighting.
##
## Headless-safe: it only mutates an Environment resource and light nodes.

const Palette := preload("res://features/world/world_palette.gd")

const APPLY_INTERVAL := 0.2
const DEFAULT_SUN_DIR := Vector3(-0.80, 0.30, -0.52)

var environment: Environment = null
var sun: DirectionalLight3D = null
var fill: DirectionalLight3D = null
var sky_material: ShaderMaterial = null
var planet: Dictionary = {}
var base_overrides: Dictionary = {}

var _day_key: Dictionary = {}
var _night_key: Dictionary = {}
var _dawn_key: Dictionary = {}
var _dusk_key: Dictionary = {}
var _base_fog_density := 0.00028
var _base_volumetric_density := 0.0035
var _base_ambient := 0.55
var _base_sun_energy := 1.55
var _base_fill_energy := 0.38
var _base_sun_dir := DEFAULT_SUN_DIR
var _time_state: Dictionary = {}
var _weather_state: Dictionary = {}
var _indoor := false
var _enabled := true
var _dirty := true
var _apply_timer := 0.0
var _flash_energy := 0.0
var _flash_timer := 0.0
var _applied := 0


func setup(env_data: Dictionary, overrides: Dictionary, p_planet: Dictionary) -> void:
	environment = env_data.get("environment") as Environment
	sun = env_data.get("sun") as DirectionalLight3D
	fill = env_data.get("fill") as DirectionalLight3D
	sky_material = env_data.get("sky_material") as ShaderMaterial
	base_overrides = overrides.duplicate(true) if overrides is Dictionary else {}
	planet = p_planet.duplicate(true) if p_planet is Dictionary else {}
	if environment != null:
		_base_fog_density = environment.fog_density
		_base_volumetric_density = environment.volumetric_fog_density
		_base_ambient = environment.ambient_light_energy
	if sun != null:
		_base_sun_energy = sun.light_energy
	if fill != null:
		_base_fill_energy = fill.light_energy
	_build_keyframes()
	_time_state = {
		"time_of_day": 0.5,
		"key": _day_key.duplicate(true),
		"sun_dir": base_overrides.get("sun_dir", DEFAULT_SUN_DIR),
	}
	_weather_state = {}
	apply()


func _build_keyframes() -> void:
	var sky: Dictionary = planet.get("sky", {}) if planet.get("sky", {}) is Dictionary else {}
	_day_key = _default_key()
	_night_key = _default_night_key()
	_dawn_key = _default_dawn_key()
	_dusk_key = _default_dusk_key()
	if sky.has("day"):
		_day_key = _merge_keys(_day_key, sky["day"])
	if sky.has("night"):
		_night_key = _merge_keys(_night_key, sky["night"])
	if sky.has("dawn"):
		_dawn_key = _merge_keys(_dawn_key, sky["dawn"])
	if sky.has("dusk"):
		_dusk_key = _merge_keys(_dusk_key, sky["dusk"])
	# The map preset's authored mood is the authoritative daytime look.
	_day_key = _merge_keys(_day_key, base_overrides)
	if base_overrides.has("sun_dir"):
		_base_sun_dir = base_overrides["sun_dir"]
	if base_overrides.has("sun_energy"):
		_base_sun_energy = float(base_overrides["sun_energy"])


func _default_key() -> Dictionary:
	return {
		"sky_top": Palette.SKY_TOP, "sky_horizon": Palette.SKY_HORIZON,
		"sky_ground": Palette.SKY_GROUND, "sun_color": Palette.SUN_COLOR,
		"fill_color": Palette.FILL_COLOR, "fog_color": Palette.FOG_COLOR,
		"sun_energy": 1.55, "fill_energy": 0.38, "ambient_energy": 0.55, "star_amount": 0.22,
	}


func _default_night_key() -> Dictionary:
	var key := _default_key()
	key["sky_top"] = Color(0.03, 0.05, 0.12)
	key["sky_horizon"] = Color(0.18, 0.22, 0.32)
	key["sky_ground"] = Color(0.05, 0.06, 0.08)
	key["sun_color"] = Color(0.55, 0.65, 0.95)
	key["fill_color"] = Color(0.25, 0.35, 0.55)
	key["fog_color"] = Color(0.12, 0.15, 0.22)
	key["sun_energy"] = 0.04
	key["fill_energy"] = 0.30
	key["ambient_energy"] = 0.20
	key["star_amount"] = 0.90
	return key


func _default_dawn_key() -> Dictionary:
	var key := _default_key()
	key["sky_top"] = Color(0.10, 0.16, 0.32)
	key["sky_horizon"] = Color(0.85, 0.55, 0.42)
	key["sky_ground"] = Color(0.18, 0.14, 0.12)
	key["sun_color"] = Color(1.0, 0.72, 0.48)
	key["fill_color"] = Color(0.35, 0.45, 0.62)
	key["fog_color"] = Color(0.45, 0.38, 0.34)
	key["sun_energy"] = 0.90
	key["fill_energy"] = 0.35
	key["ambient_energy"] = 0.45
	key["star_amount"] = 0.35
	return key


func _default_dusk_key() -> Dictionary:
	var key := _default_key()
	key["sky_top"] = Color(0.12, 0.10, 0.22)
	key["sky_horizon"] = Color(0.90, 0.40, 0.25)
	key["sky_ground"] = Color(0.15, 0.10, 0.10)
	key["sun_color"] = Color(1.0, 0.52, 0.28)
	key["fill_color"] = Color(0.32, 0.38, 0.58)
	key["fog_color"] = Color(0.42, 0.28, 0.24)
	key["sun_energy"] = 1.20
	key["fill_energy"] = 0.34
	key["ambient_energy"] = 0.42
	key["star_amount"] = 0.30
	return key


func _merge_keys(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in overrides.keys():
		if key in ["sky_top", "sky_horizon", "sky_ground", "sun_color", "fill_color", "fog_color"]:
			out[key] = overrides[key]
		elif key in ["sun_energy", "fill_energy", "ambient_energy", "star_amount"]:
			out[key] = float(overrides[key])
	return out


func set_time_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_time_state = state.duplicate(true)
	_dirty = true


func set_weather_state(state: Dictionary) -> void:
	_weather_state = state.duplicate(true) if state is Dictionary else {}
	_dirty = true


func set_indoor(value: bool) -> void:
	if _indoor == value:
		return
	_indoor = value
	_dirty = true


func is_indoor() -> bool:
	return _indoor


func set_enabled(value: bool) -> void:
	_enabled = value


func flash(strength: float = 1.5) -> void:
	_flash_energy = maxf(_flash_energy, strength)
	_flash_timer = 0.16
	_dirty = true


func _process(delta: float) -> void:
	if not _enabled:
		return
	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		if _flash_timer <= 0.0:
			_flash_energy = 0.0
			_dirty = true
	_apply_timer = maxf(0.0, _apply_timer - delta)
	if _dirty and _apply_timer <= 0.0:
		apply()


func apply() -> void:
	if environment == null:
		return
	var key: Dictionary = _time_state.get("key", _day_key)
	if not (key is Dictionary) or key.is_empty():
		key = _day_key
	var sun_dir: Vector3 = _time_state.get("sun_dir", _base_sun_dir)
	if sun_dir.length_squared() < 0.000001:
		sun_dir = _base_sun_dir
	sun_dir = sun_dir.normalized()
	var fog_mult := float(_weather_state.get("fog_mult", 1.0))
	var fog_color: Color = _weather_state.get("fog_color", key.get("fog_color", Palette.FOG_COLOR))
	var sky_tint: Color = _weather_state.get("sky_tint", Color.WHITE)
	var sun_mult := float(_weather_state.get("sun_mult", 1.0))
	var ambient_mult := float(_weather_state.get("ambient_mult", 1.0))
	var volumetric_mult := float(_weather_state.get("volumetric_mult", 1.0))
	var indoor_scale := 0.18 if _indoor else 1.0

	var key_sky_top: Color = key.get("sky_top", Palette.SKY_TOP)
	var key_sky_horizon: Color = key.get("sky_horizon", Palette.SKY_HORIZON)
	var key_sky_ground: Color = key.get("sky_ground", Palette.SKY_GROUND)
	environment.ambient_light_energy = float(key.get("ambient_energy", _base_ambient)) * ambient_mult * indoor_scale
	environment.fog_light_color = (key.get("fog_color", Palette.FOG_COLOR) as Color).lerp(fog_color, 0.55)
	environment.fog_density = _base_fog_density * fog_mult * (2.2 if _indoor else 1.0)
	environment.volumetric_fog_density = 0.0 if _indoor else _base_volumetric_density * volumetric_mult

	if sun != null:
		sun.light_color = key.get("sun_color", Palette.SUN_COLOR)
		sun.light_energy = maxf(0.0, float(key.get("sun_energy", _base_sun_energy)) * sun_mult + _flash_energy) * (0.05 if _indoor else 1.0)
		sun.transform = Transform3D(Basis.looking_at(-sun_dir, Vector3.UP), sun.position)
	if fill != null:
		fill.light_color = key.get("fill_color", Palette.FILL_COLOR)
		fill.light_energy = float(key.get("fill_energy", _base_fill_energy)) * ambient_mult * (0.25 if _indoor else 1.0)

	if sky_material != null:
		sky_material.set_shader_parameter("sky_top_color", key_sky_top.lerp(sky_tint, 0.30))
		sky_material.set_shader_parameter("sky_horizon_warm", key_sky_horizon.lerp(sky_tint, 0.35))
		sky_material.set_shader_parameter("sky_horizon_cool", (key_sky_horizon as Color).darkened(0.35).lerp(sky_tint, 0.25))
		sky_material.set_shader_parameter("ground_color", key_sky_ground)
		sky_material.set_shader_parameter("sun_color", key.get("sun_color", Palette.SUN_COLOR))
		sky_material.set_shader_parameter("sun_dir", sun_dir)
		sky_material.set_shader_parameter("star_amount", 0.0 if _indoor else float(key.get("star_amount", 0.22)))
		var planet_sky: Dictionary = planet.get("planet_sky", {}) if planet.get("planet_sky", {}) is Dictionary else {}
		for shader_key in ["planet_dir", "planet_radius", "planet_tilt", "planet_band_a", "planet_band_b", "ring_color"]:
			if planet_sky.has(shader_key):
				sky_material.set_shader_parameter(shader_key, planet_sky[shader_key])
	_applied += 1
	_dirty = false
	_apply_timer = APPLY_INTERVAL


## Snapshot for HUD/tests.
func get_state() -> Dictionary:
	var key: Dictionary = _time_state.get("key", _day_key)
	return {
		"time_of_day": float(_time_state.get("time_of_day", 0.5)),
		"sun_dir": _time_state.get("sun_dir", _base_sun_dir),
		"sun_energy": sun.light_energy if sun != null else 0.0,
		"fill_energy": fill.light_energy if fill != null else 0.0,
		"ambient_energy": environment.ambient_light_energy if environment != null else 0.0,
		"fog_density": environment.fog_density if environment != null else 0.0,
		"fog_color": key.get("fog_color", Palette.FOG_COLOR),
		"sky_top": key.get("sky_top", Palette.SKY_TOP),
		"indoor": _indoor,
		"applied": _applied,
	}
