class_name UIOutpostDiorama
extends Control
## Code-drawn stylised outpost map. Reflects the built module tiers from
## ProfileState and reports module clicks for inspection.

signal module_selected(module_id: StringName)

const MODULE_TINTS := {
	&"command_nexus": Color("f4efe5"),
	&"foundry": Color("ffb866"),
	&"armory": Color("6fa8ff"),
	&"infirmary": Color("62e6c3"),
	&"barracks": Color("c79cff"),
	&"drift_den": Color("ffc16b"),
	&"reactor": Color("c79cff"),
	&"signal_array": Color("63b8ff"),
}

const MODULE_ACCENTS := {
	&"command_nexus": Color("62e6c3"),
	&"foundry": Color("f4efe5"),
	&"armory": Color("f4efe5"),
	&"infirmary": Color("f4efe5"),
	&"barracks": Color("f4efe5"),
	&"drift_den": Color("d28b58"),
	&"reactor": Color("62e6c3"),
	&"signal_array": Color("c79cff"),
}

var selected_module: StringName = &""
var _hovered: StringName = &""
var _cell := 48.0
var _origin := Vector2.ZERO
var _hit_rects: Dictionary = {}
var _layout: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(500, 400)
	tooltip_text = "Click a module to inspect it."
	resized.connect(queue_redraw)


func refresh() -> void:
	_layout = ProfileState.get_base_layout()
	queue_redraw()


func _module_rect(module_id: StringName) -> Rect2:
	var module := ContentDB.get_base_module(module_id)
	var pos: Vector2i = _layout.get(module_id, Vector2i(0, 0))
	var footprint := module.footprint if module != null else Vector2i(2, 2)
	return Rect2(
		_origin + Vector2(pos) * _cell,
		Vector2(footprint) * _cell
	)


func _compute_geometry() -> void:
	if _layout.is_empty():
		refresh_layout_only()
	var cell_x := size.x / 8.2
	var cell_y := size.y / 8.2
	_cell = minf(cell_x, cell_y)
	var grid_span := _cell * 7.0
	_origin = Vector2((size.x - grid_span) * 0.5, (size.y - grid_span) * 0.5 + _cell * 0.35)


func refresh_layout_only() -> void:
	_layout = ProfileState.get_base_layout()


func _draw() -> void:
	if _layout.is_empty():
		refresh_layout_only()
	_compute_geometry()
	_hit_rects.clear()
	var width := size.x
	var height := size.y
	# Board plate.
	draw_rect(Rect2(Vector2.ZERO, size), UIPalette.alpha(UIPalette.ink, 0.5))
	var plate := Rect2(_origin - Vector2(_cell * 0.5, _cell * 0.5), Vector2(_cell * 8.0, _cell * 8.0))
	draw_rect(plate, UIPalette.alpha(UIPalette.surface, 0.55))
	draw_rect(plate, UIPalette.alpha(UIPalette.line, 0.85), false, 1.0)
	# Grid.
	for i in 9:
		var x := _origin.x - _cell * 0.5 + float(i) * _cell
		draw_line(Vector2(x, plate.position.y), Vector2(x, plate.end.y), UIPalette.alpha(UIPalette.line, 0.35), 1.0)
		var y := _origin.y - _cell * 0.5 + float(i) * _cell
		draw_line(Vector2(plate.position.x, y), Vector2(plate.end.x, y), UIPalette.alpha(UIPalette.line, 0.35), 1.0)
	# Concrete pads under each module slot.
	for module_id in _layout.keys():
		var rect := _module_rect(module_id)
		draw_rect(rect.grow(-2.0), UIPalette.alpha(UIPalette.ink, 0.45))
	# Extruded blocks, back to front.
	var module_ids: Array = _layout.keys()
	module_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var pa: Vector2i = _layout[a]
		var pb: Vector2i = _layout[b]
		return pa.y < pb.y if pa.y != pb.y else pa.x < pb.x
	)
	for module_id in module_ids:
		_draw_module(module_id)
	# Selected readout.
	draw_string(
		UIFonts.mono(false),
		Vector2(_origin.x - _cell * 0.5, plate.end.y + UIPalette.SP4),
		"WAYSTATION KESTREL  //  BASE POWER %d" % ProfileState.get_base_power(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		UIPalette.muted
	)


func _draw_module(module_id: StringName) -> void:
	var module := ContentDB.get_base_module(module_id)
	if module == null:
		return
	var tier := ProfileState.get_base_tier(module_id)
	var rect := _module_rect(module_id).grow(-4.0)
	_hit_rects[module_id] = _module_rect(module_id)
	var selected := module_id == selected_module
	var hovered := module_id == _hovered
	var tint: Color = MODULE_TINTS.get(module_id, module.color)
	var accent: Color = MODULE_ACCENTS.get(module_id, module.accent)
	var color := UIPalette.mix(tint, UIPalette.surface, 0.62)

	if tier <= 0:
		# Dashed "planned" footprint.
		_draw_dashed_rect(rect, UIPalette.alpha(UIPalette.line, 0.9), 5.0, 3.0)
		var center := rect.get_center()
		var plus_size := _cell * 0.14
		draw_line(center - Vector2(plus_size, 0.0), center + Vector2(plus_size, 0.0), UIPalette.alpha(UIPalette.muted_dim, 0.8), 1.5)
		draw_line(center - Vector2(0.0, plus_size), center + Vector2(0.0, plus_size), UIPalette.alpha(UIPalette.muted_dim, 0.8), 1.5)
	else:
		var height := 5.0 + float(tier) * 5.0
		var top := Rect2(rect.position - Vector2(0.0, height), rect.size)
		# Shadow.
		draw_rect(Rect2(rect.position + Vector2(5.0, 7.0), rect.size), UIPalette.alpha(UIPalette.ink, 0.4))
		# Front face.
		draw_rect(Rect2(rect.position - Vector2(0.0, 0.0), rect.size), UIPalette.darken(color, 0.34))
		# Connector faces.
		draw_rect(Rect2(rect.position - Vector2(0.0, height), Vector2(rect.size.x, height)), UIPalette.darken(color, 0.16))
		# Top face.
		draw_rect(top, color)
		# Top trim.
		draw_rect(top.grow(-3.0), UIPalette.alpha(accent, 0.28), false, 1.0)
		# Tier pips on top face.
		for i in 3:
			var pip_center := Vector2(top.position.x + 12.0 + float(i) * 11.0, top.end.y - 9.0)
			draw_circle(pip_center, 2.6, accent if i < tier else UIPalette.alpha(UIPalette.ink, 0.55))
		# Label.
		var short_name := module.display_name.to_upper()
		draw_string(
			UIFonts.body(600),
			Vector2(top.position.x, top.position.y + 16.0),
			short_name,
			HORIZONTAL_ALIGNMENT_CENTER,
			top.size.x,
			10,
			UIPalette.ink if _is_light(color) else UIPalette.ivory
		)

	if selected or hovered:
		var outline := accent if selected else UIPalette.alpha(accent, 0.55)
		draw_rect(rect.grow(2.0), outline, false, 2.0 if selected else 1.0)


func _is_light(color: Color) -> bool:
	var luminance := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	return luminance > 0.55


func _draw_dashed_rect(rect: Rect2, color: Color, dash: float, gap: float) -> void:
	var corners := [
		[rect.position, rect.position + Vector2(rect.size.x, 0.0)],
		[rect.position + Vector2(rect.size.x, 0.0), rect.end],
		[rect.end, rect.position + Vector2(0.0, rect.size.y)],
		[rect.position + Vector2(0.0, rect.size.y), rect.position],
	]
	for edge in corners:
		var from: Vector2 = edge[0]
		var to: Vector2 = edge[1]
		var length := from.distance_to(to)
		var direction := (to - from).normalized()
		var travelled := 0.0
		while travelled < length:
			var segment := minf(dash, length - travelled)
			draw_line(from + direction * travelled, from + direction * (travelled + segment), color, 1.0)
			travelled += dash + gap


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var found := _module_at((event as InputEventMouseMotion).position)
		if found != _hovered:
			_hovered = found
			if found != &"":
				var module := ContentDB.get_base_module(found)
				tooltip_text = module.display_name if module != null else ""
			else:
				tooltip_text = "Click a module to inspect it."
			queue_redraw()
	elif event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.pressed and button_event.button_index == MOUSE_BUTTON_LEFT:
			var found := _module_at(button_event.position)
			if found != &"":
				selected_module = found
				module_selected.emit(found)
				queue_redraw()
				accept_event()


func _module_at(point: Vector2) -> StringName:
	for module_id in _hit_rects.keys():
		var rect: Rect2 = _hit_rects[module_id]
		if rect.has_point(point):
			return module_id
	return &""


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		if _hovered != &"":
			_hovered = &""
			queue_redraw()
