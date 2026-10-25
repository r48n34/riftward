class_name UIPlanetPortrait
extends Control
## Code-drawn planet portrait sourced from ContentDB.get_planet(). Bands, tilt,
## ring, atmosphere rim, hazard glow and surface blotches are all seeded from the
## planet id, so a portrait is deterministic and costs a single static redraw.

var planet_id: StringName = &""
var diameter := 96
var show_ring := true

var _planet: Dictionary = {}
var _tilt := 0.0
var _band_a := Color("6f8f8a")
var _band_b := Color("1e2c2f")
var _ring_color: Color = Color.TRANSPARENT
var _atmosphere: Color = UIPalette.mint
var _hazard_color: Color = UIPalette.mint
var _bands: Array[Dictionary] = []
var _blotches: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(96, 96)
	resized.connect(queue_redraw)


func configure(planet_id: StringName, diameter: int = 96, show_ring: bool = true) -> void:
	self.planet_id = planet_id
	self.diameter = maxi(16, diameter)
	self.show_ring = show_ring
	_planet = {}
	if ContentDB != null:
		_planet = ContentDB.get_planet(planet_id)
	_build_palette()
	_build_surface()
	custom_minimum_size = Vector2(self.diameter, self.diameter)
	if not is_inside_tree():
		size = Vector2(self.diameter, self.diameter)
	queue_redraw()


func get_planet_id() -> StringName:
	return planet_id


# ---------------------------------------------------------------------------
# Deterministic setup
# ---------------------------------------------------------------------------

func _build_palette() -> void:
	var sky: Dictionary = _planet.get("planet_sky", {}) if _planet.get("planet_sky", {}) is Dictionary else {}
	var fallback: Color = _planet.get("color", UIPalette.mint)
	_band_a = sky.get("planet_band_a", fallback)
	_band_b = sky.get("planet_band_b", UIPalette.darken(fallback, 0.35))
	_ring_color = sky.get("ring_color", Color.TRANSPARENT)
	_tilt = clampf(float(sky.get("planet_tilt", 0.0)), -0.75, 0.75)
	_atmosphere = UIPalette.mix(fallback, UIPalette.ivory, 0.25)
	_hazard_color = _hazard_tint(StringName(_planet.get("hazard", &"none")), fallback)
	if not sky.has("ring_color"):
		_ring_color = Color.TRANSPARENT


func _hazard_tint(hazard: StringName, fallback: Color) -> Color:
	match hazard:
		&"heat":
			return Color("ff9a5c")
		&"cold":
			return Color("bfe8ff")
		&"toxic":
			return Color("8fffb0")
		&"deep_water":
			return Color("63d6e6")
		&"rift":
			return Color("c79cff")
		_:
			return fallback


func _build_surface() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_for(String(planet_id))
	_bands.clear()
	_blotches.clear()
	if _planet.is_empty():
		# Unknown id still gets a seeded, readable neutral world.
		_bands.append(_make_band(-0.62, -0.30, UIPalette.mix(_band_a, _band_b, 0.5)))
		_bands.append(_make_band(-0.10, 0.18, UIPalette.mix(_band_a, _band_b, 0.25)))
		_bands.append(_make_band(0.36, 0.66, UIPalette.mix(_band_a, _band_b, 0.65)))
	else:
		var count := 3 + (1 if rng.randf() > 0.45 else 0)
		var y := -0.72
		for index in count:
			var span := rng.randf_range(0.16, 0.3)
			var band_color := UIPalette.mix(_band_a, _band_b, 0.2 + 0.55 * rng.randf())
			_bands.append(_make_band(y, minf(y + span, 0.78), band_color))
			y += span + rng.randf_range(0.04, 0.12)
	# Seeded surface blotches / continents, always inside the disc.
	var blotch_count := 6 + rng.randi_range(0, 3)
	for index in blotch_count:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(0.0, 0.62)
		var radius := rng.randf_range(0.07, 0.2)
		var center := Vector2(cos(angle), sin(angle)) * distance
		var limit := 0.92 - radius
		if center.length() > limit and center.length() > 0.001:
			center = center.normalized() * limit
		var tint := UIPalette.mix(_band_a, _band_b, rng.randf_range(0.3, 0.8))
		if rng.randf() > 0.72:
			tint = UIPalette.mix(tint, _atmosphere, 0.3)
		_blotches.append({
			"center": center,
			"radius": radius,
			"color": tint,
			"alpha": rng.randf_range(0.18, 0.38),
			"stretch": Vector2(1.0, rng.randf_range(0.55, 1.0)),
		})


func _make_band(y0: float, y1: float, color: Color) -> Dictionary:
	var points := PackedVector2Array()
	var steps := 9
	for index in steps:
		var y := lerpf(y0, y1, float(index) / float(steps - 1))
		var x := sqrt(maxf(0.0, 1.0 - y * y))
		points.append(Vector2(x, y))
	for index in range(steps - 1, -1, -1):
		var y := lerpf(y0, y1, float(index) / float(steps - 1))
		var x := sqrt(maxf(0.0, 1.0 - y * y))
		points.append(Vector2(-x, y))
	return {"points": points, "color": color}


static func _seed_for(value: String) -> int:
	var hashed := value.hash()
	if hashed == 0:
		hashed = 0x5f3759df
	return hashed


# ---------------------------------------------------------------------------
# Draw
# ---------------------------------------------------------------------------

func _draw() -> void:
	var side := minf(size.x, size.y)
	if side < 8.0:
		return
	var center := size * 0.5
	var disc_radius := side * 0.5 - 1.0
	var has_ring := show_ring and _ring_color.a > 0.01
	if has_ring:
		disc_radius *= 0.74
		_draw_ring(center, disc_radius, false)
	else:
		disc_radius *= 0.9
	if disc_radius < 2.0:
		return
	# Atmosphere bloom behind the disc.
	draw_circle(center, disc_radius * 1.06, UIPalette.alpha(_atmosphere, 0.1))
	draw_circle(center, disc_radius * 1.02, UIPalette.alpha(UIPalette.ink, 0.65))
	draw_circle(center, disc_radius, UIPalette.mix(_band_b, UIPalette.ink, 0.35))
	# Bands and continents share the planet tilt transform.
	draw_set_transform(center, _tilt, Vector2.ONE)
	for band in _bands:
		var points := PackedVector2Array()
		for value in band["points"]:
			var point: Vector2 = value
			points.append(point * disc_radius)
		var band_tint: Color = band["color"]
		draw_colored_polygon(points, UIPalette.alpha(band_tint, 0.55))
	for blotch in _blotches:
		var offset: Vector2 = blotch["center"] * disc_radius
		var radius: float = float(blotch["radius"]) * disc_radius
		var tint: Color = blotch["color"]
		var stretch: Vector2 = blotch["stretch"]
		draw_set_transform(center + offset, _tilt, stretch)
		draw_circle(Vector2.ZERO, radius, UIPalette.alpha(tint, float(blotch["alpha"])))
		draw_set_transform(center, _tilt, Vector2.ONE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Atmosphere rim, hazard glow and a soft highlight.
	draw_arc(center, disc_radius, 0.0, TAU, 64, UIPalette.alpha(_atmosphere, 0.8), maxf(1.0, disc_radius * 0.035), true)
	draw_arc(center, disc_radius * 1.035, 0.0, TAU, 64, UIPalette.alpha(_hazard_color, 0.32), maxf(1.0, disc_radius * 0.07), true)
	draw_arc(center, disc_radius * 0.94, PI * 1.04, PI * 1.52, 24, UIPalette.alpha(UIPalette.ivory, 0.16), maxf(1.0, disc_radius * 0.05), true)
	if has_ring:
		_draw_ring(center, disc_radius, true)


func _draw_ring(center: Vector2, disc_radius: float, front: bool) -> void:
	if _ring_color.a <= 0.01:
		return
	draw_set_transform(center, _tilt, Vector2(1.0, 0.34))
	if front:
		draw_arc(Vector2.ZERO, disc_radius * 1.46, 0.0, PI, 40, UIPalette.alpha(_ring_color, 0.5), maxf(1.0, disc_radius * 0.05), true)
		draw_arc(Vector2.ZERO, disc_radius * 1.24, 0.0, PI, 32, UIPalette.alpha(_ring_color, 0.3), maxf(1.0, disc_radius * 0.025), true)
	else:
		draw_arc(Vector2.ZERO, disc_radius * 1.5, 0.0, TAU, 64, UIPalette.alpha(_ring_color, 0.62), maxf(1.0, disc_radius * 0.055), true)
		draw_arc(Vector2.ZERO, disc_radius * 1.28, 0.0, TAU, 48, UIPalette.alpha(_ring_color, 0.34), maxf(1.0, disc_radius * 0.028), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
