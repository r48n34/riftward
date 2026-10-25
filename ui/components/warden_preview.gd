class_name UIWardenPreview
extends Control
## Stylised code-drawn Warden bust. Reflects the equipped suit, dye, weapon skin
## and pet shell so cosmetics have obvious, immediate feedback.
##
## `configure_preview()` lets Locker tiles render arbitrary cosmetic colour
## combinations without equipping them. Compact previews draw the same bust
## smaller, skip the bottom text plate and thin out the stage grid.

const PREVIEW_SIZE := Vector2(300, 340)
const PREVIEW_SIZE_COMPACT := Vector2(160, 150)
const PREVIEW_ASPECT := 300.0 / 340.0

var compact := false

var _time := 0.0
var _redraw_accum := 0.0
var _override_suit := Color.TRANSPARENT
var _override_suit_accent := Color.TRANSPARENT
var _override_dye := Color.TRANSPARENT
var _override_skin := Color.TRANSPARENT
var _override_skin_accent := Color.TRANSPARENT
var _override_shell := Color.TRANSPARENT
var _override_shell_accent := Color.TRANSPARENT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_preview_size()
	_update_process_state()


## Configure the preview for a card/tile. Non-transparent colour arguments win
## over equipped cosmetics; TRANSPARENT keeps the equipped (or fallback) colour.
func configure_preview(
	compact: bool = false,
	suit_color: Color = Color.TRANSPARENT,
	suit_accent: Color = Color.TRANSPARENT,
	dye_color: Color = Color.TRANSPARENT,
	skin_color: Color = Color.TRANSPARENT,
	skin_accent: Color = Color.TRANSPARENT,
	shell_color: Color = Color.TRANSPARENT,
	shell_accent: Color = Color.TRANSPARENT
) -> void:
	self.compact = compact
	_override_suit = suit_color
	_override_suit_accent = suit_accent
	_override_dye = dye_color
	_override_skin = skin_color
	_override_skin_accent = skin_accent
	_override_shell = shell_color
	_override_shell_accent = shell_accent
	_apply_preview_size()
	_update_process_state()
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _apply_preview_size() -> void:
	custom_minimum_size = PREVIEW_SIZE_COMPACT if compact else PREVIEW_SIZE


func _update_process_state() -> void:
	# Compact locker tiles are static; the larger hero bust keeps its idle bob.
	set_process(not UIPalette.reduce_motion and not compact)


func _process(delta: float) -> void:
	if UIPalette.reduce_motion or compact:
		set_process(false)
		return
	_time += delta
	_redraw_accum += delta
	if _redraw_accum >= 1.0 / 24.0:
		_redraw_accum = 0.0
		queue_redraw()


func _override_color(slot: String) -> Color:
	match slot:
		"suit":
			return _override_suit
		"dye":
			return _override_dye
		"weapon_skin":
			return _override_skin
		"pet_shell":
			return _override_shell
		_:
			return Color.TRANSPARENT


func _override_accent(slot: String) -> Color:
	match slot:
		"suit":
			return _override_suit_accent
		"weapon_skin":
			return _override_skin_accent
		"pet_shell":
			return _override_shell_accent
		_:
			return Color.TRANSPARENT


func _cosmetic_color(slot: String, fallback: Color) -> Color:
	var override := _override_color(slot)
	if override.a > 0.0:
		return override
	if ProfileState == null:
		return fallback
	var cosmetic_id := ProfileState.get_equipped_cosmetic(slot)
	if ContentDB == null:
		return fallback
	var cosmetic := ContentDB.get_cosmetic(StringName(cosmetic_id))
	if cosmetic == null:
		return fallback
	return cosmetic.color


func _cosmetic_accent(slot: String, fallback: Color) -> Color:
	var override := _override_accent(slot)
	if override.a > 0.0:
		return override
	if ProfileState == null:
		return fallback
	var cosmetic_id := ProfileState.get_equipped_cosmetic(slot)
	if ContentDB == null:
		return fallback
	var cosmetic := ContentDB.get_cosmetic(StringName(cosmetic_id))
	if cosmetic == null:
		return fallback
	return cosmetic.accent


## In compact mode the bust is fitted into a smaller centred stage so it reads
## as a tile preview instead of a full-bleed hero shot.
func _stage_rect() -> Rect2:
	if not compact:
		return Rect2(Vector2.ZERO, size)
	if size.x < 20.0 or size.y < 20.0:
		return Rect2(Vector2.ZERO, size)
	var art_width := minf(size.x, size.y * PREVIEW_ASPECT)
	var art_height := art_width / PREVIEW_ASPECT
	return Rect2((size - Vector2(art_width, art_height)) * 0.5, Vector2(art_width, art_height))


func _draw() -> void:
	var stage := _stage_rect()
	var width := stage.size.x
	var height := stage.size.y
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
	draw_rect(Rect2(Vector2.ZERO, size), UIPalette.alpha(UIPalette.ink, 0.35 if not compact else 0.22))
	var rows := 7 if not compact else 3
	var cols := 9 if not compact else 4
	for i in rows:
		var t := float(i) / float(maxi(1, rows - 1))
		var y := stage.position.y + height * lerpf(0.30, 0.92, t)
		draw_line(Vector2(stage.position.x, y), Vector2(stage.end.x, y), UIPalette.alpha(UIPalette.line, 0.28), 1.0)
	for i in cols:
		var t := float(i) / float(maxi(1, cols - 1))
		var x := stage.position.x + width * lerpf(0.08, 0.92, t)
		draw_line(Vector2(x, stage.position.y + height * 0.28), Vector2(x, stage.end.y), UIPalette.alpha(UIPalette.line, 0.18), 1.0)
	# Sun wash from top right.
	var rays := 8 if not compact else 3
	for i in rays:
		var radius := height * (0.10 + float(i) * (0.42 / float(rays)))
		draw_circle(stage.position + Vector2(width * 0.78, height * 0.12), radius, UIPalette.alpha(UIPalette.amber, 0.012))

	# Ground shadow.
	draw_set_transform(stage.position + Vector2(width * 0.5, height * 0.87), 0.0, Vector2(1.0, 0.24))
	draw_circle(Vector2.ZERO, width * 0.20, UIPalette.alpha(UIPalette.ink, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var p := func(nx: float, ny: float) -> Vector2:
		return stage.position + Vector2(width * nx, height * ny)

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

	# Driftling companion. Compact previews are static (no bob).
	var bob := sin(_time * 1.6) * height * 0.012 if not UIPalette.reduce_motion and not compact else 0.0
	var drone_center: Vector2 = p.call(0.79, 0.30) + Vector2(0.0, bob)
	draw_circle(drone_center, width * 0.052, UIPalette.alpha(UIPalette.ink, 0.35))
	draw_circle(drone_center, width * 0.040, shell)
	draw_circle(drone_center, width * 0.017, shell_accent)
	draw_circle(drone_center, width * 0.008, UIPalette.ivory)
	for angle_v in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		var angle: float = float(angle_v)
		var fin: Vector2 = drone_center + Vector2(cos(angle), sin(angle)) * width * 0.055
		draw_line(drone_center, fin, UIPalette.alpha(shell, 0.7), 1.4)

	# Vignette text plate (skipped by compact locker tiles).
	if not compact:
		draw_string(
			UIFonts.mono(true),
			stage.position + Vector2(width * 0.045, height * 0.955),
			"WARDEN // SUIT LINK ACTIVE",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			UIPalette.alpha(UIPalette.muted, 0.8)
		)
