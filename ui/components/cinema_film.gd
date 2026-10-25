class_name CinemaFilmOverlay
extends Control
## Presentation layer for the loading cinema: letterbox, legibility scrims,
## vignette, scanlines and a light film grain. Drawn above the shots and below
## the chrome so the footage gets a consistent "captured drop feed" treatment.

var letterbox := 22
var grain_enabled := true
var accent := Color("62e6c3")

var _vignette: GradientTexture2D = null
var _top_scrim: GradientTexture2D = null
var _bottom_scrim: GradientTexture2D = null
var _grain_time := 0.0
var _grain_accum := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(grain_enabled and not UIPalette.reduce_motion)


func _process(delta: float) -> void:
	if UIPalette.reduce_motion:
		set_process(false)
		return
	_grain_time += delta
	_grain_accum += delta
	if _grain_accum >= 1.0 / 12.0:
		_grain_accum = 0.0
		queue_redraw()


func _draw() -> void:
	var width := size.x
	var height := size.y
	if width < 4.0 or height < 4.0:
		return
	# Legibility scrims behind the top telemetry bar and bottom operations rail.
	if _top_scrim == null:
		_top_scrim = _make_gradient(UIPalette.alpha(UIPalette.ink, 0.92), Color(0.0, 0.0, 0.0, 0.0), true)
	if _bottom_scrim == null:
		_bottom_scrim = _make_gradient(Color(0.0, 0.0, 0.0, 0.0), UIPalette.alpha(UIPalette.ink, 0.96), true)
	draw_texture_rect(_top_scrim, Rect2(0.0, 0.0, width, height * 0.20), false)
	draw_texture_rect(_bottom_scrim, Rect2(0.0, height * 0.70, width, height * 0.30), false)
	# Letterbox.
	var bar := Color(0.012, 0.019, 0.022, 1.0)
	draw_rect(Rect2(0.0, 0.0, width, letterbox), bar)
	draw_rect(Rect2(0.0, height - letterbox, width, letterbox), bar)
	# Fine scanlines.
	var scan := UIPalette.alpha(UIPalette.ink, 0.10)
	var y := float(letterbox)
	while y < height - letterbox:
		draw_rect(Rect2(0.0, y, width, 1.0), scan)
		y += 3.0
	# Vignette.
	if _vignette == null:
		_vignette = _make_vignette()
	draw_texture_rect(_vignette, Rect2(0.0, 0.0, width, height), false)
	# Film grain. Static when reduce-motion is on.
	if grain_enabled:
		var rng := RandomNumberGenerator.new()
		rng.seed = 0x51F7A11 + (0 if UIPalette.reduce_motion else int(_grain_time * 12.0) * 977)
		var grain_count := 150
		for i in grain_count:
			var px := rng.randf() * width
			var py := rng.randf() * height
			var size_px := rng.randf_range(0.5, 1.8)
			draw_circle(Vector2(px, py), size_px, UIPalette.alpha(UIPalette.ivory, rng.randf_range(0.012, 0.045)))
	# Corner registration ticks in the accent colour.
	var mark := UIPalette.alpha(accent, 0.35)
	var inset := 16.0
	var length := 12.0
	draw_line(Vector2(inset, inset), Vector2(inset + length, inset), mark, 1.0)
	draw_line(Vector2(inset, inset), Vector2(inset, inset + length), mark, 1.0)
	draw_line(Vector2(width - inset, inset), Vector2(width - inset - length, inset), mark, 1.0)
	draw_line(Vector2(width - inset, inset), Vector2(width - inset, inset + length), mark, 1.0)
	draw_line(Vector2(inset, height - inset), Vector2(inset + length, height - inset), mark, 1.0)
	draw_line(Vector2(inset, height - inset), Vector2(inset, height - inset - length), mark, 1.0)
	draw_line(Vector2(width - inset, height - inset), Vector2(width - inset - length, height - inset), mark, 1.0)
	draw_line(Vector2(width - inset, height - inset), Vector2(width - inset, height - inset - length), mark, 1.0)


func _make_gradient(from_color: Color, to_color: Color, vertical: bool) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, from_color)
	gradient.set_color(1, to_color)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 16
	texture.height = 96
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 0.0) if vertical else Vector2(0.0, 0.5)
	texture.fill_to = Vector2(0.5, 1.0) if vertical else Vector2(1.0, 0.5)
	return texture


func _make_vignette() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	gradient.set_color(1, UIPalette.alpha(UIPalette.ink, 0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 1.0)
	return texture
