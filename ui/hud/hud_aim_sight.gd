class_name UIHudAimSight
extends Control
## Procedural ADS reticle shown for every firearm before the precision scope
## threshold kicks in. Style-specific silhouettes keep weapons readable while
## staying inside the calmer RIFTWARD HUD language.

var strength := 0.0
var weapon_style := "rifle"
var accent := Color("62e6c3")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func set_sight(new_strength: float, style: String = "rifle", new_accent: Color = Color("62e6c3")) -> void:
	strength = clampf(new_strength, 0.0, 1.0)
	weapon_style = style if not style.is_empty() else "rifle"
	accent = new_accent
	visible = strength > 0.015
	if visible:
		queue_redraw()


func _draw() -> void:
	if strength <= 0.015:
		return
	var center := size * 0.5
	var alpha := strength
	var main := UIPalette.alpha(UIPalette.mix(UIPalette.ivory, accent, 0.45), alpha)
	var glow := UIPalette.alpha(accent, alpha * 0.9)
	var shadow := UIPalette.alpha(UIPalette.ink, alpha * 0.7)
	match weapon_style:
		"pistol":
			_draw_pistol(center, main, glow, shadow, alpha)
		"smg":
			_draw_smg(center, main, glow, shadow, alpha)
		"shotgun":
			_draw_shotgun(center, main, glow, shadow, alpha)
		"lmg":
			_draw_lmg(center, main, glow, shadow, alpha)
		"launcher":
			_draw_launcher(center, main, glow, shadow, alpha)
		"arc":
			_draw_arc(center, main, glow, shadow, alpha)
		_:
			_draw_rifle(center, main, glow, shadow, alpha)


func _line(from: Vector2, to: Vector2, color: Color, width: float = 1.4) -> void:
	draw_line(from, to, color, width)


func _dot(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius, color)


func _draw_rifle(center: Vector2, main: Color, glow: Color, shadow: Color, alpha: float) -> void:
	# Holo-style ring with cardinal ticks and a bright centre pip.
	var radius := 21.0
	draw_arc(center, radius, 0.0, TAU, 48, UIPalette.alpha(shadow, alpha * 0.9), 3.2)
	draw_arc(center, radius, 0.0, TAU, 48, main, 1.3)
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var dir: Vector2 = direction
		_line(center + dir * (radius - 6.0), center + dir * (radius + 7.0), main, 1.6)
	_dot(center, 3.4, UIPalette.alpha(shadow, alpha))
	_dot(center, 2.0, glow)
	draw_arc(center, radius * 0.45, 0.0, TAU, 24, UIPalette.alpha(glow, alpha * 0.18), 1.0)


func _draw_pistol(center: Vector2, main: Color, glow: Color, shadow: Color, alpha: float) -> void:
	# Minimal red-dot style reticle with a low-profile ring.
	draw_arc(center, 12.0, 0.0, TAU, 28, UIPalette.alpha(shadow, alpha * 0.85), 2.4)
	draw_arc(center, 12.0, 0.0, TAU, 28, UIPalette.alpha(main, alpha * 0.85), 1.0)
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var dir: Vector2 = direction
		_line(center + dir * 13.0, center + dir * 20.0, UIPalette.alpha(main, alpha * 0.8), 1.1)
	_dot(center, 3.2, UIPalette.alpha(shadow, alpha))
	_dot(center, 1.9, glow)


func _draw_smg(center: Vector2, main: Color, glow: Color, shadow: Color, alpha: float) -> void:
	# Short-range chevron cluster.
	for offset in [Vector2(-17.0, 0.0), Vector2(17.0, 0.0)]:
		var dir: Vector2 = offset
		var x := dir.x
		_line(center + Vector2(x * 1.1, -5.0), center + Vector2(x, 1.0), main, 1.5)
		_line(center + Vector2(x, 1.0), center + Vector2(x * 1.1, 8.0), main, 1.5)
		_line(center + Vector2(x * 1.1, -5.0), center + Vector2(x * 1.1, 8.0), UIPalette.alpha(shadow, alpha * 0.8), 0.9)
	_line(center + Vector2(-5.0, -11.0), center + Vector2(5.0, -11.0), main, 1.2)
	_line(center + Vector2(-5.0, 11.0), center + Vector2(5.0, 11.0), main, 1.2)
	_dot(center, 2.6, shadow)
	_dot(center, 1.6, glow)


func _draw_shotgun(center: Vector2, main: Color, glow: Color, shadow: Color, alpha: float) -> void:
	# Pellet spread ring.
	draw_arc(center, 27.0, 0.0, TAU, 48, UIPalette.alpha(shadow, alpha * 0.8), 2.4)
	draw_arc(center, 17.0, 0.0, TAU, 32, UIPalette.alpha(main, alpha * 0.65), 1.0)
	draw_arc(center, 7.0, 0.0, TAU, 20, UIPalette.alpha(glow, alpha * 0.8), 1.0)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var dir := Vector2(cos(angle), sin(angle))
		_dot(center + dir * 27.0, 1.1, main)
	_dot(center, 1.8, glow)


func _draw_lmg(center: Vector2, main: Color, glow: Color, shadow: Color, alpha: float) -> void:
	# Heavy bracket reticle.
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var dir: Vector2 = direction
		var start := center + dir * 13.0
		var end := center + dir * 31.0
		_line(start, end, UIPalette.alpha(shadow, alpha * 0.8), 3.0)
		_line(start, end, main, 1.6)
		_line(end, end + Vector2(-dir.y, dir.x) * 6.0, main, 1.4)
	_dot(center, 3.0, shadow)
	_dot(center, 1.8, glow)


func _draw_launcher(center: Vector2, main: Color, glow: Color, shadow: Color, alpha: float) -> void:
	draw_arc(center, 24.0, 0.0, TAU, 40, UIPalette.alpha(shadow, alpha * 0.8), 2.5)
	draw_arc(center, 24.0, 0.0, TAU, 40, UIPalette.alpha(main, alpha * 0.8), 1.2)
	for i in 4:
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		var dir := Vector2(cos(angle), sin(angle))
		_line(center + dir * 8.0, center + dir * 16.0, main, 1.3)
	_dot(center, 4.0, glow)
	draw_line(center + Vector2(-38.0, 0.0), center + Vector2(-26.0, 0.0), UIPalette.alpha(main, alpha * 0.5), 1.0)
	draw_line(center + Vector2(26.0, 0.0), center + Vector2(38.0, 0.0), UIPalette.alpha(main, alpha * 0.5), 1.0)


func _draw_arc(center: Vector2, main: Color, glow: Color, shadow: Color, alpha: float) -> void:
	# Angular arc-rifle reticle.
	var points := PackedVector2Array()
	for i in 6:
		var angle := -PI * 0.5 + TAU * float(i) / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * 22.0)
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		_line(a, b, UIPalette.alpha(shadow, alpha * 0.75), 2.6)
		_line(a, b, main, 1.1)
	draw_circle(center, 7.0, UIPalette.alpha(shadow, alpha * 0.55))
	draw_arc(center, 7.0, 0.0, TAU, 24, glow, 1.2)
	_dot(center, 2.0, glow)
