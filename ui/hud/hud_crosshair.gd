class_name UIHudCrosshair
extends Control
## Centre reticle, hit marker and directional damage arcs.

var _hit_time := -1.0
var _hit_killed := false
var _hit_crit := false
var _damage_arcs: Array = []
var _processing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(240, 240)
	offset_left = -120
	offset_top = -120
	offset_right = 120
	offset_bottom = 120


func _process(delta: float) -> void:
	var active := false
	if _hit_time >= 0.0:
		_hit_time += delta
		if _hit_time > 0.22:
			_hit_time = -1.0
		else:
			active = true
	var expired: Array = []
	for index in _damage_arcs.size():
		var arc: Dictionary = _damage_arcs[index]
		arc.time = float(arc.time) + delta
		if float(arc.time) > 0.9:
			expired.append(index)
		else:
			active = true
	for index in range(expired.size() - 1, -1, -1):
		_damage_arcs.remove_at(expired[index])
	_processing = active
	if active:
		queue_redraw()
	else:
		set_process(false)


func _ensure_processing() -> void:
	if not _processing:
		_processing = true
		set_process(true)


func ping(killed: bool = false, crit: bool = false) -> void:
	_hit_time = 0.0
	_hit_killed = killed
	_hit_crit = crit
	queue_redraw()
	_ensure_processing()


func add_damage_direction(angle_radians: float) -> void:
	var popped := false
	for arc in _damage_arcs:
		if absf(wrapf(float(arc.angle) - angle_radians, -PI, PI)) < 0.2:
			arc.time = 0.0
			popped = true
			break
	if not popped:
		_damage_arcs.append({"angle": angle_radians, "time": 0.0})
		if _damage_arcs.size() > 6:
			_damage_arcs.pop_front()
	queue_redraw()
	_ensure_processing()


func _draw() -> void:
	var center := size * 0.5
	var gap := 6.0
	var length := 8.0
	var color := UIPalette.ivory
	var shadow := UIPalette.alpha(UIPalette.ink, 0.55)
	# Four-tick reticle with a centre dot.
	for direction_v in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var direction: Vector2 = direction_v
		var from: Vector2 = center + direction * gap
		var to: Vector2 = center + direction * (gap + length)
		draw_line(from, to, shadow, 3.0)
		draw_line(from, to, color, 1.4)
	draw_circle(center, 4.0, shadow)
	draw_circle(center, 2.2, UIPalette.alpha(UIPalette.ivory, 0.9))

	# Hit marker.
	if _hit_time >= 0.0:
		var progress := clampf(_hit_time / 0.22, 0.0, 1.0)
		var alpha := 1.0 - progress
		var marker_color := UIPalette.ivory
		if _hit_killed:
			marker_color = UIPalette.danger
		elif _hit_crit:
			marker_color = UIPalette.amber
		marker_color = UIPalette.alpha(marker_color, alpha)
		var marker_radius := 9.0 + progress * 5.0
		for diagonal_v in [Vector2(1.0, 1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(-1.0, -1.0)]:
			var direction: Vector2 = (diagonal_v as Vector2).normalized()
			draw_line(center + direction * marker_radius, center + direction * (marker_radius + 7.0), marker_color, 2.2)
		if _hit_killed:
			draw_circle(center, 3.0 + progress * 4.0, UIPalette.alpha(UIPalette.danger, alpha * 0.8))

	# Directional damage arcs.
	for arc in _damage_arcs:
		var progress := clampf(float(arc.time) / 0.9, 0.0, 1.0)
		var alpha := (1.0 - progress) * 0.9
		var center_angle := float(arc.angle)
		var arc_angle := center_angle - PI * 0.5
		var radius := 78.0
		draw_arc(center, radius, arc_angle - 0.28, arc_angle + 0.28, 16, UIPalette.alpha(UIPalette.danger, alpha), 4.0, true)
		draw_arc(center, radius + 4.0, arc_angle - 0.18, arc_angle + 0.18, 12, UIPalette.alpha(UIPalette.amber, alpha * 0.4), 2.0, true)
