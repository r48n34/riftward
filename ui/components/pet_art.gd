class_name UIPetArt
extends Control
## Code-drawn Driftling companion art: shell body, fins, lens eye and orbit rings.
## Colours come from ContentDB.get_pet(); optional shell_color/shell_accent
## overrides let the Locker preview an unequipped shell cosmetic.

var pet_id: StringName = &""
var diameter := 72
## Optional cosmetic shell overrides. TRANSPARENT keeps the pet's own colours.
var shell_color: Color = Color.TRANSPARENT
var shell_accent: Color = Color.TRANSPARENT

var _pet: PetData = null
var _core := UIPalette.mint
var _shell := UIPalette.ivory
var _shell_dark := UIPalette.surface_high
var _role := &"support"
var _details: Array[Dictionary] = []
var _seed := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(72, 72)
	resized.connect(queue_redraw)


func configure(
	pet_id: StringName,
	diameter: int = 72,
	shell_color: Color = Color.TRANSPARENT,
	shell_accent: Color = Color.TRANSPARENT
) -> void:
	self.pet_id = pet_id
	self.diameter = maxi(24, diameter)
	self.shell_color = shell_color
	self.shell_accent = shell_accent
	_pet = null
	if ContentDB != null:
		_pet = ContentDB.get_pet(pet_id)
	var own_color := UIPalette.mint
	var own_shell := UIPalette.ivory
	if _pet != null:
		_role = _pet.role
		own_color = _pet.color
		own_shell = _pet.shell_color
	else:
		_role = _role_from_id(pet_id)
		own_color = _role_color(_role)
		own_shell = UIPalette.mix(UIPalette.ivory, own_color, 0.12)
	if own_color.a <= 0.001:
		own_color = _role_color(_role)
	_core = shell_accent if shell_accent.a > 0.001 else own_color
	_shell = shell_color if shell_color.a > 0.001 else own_shell
	if _shell.a <= 0.001:
		_shell = UIPalette.ivory
	# Keep dark shells readable against the dark card background.
	var luminance := _shell.r * 0.2126 + _shell.g * 0.7152 + _shell.b * 0.0722
	if luminance < 0.2:
		_shell = UIPalette.mix(_shell, UIPalette.ivory, 0.3)
	_shell_dark = UIPalette.darken(_shell, 0.24)
	_seed = absi(String(pet_id).hash())
	_build_details()
	custom_minimum_size = Vector2(self.diameter, self.diameter)
	if not is_inside_tree():
		size = Vector2(self.diameter, self.diameter)
	queue_redraw()


func get_pet_id() -> StringName:
	return pet_id


# ---------------------------------------------------------------------------
# Resolution
# ---------------------------------------------------------------------------

func _role_from_id(value: StringName) -> StringName:
	match absi(String(value).hash()) % 3:
		0:
			return &"support"
		1:
			return &"combat"
		_:
			return &"utility"


func _role_color(role: StringName) -> Color:
	match role:
		&"combat":
			return UIPalette.amber
		&"utility":
			return UIPalette.blue
		_:
			return UIPalette.mint


func _build_details() -> void:
	_details.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 41
	for index in 3:
		var angle := rng.randf_range(-PI, 0.0)
		var distance := rng.randf_range(0.1, 0.3)
		_details.append({
			"pos": Vector2(cos(angle), sin(angle)) * distance + Vector2(0.0, -0.02),
			"radius": rng.randf_range(0.012, 0.024),
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


func _linen(a: Vector2, b: Vector2, color: Color, width: float = 1.0) -> void:
	draw_line(_pt(a), _pt(b), color, _line_width(width), true)


func _circlen(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(_pt(center), maxf(0.7, minf(size.x, size.y) * 0.5 * radius), color)


func _line_width(width: float) -> float:
	return maxf(1.0, minf(size.x, size.y) / 72.0 * width)


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 24:
		var angle := TAU * float(index) / 24.0
		points.append(_pt(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y)))
	draw_colored_polygon(points, color)


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side < 14.0:
		return
	var center := size * 0.5
	var radius := side * 0.5 - 1.0
	draw_circle(center, radius, UIPalette.alpha(UIPalette.ink, 0.66))
	draw_circle(center + Vector2(0.0, -radius * 0.1), radius * 0.86, UIPalette.alpha(UIPalette.mix(UIPalette.surface_high, _core, 0.1), 0.55))
	draw_arc(center, radius, 0.0, TAU, 48, UIPalette.alpha(_core, 0.9), _line_width(2.4), true)
	# Orbit rings behind the body.
	draw_set_transform(center, 0.0, Vector2(1.0, 0.38))
	draw_arc(Vector2.ZERO, radius * 0.84, 0.0, TAU, 40, UIPalette.alpha(_core, 0.34), 1.0, true)
	draw_arc(Vector2.ZERO, radius * 0.7, 0.0, TAU, 36, UIPalette.alpha(_core, 0.18), 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Fins behind the shell.
	for index in 5:
		var angle := -PI * 0.5 + TAU * float(index) / 5.0
		var base_angle := angle - 0.16
		var tip := Vector2(cos(angle), sin(angle)) * 0.62
		var left := Vector2(cos(base_angle), sin(base_angle)) * 0.42
		var right := Vector2(cos(base_angle + 0.32), sin(base_angle + 0.32)) * 0.42
		_filln([left, tip, right], UIPalette.alpha(UIPalette.mix(_shell, _core, 0.35), 0.8))
		_linen(tip, right, UIPalette.alpha(_core, 0.4), 0.8)
	# Shell body.
	_ellipse(Vector2(0.0, -0.02), Vector2(0.52, 0.44), _shell)
	_ellipse(Vector2(-0.03, -0.12), Vector2(0.4, 0.25), UIPalette.alpha(UIPalette.brighten(_shell, 0.12), 0.7))
	# Panel seam and rim.
	draw_arc(_pt(Vector2(0.0, -0.02)), radius * 0.5, PI * 0.08, PI * 0.92, 24, UIPalette.alpha(_shell_dark, 0.9), _line_width(1.4), true)
	draw_arc(_pt(Vector2(0.0, -0.02)), radius * 0.52, PI * 0.05, PI * 1.0, 24, UIPalette.alpha(UIPalette.ivory, 0.3), 1.0, true)
	# Eye lens.
	_circlen(Vector2(0.0, 0.04), 0.23, UIPalette.alpha(UIPalette.ink, 0.85))
	_circlen(Vector2(0.0, 0.04), 0.19, UIPalette.alpha(_core, 0.32))
	_circlen(Vector2(0.0, 0.04), 0.13, _core)
	_circlen(Vector2(0.0, 0.04), 0.065, UIPalette.alpha(UIPalette.ink, 0.85))
	_circlen(Vector2(-0.045, 0.0), 0.035, UIPalette.alpha(UIPalette.ivory, 0.9))
	# Front accent rings and stabiliser fins.
	draw_set_transform(center + Vector2(0.0, radius * 0.12), 0.0, Vector2(1.0, 0.32))
	draw_arc(Vector2.ZERO, radius * 0.5, 0.0, TAU, 32, UIPalette.alpha(_core, 0.5), _line_width(1.2), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_filln([Vector2(-0.5, 0.28), Vector2(-0.62, 0.46), Vector2(-0.36, 0.46)], UIPalette.alpha(_shell_dark, 0.9))
	_filln([Vector2(0.5, 0.28), Vector2(0.62, 0.46), Vector2(0.36, 0.46)], UIPalette.alpha(_shell_dark, 0.9))
	_draw_role_detail()
	# Seeded rivets on the shell.
	for detail in _details:
		var point: Vector2 = detail["pos"]
		_circlen(point, float(detail["radius"]), UIPalette.alpha(_shell_dark, 0.7))
	# Subtle bottom vignette.
	draw_arc(center, radius * 0.985, PI * 0.18, PI * 0.82, 20, UIPalette.alpha(UIPalette.ink, 0.26), _line_width(2.8), true)


func _draw_role_detail() -> void:
	var side := minf(size.x, size.y)
	var radius := side * 0.5 - 1.0
	match _role:
		&"combat":
			for index in 3:
				var x := -0.2 + float(index) * 0.2
				_linen(Vector2(x, 0.3), Vector2(x + 0.04, 0.42), UIPalette.alpha(UIPalette.amber, 0.85), 1.2)
			_circlen(Vector2(0.34, -0.24), 0.03, UIPalette.alpha(UIPalette.danger, 0.85))
			_circlen(Vector2(0.42, -0.16), 0.02, UIPalette.alpha(UIPalette.amber, 0.7))
		&"utility":
			_linen(Vector2(0.08, -0.42), Vector2(0.2, -0.68), UIPalette.alpha(_shell_dark, 0.95), 1.4)
			draw_arc(_pt(Vector2(0.2, -0.68)), maxf(1.0, radius * 0.14), -PI * 0.9, PI * 0.1, 12, _core, 1.2, true)
			_circlen(Vector2(0.2, -0.68), 0.03, _core)
		_:
			# Support halo and cross.
			draw_arc(_pt(Vector2(0.0, -0.08)), maxf(2.0, radius * 0.62), PI * 1.12, PI * 1.88, 20, UIPalette.alpha(_core, 0.55), 1.4, true)
			_linen(Vector2(-0.12, 0.36), Vector2(0.12, 0.36), UIPalette.alpha(_core, 0.85), 1.4)
			_linen(Vector2(0.0, 0.24), Vector2(0.0, 0.48), UIPalette.alpha(_core, 0.85), 1.4)
	# Tiny orbit mote for every role.
	_circlen(Vector2(-0.58, -0.34), 0.035, UIPalette.alpha(_core, 0.8))
