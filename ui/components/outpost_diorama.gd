class_name UIOutpostDiorama
extends Control
## Stable 8x8 isometric board for Waystation Kestrel. The parent control draws
## the plate, ground texture, pads, connector walkways, labels and selection;
## one UIModuleArt child per module draws the actual structure at the exact
## ProfileState layout rect. Geometry is rebuilt on resize/refresh, never only
## during _draw, so hit testing and tests are deterministic.

signal module_selected(module_id: StringName)

const BOARD_CELLS := 8
const NEXUS_ID := &"command_nexus"
const BASE_LABEL_FORMAT := "WAYSTATION KESTREL // BASE POWER %d"

var selected_module: StringName = &""

var _hovered: StringName = &""
var _layout: Dictionary = {}
var _footprints: Dictionary = {}
var _hit_rects: Dictionary = {}
var _art_by_id: Dictionary = {}
var _board_rect := Rect2()
var _cell := 0.0
var _geometry_size := Vector2(-1.0, -1.0)
var _layout_dirty := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(300, 280)
	clip_contents = true
	tooltip_text = "Click a module to inspect it."
	resized.connect(_on_resized)
	_update_geometry(true)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func refresh() -> void:
	_layout_dirty = true
	_geometry_size = Vector2(-1.0, -1.0)
	_update_geometry(true)
	if not _hovered.is_empty() and not _layout.has(_hovered):
		_hovered = &""
	_update_tooltip()
	queue_redraw()


func get_board_rect() -> Rect2:
	_ensure_geometry()
	return _board_rect


func get_module_rect(module_id: StringName) -> Rect2:
	_ensure_geometry()
	return _module_rect_raw(module_id)


func get_layout() -> Dictionary:
	_ensure_geometry()
	return _layout.duplicate()


func get_module_art() -> Array:
	_ensure_geometry()
	var result: Array = []
	for module_id in _layout.keys():
		var art: Variant = _art_by_id.get(module_id)
		if art is UIModuleArt and is_instance_valid(art):
			result.append(art)
	return result


func get_module_at(point: Vector2) -> StringName:
	_ensure_geometry()
	return _module_at(point)


func get_cell_size() -> float:
	_ensure_geometry()
	return _cell


func get_selected_module() -> StringName:
	return selected_module


# ---------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------

func _on_resized() -> void:
	_geometry_size = Vector2(-1.0, -1.0)
	_update_geometry(true)
	queue_redraw()


func _ensure_geometry() -> void:
	if _board_rect.size.x <= 0.0 or _geometry_size != size or _layout.is_empty():
		_update_geometry(true)
	elif _hit_rects.size() != _layout.size():
		_rebuild_hit_rects()


func _compute_geometry() -> void:
	_board_rect = Rect2()
	_cell = 0.0
	if size.x < 40.0 or size.y < 40.0:
		return
	var margin: float = clampf(minf(size.x, size.y) * 0.035, 3.0, 16.0)
	var label_band: float = clampf(size.y * 0.085, 15.0, 28.0)
	var available_w: float = maxf(24.0, size.x - margin * 2.0)
	var available_h: float = maxf(24.0, size.y - margin * 2.0 - label_band)
	var side: float = floorf(minf(available_w, available_h))
	if side < 32.0:
		return
	var pos_x: float = floorf((size.x - side) * 0.5)
	var pos_y: float = floorf(margin + (available_h - side) * 0.5)
	_board_rect = Rect2(Vector2(pos_x, pos_y), Vector2(side, side))
	_cell = side / float(BOARD_CELLS)


func _update_geometry(sync_children: bool = true) -> void:
	_compute_geometry()
	if _layout_dirty or _layout.is_empty():
		_layout = _resolve_layout()
		_layout_dirty = false
	if sync_children:
		_sync_children()
	_rebuild_hit_rects()
	_geometry_size = size


func _rebuild_hit_rects() -> void:
	_hit_rects.clear()
	if _board_rect.size.x <= 0.0:
		return
	for module_id in _layout.keys():
		_hit_rects[module_id] = _module_rect_raw(module_id)


func _module_rect_raw(module_id: StringName) -> Rect2:
	if not _layout.has(module_id) or _cell <= 0.0:
		return Rect2()
	var cell_pos: Vector2i = _layout[module_id]
	var footprint: Vector2i = _footprints.get(module_id, Vector2i(2, 2))
	return Rect2(
		_board_rect.position + Vector2(cell_pos.x, cell_pos.y) * _cell,
		Vector2(footprint.x, footprint.y) * _cell
	)


func _module_at(point: Vector2) -> StringName:
	for module_id in _layout.keys():
		var rect: Rect2 = _hit_rects.get(module_id, Rect2())
		if rect.size.x > 0.0 and rect.has_point(point):
			return module_id
	return &""


# ---------------------------------------------------------------------------
# Layout resolution (safe against old / invalid saves)
# ---------------------------------------------------------------------------

func _resolve_layout() -> Dictionary:
	_footprints.clear()
	var module_ids: Array[StringName] = []
	var base_layout: Dictionary = {}
	if ProfileState != null:
		base_layout = ProfileState.BASE_LAYOUT
	if ContentDB != null:
		for raw_id in ContentDB.base_modules.keys():
			var module_id := StringName(raw_id)
			var module := ContentDB.get_base_module(module_id)
			_footprints[module_id] = module.footprint if module != null else Vector2i(2, 2)
			module_ids.append(module_id)
	# Canonical order first, then any extra content modules, so fallback seats
	# are deterministic across runs.
	var ordered: Array[StringName] = []
	for raw_id in base_layout.keys():
		var module_id := StringName(raw_id)
		if not ordered.has(module_id):
			ordered.append(module_id)
			if not _footprints.has(module_id):
				var module := ContentDB.get_base_module(module_id) if ContentDB != null else null
				_footprints[module_id] = module.footprint if module != null else Vector2i(2, 2)
	for module_id in module_ids:
		if not ordered.has(module_id):
			ordered.append(module_id)
	if ordered.is_empty():
		return {}
	var stored: Dictionary = {}
	if ProfileState != null:
		var loaded: Dictionary = ProfileState.get_base_layout()
		if loaded is Dictionary:
			stored = loaded
	var resolved: Dictionary = {}
	var occupied: Dictionary = {}
	for module_id in ordered:
		var footprint: Vector2i = _footprints.get(module_id, Vector2i(2, 2))
		footprint = Vector2i(clampi(footprint.x, 1, BOARD_CELLS), clampi(footprint.y, 1, BOARD_CELLS))
		_footprints[module_id] = footprint
		var position := _read_position(stored.get(module_id), module_id, base_layout)
		if not _fits(position, footprint, occupied):
			position = _find_free_slot(footprint, occupied)
		if position.x < 0:
			continue
		resolved[module_id] = position
		_occupy(position, footprint, occupied)
	return resolved


func _read_position(value: Variant, module_id: StringName, base_layout: Dictionary) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(roundi(value.x), roundi(value.y))
	if value is Array:
		var array: Array = value
		if array.size() >= 2 and _is_number(array[0]) and _is_number(array[1]):
			return Vector2i(int(array[0]), int(array[1]))
	if value is String or value is StringName:
		var parsed: Variant = str_to_var(String(value))
		if parsed is Vector2i:
			return parsed
		if parsed is Array:
			var parsed_array: Array = parsed
			if parsed_array.size() >= 2 and _is_number(parsed_array[0]) and _is_number(parsed_array[1]):
				return Vector2i(int(parsed_array[0]), int(parsed_array[1]))
	if base_layout.has(module_id):
		var fallback: Variant = base_layout[module_id]
		if fallback is Vector2i:
			return fallback
	return Vector2i(-1, -1)


func _is_number(value: Variant) -> bool:
	return value is int or value is float


func _fits(position: Vector2i, footprint: Vector2i, occupied: Dictionary) -> bool:
	if position.x < 0 or position.y < 0:
		return false
	if position.x + footprint.x > BOARD_CELLS or position.y + footprint.y > BOARD_CELLS:
		return false
	for y in footprint.y:
		for x in footprint.x:
			if occupied.has(Vector2i(position.x + x, position.y + y)):
				return false
	return true


func _find_free_slot(footprint: Vector2i, occupied: Dictionary) -> Vector2i:
	for y in BOARD_CELLS:
		for x in BOARD_CELLS:
			var candidate := Vector2i(x, y)
			if _fits(candidate, footprint, occupied):
				return candidate
	return Vector2i(-1, -1)


func _occupy(position: Vector2i, footprint: Vector2i, occupied: Dictionary) -> void:
	for y in footprint.y:
		for x in footprint.x:
			occupied[Vector2i(position.x + x, position.y + y)] = true


# ---------------------------------------------------------------------------
# Children
# ---------------------------------------------------------------------------

func _sync_children() -> void:
	if _board_rect.size.x <= 0.0:
		return
	var keep: Dictionary = {}
	for module_id in _layout.keys():
		keep[module_id] = true
		var art: Variant = _art_by_id.get(module_id)
		if not (art is UIModuleArt) or not is_instance_valid(art):
			art = UIModuleArt.new()
			art.name = "Module_%s" % String(module_id)
			add_child(art)
			_art_by_id[module_id] = art
		var rect := _module_rect_raw(module_id)
		art.position = rect.position
		art.size = rect.size
		var cell_pos: Vector2i = _layout[module_id]
		art.z_index = 1 + cell_pos.y
		var compact: bool = minf(rect.size.x, rect.size.y) < 92.0
		art.configure(
			module_id,
			_tier_for(module_id),
			_accent_for(module_id),
			module_id == selected_module,
			module_id == _hovered,
			compact
		)
	for module_id in _art_by_id.keys():
		if keep.has(module_id):
			continue
		var stale: Variant = _art_by_id[module_id]
		_art_by_id.erase(module_id)
		if stale is Control and is_instance_valid(stale):
			stale.queue_free()


func _sync_child_states() -> void:
	for module_id in _layout.keys():
		var art: Variant = _art_by_id.get(module_id)
		if not (art is UIModuleArt) or not is_instance_valid(art):
			continue
		var rect := _module_rect_raw(module_id)
		var compact: bool = minf(rect.size.x, rect.size.y) < 92.0
		art.configure(
			module_id,
			_tier_for(module_id),
			_accent_for(module_id),
			module_id == selected_module,
			module_id == _hovered,
			compact
		)


func _tier_for(module_id: StringName) -> int:
	if ProfileState == null:
		return 0
	return ProfileState.get_base_tier(module_id)


func _accent_for(module_id: StringName) -> Color:
	var module := ContentDB.get_base_module(module_id) if ContentDB != null else null
	if module == null:
		return UIPalette.mint
	return module.accent


func _display_name_for(module_id: StringName) -> String:
	var module := ContentDB.get_base_module(module_id) if ContentDB != null else null
	if module == null:
		return String(module_id).replace("_", " ").capitalize()
	return module.display_name


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	if _board_rect.size.x <= 0.0 or _geometry_size != size:
		_update_geometry(true)
	if size.x > 1.0 and size.y > 1.0:
		draw_rect(Rect2(Vector2.ZERO, size), UIPalette.alpha(UIPalette.ink, 0.24))
	if _board_rect.size.x <= 0.0 or _cell <= 0.0:
		return
	_draw_ground_texture()
	_draw_plate()
	_draw_roads()
	_draw_foundation_slots()
	_draw_perimeter()
	_draw_selection()
	_draw_labels()


func _draw_ground_texture() -> void:
	var board := _board_rect
	var center := board.get_center()
	# Low-contrast contour bands, all contained by the plate.
	var contour_a := _ellipse_points(center + Vector2(-board.size.x * 0.06, board.size.y * 0.03), board.size.x * 0.30, board.size.y * 0.20, 34)
	var contour_b := _ellipse_points(center + Vector2(board.size.x * 0.10, -board.size.y * 0.05), board.size.x * 0.22, board.size.y * 0.15, 30)
	draw_polyline(contour_a, UIPalette.alpha(UIPalette.line, 0.14), 1.0, true)
	draw_polyline(contour_b, UIPalette.alpha(UIPalette.line, 0.10), 1.0, true)
	# Deterministic terrain specks: no RNG, stable between frames.
	for i in 46:
		var fx: float = _hash01(float(i) * 12.9898 + 0.37)
		var fy: float = _hash01(float(i) * 78.233 + 4.13)
		var point := board.position + Vector2(board.size.x * (0.04 + fx * 0.92), board.size.y * (0.05 + fy * 0.90))
		var radius: float = 0.6 + float(i % 3) * 0.35
		draw_circle(point, radius, UIPalette.alpha(UIPalette.line, 0.11))
	# Soft vignette bands (four edges), drawn inside the plate.
	var band: float = maxf(3.0, board.size.x * 0.035)
	draw_rect(Rect2(board.position, Vector2(board.size.x, band)), UIPalette.alpha(UIPalette.ink, 0.10))
	draw_rect(Rect2(Vector2(board.position.x, board.end.y - band), Vector2(board.size.x, band)), UIPalette.alpha(UIPalette.ink, 0.12))


func _draw_plate() -> void:
	var board := _board_rect
	draw_rect(Rect2(board.position + Vector2(2.0, 3.0), board.size), UIPalette.alpha(UIPalette.ink, 0.32))
	draw_rect(board, UIPalette.mix(UIPalette.surface, UIPalette.ink, 0.24))
	draw_rect(board.grow(-1.0), UIPalette.alpha(UIPalette.line, 0.85), false, 1.0, true)
	# Grid.
	for i in BOARD_CELLS + 1:
		var x: float = board.position.x + float(i) * _cell
		draw_line(Vector2(x, board.position.y), Vector2(x, board.end.y), UIPalette.alpha(UIPalette.line, 0.28), 1.0)
		var y: float = board.position.y + float(i) * _cell
		draw_line(Vector2(board.position.x, y), Vector2(board.end.x, y), UIPalette.alpha(UIPalette.line, 0.28), 1.0)
	# Center cross ticks at every 2 cells.
	for i in range(2, BOARD_CELLS, 2):
		var x: float = board.position.x + float(i) * _cell
		var y: float = board.position.y + float(i) * _cell
		draw_line(Vector2(x - 3.0, board.position.y), Vector2(x + 3.0, board.position.y), UIPalette.alpha(UIPalette.ivory, 0.20), 1.0, true)
		draw_line(Vector2(board.position.x, y - 3.0), Vector2(board.position.x, y + 3.0), UIPalette.alpha(UIPalette.ivory, 0.20), 1.0, true)


func _draw_roads() -> void:
	if not _layout.has(NEXUS_ID):
		return
	var nexus_rect := _module_rect_raw(NEXUS_ID)
	var nexus_center := nexus_rect.get_center()
	var road_width: float = maxf(1.4, _cell * 0.12)
	for module_id in _layout.keys():
		if module_id == NEXUS_ID:
			continue
		var rect := _module_rect_raw(module_id)
		var points := _road_points(rect.get_center(), nexus_center)
		var built: bool = _tier_for(module_id) > 0
		var accent := _accent_for(module_id)
		if built:
			draw_polyline(points, UIPalette.alpha(UIPalette.ink, 0.46), road_width + 2.0, true)
			draw_polyline(points, UIPalette.alpha(UIPalette.mix(UIPalette.line, UIPalette.surface_high, 0.50), 0.95), road_width, true)
			_draw_dashed_path(points, UIPalette.alpha(accent, 0.34), maxf(0.9, road_width * 0.14), _cell * 0.16, _cell * 0.13)
		else:
			_draw_dashed_path(points, UIPalette.alpha(UIPalette.line, 0.42), maxf(1.0, road_width * 0.42), _cell * 0.12, _cell * 0.10)
	draw_circle(nexus_center, maxf(1.4, _cell * 0.05), UIPalette.alpha(_accent_for(NEXUS_ID), 0.28))
	draw_circle(nexus_center, maxf(1.0, _cell * 0.022), UIPalette.alpha(_accent_for(NEXUS_ID), 0.55), false, 1.0, true)


func _draw_foundation_slots() -> void:
	for module_id in _layout.keys():
		var rect := _module_rect_raw(module_id)
		if rect.size.x <= 1.0:
			continue
		var inset := rect.grow(-1.5)
		draw_rect(inset, UIPalette.alpha(UIPalette.ink, 0.18))
		draw_rect(inset, UIPalette.alpha(UIPalette.line, 0.24), false, 1.0, true)
		# Slot corner ticks.
		var tick: float = minf(7.0, minf(rect.size.x, rect.size.y) * 0.16)
		for corner in [
			[inset.position, Vector2(1.0, 0.0), Vector2(0.0, 1.0)],
			[Vector2(inset.end.x, inset.position.y), Vector2(-1.0, 0.0), Vector2(0.0, 1.0)],
			[inset.end, Vector2(-1.0, 0.0), Vector2(0.0, -1.0)],
			[Vector2(inset.position.x, inset.end.y), Vector2(1.0, 0.0), Vector2(0.0, -1.0)],
		]:
			var origin: Vector2 = corner[0]
			var dir_h: Vector2 = corner[1]
			var dir_v: Vector2 = corner[2]
			draw_line(origin, origin + dir_h * tick, UIPalette.alpha(UIPalette.ivory, 0.12), 1.0, true)
			draw_line(origin, origin + dir_v * tick, UIPalette.alpha(UIPalette.ivory, 0.12), 1.0, true)


func _draw_perimeter() -> void:
	var board := _board_rect
	var accent := UIPalette.alpha(UIPalette.mint, 0.42)
	var bracket: float = clampf(minf(board.size.x, board.size.y) * 0.06, 6.0, 18.0)
	var inset: float = 3.0
	var corners: Array = [
		[board.position + Vector2(inset, inset), Vector2(1.0, 0.0), Vector2(0.0, 1.0)],
		[Vector2(board.end.x - inset, board.position.y + inset), Vector2(-1.0, 0.0), Vector2(0.0, 1.0)],
		[board.end - Vector2(inset, inset), Vector2(-1.0, 0.0), Vector2(0.0, -1.0)],
		[Vector2(board.position.x + inset, board.end.y - inset), Vector2(1.0, 0.0), Vector2(0.0, -1.0)],
	]
	for corner in corners:
		var origin: Vector2 = corner[0]
		draw_line(origin, origin + (corner[1] as Vector2) * bracket, accent, 1.5, true)
		draw_line(origin, origin + (corner[2] as Vector2) * bracket, accent, 1.5, true)
	# Edge tick lights.
	var dot: float = maxf(0.9, _cell * 0.035)
	for i in range(1, BOARD_CELLS):
		var x: float = board.position.x + float(i) * _cell
		var y: float = board.position.y + float(i) * _cell
		draw_circle(Vector2(x, board.position.y + inset), dot, UIPalette.alpha(UIPalette.ivory, 0.20))
		draw_circle(Vector2(board.end.x - inset, y), dot, UIPalette.alpha(UIPalette.ivory, 0.20))
	# North marker.
	var north := Vector2(board.end.x - 16.0, board.position.y + 16.0)
	draw_line(north + Vector2(0.0, 5.0), north + Vector2(0.0, -5.0), UIPalette.alpha(UIPalette.ivory, 0.42), 1.2, true)
	draw_line(north + Vector2(0.0, -5.0), north + Vector2(-2.5, -1.0), UIPalette.alpha(UIPalette.ivory, 0.42), 1.2, true)
	draw_line(north + Vector2(0.0, -5.0), north + Vector2(2.5, -1.0), UIPalette.alpha(UIPalette.ivory, 0.42), 1.2, true)
	var font := UIFonts.mono(true)
	if font != null:
		draw_string(font, north + Vector2(-3.0, -8.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIPalette.alpha(UIPalette.ivory, 0.42))


func _draw_selection() -> void:
	if _hovered != &"" and _layout.has(_hovered):
		_draw_brackets(_module_rect_raw(_hovered), _accent_for(_hovered), 0.45, 1.0)
	if selected_module != &"" and _layout.has(selected_module):
		var rect := _module_rect_raw(selected_module)
		var accent := _accent_for(selected_module)
		draw_rect(rect.grow(1.0), UIPalette.alpha(accent, 0.06))
		_draw_brackets(rect, accent, 0.95, 2.0)
		# Pointer triangle above the selected pad, kept inside the board.
		var pointer_y: float = rect.position.y - 2.0
		if pointer_y - 8.0 > _board_rect.position.y:
			var pointer := PackedVector2Array([
				Vector2(rect.get_center().x - 4.0, pointer_y - 7.0),
				Vector2(rect.get_center().x + 4.0, pointer_y - 7.0),
				Vector2(rect.get_center().x, pointer_y),
			])
			draw_colored_polygon(pointer, UIPalette.alpha(accent, 0.9))


func _draw_brackets(rect: Rect2, accent: Color, strength: float, width: float) -> void:
	var color := UIPalette.alpha(accent, strength)
	var length: float = minf(12.0, minf(rect.size.x, rect.size.y) * 0.22)
	var inset: float = 1.5
	var top_left: Vector2 = rect.position + Vector2(inset, inset)
	var top_right: Vector2 = Vector2(rect.end.x - inset, rect.position.y + inset)
	var bottom_left: Vector2 = Vector2(rect.position.x + inset, rect.end.y - inset)
	var bottom_right: Vector2 = rect.end - Vector2(inset, inset)
	draw_line(top_left, top_left + Vector2(length, 0.0), color, width, true)
	draw_line(top_left, top_left + Vector2(0.0, length), color, width, true)
	draw_line(top_right, top_right - Vector2(length, 0.0), color, width, true)
	draw_line(top_right, top_right + Vector2(0.0, length), color, width, true)
	draw_line(bottom_left, bottom_left + Vector2(length, 0.0), color, width, true)
	draw_line(bottom_left, bottom_left - Vector2(0.0, length), color, width, true)
	draw_line(bottom_right, bottom_right - Vector2(length, 0.0), color, width, true)
	draw_line(bottom_right, bottom_right - Vector2(0.0, length), color, width, true)


func _draw_labels() -> void:
	var board := _board_rect
	var font := UIFonts.mono(false)
	if font == null:
		return
	var label_band: float = maxf(12.0, size.y - board.end.y)
	var font_size: int = clampi(roundi(size.y * 0.020), 9, 13)
	var label := BASE_LABEL_FORMAT % (ProfileState.get_base_power() if ProfileState != null else 0)
	var baseline := board.end.y + maxf(11.0, label_band * 0.62)
	draw_string(
		font,
		Vector2(board.position.x, baseline),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		board.size.x,
		font_size,
		UIPalette.alpha(UIPalette.muted, 0.92)
	)


# ---------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------

func _ellipse_points(center: Vector2, rx: float, ry: float, segments: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := maxi(3, segments)
	for i in count + 1:
		var angle: float = TAU * float(i) / float(count)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points


func _road_points(from: Vector2, to: Vector2) -> PackedVector2Array:
	var bend: Vector2
	if absf(to.x - from.x) >= absf(to.y - from.y):
		bend = Vector2(to.x, from.y)
	else:
		bend = Vector2(from.x, to.y)
	return PackedVector2Array([from, bend, to])


func _draw_dashed_path(points: PackedVector2Array, color: Color, width: float, dash: float, gap: float) -> void:
	for i in points.size() - 1:
		var from: Vector2 = points[i]
		var to: Vector2 = points[i + 1]
		var length := from.distance_to(to)
		if length <= 0.01:
			continue
		var direction := (to - from) / length
		var travelled := 0.0
		while travelled < length:
			var segment := minf(dash, length - travelled)
			draw_line(from + direction * travelled, from + direction * (travelled + segment), color, width, true)
			travelled += dash + gap


func _hash01(value: float) -> float:
	var hashed: float = sin(value) * 43758.5453
	return hashed - floorf(hashed)


# ---------------------------------------------------------------------------
# Input / hover
# ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_set_hover(_module_at(motion.position))
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			var found := _module_at(click.position)
			if found != &"":
				selected_module = found
				_sync_child_states()
				_update_tooltip()
				queue_redraw()
				module_selected.emit(found)
				accept_event()


func _set_hover(module_id: StringName) -> void:
	if module_id == _hovered:
		return
	_hovered = module_id
	_sync_child_states()
	_update_tooltip()
	queue_redraw()


func _update_tooltip() -> void:
	if _hovered != &"":
		var tier: int = _tier_for(_hovered)
		var state := "Planned" if tier <= 0 else "Tier %d" % tier
		tooltip_text = "%s - %s\nClick to inspect." % [_display_name_for(_hovered), state]
	else:
		tooltip_text = "Click a module on the map to inspect it."


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hovered != &"":
		_hovered = &""
		_sync_child_states()
		_update_tooltip()
		queue_redraw()
