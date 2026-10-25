class_name UIAllyPortrait
extends Control
## Code-drawn helmeted Warden portrait for squad roster / active slot cards.
## Ally identity (colour, role insignia, visor treatment) comes from
## ContentDB.get_ally(); rivets and small details are seeded from the ally id.

var ally_id: StringName = &""
var diameter := 72

var _ally: AllyData = null
var _accent := UIPalette.mint
var _armor := UIPalette.surface_high
var _armor_dark := UIPalette.surface
var _visor := UIPalette.mint
var _role := &"medic"
var _details: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(72, 72)
	resized.connect(queue_redraw)


func configure(ally_id: StringName, diameter: int = 72) -> void:
	self.ally_id = ally_id
	self.diameter = maxi(24, diameter)
	_ally = null
	if ContentDB != null:
		_ally = ContentDB.get_ally(ally_id)
	if _ally != null:
		_role = _ally.role
		_accent = _ally.color
	else:
		_role = _role_from_id(ally_id)
		_accent = _role_color(_role)
	if _accent.a <= 0.001:
		_accent = _role_color(_role)
	_armor = UIPalette.mix(UIPalette.surface_high, _accent, 0.28)
	_armor_dark = UIPalette.darken(_armor, 0.22)
	_visor = UIPalette.brighten(_accent, 0.25)
	_build_details()
	custom_minimum_size = Vector2(self.diameter, self.diameter)
	if not is_inside_tree():
		size = Vector2(self.diameter, self.diameter)
	queue_redraw()


func get_ally_id() -> StringName:
	return ally_id


# ---------------------------------------------------------------------------
# Resolution
# ---------------------------------------------------------------------------

func _role_from_id(value: StringName) -> StringName:
	match absi(String(value).hash()) % 4:
		0:
			return &"medic"
		1:
			return &"heavy"
		2:
			return &"scout"
		_:
			return &"engineer"


func _role_color(role: StringName) -> Color:
	match role:
		&"heavy":
			return UIPalette.amber
		&"scout":
			return UIPalette.blue
		&"engineer":
			return UIPalette.violet
		_:
			return UIPalette.mint


func _build_details() -> void:
	_details.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(String(ally_id).hash())
	for index in 3:
		_details.append({
			"pos": Vector2(rng.randf_range(-0.36, 0.36), rng.randf_range(-0.46, -0.12)),
			"radius": rng.randf_range(0.016, 0.03),
			"light": rng.randf() > 0.4,
		})
	if rng.randf() > 0.55:
		_details.append({
			"pos": Vector2(rng.randf_range(-0.5, -0.24), rng.randf_range(0.38, 0.6)),
			"radius": rng.randf_range(0.014, 0.025),
			"light": false,
		})


# ---------------------------------------------------------------------------
# Draw
# ---------------------------------------------------------------------------

func _pt(normalized: Vector2) -> Vector2:
	var side := minf(size.x, size.y)
	var radius := side * 0.5 - 1.0
	return size * 0.5 + normalized * radius


func _filln(values: Array, color: Color) -> void:
	var points := PackedVector2Array()
	for value in values:
		points.append(_pt(value))
	draw_colored_polygon(points, color)


func _outlinen(values: Array, color: Color, width: float = 1.0, closed: bool = true) -> void:
	var points := PackedVector2Array()
	for value in values:
		points.append(_pt(value))
	if closed and points.size() > 1:
		points.append(points[0])
	draw_polyline(points, color, _line_width(width), true)


func _linen(a: Vector2, b: Vector2, color: Color, width: float = 1.0) -> void:
	draw_line(_pt(a), _pt(b), color, _line_width(width), true)


func _circlen(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(_pt(center), maxf(0.7, minf(size.x, size.y) * 0.5 * radius), color)


func _line_width(width: float) -> float:
	return maxf(1.0, minf(size.x, size.y) / 72.0 * width)


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side < 14.0:
		return
	var center := size * 0.5
	var radius := side * 0.5 - 1.0
	# Backdrop and rim.
	draw_circle(center, radius, UIPalette.alpha(UIPalette.ink, 0.68))
	draw_circle(center + Vector2(0.0, -radius * 0.12), radius * 0.9, UIPalette.alpha(UIPalette.mix(UIPalette.surface_high, _accent, 0.08), 0.55))
	draw_arc(center, radius, 0.0, TAU, 48, UIPalette.alpha(_accent, 0.92), _line_width(2.6), true)
	draw_arc(center, radius * 0.94, 0.0, TAU, 48, UIPalette.alpha(UIPalette.ink, 0.4), 1.0, true)
	# Shoulders / chest.
	_filln([
		Vector2(-0.66, 0.88), Vector2(-0.46, 0.3), Vector2(0.46, 0.3),
		Vector2(0.66, 0.88), Vector2(0.36, 0.94), Vector2(-0.36, 0.94),
	], _armor_dark)
	_filln([
		Vector2(-0.44, 0.34), Vector2(0.44, 0.34), Vector2(0.36, 0.78),
		Vector2(0.2, 0.9), Vector2(-0.2, 0.9), Vector2(-0.36, 0.78),
	], _armor)
	_linen(Vector2(-0.32, 0.36), Vector2(0.32, 0.36), UIPalette.alpha(_visor, 0.45), 1.0)
	_linen(Vector2(-0.3, 0.6), Vector2(0.3, 0.6), UIPalette.alpha(UIPalette.ivory, 0.16), 0.8)
	# Shoulder pads.
	_filln([Vector2(-0.74, 0.58), Vector2(-0.52, 0.38), Vector2(-0.42, 0.68), Vector2(-0.62, 0.82)], _armor_dark)
	_filln([Vector2(0.74, 0.58), Vector2(0.52, 0.38), Vector2(0.42, 0.68), Vector2(0.62, 0.82)], _armor_dark)
	# Helmet dome and jaw.
	_circlen(Vector2(0.0, -0.24), 0.44, _armor)
	_circlen(Vector2(0.0, -0.11), 0.36, _armor_dark)
	_filln([
		Vector2(-0.33, -0.21), Vector2(0.33, -0.21), Vector2(0.3, 0.02),
		Vector2(0.18, 0.11), Vector2(-0.18, 0.11), Vector2(-0.3, 0.02),
	], UIPalette.alpha(UIPalette.ink, 0.88))
	_linen(Vector2(-0.24, -0.06), Vector2(0.24, -0.06), _visor, 1.6)
	_linen(Vector2(-0.32, -0.19), Vector2(0.32, -0.19), UIPalette.alpha(UIPalette.ivory, 0.28), 0.8)
	_linen(Vector2(-0.33, 0.16), Vector2(0.33, 0.16), UIPalette.alpha(_accent, 0.4), 0.8)
	# Ear guards and antenna / headset.
	_circlen(Vector2(-0.42, -0.02), 0.1, _armor_dark)
	_circlen(Vector2(0.42, -0.02), 0.1, _armor_dark)
	_circlen(Vector2(-0.42, -0.02), 0.03, UIPalette.alpha(_visor, 0.8))
	_circlen(Vector2(0.42, -0.02), 0.03, UIPalette.alpha(_visor, 0.8))
	_linen(Vector2(0.42, -0.08), Vector2(0.54, -0.34), UIPalette.alpha(_armor, 0.9), 1.2)
	_circlen(Vector2(0.54, -0.34), 0.035, _visor)
	_draw_role_insignia()
	_draw_role_helmet_detail()
	# Seeded rivets / wear.
	for detail in _details:
		var point: Vector2 = detail["pos"]
		var tint := UIPalette.alpha(UIPalette.ivory, 0.35) if bool(detail["light"]) else UIPalette.alpha(UIPalette.ink, 0.5)
		_circlen(point, float(detail["radius"]), tint)
	# Soft vignette at the bottom of the disc.
	draw_arc(center, radius * 0.985, PI * 0.15, PI * 0.85, 24, UIPalette.alpha(UIPalette.ink, 0.28), _line_width(3.0), true)


func _draw_role_insignia() -> void:
	var tint := UIPalette.alpha(_visor, 0.95)
	match _role:
		&"heavy":
			# Shield chevron on the chest.
			_linen(Vector2(-0.12, 0.5), Vector2(0.12, 0.5), tint, 1.6)
			_linen(Vector2(-0.12, 0.5), Vector2(0.0, 0.65), tint, 1.6)
			_linen(Vector2(0.12, 0.5), Vector2(0.0, 0.65), tint, 1.6)
			_linen(Vector2(0.0, 0.65), Vector2(0.0, 0.74), UIPalette.alpha(tint, 0.6), 1.0)
		&"scout":
			_outlinen([Vector2(-0.12, 0.52), Vector2(0.12, 0.52), Vector2(0.0, 0.72)], tint, 1.4)
			_circlen(Vector2(0.0, 0.58), 0.025, UIPalette.alpha(UIPalette.ink, 0.8))
		&"engineer":
			_circlen(Vector2(0.0, 0.6), 0.1, UIPalette.alpha(UIPalette.ink, 0.45))
			_circlen(Vector2(0.0, 0.6), 0.085, UIPalette.alpha(tint, 0.18))
			_circlen(Vector2(0.0, 0.6), 0.03, tint)
			for index in 2:
				var dx := -0.085 if index == 0 else 0.085
				_linen(Vector2(dx, 0.6), Vector2(dx * 1.7, 0.6), UIPalette.alpha(tint, 0.7), 1.0)
		_:
			_linen(Vector2(-0.1, 0.6), Vector2(0.1, 0.6), tint, 1.8)
			_linen(Vector2(0.0, 0.5), Vector2(0.0, 0.7), tint, 1.8)


func _draw_role_helmet_detail() -> void:
	match _role:
		&"heavy":
			_linen(Vector2(-0.3, -0.35), Vector2(0.3, -0.35), UIPalette.alpha(_visor, 0.5), 1.4)
			_linen(Vector2(-0.26, -0.31), Vector2(0.26, -0.31), UIPalette.alpha(UIPalette.ink, 0.5), 1.0)
		&"scout":
			_linen(Vector2(-0.28, -0.08), Vector2(0.16, -0.13), _visor, 1.2)
			_linen(Vector2(0.03, -0.44), Vector2(0.03, -0.66), UIPalette.alpha(_armor, 0.9), 1.0)
			_circlen(Vector2(0.03, -0.66), 0.03, _visor)
		&"engineer":
			_circlen(Vector2(-0.14, -0.08), 0.075, UIPalette.alpha(UIPalette.ink, 0.8))
			_circlen(Vector2(0.16, -0.08), 0.075, UIPalette.alpha(UIPalette.ink, 0.8))
			_circlen(Vector2(-0.14, -0.08), 0.035, _visor)
			_circlen(Vector2(0.16, -0.08), 0.035, _visor)
		_:
			_linen(Vector2(-0.34, -0.3), Vector2(-0.18, -0.42), UIPalette.alpha(UIPalette.ivory, 0.3), 0.8)
