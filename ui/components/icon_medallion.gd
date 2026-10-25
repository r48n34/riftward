class_name UIIconMedallion
extends Control
## Code-drawn hexagonal icon medallion: accent ring, tinted inner plate and a
## centred line-icon texture from UIIcons. Static (redraws only on configure or
## resize), cached texture lookup and headless-safe: the icon name is reported
## even when ContentDB/UIIcons has no resource available.

var icon_name: StringName = &""
var accent: Color = UIPalette.mint
var glyph_ratio := 0.52
var filled := true

var _glyph: TextureRect = null
var _texture: Texture2D = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(40, 40)
	resized.connect(_on_resized)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_glyph()
	_layout_glyph()
	queue_redraw()


## Build the medallion. `diameter` is both axes; glyph_ratio is the icon size as
## a fraction of the medallion diameter. Safe to call before entering the tree
## and safe to call repeatedly.
func configure(
	icon_name: StringName,
	diameter: int,
	accent: Color,
	glyph_ratio: float = 0.52,
	filled: bool = true
) -> void:
	self.icon_name = icon_name
	self.accent = accent
	self.glyph_ratio = clampf(glyph_ratio, 0.2, 0.9)
	self.filled = filled
	var side := maxi(8, diameter)
	custom_minimum_size = Vector2(side, side)
	if not is_inside_tree():
		size = Vector2(side, side)
	_ensure_glyph()
	_apply_glyph()
	_layout_glyph()
	queue_redraw()


func get_icon_name() -> StringName:
	return icon_name


func _ensure_glyph() -> void:
	if _glyph != null and is_instance_valid(_glyph):
		return
	_glyph = TextureRect.new()
	_glyph.name = "Glyph"
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_glyph)


func _apply_glyph() -> void:
	_texture = UIIcons.get_icon(icon_name)
	if _glyph == null or not is_instance_valid(_glyph):
		return
	_glyph.texture = _texture
	_glyph.modulate = accent
	_glyph.visible = _texture != null


func _layout_glyph() -> void:
	if _glyph == null or not is_instance_valid(_glyph):
		return
	var side := minf(size.x, size.y)
	var glyph_side := maxf(6.0, side * clampf(glyph_ratio, 0.2, 0.9))
	_glyph.position = (size - Vector2(glyph_side, glyph_side)) * 0.5
	_glyph.size = Vector2(glyph_side, glyph_side)
	_glyph.modulate = accent


func _on_resized() -> void:
	_layout_glyph()
	queue_redraw()


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side < 8.0 or accent.a <= 0.001:
		return
	var center := size * 0.5
	var radius := side * 0.5 - 1.0
	if radius < 4.0:
		return
	var hex := PackedVector2Array()
	for index in 6:
		var angle := -PI * 0.5 + TAU * float(index) / 6.0
		hex.append(center + Vector2(cos(angle), sin(angle)) * radius)
	var disc_fill := UIPalette.alpha(accent, 0.16 if filled else 0.05)
	draw_colored_polygon(hex, disc_fill)
	var outer := hex.duplicate()
	outer.append(hex[0])
	draw_polyline(outer, UIPalette.alpha(accent, 0.95), maxf(1.0, side * 0.032), true)
	var inner := PackedVector2Array()
	for index in 6:
		var angle := -PI * 0.5 + TAU * float(index) / 6.0
		inner.append(center + Vector2(cos(angle), sin(angle)) * radius * 0.82)
	inner.append(inner[0])
	draw_polyline(inner, UIPalette.alpha(accent, 0.3), 1.0, true)
	if filled:
		draw_circle(center, radius * 0.56, UIPalette.alpha(UIPalette.ink, 0.3))
	if _texture == null:
		# Never render an empty medallion when an icon asset is missing: draw a
		# small deterministic cross so the control still reads as intentional.
		var arm := radius * clampf(glyph_ratio, 0.2, 0.9) * 0.48
		var fallback := UIPalette.alpha(accent, 0.9)
		draw_line(center + Vector2(0.0, -arm), center + Vector2(0.0, arm), fallback, 1.6, true)
		draw_line(center + Vector2(-arm, 0.0), center + Vector2(arm, 0.0), fallback, 1.6, true)
	draw_circle(hex[0], maxf(1.2, side * 0.042), accent)
