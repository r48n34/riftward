class_name UIWardenPreview
extends Control
## Stylised code-drawn Warden bust. Reflects the equipped suit, dye, weapon skin
## and pet shell so cosmetics have obvious, immediate feedback.

var _time := 0.0
var _redraw_accum := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300, 340)
	set_process(not UIPalette.reduce_motion)


func refresh() -> void:
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


func _cosmetic_color(slot: String, fallback: Color) -> Color:
	var cosmetic_id := ProfileState.get_equipped_cosmetic(slot)
	var cosmetic := ContentDB.get_cosmetic(StringName(cosmetic_id))
	if cosmetic == null:
		return fallback
	return cosmetic.color


func _cosmetic_accent(slot: String, fallback: Color) -> Color:
	var cosmetic_id := ProfileState.get_equipped_cosmetic(slot)
	var cosmetic := ContentDB.get_cosmetic(StringName(cosmetic_id))
	if cosmetic == null:
		return fallback
	return cosmetic.accent


func _draw() -> void:
	var width := size.x
	var height := size.y
	if width < 20.0 or height < 20.0:
		return
	var suit := _cosmetic_color("suit", Color("f4efe5"))
	var suit_dark := UIPalette.darken(suit, 0.18)
	var accent := _cosmetic_accent("suit", UIPalette.mint)
	var dye := _cosmetic_color("dye", UIPalette.mint)
	var skin := _cosmetic_color("weapon_skin", Color("f4efe5"))
	var skin_accent := _cosmetic_accent("weapon_skin", UIPalette.mint)
	var shell := _cosmetic_color("pet_shell", Color("f4efe5"))
	var shell_accent := _cosmetic_accent("pet_shell", UIPalette.mint)

	# Backdrop / stage.
	draw_rect(Rect2(Vector2.ZERO, size), UIPalette.alpha(UIPalette.ink, 0.35))
	for i in 7:
		var y := height * (0.30 + float(i) * 0.088)
		draw_line(Vector2(0.0, y), Vector2(width, y), UIPalette.alpha(UIPalette.line, 0.28), 1.0)
	for i in 9:
		var x := width * (0.08 + float(i) * 0.105)
		draw_line(Vector2(x, height * 0.28), Vector2(x, height), UIPalette.alpha(UIPalette.line, 0.18), 1.0)
	# Sun wash from top right.
	for i in 8:
		var radius := height * (0.10 + float(i) * 0.06)
		draw_circle(Vector2(width * 0.78, height * 0.12), radius, UIPalette.alpha(UIPalette.amber, 0.012))

	# Ground shadow.
	draw_set_transform(Vector2(width * 0.5, height * 0.87), 0.0, Vector2(1.0, 0.24))
	draw_circle(Vector2.ZERO, width * 0.20, UIPalette.alpha(UIPalette.ink, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var p := func(nx: float, ny: float) -> Vector2:
		return Vector2(width * nx, height * ny)

	# Cloak behind the body.
	var cloak := PackedVector2Array([
		p.call(0.36, 0.34), p.call(0.64, 0.34), p.call(0.70, 0.78), p.call(0.30, 0.78),
	])
	draw_colored_polygon(cloak, UIPalette.darken(suit, 0.28))

	# Legs.
	draw_colored_polygon(PackedVector2Array([p.call(0.435, 0.62), p.call(0.49, 0.62), p.call(0.475, 0.86), p.call(0.425, 0.86)]), suit_dark)
	draw_colored_polygon(PackedVector2Array([p.call(0.51, 0.62), p.call(0.565, 0.62), p.call(0.575, 0.86), p.call(0.525, 0.86)]), suit_dark)
	# Boots.
	draw_rect(Rect2(p.call(0.405, 0.84) as Vector2, Vector2(width * 0.075, height * 0.035)), UIPalette.darken(accent, 0.35))
	draw_rect(Rect2(p.call(0.52, 0.84) as Vector2, Vector2(width * 0.075, height * 0.035)), UIPalette.darken(accent, 0.35))

	# Torso.
	var torso := PackedVector2Array([
		p.call(0.37, 0.33), p.call(0.63, 0.33), p.call(0.66, 0.50), p.call(0.61, 0.63), p.call(0.39, 0.63), p.call(0.34, 0.50),
	])
	draw_colored_polygon(torso, suit)
	# Chest plate / dye panels.
	draw_colored_polygon(PackedVector2Array([
		p.call(0.42, 0.36), p.call(0.58, 0.36), p.call(0.60, 0.47), p.call(0.40, 0.47),
	]), UIPalette.mix(suit, dye, 0.55))
	draw_line(p.call(0.40, 0.48), p.call(0.60, 0.48), UIPalette.alpha(accent, 0.8), 2.0)
	# Belt.
	draw_rect(Rect2(p.call(0.385, 0.60) as Vector2, Vector2(width * 0.23, height * 0.022)), UIPalette.alpha(UIPalette.ink, 0.55))

	# Shoulders.
	draw_circle(p.call(0.335, 0.375), width * 0.055, suit_dark)
	draw_circle(p.call(0.665, 0.375), width * 0.055, suit_dark)
	draw_circle(p.call(0.335, 0.375), width * 0.028, dye)
	draw_circle(p.call(0.665, 0.375), width * 0.028, dye)
	# Arms.
	draw_line(p.call(0.325, 0.40), p.call(0.30, 0.56), suit_dark, width * 0.045)
	draw_line(p.call(0.675, 0.40), p.call(0.70, 0.56), suit_dark, width * 0.045)

	# Head + helmet.
	draw_circle(p.call(0.5, 0.245), width * 0.062, suit)
	draw_circle(p.call(0.5, 0.235), width * 0.058, UIPalette.darken(suit, 0.12))
	draw_rect(Rect2(p.call(0.452, 0.222) as Vector2, Vector2(width * 0.096, height * 0.035)), UIPalette.alpha(UIPalette.ink, 0.85))
	draw_line(p.call(0.456, 0.238), p.call(0.544, 0.238), accent, 2.4)
	draw_line(p.call(0.5, 0.18), p.call(0.5, 0.155), UIPalette.alpha(dye, 0.9), 2.0)

	# Chest core.
	draw_circle(p.call(0.5, 0.435), width * 0.030, UIPalette.alpha(accent, 0.22))
	draw_circle(p.call(0.5, 0.435), width * 0.016, accent)

	# Rifle across the chest.
	var rifle_top: Vector2 = p.call(0.29, 0.60)
	var rifle_bottom: Vector2 = p.call(0.71, 0.50)
	draw_line(rifle_top, rifle_bottom, UIPalette.darken(skin, 0.35), width * 0.036)
	draw_line(rifle_top.lerp(rifle_bottom, 0.12), rifle_bottom.lerp(rifle_top, 0.08), skin, width * 0.018)
	draw_line(rifle_top.lerp(rifle_bottom, 0.42), rifle_bottom.lerp(rifle_top, 0.36), skin_accent, width * 0.008)
	draw_circle(p.call(0.34, 0.585), width * 0.022, UIPalette.darken(skin, 0.5))

	# Driftling companion.
	var bob := sin(_time * 1.6) * height * 0.012 if not UIPalette.reduce_motion else 0.0
	var drone_center: Vector2 = p.call(0.79, 0.30) + Vector2(0.0, bob)
	draw_circle(drone_center, width * 0.052, UIPalette.alpha(UIPalette.ink, 0.35))
	draw_circle(drone_center, width * 0.040, shell)
	draw_circle(drone_center, width * 0.017, shell_accent)
	draw_circle(drone_center, width * 0.008, UIPalette.ivory)
	for angle_v in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		var angle: float = float(angle_v)
		var fin: Vector2 = drone_center + Vector2(cos(angle), sin(angle)) * width * 0.055
		draw_line(drone_center, fin, UIPalette.alpha(shell, 0.7), 1.4)

	# Vignette text plate.
	draw_string(
		UIFonts.mono(true),
		Vector2(width * 0.045, height * 0.955),
		"WARDEN // SUIT LINK ACTIVE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		UIPalette.alpha(UIPalette.muted, 0.8)
	)
