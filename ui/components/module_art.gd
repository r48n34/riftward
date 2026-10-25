class_name UIModuleArt
extends Control
## Code-drawn 2.5D isometric render of a single outpost module on its
## foundation pad. Every module has a distinct, readable silhouette and tier 0
## is shown as a blueprint ghost so planned construction reads immediately.
## Pure draw_* primitives: no textures, deterministic frame, safe headless.

const MODULE_CODES := {
	&"command_nexus": "NX-01",
	&"foundry": "FN-02",
	&"armory": "AR-03",
	&"infirmary": "MD-04",
	&"barracks": "BK-05",
	&"drift_den": "DD-06",
	&"reactor": "RX-07",
	&"signal_array": "SA-08",
}

## Muted body hues. The accent passed in configure() still drives all lights,
## trim, tier pips and selection so the screen palette stays authoritative.
const MODULE_HUES := {
	&"command_nexus": Color("e8e2d6"),
	&"foundry": Color("c58a56"),
	&"armory": Color("8ea6bd"),
	&"infirmary": Color("a8ddcf"),
	&"barracks": Color("c2ad8e"),
	&"drift_den": Color("d09d6b"),
	&"reactor": Color("a7a6c9"),
	&"signal_array": Color("96b8d8"),
}

## Ghost massing hints: hw/hh are fractions of the pad half-size, rise is a
## fraction of the control height.
const MODULE_MASSING := {
	&"command_nexus": {"hw": 0.35, "hh": 0.60, "rise": 0.34},
	&"foundry": {"hw": 0.47, "hh": 0.53, "rise": 0.17},
	&"armory": {"hw": 0.45, "hh": 0.55, "rise": 0.15},
	&"infirmary": {"hw": 0.37, "hh": 0.57, "rise": 0.17},
	&"barracks": {"hw": 0.55, "hh": 0.49, "rise": 0.15},
	&"drift_den": {"hw": 0.38, "hh": 0.61, "rise": 0.19},
	&"reactor": {"hw": 0.52, "hh": 0.57, "rise": 0.30},
	&"signal_array": {"hw": 0.18, "hh": 0.40, "rise": 0.46},
}

var _module_id: StringName = &""
var _tier: int = 0
var _accent: Color = Color("62e6c3")
var _selected: bool = false
var _hovered: bool = false
var _compact: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(32, 32)
	clip_contents = true
	resized.connect(queue_redraw)


func configure(
	module_id: StringName,
	tier: int,
	accent: Color,
	selected: bool = false,
	hovered: bool = false,
	compact: bool = false
) -> void:
	_module_id = module_id
	_tier = clampi(tier, 0, 3)
	_accent = accent
	_selected = selected
	_hovered = hovered
	_compact = compact
	queue_redraw()


func get_module_id() -> StringName:
	return _module_id


func get_tier() -> int:
	return _tier


func is_selected() -> bool:
	return _selected


func is_hovered() -> bool:
	return _hovered


func is_compact() -> bool:
	return _compact


# ---------------------------------------------------------------------------
# Drawing entry point
# ---------------------------------------------------------------------------

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 8.0 or h < 8.0:
		return
	var m := _metrics(w, h)
	if _tier <= 0:
		_draw_ghost(m)
		_draw_plate_details(m)
		_draw_frame(m)
		return
	var pal := _palette()
	_draw_foundation(m, pal)
	match _module_id:
		&"command_nexus":
			_draw_command_nexus(m, pal)
		&"foundry":
			_draw_foundry(m, pal)
		&"armory":
			_draw_armory(m, pal)
		&"infirmary":
			_draw_infirmary(m, pal)
		&"barracks":
			_draw_barracks(m, pal)
		&"drift_den":
			_draw_drift_den(m, pal)
		&"reactor":
			_draw_reactor(m, pal)
		&"signal_array":
			_draw_signal_array(m, pal)
		_:
			_draw_generic(m, pal)
	_draw_plate_details(m)
	_draw_frame(m)


func _metrics(w: float, h: float) -> Dictionary:
	var s: float = minf(w, h)
	var pad_hw: float = w * 0.465
	var pad_hh: float = minf(h * 0.122, pad_hw * 0.34)
	var pad_depth: float = maxf(1.5, minf(h * 0.042, pad_hh * 0.55))
	var pad_center := Vector2(w * 0.5, h * 0.772)
	var detail := 1.0
	if _compact or s < 74.0:
		detail = 0.62
	if s < 54.0:
		detail = 0.42
	return {
		"w": w,
		"h": h,
		"s": s,
		"pad_center": pad_center,
		"pad_hw": pad_hw,
		"pad_hh": pad_hh,
		"pad_depth": pad_depth,
		"base": pad_center - Vector2(0.0, pad_hh * 0.18),
		"detail": detail,
		"compact": _compact or s < 74.0,
	}


func _palette() -> Dictionary:
	var hue: Color = MODULE_HUES.get(_module_id, Color("c5d2d4"))
	var body_top := UIPalette.mix(hue, UIPalette.ivory, 0.30)
	var body_left := UIPalette.darken(UIPalette.mix(hue, UIPalette.surface_raised, 0.34), 0.10)
	var body_right := UIPalette.darken(UIPalette.mix(hue, UIPalette.surface_raised, 0.18), 0.03)
	var roof_top := UIPalette.mix(body_top, UIPalette.ivory, 0.14)
	var roof_left := UIPalette.darken(body_left, 0.12)
	var roof_right := UIPalette.darken(body_right, 0.08)
	var metal_top := UIPalette.mix(UIPalette.line, UIPalette.surface_high, 0.32)
	var metal_left := UIPalette.darken(metal_top, 0.14)
	var metal_right := UIPalette.darken(metal_top, 0.06)
	return {
		"top": body_top,
		"left": body_left,
		"right": body_right,
		"roof_top": roof_top,
		"roof_left": roof_left,
		"roof_right": roof_right,
		"metal_top": metal_top,
		"metal_left": metal_left,
		"metal_right": metal_right,
		"plate_top": UIPalette.mix(UIPalette.surface_high, UIPalette.line, 0.28),
		"plate_left": UIPalette.darken(UIPalette.surface_raised, 0.08),
		"plate_right": UIPalette.darken(UIPalette.surface_raised, 0.02),
		"edge": UIPalette.alpha(UIPalette.ink, 0.60),
		"line": UIPalette.alpha(UIPalette.line, 0.85),
		"trim": UIPalette.alpha(_accent, 0.60),
		"glow": UIPalette.alpha(_accent, 0.85),
		"warm": UIPalette.alpha(UIPalette.amber, 0.85),
	}


# ---------------------------------------------------------------------------
# Primitive helpers
# ---------------------------------------------------------------------------

func _iso(center: Vector2, hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -hh),
		center + Vector2(hw, 0.0),
		center + Vector2(0.0, hh),
		center + Vector2(-hw, 0.0),
	])


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(points)
	if out.size() > 0:
		out.append(out[0])
	return out


func _poly(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		out.append(point)
	return out


func _ellipse(center: Vector2, rx: float, ry: float, segments: int = 24, start: float = 0.0, end: float = TAU) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count := maxi(3, segments)
	for i in count + 1:
		var a: float = lerpf(start, end, float(i) / float(count))
		out.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return out


func _prism(center: Vector2, hw: float, hh: float, height: float, top_col: Color, left_col: Color, right_col: Color, edge_col: Color, edge_width: float = 1.0) -> Dictionary:
	var base := _iso(center, hw, hh)
	var top_center := center - Vector2(0.0, height)
	var top := _iso(top_center, hw, hh)
	draw_colored_polygon(_poly([base[3], base[2], top[2], top[3]]), left_col)
	draw_colored_polygon(_poly([base[2], base[1], top[1], top[2]]), right_col)
	draw_colored_polygon(top, top_col)
	draw_polyline(_closed(top), edge_col, edge_width, true)
	draw_line(base[3], top[3], edge_col, edge_width, true)
	draw_line(base[2], top[2], edge_col, edge_width, true)
	draw_line(base[1], top[1], edge_col, edge_width, true)
	return {
		"base": base,
		"top": top,
		"top_center": top_center,
		"height": height,
	}


func _slab(center: Vector2, hw: float, hh: float, height: float, col: Color, edge_col: Color) -> Dictionary:
	var base := _iso(center, hw, hh)
	var top_center := center - Vector2(0.0, height)
	var top := _iso(top_center, hw, hh)
	draw_colored_polygon(_poly([base[3], base[2], top[2], top[3]]), UIPalette.darken(col, 0.12))
	draw_colored_polygon(_poly([base[2], base[1], top[1], top[2]]), UIPalette.darken(col, 0.05))
	draw_colored_polygon(top, col)
	draw_polyline(_closed(top), edge_col, 1.0, true)
	return {"base": base, "top": top, "top_center": top_center}


func _face_line(a: Vector2, b: Vector2, y: float, color: Color, width: float = 1.0, from_t: float = 0.08, to_t: float = 0.92) -> void:
	if width <= 0.0:
		return
	draw_line(a.lerp(b, from_t) + Vector2(0.0, y), a.lerp(b, to_t) + Vector2(0.0, y), color, width, true)


func _face_rect(a: Vector2, b: Vector2, t: float, y: float, paint_size: Vector2, color: Color) -> void:
	var span := b - a
	var slope: float = span.y / maxf(absf(span.x), 0.001)
	var p: Vector2 = a.lerp(b, t) + Vector2(0.0, y)
	draw_colored_polygon(_poly([
		p,
		p + Vector2(paint_size.x, paint_size.x * slope),
		p + Vector2(paint_size.x, paint_size.x * slope - paint_size.y),
		p + Vector2(0.0, -paint_size.y),
	]), color)


func _face_windows(a: Vector2, b: Vector2, height: float, rows: int, cols: int, win: Vector2, color: Color, row_base: float = 0.30, row_step: float = 0.30) -> void:
	if rows <= 0 or cols <= 0 or win.x <= 0.4 or win.y <= 0.4:
		return
	for row in rows:
		var y: float = -height * (row_base + float(row) * row_step)
		for col in cols:
			var t: float = (float(col) + 0.72) / (float(cols) + 0.44)
			_face_rect(a, b, t, y, win, color)


func _dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	var length := from.distance_to(to)
	if length <= 0.01:
		return
	var direction := (to - from) / length
	var travelled := 0.0
	while travelled < length:
		var segment := minf(dash, length - travelled)
		draw_line(from + direction * travelled, from + direction * (travelled + segment), color, width, true)
		travelled += dash + gap


func _dashed_loop(points: PackedVector2Array, color: Color, width: float, dash: float, gap: float) -> void:
	if points.size() < 2:
		return
	for i in points.size():
		_dashed_line(points[i], points[(i + 1) % points.size()], color, width, dash, gap)


func _dashed_ellipse(center: Vector2, rx: float, ry: float, color: Color, width: float, dash: float, gap: float) -> void:
	var points := _ellipse(center, rx, ry, 40)
	_dashed_loop(points, color, width, dash, gap)


func _ring(center: Vector2, rx: float, ry: float, color: Color, width: float, segments: int = 24) -> void:
	draw_polyline(_ellipse(center, rx, ry, segments), color, width, true)


func _cable(from: Vector2, to: Vector2, sag: float, color: Color, width: float = 1.0) -> void:
	var points := PackedVector2Array()
	var steps := 10
	for i in steps + 1:
		var t: float = float(i) / float(steps)
		var p: Vector2 = from.lerp(to, t)
		p.y += sin(t * PI) * sag
		points.append(p)
	draw_polyline(points, color, width, true)


# ---------------------------------------------------------------------------
# Foundation / overlays
# ---------------------------------------------------------------------------

func _draw_foundation(m: Dictionary, pal: Dictionary) -> void:
	var center: Vector2 = m["pad_center"]
	var hw: float = m["pad_hw"]
	var hh: float = m["pad_hh"]
	var depth: float = m["pad_depth"]
	var s: float = m["s"]
	# Soft stage light under the pad (reads as a powered foundation pad).
	draw_set_transform(center + Vector2(0.0, hh * 0.20), 0.0, Vector2(1.0, maxf(0.16, hh / maxf(hw, 1.0))))
	draw_circle(Vector2.ZERO, hw * 1.02, UIPalette.alpha(_accent, 0.035))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(center + Vector2(0.0, depth * 1.35), 0.0, Vector2(1.0, maxf(0.20, hh / maxf(hw, 1.0))))
	draw_circle(Vector2.ZERO, hw * 0.96, UIPalette.alpha(UIPalette.ink, 0.36))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var top := _iso(center, hw, hh)
	var low := _iso(center + Vector2(0.0, depth), hw, hh)
	draw_colored_polygon(_poly([top[3], top[2], low[2], low[3]]), pal["plate_left"])
	draw_colored_polygon(_poly([top[2], top[1], low[1], low[2]]), pal["plate_right"])
	draw_colored_polygon(top, pal["plate_top"])
	draw_polyline(_closed(top), pal["line"], 1.0, true)
	var inner := _iso(center - Vector2(0.0, hh * 0.10), hw * 0.80, hh * 0.72)
	draw_polyline(_closed(inner), UIPalette.alpha(UIPalette.line, 0.45), 1.0, true)
	for point in top:
		draw_circle(point, maxf(0.8, s * 0.011), UIPalette.alpha(_accent, 0.42))
	draw_line(top[2], low[2], UIPalette.alpha(_accent, 0.32), 1.2, true)
	draw_line(top[3], low[3], UIPalette.alpha(UIPalette.ivory, 0.12), 1.0, true)


func _draw_plate_details(m: Dictionary) -> void:
	var w: float = m["w"]
	var h: float = m["h"]
	var s: float = m["s"]
	var compact: bool = m["compact"]
	if not compact and s >= 84.0:
		var font := UIFonts.mono(false)
		if font != null:
			var code: String = MODULE_CODES.get(_module_id, "MOD")
			draw_string(
				font,
				Vector2(w * 0.08, h - maxf(2.5, h * 0.030)),
				code,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				clampi(roundi(s * 0.066), 7, 10),
				UIPalette.alpha(UIPalette.ivory, 0.52)
			)
	var pip_size: float = clampf(s * 0.016, 1.1, 2.8)
	var gap: float = pip_size * 3.2
	var start_x: float = w * 0.80 - gap
	var y: float = h - maxf(3.5, h * 0.045)
	for i in 3:
		var point := Vector2(start_x + float(i) * gap, y)
		draw_circle(point, pip_size, _accent if i < _tier else UIPalette.alpha(UIPalette.ink, 0.65))
	if _tier > 0 and s >= 84.0:
		draw_line(
			Vector2(w * 0.74, y),
			Vector2(w * 0.78, y),
			UIPalette.alpha(_accent, 0.35),
			1.0,
			true
		)


func _draw_frame(m: Dictionary) -> void:
	if not (_selected or _hovered):
		return
	var w: float = m["w"]
	var h: float = m["h"]
	var strength: float = 0.9 if _selected else 0.42
	var color := UIPalette.alpha(_accent, strength)
	var rect := Rect2(Vector2(1.0, 1.0), Vector2(maxf(0.0, w - 2.0), maxf(0.0, h - 2.0)))
	draw_rect(rect, color, false, 1.5 if _selected else 1.0, true)
	if not _selected:
		return
	var bracket: float = minf(w, h) * 0.16
	var width: float = 2.0
	var inset: float = 2.0
	draw_line(Vector2(inset, inset), Vector2(inset + bracket, inset), color, width, true)
	draw_line(Vector2(inset, inset), Vector2(inset, inset + bracket), color, width, true)
	draw_line(Vector2(w - inset, inset), Vector2(w - inset - bracket, inset), color, width, true)
	draw_line(Vector2(w - inset, inset), Vector2(w - inset, inset + bracket), color, width, true)
	draw_line(Vector2(inset, h - inset), Vector2(inset + bracket, h - inset), color, width, true)
	draw_line(Vector2(inset, h - inset), Vector2(inset, h - inset - bracket), color, width, true)
	draw_line(Vector2(w - inset, h - inset), Vector2(w - inset - bracket, h - inset), color, width, true)
	draw_line(Vector2(w - inset, h - inset), Vector2(w - inset, h - inset - bracket), color, width, true)


# ---------------------------------------------------------------------------
# Tier 0 blueprint ghost
# ---------------------------------------------------------------------------

func _draw_ghost(m: Dictionary) -> void:
	var w: float = m["w"]
	var h: float = m["h"]
	var s: float = m["s"]
	var pad_center: Vector2 = m["pad_center"]
	var pad_hw: float = m["pad_hw"]
	var pad_hh: float = m["pad_hh"]
	var base: Vector2 = m["base"]
	var blueprint := UIPalette.mix(_accent, UIPalette.blue, 0.62)
	var pad := _iso(pad_center, pad_hw, pad_hh)
	draw_colored_polygon(pad, UIPalette.alpha(blueprint, 0.055))
	_dashed_loop(pad, UIPalette.alpha(blueprint, 0.72), 1.2, maxf(3.0, s * 0.055), maxf(2.0, s * 0.035))
	# Slot ticks at the pad corners.
	for point in pad:
		var inward: Vector2 = (pad_center - point).normalized() * maxf(2.0, s * 0.020)
		draw_circle(point, maxf(0.9, s * 0.010), UIPalette.alpha(blueprint, 0.55))
		draw_line(point, point - inward * 1.7, UIPalette.alpha(blueprint, 0.38), 1.0, true)
	var mass: Dictionary = MODULE_MASSING.get(_module_id, {"hw": 0.32, "hh": 0.52, "rise": 0.18})
	var hw: float = pad_hw * float(mass["hw"])
	var hh: float = pad_hh * float(mass["hh"])
	var rise: float = h * float(mass["rise"])
	var lower := _iso(base, hw, hh)
	var upper := _iso(base - Vector2(0.0, rise), hw, hh)
	draw_colored_polygon(lower, UIPalette.alpha(blueprint, 0.035))
	draw_colored_polygon(upper, UIPalette.alpha(blueprint, 0.055))
	draw_polyline(_closed(lower), UIPalette.alpha(blueprint, 0.30), 1.0, true)
	draw_polyline(_closed(upper), UIPalette.alpha(blueprint, 0.46), 1.0, true)
	for i in 4:
		draw_line(lower[i], upper[i], UIPalette.alpha(blueprint, 0.28), 1.0, true)
	var mid := _iso(base - Vector2(0.0, rise * 0.5), hw, hh)
	draw_polyline(_closed(mid), UIPalette.alpha(blueprint, 0.20), 1.0, true)
	# Construction cross + ring.
	var center: Vector2 = base - Vector2(0.0, rise * 0.46)
	var arm: float = maxf(3.5, s * 0.048)
	draw_circle(center, arm * 1.05, UIPalette.alpha(blueprint, 0.16))
	draw_circle(center, arm * 1.05, UIPalette.alpha(blueprint, 0.50), false, 1.0, true)
	draw_line(center - Vector2(arm, 0.0), center + Vector2(arm, 0.0), UIPalette.alpha(blueprint, 0.85), 1.4, true)
	draw_line(center - Vector2(0.0, arm), center + Vector2(0.0, arm), UIPalette.alpha(blueprint, 0.85), 1.4, true)
	# Anchor bolts around the footprint.
	for i in 3:
		var t: float = float(i) / 3.0
		var point: Vector2 = pad[3].lerp(pad[2], 0.2 + t * 0.6)
		draw_circle(point + Vector2(0.0, 1.0), maxf(0.7, s * 0.008), UIPalette.alpha(blueprint, 0.30))
	if not bool(m["compact"]) and s >= 92.0:
		var font := UIFonts.mono(false)
		if font != null:
			draw_string(
				font,
				Vector2(w * 0.08, h - maxf(2.5, h * 0.030)),
				"%s // PLAN" % String(MODULE_CODES.get(_module_id, "MOD")),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				clampi(roundi(s * 0.062), 7, 9),
				UIPalette.alpha(blueprint, 0.55)
			)


# ---------------------------------------------------------------------------
# command_nexus: central command tower + dome, antenna, windows, landing ring
# ---------------------------------------------------------------------------

func _draw_command_nexus(m: Dictionary, pal: Dictionary) -> void:
	var s: float = m["s"]
	var base: Vector2 = m["base"]
	var pad_hw: float = m["pad_hw"]
	var pad_hh: float = m["pad_hh"]
	var detail: float = m["detail"]
	var platform_h: float = s * 0.058
	var platform := _prism(base, pad_hw * 0.72, pad_hh * 0.64, platform_h, pal["roof_top"], pal["roof_left"], pal["roof_right"], pal["edge"])
	var deck: Vector2 = platform["top_center"]
	if detail > 0.5:
		_prism(base + Vector2(-pad_hw * 0.52, pad_hh * 0.10), pad_hw * 0.19, pad_hh * 0.24, s * 0.085, pal["top"], pal["left"], pal["right"], pal["edge"])
		_prism(base + Vector2(pad_hw * 0.52, pad_hh * 0.10), pad_hw * 0.19, pad_hh * 0.24, s * 0.085, pal["top"], pal["left"], pal["right"], pal["edge"])
	var tower_h: float = s * (0.28 + 0.030 * float(_tier))
	var tower := _prism(deck, pad_hw * 0.33, pad_hh * 0.39, tower_h, pal["top"], pal["left"], pal["right"], pal["edge"])
	var tower_top: Vector2 = tower["top_center"]
	var tower_base: PackedVector2Array = tower["base"]
	# Window rows.
	var rows: int = mini(3, _tier + 1)
	var win := Vector2(maxf(1.6, s * 0.026), maxf(1.2, s * 0.016))
	_face_windows(tower_base[3], tower_base[2], tower_h, rows, 2, win, UIPalette.alpha(_accent, 0.78))
	_face_windows(tower_base[2], tower_base[1], tower_h, rows, 2, win, UIPalette.alpha(_accent, 0.62))
	var band := _iso(tower_top + Vector2(0.0, tower_h * 0.55), pad_hw * 0.35, pad_hh * 0.415)
	draw_polyline(_closed(band), UIPalette.alpha(_accent, 0.36), 1.0, true)
	# Neck + dome.
	var neck_h: float = s * 0.042
	var neck := _prism(tower_top, pad_hw * 0.245, pad_hh * 0.30, neck_h, pal["roof_top"], pal["roof_left"], pal["roof_right"], pal["edge"])
	var dome_center: Vector2 = neck["top_center"]
	var dome_rx: float = pad_hw * 0.30
	var dome_ry: float = s * 0.082
	draw_colored_polygon(_ellipse(dome_center, dome_rx, dome_ry, 24, PI, TAU), UIPalette.mix(pal["top"], UIPalette.ivory, 0.30))
	draw_polyline(_ellipse(dome_center, dome_rx, dome_ry, 24, PI, TAU), pal["edge"], 1.0, true)
	draw_line(dome_center - Vector2(dome_rx, 0.0), dome_center + Vector2(dome_rx, 0.0), pal["edge"], 1.0, true)
	draw_arc(dome_center, dome_rx * 0.55, PI * 1.10, PI * 1.90, 10, UIPalette.alpha(UIPalette.ivory, 0.35), 1.0, true)
	draw_arc(dome_center, dome_rx * 0.97, PI * 1.05, PI * 1.95, 16, UIPalette.alpha(_accent, 0.65), 1.6, true)
	var beacon_y: float = dome_center.y - dome_ry
	# Antenna mast with crossbars.
	var mast_h: float = s * (0.125 + 0.020 * float(_tier))
	var mast_top := Vector2(dome_center.x, beacon_y - mast_h)
	draw_line(Vector2(dome_center.x, beacon_y), mast_top, UIPalette.mix(pal["metal_top"], UIPalette.ivory, 0.35), 1.4, true)
	draw_line(mast_top + Vector2(-s * 0.050, s * 0.035), mast_top + Vector2(s * 0.050, s * 0.035), UIPalette.alpha(UIPalette.ivory, 0.42), 1.0, true)
	draw_line(mast_top + Vector2(-s * 0.032, s * 0.070), mast_top + Vector2(s * 0.032, s * 0.070), UIPalette.alpha(UIPalette.ivory, 0.28), 1.0, true)
	draw_circle(mast_top, maxf(1.6, s * 0.020), UIPalette.alpha(_accent, 0.20))
	draw_circle(mast_top, maxf(1.2, s * 0.014), pal["glow"])
	draw_circle(mast_top, maxf(0.6, s * 0.006), UIPalette.ivory)
	if _tier >= 2:
		draw_line(Vector2(dome_center.x - dome_rx * 0.92, beacon_y + dome_ry * 0.10), Vector2(dome_center.x - dome_rx * 1.16, beacon_y - s * 0.055), UIPalette.alpha(UIPalette.ivory, 0.30), 1.0, true)
		draw_circle(Vector2(dome_center.x - dome_rx * 1.16, beacon_y - s * 0.055), maxf(0.8, s * 0.009), UIPalette.alpha(_accent, 0.7))
	# Landing ring on the pad deck.
	var ring_center := base + Vector2(pad_hw * 0.04, pad_hh * 0.66)
	var ring_rx: float = pad_hw * 0.32
	var ring_ry: float = maxf(2.0, pad_hh * 0.33)
	_dashed_ellipse(ring_center, ring_rx, ring_ry, UIPalette.alpha(_accent, 0.52), 1.2, maxf(2.5, s * 0.045), maxf(2.0, s * 0.030))
	if detail > 0.5:
		draw_line(ring_center + Vector2(-ring_rx * 0.16, -ring_ry * 0.55), ring_center + Vector2(-ring_rx * 0.16, ring_ry * 0.55), UIPalette.alpha(UIPalette.ivory, 0.35), 1.0, true)
		draw_line(ring_center + Vector2(ring_rx * 0.16, -ring_ry * 0.55), ring_center + Vector2(ring_rx * 0.16, ring_ry * 0.55), UIPalette.alpha(UIPalette.ivory, 0.35), 1.0, true)
		draw_line(ring_center + Vector2(-ring_rx * 0.16, 0.0), ring_center + Vector2(ring_rx * 0.16, 0.0), UIPalette.alpha(UIPalette.ivory, 0.35), 1.0, true)
	draw_circle(ring_center + Vector2(0.0, -ring_ry * 0.2), maxf(1.0, s * 0.012), UIPalette.alpha(UIPalette.amber, 0.45))
	# Tier 3 command mast fins.
	if _tier >= 3:
		for side in [-1.0, 1.0]:
			draw_line(
				tower_top + Vector2(side * pad_hw * 0.15, -tower_h * 0.15),
				tower_top + Vector2(side * pad_hw * 0.26, -tower_h * 0.35),
				UIPalette.alpha(UIPalette.ivory, 0.28), 1.2, true
			)


# ---------------------------------------------------------------------------
# foundry: long shed + twin chimneys + glowing forge door + crane
# ---------------------------------------------------------------------------

func _draw_foundry(m: Dictionary, pal: Dictionary) -> void:
	var s: float = m["s"]
	var base: Vector2 = m["base"]
	var pad_hw: float = m["pad_hw"]
	var pad_hh: float = m["pad_hh"]
	var detail: float = m["detail"]
	var shed_h: float = s * (0.135 + 0.022 * float(_tier))
	var hw: float = pad_hw * 0.45
	var hh: float = pad_hh * 0.50
	var shed_center := base + Vector2(-pad_hw * 0.035, 0.0)
	var shed := _prism(shed_center, hw, hh, shed_h, pal["top"], pal["left"], pal["right"], pal["edge"])
	var roof_center: Vector2 = shed["top_center"]
	var shed_base: PackedVector2Array = shed["base"]
	var shed_top: PackedVector2Array = shed["top"]
	# Roof slab + trim.
	_slab(roof_center - Vector2(0.0, s * 0.008), hw * 1.04, hh * 1.06, s * 0.034, pal["roof_top"], pal["edge"])
	draw_line(shed_top[3], shed_top[2], UIPalette.alpha(UIPalette.ivory, 0.25), 1.0, true)
	draw_line(shed_top[2], shed_top[1], UIPalette.alpha(UIPalette.ivory, 0.18), 1.0, true)
	# Sawtooth roof ribs.
	if detail > 0.55:
		for i in 3:
			var t: float = 0.24 + float(i) * 0.24
			var a: Vector2 = shed_top[3].lerp(shed_top[2], t)
			var b: Vector2 = shed_top[0].lerp(shed_top[1], t)
			draw_line(a + Vector2(0.0, -s * 0.012), b + Vector2(0.0, -s * 0.012), UIPalette.alpha(UIPalette.ink, 0.30), 1.0, true)
	# Twin chimneys (draw behind the shed roof).
	var chimney_h: float = s * (0.235 + 0.025 * float(_tier))
	for side in [-1.0, 1.0]:
		var chimney_center := roof_center + Vector2(side * hw * 0.42, -hh * 0.34)
		var body := _prism(chimney_center, s * 0.031, hh * 0.27, chimney_h, pal["metal_top"], pal["metal_left"], pal["metal_right"], pal["edge"])
		var cap_center: Vector2 = body["top_center"]
		draw_rect(Rect2(cap_center - Vector2(s * 0.035, s * 0.016), Vector2(s * 0.070, s * 0.015)), UIPalette.darken(pal["metal_top"], 0.10))
		draw_line(cap_center - Vector2(s * 0.035, s * 0.016), cap_center + Vector2(s * 0.035, s * 0.016), pal["edge"], 1.0, true)
		draw_line(cap_center + Vector2(-s * 0.035, 0.0), cap_center + Vector2(s * 0.035, 0.0), UIPalette.alpha(_accent, 0.55), 1.4, true)
		draw_line(cap_center + Vector2(0.0, -s * 0.02), cap_center + Vector2(0.0, -s * 0.050), UIPalette.alpha(_accent, 0.35), 1.0, true)
		if detail > 0.55:
			for puff in 3:
				var puff_y: float = cap_center.y - s * (0.060 + float(puff) * 0.032)
				var puff_x: float = cap_center.x + s * (0.020 + float(puff) * 0.012)
				draw_circle(Vector2(puff_x, puff_y), s * (0.016 + float(puff) * 0.006), UIPalette.alpha(UIPalette.ivory, 0.055 - float(puff) * 0.012))
	# Glowing forge door on the front-right face.
	var door_y: float = -shed_h * 0.34
	_face_rect(shed_base[2], shed_base[1], 0.34, door_y, Vector2(s * 0.135, s * 0.110), UIPalette.alpha(UIPalette.amber, 0.12))
	_face_rect(shed_base[2], shed_base[1], 0.36, door_y, Vector2(s * 0.094, s * 0.085), UIPalette.alpha(UIPalette.amber, 0.32))
	_face_rect(shed_base[2], shed_base[1], 0.38, door_y, Vector2(s * 0.068, s * 0.073), UIPalette.alpha(UIPalette.amber, 0.88))
	_face_rect(shed_base[2], shed_base[1], 0.40, door_y, Vector2(s * 0.035, s * 0.059), UIPalette.alpha(UIPalette.ivory, 0.72))
	for i in 3:
		_face_rect(shed_base[2], shed_base[1], 0.382 + float(i) * 0.013, door_y, Vector2(s * 0.0035, s * 0.065), UIPalette.alpha(UIPalette.ink, 0.45))
	# Window slits on the left wall.
	_face_windows(shed_base[3], shed_base[2], shed_h, 1, 3, Vector2(s * 0.032, s * 0.016), UIPalette.alpha(UIPalette.amber, 0.45))
	# Crane: mast, jib, cable and hook.
	var crane_base := shed_center + Vector2(hw * 1.22, -hh * 0.10)
	var crane_h: float = s * (0.285 + 0.030 * float(_tier))
	var crane_top := crane_base - Vector2(0.0, crane_h)
	var steel := UIPalette.mix(pal["metal_top"], UIPalette.ivory, 0.28)
	draw_line(crane_base, crane_top, steel, 2.0, true)
	draw_line(crane_base + Vector2(-s * 0.026, 0.0), crane_top, UIPalette.alpha(steel, 0.55), 1.0, true)
	draw_line(crane_base + Vector2(s * 0.026, 0.0), crane_top, UIPalette.alpha(steel, 0.55), 1.0, true)
	for i in 3:
		var y: float = lerpf(crane_base.y, crane_top.y, 0.25 + float(i) * 0.25)
		draw_line(Vector2(crane_base.x - s * 0.020, y), Vector2(crane_base.x + s * 0.020, y - s * 0.012), UIPalette.alpha(steel, 0.45), 1.0, true)
	var jib_end := crane_top + Vector2(-s * 0.205, -s * 0.060)
	draw_line(crane_top, jib_end, steel, 2.0, true)
	draw_line(crane_top + Vector2(0.0, s * 0.014), jib_end + Vector2(s * 0.050, s * 0.020), UIPalette.alpha(steel, 0.50), 1.0, true)
	for i in 4:
		var t: float = 0.15 + float(i) * 0.22
		var top_point: Vector2 = crane_top.lerp(jib_end, t)
		var low_point: Vector2 = (crane_top + Vector2(0.0, s * 0.014)).lerp(jib_end + Vector2(s * 0.050, s * 0.020), t)
		draw_line(top_point, low_point, UIPalette.alpha(steel, 0.40), 1.0, true)
	var hook_top: Vector2 = jib_end + Vector2(0.0, s * 0.035)
	draw_line(jib_end, hook_top, UIPalette.alpha(UIPalette.ivory, 0.50), 1.0, true)
	draw_circle(hook_top + Vector2(0.0, s * 0.012), maxf(1.2, s * 0.012), UIPalette.alpha(UIPalette.amber, 0.75), false, 1.2, true)
	draw_circle(crane_top, maxf(1.0, s * 0.010), UIPalette.alpha(_accent, 0.75))
	if _tier >= 2:
		var stack := _prism(roof_center + Vector2(-hw * 0.62, hh * 0.18), s * 0.022, hh * 0.20, s * 0.075, pal["metal_top"], pal["metal_left"], pal["metal_right"], pal["edge"])
		draw_line(stack["top_center"] + Vector2(-s * 0.018, 0.0), stack["top_center"] + Vector2(s * 0.018, 0.0), UIPalette.alpha(_accent, 0.55), 1.2, true)
	if _tier >= 3:
		draw_circle(crane_top + Vector2(-s * 0.018, -s * 0.012), maxf(1.2, s * 0.014), UIPalette.alpha(UIPalette.amber, 0.30))
		draw_circle(crane_top + Vector2(-s * 0.018, -s * 0.012), maxf(0.8, s * 0.008), UIPalette.alpha(UIPalette.amber, 0.90))


# ---------------------------------------------------------------------------
# armory: reinforced bunker + ammo crates + roof turret
# ---------------------------------------------------------------------------

func _draw_armory(m: Dictionary, pal: Dictionary) -> void:
	var s: float = m["s"]
	var base: Vector2 = m["base"]
	var pad_hw: float = m["pad_hw"]
	var pad_hh: float = m["pad_hh"]
	var detail: float = m["detail"]
	var bunker_h: float = s * (0.135 + 0.016 * float(_tier))
	var hw: float = pad_hw * 0.45
	var hh: float = pad_hh * 0.53
	var bunker := _prism(base, hw, hh, bunker_h, pal["top"], pal["left"], pal["right"], pal["edge"])
	var top_center: Vector2 = bunker["top_center"]
	var top_pts: PackedVector2Array = bunker["top"]
	var base_pts: PackedVector2Array = bunker["base"]
	# Reinforced roof cap.
	_slab(top_center - Vector2(0.0, s * 0.006), hw * 1.05, hh * 1.06, s * 0.032, pal["roof_top"], pal["edge"])
	draw_line(top_pts[3], top_pts[2], UIPalette.alpha(pal["line"], 0.9), 1.0, true)
	draw_line(top_pts[2], top_pts[1], UIPalette.alpha(pal["line"], 0.9), 1.0, true)
	# Armour seams and rivets.
	draw_line(base_pts[2], top_pts[2], UIPalette.alpha(UIPalette.ink, 0.32), 1.0, true)
	for row in 2:
		var t: float = 0.28 + float(row) * 0.30
		_face_line(base_pts[3], base_pts[2], -bunker_h * t, UIPalette.alpha(UIPalette.ink, 0.28), 1.0)
		_face_line(base_pts[2], base_pts[1], -bunker_h * t, UIPalette.alpha(UIPalette.ink, 0.24), 1.0)
	for i in 4:
		var t: float = 0.16 + float(i) * 0.22
		var rivet: Vector2 = base_pts[2].lerp(base_pts[1], t) + Vector2(0.0, -bunker_h * 0.78)
		draw_circle(rivet, maxf(0.7, s * 0.008), UIPalette.alpha(UIPalette.ivory, 0.28))
	# Blast door.
	_face_rect(base_pts[3], base_pts[2], 0.34, -bunker_h * 0.12, Vector2(s * 0.085, s * 0.090), UIPalette.alpha(UIPalette.ink, 0.55))
	_face_rect(base_pts[3], base_pts[2], 0.35, -bunker_h * 0.12, Vector2(s * 0.072, s * 0.078), UIPalette.darken(pal["metal_top"], 0.10))
	_face_rect(base_pts[3], base_pts[2], 0.38, -bunker_h * 0.48, Vector2(s * 0.036, s * 0.020), UIPalette.alpha(_accent, 0.55))
	# Hazard band.
	for i in 4:
		var t0: float = 0.58 + float(i) * 0.085
		_face_rect(base_pts[2], base_pts[1], t0, -bunker_h * 0.06, Vector2(s * 0.028, s * 0.022), UIPalette.alpha(UIPalette.amber, 0.62))
	# Roof turret.
	if detail > 0.45:
		var turret_center := top_center + Vector2(hw * 0.32, -hh * 0.10)
		_ring(turret_center, s * 0.066, s * 0.025, UIPalette.alpha(pal["line"], 0.9), 1.0, 18)
		var turret := _prism(turret_center - Vector2(0.0, s * 0.010), s * 0.054, s * 0.023, s * 0.034, pal["metal_top"], pal["metal_left"], pal["metal_right"], pal["edge"])
		var turret_top: Vector2 = turret["top_center"]
		draw_line(turret_top + Vector2(-s * 0.006, 0.0), turret_top + Vector2(s * 0.132, -s * 0.046), UIPalette.darken(pal["metal_top"], 0.18), 2.6, true)
		draw_line(turret_top + Vector2(s * 0.014, s * 0.015), turret_top + Vector2(s * 0.128, -s * 0.014), UIPalette.darken(pal["metal_top"], 0.26), 2.0, true)
		draw_circle(turret_top + Vector2(s * 0.132, -s * 0.046), maxf(1.0, s * 0.010), UIPalette.alpha(_accent, 0.75))
		draw_circle(turret_top, maxf(0.9, s * 0.008), UIPalette.alpha(_accent, 0.60))
	# Ammo crates in front-left.
	var crate_total: int = 2 if detail > 0.55 else 1
	for i in crate_total:
		var offset := Vector2(-pad_hw * 0.32 + float(i) * s * 0.070, pad_hh * 0.50 - float(i) * s * 0.010)
		var crate := _prism(base + offset, s * 0.047, s * 0.022, s * 0.054, UIPalette.mix(UIPalette.amber, pal["metal_top"], 0.45), pal["metal_left"], pal["metal_right"], pal["edge"])
		var crate_top: Vector2 = crate["top_center"]
		draw_line(crate_top + Vector2(-s * 0.040, s * 0.010), crate_top + Vector2(s * 0.040, s * 0.010), UIPalette.alpha(UIPalette.ink, 0.48), 1.0, true)
		draw_line(crate_top + Vector2(0.0, s * 0.002), crate_top + Vector2(0.0, s * 0.025), UIPalette.alpha(UIPalette.ink, 0.42), 1.0, true)
		draw_line(crate_top + Vector2(-s * 0.014, -s * 0.012), crate_top + Vector2(-s * 0.014, s * 0.030), UIPalette.alpha(UIPalette.amber, 0.55), 1.0, true)
	# Perch marker.
	draw_line(top_pts[0] + Vector2(-s * 0.012, s * 0.010), top_pts[0] + Vector2(-s * 0.012, -s * 0.040), UIPalette.alpha(UIPalette.ivory, 0.35), 1.0, true)


# ---------------------------------------------------------------------------
# infirmary: rounded clinic + cross sign + light strips + pad
# ---------------------------------------------------------------------------

func _draw_infirmary(m: Dictionary, pal: Dictionary) -> void:
	var s: float = m["s"]
	var base: Vector2 = m["base"]
	var pad_hw: float = m["pad_hw"]
	var pad_hh: float = m["pad_hh"]
	var detail: float = m["detail"]
	var body_h: float = s * (0.130 + 0.016 * float(_tier))
	var hw: float = pad_hw * 0.37
	var hh: float = pad_hh * 0.49
	var body := _prism(base, hw, hh, body_h, pal["top"], pal["left"], pal["right"], pal["edge"])
	var top_center: Vector2 = body["top_center"]
	var top_pts: PackedVector2Array = body["top"]
	var base_pts: PackedVector2Array = body["base"]
	# Rounded roof cap.
	var cap_rx: float = hw * 1.02
	var cap_ry: float = s * 0.085
	draw_colored_polygon(_ellipse(top_center, cap_rx, cap_ry, 24, PI, TAU), UIPalette.mix(pal["roof_top"], UIPalette.ivory, 0.18))
	draw_polyline(_ellipse(top_center, cap_rx, cap_ry, 24, PI, TAU), pal["edge"], 1.0, true)
	draw_line(top_center - Vector2(cap_rx, 0.0), top_center + Vector2(cap_rx, 0.0), pal["edge"], 1.0, true)
	draw_arc(top_center, cap_rx * 0.92, PI * 1.10, PI * 1.90, 14, UIPalette.alpha(UIPalette.ivory, 0.32), 1.0, true)
	# Light strips wrapping the facade.
	var strip_y: float = -body_h * 0.26
	_face_line(base_pts[3], base_pts[2], strip_y, UIPalette.alpha(_accent, 0.72), 1.6)
	_face_line(base_pts[2], base_pts[1], strip_y, UIPalette.alpha(_accent, 0.52), 1.4)
	_face_line(base_pts[3], base_pts[2], strip_y - body_h * 0.30, UIPalette.alpha(UIPalette.ivory, 0.18), 1.0)
	_face_line(base_pts[2], base_pts[1], strip_y - body_h * 0.30, UIPalette.alpha(UIPalette.ivory, 0.14), 1.0)
	# Cross sign on the front-left facade.
	var sign_center: Vector2 = base_pts[3].lerp(base_pts[2], 0.56) + Vector2(0.0, -body_h * 0.54)
	var sign_size: float = s * 0.056
	draw_rect(Rect2(sign_center - Vector2(sign_size * 0.78, sign_size * 0.78), Vector2(sign_size * 1.56, sign_size * 1.56)), UIPalette.alpha(UIPalette.ink, 0.35))
	draw_rect(Rect2(sign_center - Vector2(sign_size * 0.78, sign_size * 0.78), Vector2(sign_size * 1.56, sign_size * 1.56)), UIPalette.alpha(_accent, 0.55), false, 1.0, true)
	draw_rect(Rect2(sign_center - Vector2(sign_size * 0.20, sign_size * 0.66), Vector2(sign_size * 0.40, sign_size * 1.32)), UIPalette.alpha(UIPalette.ivory, 0.92))
	draw_rect(Rect2(sign_center - Vector2(sign_size * 0.66, sign_size * 0.20), Vector2(sign_size * 1.32, sign_size * 0.40)), UIPalette.alpha(UIPalette.ivory, 0.92))
	# Pad with a med ring.
	var ring_center := base + Vector2(-pad_hw * 0.24, pad_hh * 0.66)
	_ring(ring_center, pad_hw * 0.20, maxf(1.8, pad_hh * 0.22), UIPalette.alpha(UIPalette.mint, 0.35), 1.0, 20)
	draw_line(ring_center - Vector2(s * 0.022, 0.0), ring_center + Vector2(s * 0.022, 0.0), UIPalette.alpha(UIPalette.mint, 0.42), 1.2, true)
	draw_line(ring_center - Vector2(0.0, s * 0.010), ring_center + Vector2(0.0, s * 0.010), UIPalette.alpha(UIPalette.mint, 0.42), 1.2, true)
	# Annex pod.
	if detail > 0.55:
		var annex_center := base + Vector2(-hw * 1.30, hh * 0.28)
		var annex := _prism(annex_center, hw * 0.42, hh * 0.38, body_h * 0.68, pal["top"], pal["left"], pal["right"], pal["edge"])
		var annex_top: Vector2 = annex["top_center"]
		draw_colored_polygon(_ellipse(annex_top, hw * 0.44, s * 0.030, 18, PI, TAU), UIPalette.mix(pal["roof_top"], UIPalette.ivory, 0.16))
		draw_line(annex_top + Vector2(-hw * 0.44, 0.0), annex_top + Vector2(hw * 0.44, 0.0), pal["edge"], 1.0, true)
		_face_windows(base_pts[3], base_pts[2], body_h, 1, 2, Vector2(s * 0.030, s * 0.020), UIPalette.alpha(UIPalette.ivory, 0.22), 0.36, 0.30)
	else:
		_face_windows(base_pts[3], base_pts[2], body_h, 1, 2, Vector2(s * 0.028, s * 0.018), UIPalette.alpha(UIPalette.ivory, 0.20), 0.36, 0.30)
	# Roof beacon.
	var beacon := top_center + Vector2(cap_rx * 0.52, -cap_ry * 1.10)
	draw_line(Vector2(beacon.x, beacon.y), Vector2(beacon.x, beacon.y - s * 0.020), UIPalette.alpha(UIPalette.ivory, 0.38), 1.0, true)
	draw_circle(beacon + Vector2(0.0, -s * 0.024), maxf(0.9, s * 0.010), UIPalette.alpha(UIPalette.mint, 0.85))


# ---------------------------------------------------------------------------
# barracks: wide hall + window rows + flag + antenna
# ---------------------------------------------------------------------------

func _draw_barracks(m: Dictionary, pal: Dictionary) -> void:
	var s: float = m["s"]
	var w: float = m["w"]
	var base: Vector2 = m["base"]
	var pad_hw: float = m["pad_hw"]
	var pad_hh: float = m["pad_hh"]
	var detail: float = m["detail"]
	var hall_h: float = s * (0.135 + 0.016 * float(_tier))
	var hw: float = minf(pad_hw * 0.80, w * 0.36)
	var hh: float = pad_hh * 0.45
	var hall := _prism(base, hw, hh, hall_h, pal["top"], pal["left"], pal["right"], pal["edge"])
	var top_center: Vector2 = hall["top_center"]
	var top_pts: PackedVector2Array = hall["top"]
	var base_pts: PackedVector2Array = hall["base"]
	# Roof slab, trim and vents.
	_slab(top_center - Vector2(0.0, s * 0.006), hw * 1.03, hh * 1.08, s * 0.028, pal["roof_top"], pal["edge"])
	draw_line(top_pts[3], top_pts[2], UIPalette.alpha(UIPalette.ivory, 0.25), 1.0, true)
	draw_line(top_pts[2], top_pts[1], UIPalette.alpha(UIPalette.ivory, 0.18), 1.0, true)
	if detail > 0.55:
		for i in 2:
			var vent := _prism(top_center + Vector2(-hw * 0.30 + float(i) * hw * 0.55, -hh * 0.10), s * 0.026, hh * 0.22, s * 0.026, pal["metal_top"], pal["metal_left"], pal["metal_right"], pal["edge"])
			draw_line(vent["top_center"] + Vector2(-s * 0.020, 0.0), vent["top_center"] + Vector2(s * 0.020, 0.0), UIPalette.alpha(UIPalette.ink, 0.35), 1.0, true)
	# Window rows.
	var rows: int = 2 if detail > 0.5 else 1
	var cols: int = 4 + _tier
	_face_windows(base_pts[2], base_pts[1], hall_h, rows, cols, Vector2(s * 0.028, s * 0.018), UIPalette.alpha(UIPalette.amber, 0.48), 0.34, 0.30)
	_face_windows(base_pts[3], base_pts[2], hall_h, rows, 2, Vector2(s * 0.024, s * 0.016), UIPalette.alpha(UIPalette.amber, 0.34), 0.34, 0.30)
	# Door.
	_face_rect(base_pts[2], base_pts[1], 0.43, -hall_h * 0.04, Vector2(s * 0.068, s * 0.092), UIPalette.alpha(UIPalette.ink, 0.55))
	_face_rect(base_pts[2], base_pts[1], 0.445, -hall_h * 0.04, Vector2(s * 0.056, s * 0.080), UIPalette.alpha(UIPalette.mint, 0.42))
	_face_rect(base_pts[2], base_pts[1], 0.455, -hall_h * 0.04, Vector2(s * 0.034, s * 0.070), UIPalette.alpha(UIPalette.ink, 0.42))
	# Flag pole on the left end.
	var pole_base: Vector2 = top_pts[3] + Vector2(-hw * 0.10, -s * 0.012)
	var pole_top: Vector2 = pole_base - Vector2(0.0, s * (0.22 + 0.015 * float(_tier)))
	draw_line(pole_base, pole_top, UIPalette.alpha(UIPalette.ivory, 0.65), 1.4, true)
	draw_line(pole_base + Vector2(0.0, s * 0.010), pole_base - Vector2(s * 0.040, 0.0), UIPalette.alpha(UIPalette.ivory, 0.30), 1.0, true)
	var flag := _poly([
		pole_top,
		pole_top + Vector2(s * 0.120, s * 0.026),
		pole_top + Vector2(s * 0.092, s * 0.056),
		pole_top + Vector2(s * 0.005, s * 0.056),
	])
	draw_colored_polygon(flag, UIPalette.alpha(_accent, 0.80))
	draw_polyline(_closed(flag), UIPalette.alpha(UIPalette.ivory, 0.35), 1.0, true)
	draw_circle(pole_top + Vector2(s * 0.058, s * 0.030), maxf(0.8, s * 0.010), UIPalette.alpha(UIPalette.ink, 0.55))
	# Antenna on the right end.
	var antenna_base: Vector2 = top_pts[1] + Vector2(hw * 0.08, -s * 0.010)
	var antenna_top: Vector2 = antenna_base - Vector2(0.0, s * (0.16 + 0.012 * float(_tier)))
	draw_line(antenna_base, antenna_top, UIPalette.alpha(UIPalette.ivory, 0.52), 1.2, true)
	draw_line(antenna_top + Vector2(-s * 0.026, s * 0.020), antenna_top + Vector2(s * 0.026, s * 0.020), UIPalette.alpha(UIPalette.ivory, 0.30), 1.0, true)
	draw_circle(antenna_top, maxf(0.9, s * 0.010), UIPalette.alpha(UIPalette.amber, 0.80))
	# Tier details: roof rail and extra windows.
	if _tier >= 2:
		draw_line(top_pts[0], top_pts[1], UIPalette.alpha(_accent, 0.28), 1.2, true)
	if _tier >= 3:
		draw_line(base_pts[1], top_pts[1], UIPalette.alpha(_accent, 0.30), 1.0, true)
		draw_circle(antenna_top + Vector2(0.0, -s * 0.022), maxf(1.0, s * 0.012), UIPalette.alpha(UIPalette.amber, 0.22))


# ---------------------------------------------------------------------------
# drift_den: rounded dome + paw insignia + drone pad + pipes
# ---------------------------------------------------------------------------

func _draw_drift_den(m: Dictionary, pal: Dictionary) -> void:
	var s: float = m["s"]
	var base: Vector2 = m["base"]
	var pad_hw: float = m["pad_hw"]
	var pad_hh: float = m["pad_hh"]
	var detail: float = m["detail"]
	var hw: float = pad_hw * 0.38
	var hh: float = pad_hh * 0.51
	var base_h: float = s * 0.060
	var body := _prism(base, hw, hh, base_h, pal["top"], pal["left"], pal["right"], pal["edge"])
	var top_center: Vector2 = body["top_center"]
	var dome_rx: float = hw * 1.05
	var dome_ry: float = s * (0.185 + 0.014 * float(_tier))
	# Dome body.
	draw_colored_polygon(_ellipse(top_center, dome_rx, dome_ry, 26, PI, TAU), pal["top"])
	draw_polyline(_ellipse(top_center, dome_rx, dome_ry, 26, PI, TAU), pal["edge"], 1.1, true)
	draw_line(top_center - Vector2(dome_rx, 0.0), top_center + Vector2(dome_rx, 0.0), pal["edge"], 1.0, true)
	# Dome ribs.
	draw_arc(top_center, dome_rx * 0.92, PI * 1.08, PI * 1.92, 16, UIPalette.alpha(UIPalette.ivory, 0.28), 1.0, true)
	draw_arc(top_center, dome_rx * 0.60, PI * 1.12, PI * 1.88, 12, UIPalette.alpha(UIPalette.ivory, 0.18), 1.0, true)
	draw_arc(top_center, dome_rx * 0.96, PI * 1.02, PI * 1.45, 10, UIPalette.alpha(UIPalette.amber, 0.30), 2.0, true)
	# Paw insignia on the dome.
	var paw_center: Vector2 = top_center + Vector2(dome_rx * 0.06, -dome_ry * 0.34)
	draw_circle(paw_center, maxf(2.4, s * 0.034), UIPalette.alpha(UIPalette.ink, 0.38))
	draw_circle(paw_center, maxf(1.8, s * 0.025), UIPalette.alpha(_accent, 0.55))
	for i in 4:
		var angle: float = PI + 0.32 + float(i) * 0.34
		var toe: Vector2 = paw_center + Vector2(cos(angle) * s * 0.046, sin(angle) * s * 0.046 - s * 0.006)
		draw_circle(toe, maxf(1.1, s * 0.014), UIPalette.alpha(_accent, 0.55))
	# Drone pad on the foundation.
	var pad_center: Vector2 = base + Vector2(pad_hw * 0.30, pad_hh * 0.76)
	var pad_rx: float = pad_hw * 0.25
	var pad_ry: float = maxf(1.8, pad_hh * 0.26)
	_ring(pad_center, pad_rx, pad_ry, UIPalette.alpha(UIPalette.amber, 0.38), 1.0, 20)
	_ring(pad_center, pad_rx * 0.62, pad_ry * 0.62, UIPalette.alpha(UIPalette.ivory, 0.18), 1.0, 16)
	if detail > 0.5:
		var drone := pad_center + Vector2(0.0, -s * 0.012)
		draw_circle(drone, maxf(1.6, s * 0.020), UIPalette.alpha(pal["metal_top"], 0.95))
		draw_circle(drone, maxf(1.1, s * 0.014), UIPalette.alpha(UIPalette.ink, 0.55))
		draw_circle(drone, maxf(0.6, s * 0.006), UIPalette.alpha(_accent, 0.95))
		for side in [-1.0, 1.0]:
			draw_line(drone + Vector2(side * s * 0.018, 0.0), drone + Vector2(side * s * 0.038, -s * 0.008), UIPalette.alpha(pal["metal_top"], 0.9), 1.2, true)
			draw_circle(drone + Vector2(side * s * 0.038, -s * 0.008), maxf(0.8, s * 0.008), UIPalette.alpha(_accent, 0.35), false, 1.0, true)
	# Pipes from the dome to the pad.
	var pipe_color := UIPalette.alpha(pal["metal_top"], 0.95)
	var pipe_a := base + Vector2(hw * 0.92, -base_h * 0.55)
	var pipe_b := base + Vector2(pad_hw * 0.18, pad_hh * 0.42)
	var pipe_c := pipe_b + Vector2(pad_hw * 0.20, 0.0)
	draw_polyline(_poly([pipe_a, pipe_b, pipe_c]), pipe_color, 2.0, true)
	draw_circle(pipe_b, maxf(1.0, s * 0.011), UIPalette.alpha(UIPalette.amber, 0.40))
	draw_line(pipe_b, pipe_c, UIPalette.alpha(_accent, 0.30), 0.8, true)
	var pipe2_a := base + Vector2(-hw * 0.72, -base_h * 0.30)
	var pipe2_b := base + Vector2(-pad_hw * 0.04, pad_hh * 0.30)
	draw_polyline(_poly([pipe2_a, pipe2_b]), UIPalette.alpha(pal["metal_top"], 0.55), 1.4, true)
	if _tier >= 2:
		var antenna_base: Vector2 = top_center + Vector2(dome_rx * 0.55, -dome_ry * 0.55)
		var antenna_top: Vector2 = antenna_base - Vector2(0.0, s * 0.075)
		draw_line(antenna_base, antenna_top, UIPalette.alpha(UIPalette.ivory, 0.55), 1.1, true)
		draw_circle(antenna_top, maxf(0.8, s * 0.009), UIPalette.alpha(_accent, 0.80))
	if _tier >= 3:
		draw_arc(top_center, dome_rx * 1.02, PI * 1.10, PI * 1.55, 12, UIPalette.alpha(_accent, 0.40), 1.2, true)


# ---------------------------------------------------------------------------
# reactor: twin cooling towers + glowing core + hazard stripes
# ---------------------------------------------------------------------------

func _draw_reactor(m: Dictionary, pal: Dictionary) -> void:
	var s: float = m["s"]
	var h: float = m["h"]
	var base: Vector2 = m["base"]
	var pad_hw: float = m["pad_hw"]
	var pad_hh: float = m["pad_hh"]
	var detail: float = m["detail"]
	var plinth_h: float = s * 0.052
	var plinth := _prism(base, pad_hw * 0.68, pad_hh * 0.55, plinth_h, pal["roof_top"], pal["roof_left"], pal["roof_right"], pal["edge"])
	var deck: Vector2 = plinth["top_center"]
	var deck_pts: PackedVector2Array = plinth["top"]
	var tower_h: float = minf(h * 0.38, s * (0.34 + 0.035 * float(_tier)))
	var bw: float = pad_hw * 0.18
	var tower_y: float = deck.y + pad_hh * 0.02
	for side in [-1.0, 1.0]:
		var cx: float = base.x + side * pad_hw * 0.31
		var bl := Vector2(cx - bw, tower_y)
		var br := Vector2(cx + bw, tower_y)
		var tw: float = bw * 0.70
		var tl := Vector2(cx - tw, tower_y - tower_h)
		var tr := Vector2(cx + tw, tower_y - tower_h)
		var mid := Vector2(cx, tower_y)
		draw_colored_polygon(_poly([bl, mid, Vector2(cx, tower_y - tower_h), tl]), pal["left"])
		draw_colored_polygon(_poly([mid, br, tr, Vector2(cx, tower_y - tower_h)]), pal["right"])
		# Rim and glow.
		draw_colored_polygon(_ellipse(Vector2(cx, tower_y - tower_h), tw, maxf(1.6, tw * 0.34), 20), UIPalette.darken(pal["metal_top"], 0.16))
		draw_polyline(_ellipse(Vector2(cx, tower_y - tower_h), tw, maxf(1.6, tw * 0.34), 20), pal["edge"], 1.0, true)
		draw_polyline(_ellipse(Vector2(cx, tower_y - tower_h), tw * 0.62, maxf(1.0, tw * 0.21), 16), UIPalette.alpha(_accent, 0.45), 1.0, true)
		for band_i in 3:
			var band_y: float = tower_y - tower_h * (0.22 + float(band_i) * 0.24)
			var band_w: float = lerpf(bw, tw, 0.22 + float(band_i) * 0.24)
			draw_line(Vector2(cx - band_w, band_y), Vector2(cx + band_w, band_y), UIPalette.alpha(UIPalette.ivory, 0.16), 1.0, true)
		draw_line(Vector2(cx - bw * 0.98, tower_y), Vector2(cx - tw * 0.98, tower_y - tower_h), UIPalette.alpha(UIPalette.ink, 0.28), 1.0, true)
		draw_line(Vector2(cx, tower_y), Vector2(cx, tower_y - tower_h), UIPalette.alpha(UIPalette.ink, 0.20), 1.0, true)
		draw_line(Vector2(cx - bw, tower_y), Vector2(cx + bw, tower_y), UIPalette.alpha(_accent, 0.30), 1.0, true)
	# Glowing core between the towers.
	var core_center := Vector2(base.x, deck.y - s * 0.090)
	for i in 4:
		var radius: float = s * (0.050 + float(i) * 0.024)
		draw_circle(core_center, radius, UIPalette.alpha(_accent, 0.030 + float(i) * 0.012))
	draw_circle(core_center, maxf(2.2, s * 0.034), UIPalette.alpha(_accent, 0.85))
	draw_circle(core_center, maxf(1.2, s * 0.018), UIPalette.alpha(UIPalette.ivory, 0.95))
	draw_line(core_center - Vector2(0.0, s * 0.062), core_center + Vector2(0.0, s * 0.062), UIPalette.alpha(_accent, 0.40), 2.0, true)
	if detail > 0.5:
		# Pipe bridge high between towers.
		var bridge_y: float = deck.y - tower_h * 0.72
		draw_line(Vector2(base.x - pad_hw * 0.30 + bw, bridge_y), Vector2(base.x + pad_hw * 0.30 - bw, bridge_y), UIPalette.alpha(pal["metal_top"], 0.75), 1.6, true)
		draw_line(Vector2(base.x - pad_hw * 0.12, bridge_y), Vector2(base.x - pad_hw * 0.12, bridge_y + s * 0.030), UIPalette.alpha(pal["metal_top"], 0.45), 1.0, true)
		draw_line(Vector2(base.x + pad_hw * 0.12, bridge_y), Vector2(base.x + pad_hw * 0.12, bridge_y + s * 0.030), UIPalette.alpha(pal["metal_top"], 0.45), 1.0, true)
	# Hazard stripes on the plinth front.
	for stripe in 5:
		var t0: float = 0.10 + float(stripe) * 0.16
		draw_line(
			deck_pts[2].lerp(deck_pts[1], t0) + Vector2(0.0, -plinth_h * 0.18),
			deck_pts[2].lerp(deck_pts[1], t0 + 0.08) + Vector2(0.0, -plinth_h * 0.62),
			UIPalette.alpha(UIPalette.amber, 0.40),
			1.2,
			true
		)
		draw_line(
			deck_pts[3].lerp(deck_pts[2], t0) + Vector2(0.0, -plinth_h * 0.18),
			deck_pts[3].lerp(deck_pts[2], t0 + 0.08) + Vector2(0.0, -plinth_h * 0.62),
			UIPalette.alpha(UIPalette.amber, 0.34),
			1.2,
			true
		)
	if _tier >= 2:
		draw_arc(core_center, s * 0.065, 0.0, TAU, 28, UIPalette.alpha(_accent, 0.50), 1.2, true)
	if _tier >= 3:
		for side in [-1.0, 1.0]:
			var vent_top: Vector2 = Vector2(base.x + side * pad_hw * 0.30, tower_y - tower_h)
			draw_line(vent_top + Vector2(0.0, -s * 0.010), vent_top + Vector2(0.0, -s * 0.045), UIPalette.alpha(UIPalette.ivory, 0.30), 1.2, true)
			draw_circle(vent_top + Vector2(0.0, -s * 0.050), maxf(0.9, s * 0.010), UIPalette.alpha(UIPalette.amber, 0.70))


# ---------------------------------------------------------------------------
# signal_array: tall dish tower + beacon + cables
# ---------------------------------------------------------------------------

func _draw_signal_array(m: Dictionary, pal: Dictionary) -> void:
	var s: float = m["s"]
	var h: float = m["h"]
	var base: Vector2 = m["base"]
	var pad_hw: float = m["pad_hw"]
	var pad_hh: float = m["pad_hh"]
	var detail: float = m["detail"]
	var foot_h: float = s * 0.055
	var foot := _prism(base, pad_hw * 0.37, pad_hh * 0.46, foot_h, pal["roof_top"], pal["roof_left"], pal["roof_right"], pal["edge"])
	var deck: Vector2 = foot["top_center"]
	var mast_h: float = minf(h * 0.50, s * (0.32 + 0.040 * float(_tier)))
	var bottom_half: float = s * 0.052
	var top_half: float = s * 0.020
	var mast_base := deck
	var mast_top := mast_base - Vector2(0.0, mast_h)
	var steel := UIPalette.mix(pal["metal_top"], UIPalette.ivory, 0.30)
	var dim := UIPalette.alpha(steel, 0.60)
	# Lattice legs.
	draw_line(mast_base + Vector2(-bottom_half, 0.0), mast_top + Vector2(-top_half, 0.0), steel, 1.8, true)
	draw_line(mast_base + Vector2(bottom_half, 0.0), mast_top + Vector2(top_half, 0.0), steel, 1.8, true)
	var segments: int = 4 + _tier
	for i in segments:
		var t0: float = float(i) / float(segments)
		var t1: float = float(i + 1) / float(segments)
		var a0: Vector2 = mast_base + Vector2(-lerpf(bottom_half, top_half, t0), -mast_h * t0)
		var b0: Vector2 = mast_base + Vector2(lerpf(bottom_half, top_half, t0), -mast_h * t0)
		var a1: Vector2 = mast_base + Vector2(-lerpf(bottom_half, top_half, t1), -mast_h * t1)
		var b1: Vector2 = mast_base + Vector2(lerpf(bottom_half, top_half, t1), -mast_h * t1)
		draw_line(a0, b0, dim, 1.0, true)
		draw_line(a0, b1, UIPalette.alpha(steel, 0.38), 1.0, true)
		draw_line(b0, a1, UIPalette.alpha(steel, 0.38), 1.0, true)
	# Dish: a tilted ellipse with a feed arm.
	var dish_center: Vector2 = mast_top + Vector2(0.0, -s * 0.010)
	var dish_rx: float = s * (0.130 + 0.009 * float(_tier))
	var dish_ry: float = dish_rx * 0.62
	var dish_tilt: float = -0.42
	draw_set_transform(dish_center, dish_tilt, Vector2(1.0, 0.58))
	draw_circle(Vector2.ZERO, dish_rx, UIPalette.alpha(_accent, 0.08))
	draw_arc(Vector2.ZERO, dish_rx, 0.0, TAU, 30, UIPalette.alpha(UIPalette.ivory, 0.62), 1.5, true)
	draw_arc(Vector2.ZERO, dish_rx * 0.55, 0.0, TAU, 22, UIPalette.alpha(_accent, 0.35), 1.0, true)
	draw_line(Vector2(-dish_rx, 0.0), Vector2(dish_rx, 0.0), UIPalette.alpha(UIPalette.ivory, 0.24), 1.0, true)
	draw_line(Vector2.ZERO, Vector2(dish_rx * 0.80, 0.0), UIPalette.alpha(UIPalette.ivory, 0.50), 1.3, true)
	draw_circle(Vector2(dish_rx * 0.80, 0.0), maxf(1.0, s * 0.010), UIPalette.alpha(_accent, 0.90))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Feed horn.
	draw_line(dish_center + Vector2(0.0, -dish_ry * 0.2), dish_center + Vector2(s * 0.020, -dish_ry * 1.35), UIPalette.alpha(UIPalette.ivory, 0.42), 1.0, true)
	draw_circle(dish_center + Vector2(s * 0.020, -dish_ry * 1.35), maxf(1.0, s * 0.009), UIPalette.alpha(_accent, 0.85))
	# Beacon above the dish.
	var beacon := dish_center - Vector2(0.0, dish_ry + s * 0.030)
	draw_line(dish_center, beacon, UIPalette.alpha(UIPalette.ivory, 0.32), 1.0, true)
	draw_circle(beacon, maxf(1.6, s * 0.020), UIPalette.alpha(_accent, 0.20))
	draw_circle(beacon, maxf(1.0, s * 0.012), UIPalette.alpha(_accent, 0.95))
	if _tier >= 2:
		for ray in 4:
			var angle: float = -PI * 0.5 + (float(ray) - 1.5) * 0.40
			draw_line(beacon, beacon + Vector2(cos(angle), sin(angle)) * s * 0.042, UIPalette.alpha(_accent, 0.35), 1.0, true)
	# Guy cables to the foundation.
	_cable(mast_top + Vector2(0.0, s * 0.060), base + Vector2(-pad_hw * 0.78, pad_hh * 0.34), s * 0.035, UIPalette.alpha(steel, 0.35), 1.0)
	_cable(mast_top + Vector2(0.0, s * 0.060), base + Vector2(pad_hw * 0.78, pad_hh * 0.34), s * 0.035, UIPalette.alpha(steel, 0.35), 1.0)
	if detail > 0.55:
		_cable(mast_base + Vector2(0.0, -mast_h * 0.45), base + Vector2(-pad_hw * 0.55, pad_hh * 0.70), s * 0.028, UIPalette.alpha(steel, 0.22), 1.0)
		_cable(mast_base + Vector2(0.0, -mast_h * 0.45), base + Vector2(pad_hw * 0.55, pad_hh * 0.70), s * 0.028, UIPalette.alpha(steel, 0.22), 1.0)
	# Small storage shed at the mast foot.
	if detail > 0.5:
		var shed := _prism(base + Vector2(-pad_hw * 0.20, pad_hh * 0.20), s * 0.050, s * 0.022, s * 0.040, pal["top"], pal["left"], pal["right"], pal["edge"])
		draw_line(shed["top_center"] + Vector2(-s * 0.042, s * 0.010), shed["top_center"] + Vector2(s * 0.042, s * 0.010), UIPalette.alpha(UIPalette.ink, 0.40), 1.0, true)
	# Tier 3 secondary dish.
	if _tier >= 3:
		var side_dish := mast_base + Vector2(-s * 0.085, -mast_h * 0.52)
		draw_set_transform(side_dish, 0.40, Vector2(1.0, 0.55))
		draw_arc(Vector2.ZERO, s * 0.050, 0.0, TAU, 20, UIPalette.alpha(UIPalette.ivory, 0.50), 1.2, true)
		draw_circle(Vector2.ZERO, s * 0.016, UIPalette.alpha(_accent, 0.30))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_line(side_dish, mast_base + Vector2(-s * 0.030, -mast_h * 0.35), UIPalette.alpha(steel, 0.45), 1.0, true)


# ---------------------------------------------------------------------------
# Unknown module fallback
# ---------------------------------------------------------------------------

func _draw_generic(m: Dictionary, pal: Dictionary) -> void:
	var s: float = m["s"]
	var base: Vector2 = m["base"]
	var pad_hw: float = m["pad_hw"]
	var pad_hh: float = m["pad_hh"]
	var body_h: float = s * (0.12 + 0.02 * float(_tier))
	var body := _prism(base, pad_hw * 0.32, pad_hh * 0.46, body_h, pal["top"], pal["left"], pal["right"], pal["edge"])
	var top_center: Vector2 = body["top_center"]
	var base_pts: PackedVector2Array = body["base"]
	_slab(top_center - Vector2(0.0, s * 0.006), pad_hw * 0.34, pad_hh * 0.48, s * 0.022, pal["roof_top"], pal["edge"])
	_face_windows(base_pts[3], base_pts[2], body_h, 2, 2, Vector2(s * 0.028, s * 0.018), UIPalette.alpha(_accent, 0.50))
	draw_line(Vector2(base.x, top_center.y), Vector2(base.x, top_center.y - s * 0.10), UIPalette.alpha(UIPalette.ivory, 0.40), 1.2, true)
	draw_circle(Vector2(base.x, top_center.y - s * 0.10), maxf(1.0, s * 0.010), UIPalette.alpha(_accent, 0.80))
