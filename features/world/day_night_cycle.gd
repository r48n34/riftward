extends Node
## DAY / NIGHT CYCLE — seeded time-of-day driver for the environment director.
##
## One full day runs over the planet's authored `day_length`; the start fraction
## comes from the map preset (late afternoon, dusk, noon, night...). Four
## keyframes (night / dawn / day / dusk) are interpolated and handed to
## EnvironmentDirector together with a physically-plausible sun direction.

signal time_changed(fraction: float)

const NIGHT_START := 0.82
const DAWN_START := 0.22
const DAY_START := 0.38
const DUSK_START := 0.70

var director: Node = null
var day_length := 1080.0
var time_of_day := 0.62
var running := true
var _planet: Dictionary = {}
var _accum := 0.0
var _last_emit := 0.0
var _night_key: Dictionary = {}
var _dawn_key: Dictionary = {}
var _day_key: Dictionary = {}
var _dusk_key: Dictionary = {}


func _ready() -> void:
	add_to_group("day_night")


func setup(p_director: Node, planet: Dictionary, start_fraction: float = 0.62) -> void:
	director = p_director
	_planet = planet.duplicate(true) if planet is Dictionary else {}
	day_length = maxf(120.0, float(_planet.get("day_length", 1080.0)))
	time_of_day = clampf(start_fraction, 0.0, 0.999)
	_build_keys()
	_apply()


func _build_keys() -> void:
	var sky: Dictionary = _planet.get("sky", {}) if _planet.get("sky", {}) is Dictionary else {}
	_night_key = sky.get("night", {})
	_dawn_key = sky.get("dawn", {})
	_day_key = sky.get("day", {})
	_dusk_key = sky.get("dusk", {})


func _process(delta: float) -> void:
	if not running:
		return
	time_of_day = fposmod(time_of_day + delta / day_length, 1.0)
	_accum += delta
	if _accum < 0.2:
		return
	_accum = 0.0
	_apply()


func _apply() -> void:
	if director == null or not is_instance_valid(director):
		return
	var state := get_state()
	director.call("set_time_state", state)
	_last_emit += 1
	if _last_emit >= 5:
		_last_emit = 0
		time_changed.emit(time_of_day)


## Returns the interpolated keyframe + sun direction for the current time.
func get_state() -> Dictionary:
	var key := _sample_key()
	var sun_dir := _sun_direction(time_of_day)
	return {
		"time_of_day": time_of_day,
		"key": key,
		"sun_dir": sun_dir,
		"is_night": is_night(),
	}


func _sample_key() -> Dictionary:
	var keys: Array[Dictionary] = [_night_key, _dawn_key, _day_key, _dusk_key, _night_key]
	var points: Array[float] = [0.0, DAWN_START, DAY_START, DUSK_START, 1.0]
	for i in range(1, points.size()):
		if time_of_day <= points[i]:
			var t := (time_of_day - points[i - 1]) / maxf(0.0001, points[i] - points[i - 1])
			return _blend_keys(keys[i - 1], keys[i], smoothstep(0.0, 1.0, t))
	return keys[0].duplicate(true)


func _blend_keys(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	if a.is_empty():
		return b.duplicate(true) if b is Dictionary else {}
	if b.is_empty():
		return a.duplicate(true)
	var out := a.duplicate(true)
	for key in ["sky_top", "sky_horizon", "sky_ground", "sun_color", "fill_color", "fog_color"]:
		if a.has(key) and b.has(key):
			out[key] = (a[key] as Color).lerp(b[key], t)
		elif b.has(key):
			out[key] = b[key]
	for key in ["sun_energy", "fill_energy", "ambient_energy", "star_amount"]:
		if a.has(key) and b.has(key):
			out[key] = lerpf(float(a[key]), float(b[key]), t)
		elif b.has(key):
			out[key] = b[key]
	return out


func _sun_direction(fraction: float) -> Vector3:
	# 0.25 = sunrise on the horizon, 0.5 = zenith, 0.75 = sunset.
	var theta := (fraction - 0.25) * TAU
	return Vector3(cos(theta) * 0.82, sin(theta), -0.36).normalized()


func get_time_of_day() -> float:
	return time_of_day


func get_clock_text() -> String:
	var total_minutes := int(round(time_of_day * 1440.0))
	var hours := int(total_minutes / 60) % 24
	var minutes := total_minutes % 60
	return "%02d:%02d" % [hours, minutes]


func is_night() -> bool:
	return time_of_day >= NIGHT_START or time_of_day < 0.20


func get_sun_direction() -> Vector3:
	return _sun_direction(time_of_day)


func set_time_of_day(fraction: float) -> void:
	time_of_day = clampf(fraction, 0.0, 0.999)
	_apply()
