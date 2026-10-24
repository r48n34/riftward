class_name UIHudScope
extends Control
## Full-screen precision scope overlay for high-zoom weapons (DMR / rail).
## A procedurally generated radial mask leaves a circular lens; the reticle,
## mil-dots and readouts fade in with ADS strength.

var strength := 0.0
var zoom := 1.0
var effective_range := 120.0

var _mask: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ensure_mask()
	visible = false


func set_scope(new_strength: float, new_zoom: float = 1.0, range_m: float = 120.0) -> void:
	strength = clampf(new_strength, 0.0, 1.0)
	zoom = maxf(0.1, new_zoom)
	effective_range = maxf(1.0, range_m)
	visible = strength > 0.02
	queue_redraw()


func _ensure_mask() -> void:
	if _mask != null:
		return
	var resolution := 256
	var image := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	var center := Vector2(resolution - 1, resolution - 1) * 0.5
	var max_radius := float(resolution) * 0.5
	for y in resolution:
		for x in resolution:
			var distance := Vector2(float(x), float(y)).distance_to(center) / max_radius
			# 0 inside the lens, 1 outside; a short ramp softens the rim.
			var alpha := clampf((distance - 0.80) / 0.07, 0.0, 1.0)
			image.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))
	_mask = ImageTexture.create_from_image(image)


func _draw() -> void:
	if strength <= 0.02:
		return
	var square := minf(size.x, size.y)
	var center := size * 0.5
	var lens_radius := square * 0.42
	var alpha := strength
	var ink := UIPalette.alpha(Color.BLACK, alpha)
	# Side bars keep the lens circular on widescreen displays.
	if size.x > square:
		var side := (size.x - square) * 0.5
		draw_rect(Rect2(0.0, 0.0, side, size.y), ink)
		draw_rect(Rect2(size.x - side, 0.0, side, size.y), ink)
	elif size.y > square:
		var band := (size.y - square) * 0.5
		draw_rect(Rect2(0.0, 0.0, size.x, band), ink)
		draw_rect(Rect2(0.0, size.y - band, size.x, band), ink)
	# The mask itself covers the square portion.
	draw_texture_rect(_mask, Rect2(center - Vector2(square, square) * 0.5, Vector2(square, square)), false, Color(1, 1, 1, alpha))
	# Lens ring and reticle.
	var ring_color := UIPalette.alpha(UIPalette.ivory, 0.55 * alpha)
	draw_arc(center, lens_radius, 0.0, TAU, 96, ring_color, 1.2)
	draw_arc(center, lens_radius * 0.84, 0.0, TAU, 96, UIPalette.alpha(UIPalette.muted_dim, 0.25 * alpha), 1.0)
	var reticle := UIPalette.alpha(UIPalette.ivory, 0.78 * alpha)
	var gap := lens_radius * 0.16
	draw_line(center + Vector2(-lens_radius * 0.72, 0.0), center + Vector2(-gap, 0.0), reticle, 1.0)
	draw_line(center + Vector2(gap, 0.0), center + Vector2(lens_radius * 0.72, 0.0), reticle, 1.0)
	draw_line(center + Vector2(0.0, -lens_radius * 0.72), center + Vector2(0.0, -gap), reticle, 1.0)
	draw_line(center + Vector2(0.0, gap), center + Vector2(0.0, lens_radius * 0.72), reticle, 1.0)
	draw_circle(center, 1.6, reticle)
	# Mil-dots along the horizontal and vertical axes.
	for i in range(1, 5):
		var distance := lens_radius * (0.18 + float(i) * 0.11)
		draw_circle(center + Vector2(distance, 0.0), 1.0, reticle)
		draw_circle(center + Vector2(-distance, 0.0), 1.0, reticle)
		draw_circle(center + Vector2(0.0, distance), 1.0, reticle)
	# Readouts.
	var label_color := UIPalette.alpha(UIPalette.ivory, 0.8 * alpha)
	var zoom_value := 1.0 / maxf(0.2, zoom)
	draw_string(
		UIFonts.mono(true),
		center + Vector2(-lens_radius * 0.9, lens_radius * 0.86),
		"%.1fx" % zoom_value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		label_color
	)
	draw_string(
		UIFonts.mono(false),
		center + Vector2(lens_radius * 0.42, lens_radius * 0.86),
		"%d m" % int(effective_range),
		HORIZONTAL_ALIGNMENT_RIGHT,
		lens_radius * 0.48,
		11,
		UIPalette.alpha(UIPalette.muted, 0.8 * alpha)
	)
