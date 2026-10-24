class_name UIBackdrop
extends Control
## Procedural scenic backdrop: warm alien sky, layered ridge silhouettes, relay
## spires and drifting dust. Used behind the main menu and hub. Everything is
## drawn in code, deterministic, and flattened to a static frame when the
## reduce-motion setting is on.

enum Mood { MENU, HUB }

var mood: Mood = Mood.MENU
var _time := 0.0
var _redraw_accum := 0.0
var _dust: Array = []
var _size_key := Vector2.ZERO
var _left_scrim: GradientTexture2D = null
var _bottom_scrim: GradientTexture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_seed_dust()
	set_process(not UIPalette.reduce_motion)
	resized.connect(_on_resized)


func configure(new_mood: Mood = Mood.MENU) -> void:
	mood = new_mood
	queue_redraw()


func _seed_dust() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x51F7A11
	_dust.clear()
	var count := 38 if mood == Mood.MENU else 22
	for i in count:
		_dust.append({
			"pos": Vector2(rng.randf(), rng.randf_range(0.28, 0.95)),
			"speed": rng.randf_range(0.004, 0.016),
			"size": rng.randf_range(0.7, 2.1),
			"alpha": rng.randf_range(0.05, 0.22),
			"phase": rng.randf_range(0.0, TAU),
		})


func _on_resized() -> void:
	_size_key = size
	queue_redraw()


func _process(delta: float) -> void:
	if UIPalette.reduce_motion:
		set_process(false)
		return
	_time += delta
	_redraw_accum += delta
	if _redraw_accum >= 1.0 / 24.0:
		_redraw_accum = 0.0
		queue_redraw()


func _draw() -> void:
	var width := size.x
	var height := size.y
	if width <= 4.0 or height <= 4.0:
		return
	var hub := mood == Mood.HUB
	var horizon := height * (0.70 if hub else 0.66)
	var sun_pos := Vector2(width * (0.74 if hub else 0.72), height * (0.40 if hub else 0.38))
	_draw_sky(width, height, horizon, sun_pos, hub)
	if not hub:
		_draw_planet(width, height)
	_draw_ridges(width, height, horizon)
	_draw_spires(width, height, horizon)
	_draw_dust(width, height)
	_draw_scrim(width, height, hub)


func _draw_sky(width: float, height: float, horizon: float, sun_pos: Vector2, hub: bool) -> void:
	var top := Color("101d21") if not hub else Color("0b1215")
	var mid := Color("435551") if not hub else Color("2b3a3a")
	var warm := Color("d9a173") if not hub else Color("8a6c55")
	var low := Color("f0c48f") if not hub else Color("b98c62")
	var bands := 56
	for i in bands:
		var t := float(i) / float(bands - 1)
		var color: Color
		if t < 0.55:
			color = top.lerp(mid, t / 0.55)
		elif t < 0.85:
			color = mid.lerp(warm, (t - 0.55) / 0.30)
		else:
			color = warm.lerp(low, (t - 0.85) / 0.15)
		draw_rect(Rect2(0.0, t * height, width, height / bands + 1.0), color)
	# Sun glow.
	var glow := Color("ffd9a0")
	var glow_alpha := 0.10 if hub else 0.20
	for ring in range(16, 0, -1):
		var radius := float(ring) * height * 0.030
		draw_circle(sun_pos, radius, UIPalette.alpha(glow, glow_alpha * 0.10))
	draw_circle(sun_pos, height * 0.052, UIPalette.alpha(glow, 0.85 if not hub else 0.5))
	draw_circle(sun_pos, height * 0.038, UIPalette.alpha(Color("fff2d8"), 0.95 if not hub else 0.7))
	# Ground haze.
	var haze_top := horizon - height * 0.10
	for i in 12:
		var t := float(i) / 12.0
		draw_rect(
			Rect2(0.0, haze_top + t * height * 0.10, width, height * 0.012),
			UIPalette.alpha(Color("e8c39a"), (0.05 + 0.02 * (1.0 - t)) * (0.6 if hub else 1.0))
		)


func _draw_planet(width: float, height: float) -> void:
	var center := Vector2(width * 0.185, height * 0.23)
	var radius := minf(height * 0.082, width * 0.05)
	draw_circle(center, radius, UIPalette.alpha(Color("cfd4c4"), 0.16))
	draw_circle(center, radius * 0.92, UIPalette.alpha(Color("b9c2b4"), 0.10))
	# Rings: two flat ellipses drawn as polylines.
	for ring in [1.45, 1.70]:
		var points := PackedVector2Array()
		for i in 49:
			var angle := float(i) / 48.0 * TAU
			points.append(center + Vector2(cos(angle) * radius * ring, sin(angle) * radius * ring * 0.18))
		draw_polyline(points, UIPalette.alpha(Color("e6dcc8"), 0.14 if ring < 1.6 else 0.08), 1.2, true)


func _draw_ridges(width: float, height: float, horizon: float) -> void:
	var layers := [
		{"base": horizon + height * 0.02, "amp": height * 0.085, "color": Color("2c3f42"), "seed": 91, "rim": 0.18},
		{"base": horizon + height * 0.12, "amp": height * 0.12, "color": Color("1b2a2d"), "seed": 412, "rim": 0.12},
		{"base": horizon + height * 0.27, "amp": height * 0.16, "color": Color("0d1517"), "seed": 7, "rim": 0.0},
	]
	for layer in layers:
		var points := _ridge_points(float(layer.base), float(layer.amp), int(layer.seed), 34, width)
		_draw_ridge_fill(points, height, layer.color)
		if float(layer.rim) > 0.0:
			draw_polyline(points, UIPalette.alpha(Color("ffd9a0"), float(layer.rim)), 1.0, true)


## Fills a ridgeline with per-segment triangle pairs. Using raw primitives
## avoids polygon triangulation entirely (generated outlines can contain
## degenerate slivers that the triangulator rejects).
func _draw_ridge_fill(points: PackedVector2Array, height: float, color: Color) -> void:
	var colors := PackedColorArray([color, color, color])
	var bottom := height + 8.0
	for index in points.size() - 1:
		var a := points[index]
		var b := points[index + 1]
		if b.x <= a.x:
			continue
		var bottom_right := Vector2(b.x, bottom)
		var bottom_left := Vector2(a.x, bottom)
		draw_primitive(PackedVector2Array([a, b, bottom_right]), colors, PackedVector2Array())
		draw_primitive(PackedVector2Array([a, bottom_right, bottom_left]), colors, PackedVector2Array())


func _ridge_points(base_y: float, amplitude: float, seed_value: int, steps: int, width: float) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var phase_a := rng.randf_range(0.0, TAU)
	var phase_b := rng.randf_range(0.0, TAU)
	var points := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		var y := base_y
		y -= amplitude * (0.5 * sin(t * TAU * 1.15 + phase_a) + 0.3 * sin(t * TAU * 2.7 + phase_b) + 0.14 * sin(t * TAU * 6.1 + phase_a * 1.7))
		# Flatten the left third slightly so hero copy sits on calmer shapes.
		if t < 0.42:
			y = lerpf(base_y - amplitude * 0.2, y, 0.55 + t * 0.9)
		points.append(Vector2(t * width, y))
	return points


func _draw_spires(width: float, height: float, horizon: float) -> void:
	var spires := [
		{"x": 0.60, "h": 0.16, "w": 0.0022},
		{"x": 0.77, "h": 0.23, "w": 0.0030},
		{"x": 0.90, "h": 0.12, "w": 0.0018},
	]
	var pulse := 0.5 + 0.5 * sin(_time * 1.7)
	for spire in spires:
		var x := width * float(spire.x)
		var top_y := horizon - height * float(spire.h)
		var base_y := horizon + height * 0.05
		var thickness := maxf(1.0, width * float(spire.w))
		draw_line(Vector2(x, base_y), Vector2(x, top_y), Color("0a1113"), thickness)
		draw_line(Vector2(x - thickness * 3.0, top_y + height * 0.02), Vector2(x + thickness * 3.0, top_y + height * 0.02), Color("0a1113"), thickness * 0.7)
		var light_color := UIPalette.alpha(UIPalette.amber, 0.35 + 0.35 * pulse)
		draw_circle(Vector2(x, top_y), maxf(1.2, width * 0.0018), light_color)


func _draw_dust(width: float, height: float) -> void:
	var drift := _time * 0.004
	for mote in _dust:
		var base: Vector2 = mote.pos
		var x := fposmod(base.x + drift * float(mote.speed) * 22.0, 1.0) * width
		var y := (base.y + sin(_time * 0.35 + float(mote.phase)) * 0.004) * height
		var color := UIPalette.alpha(Color("ffe7c4"), float(mote.alpha))
		draw_circle(Vector2(x, y), float(mote.size), color)


func _draw_scrim(width: float, height: float, hub: bool) -> void:
	# Central field darkening for data readability.
	draw_rect(Rect2(0.0, 0.0, width, height), UIPalette.alpha(UIPalette.ink, 0.16 if hub else 0.05))
	# Left-to-right legibility scrim, drawn from a cached gradient texture so the
	# edge has no alpha-banding seams.
	if _left_scrim == null:
		_left_scrim = _make_gradient_texture(
			UIPalette.alpha(UIPalette.ink, 0.62 if hub else 0.56),
			Color(0.0, 0.0, 0.0, 0.0),
			true
		)
	draw_texture_rect(_left_scrim, Rect2(0.0, 0.0, width * (0.78 if hub else 0.68), height), false)
	if _bottom_scrim == null:
		_bottom_scrim = _make_gradient_texture(
			Color(0.0, 0.0, 0.0, 0.0),
			UIPalette.alpha(UIPalette.ink, 0.42),
			false
		)
	draw_texture_rect(_bottom_scrim, Rect2(0.0, height * 0.68, width, height * 0.32), false)


func _make_gradient_texture(from_color: Color, to_color: Color, horizontal: bool) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, from_color)
	gradient.set_color(1, to_color)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 8
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.0, 0.5) if horizontal else Vector2(0.5, 0.0)
	texture.fill_to = Vector2(1.0, 0.5) if horizontal else Vector2(0.5, 1.0)
	return texture
