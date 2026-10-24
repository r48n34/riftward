class_name UIHudCompass
extends Control
## Slim top-centre compass strip. Reads the player heading; gameplay pushes
## objective/POI markers through set_markers(). Entries may carry a "kind" that
## selects a distinct glyph; legacy entries with only degrees/color still work.

const MAX_MARKERS := 24
const MARKER_SPAN := 90.0

var heading_degrees := 0.0
var markers: Array = []
var _panel_style: StyleBoxFlat = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(480, 30)
	_panel_style = UITheme._box(UIPalette.alpha(UIPalette.ink, 0.55), UIPalette.alpha(UIPalette.line, 0.7), UIPalette.R_CHIP, 1, Vector4(0, 0, 0, 0))


func set_heading(degrees: float) -> void:
	heading_degrees = fposmod(degrees, 360.0)
	queue_redraw()


func add_marker(degrees: float, color: Color) -> int:
	markers.append({"angle": fposmod(degrees, 360.0), "color": color, "kind": &""})
	queue_redraw()
	return markers.size() - 1


func set_markers(entries: Array) -> void:
	markers.clear()
	for entry in entries:
		if not (entry is Dictionary):
			continue
		if markers.size() >= MAX_MARKERS:
			break
		var data: Dictionary = entry
		markers.append({
			"angle": fposmod(float(data.get("degrees", data.get("angle", 0.0))), 360.0),
			"color": data.get("color", UIPalette.mint),
			"kind": StringName(data.get("kind", &"")),
		})
	queue_redraw()


func clear_markers() -> void:
	markers.clear()
	queue_redraw()


func _draw() -> void:
	var width := size.x
	var height := size.y
	if width < 40.0:
		return
	if _panel_style != null:
		_panel_style.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))

	var center := width * 0.5
	var span := MARKER_SPAN
	var pixels_per_degree := (width * 0.5) / span
	var baseline := height * 0.62

	# Tick marks every 5 degrees, labels every 45.
	for marker_index in range(-18, 19):
		var degrees := float(marker_index) * 5.0
		var delta := wrapf(degrees - heading_degrees, -180.0, 180.0)
		if absf(delta) > span:
			continue
		var x := center + delta * pixels_per_degree
		var is_major := int(fposmod(degrees, 45.0)) == 0
		var tick_height := 9.0 if is_major else 4.0
		var tick_color := UIPalette.ivory if is_major else UIPalette.muted_dim
		draw_line(Vector2(x, baseline - tick_height), Vector2(x, baseline), UIPalette.alpha(tick_color, 0.85 if is_major else 0.5), 1.0)
		if is_major:
			draw_string(
				UIFonts.body(600),
				Vector2(x - 18.0, baseline - 13.0),
				_cardinal_label(fposmod(degrees, 360.0)),
				HORIZONTAL_ALIGNMENT_CENTER,
				36.0,
				10,
				UIPalette.ivory if _cardinal_label(fposmod(degrees, 360.0)).length() <= 2 else UIPalette.muted
			)

	# Objective markers, capped defensively.
	var marker_count := mini(markers.size(), MAX_MARKERS)
	for marker_index in marker_count:
		var marker = markers[marker_index]
		if not (marker is Dictionary):
			continue
		var delta := wrapf(float(marker.angle) - heading_degrees, -180.0, 180.0)
		if absf(delta) > span:
			continue
		var x := center + delta * pixels_per_degree
		_draw_marker_shape(Vector2(x, baseline + 4.0), StringName(marker.get("kind", &"")), marker.get("color", UIPalette.mint))

	# Centre notch + heading readout.
	draw_colored_polygon(
		PackedVector2Array([Vector2(center - 5.0, 2.0), Vector2(center + 5.0, 2.0), Vector2(center, 9.0)]),
		UIPalette.mint
	)
	draw_string(UIFonts.mono(true), Vector2(0.0, height - 3.0), "%03d°" % int(round(heading_degrees)), HORIZONTAL_ALIGNMENT_CENTER, width, 10, UIPalette.ivory)


func _draw_marker_shape(pos: Vector2, kind: StringName, color: Color) -> void:
	match kind:
		&"objective":
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(0.0, -4.5), pos + Vector2(4.5, 0.0),
				pos + Vector2(0.0, 4.5), pos + Vector2(-4.5, 0.0),
			]), color)
		&"exfil":
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(0.0, -5.0), pos + Vector2(4.5, 3.0), pos + Vector2(-4.5, 3.0),
			]), color)
		&"cache":
			draw_rect(Rect2(pos - Vector2(3.4, 3.4), Vector2(6.8, 6.8)), color, false, 1.2)
			draw_rect(Rect2(pos - Vector2(1.2, 1.2), Vector2(2.4, 2.4)), color, true)
		&"bounty":
			draw_line(pos + Vector2(-3.4, -3.4), pos + Vector2(3.4, 3.4), color, 1.6)
			draw_line(pos + Vector2(-3.4, 3.4), pos + Vector2(3.4, -3.4), color, 1.6)
		&"building":
			draw_rect(Rect2(pos - Vector2(3.2, 3.2), Vector2(6.4, 6.4)), color, false, 1.2)
		&"poi":
			draw_circle(pos, 3.0, color)
			draw_circle(pos, 1.2, UIPalette.ink)
		&"supply":
			draw_circle(pos, 4.2, color)
			draw_circle(pos, 2.1, UIPalette.ink)
		&"shrine":
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(0.0, -4.5), pos + Vector2(3.5, 0.0),
				pos + Vector2(0.0, 4.5), pos + Vector2(-3.5, 0.0),
			]), color)
			draw_circle(pos, 1.3, UIPalette.ink)
		_:
			# Legacy glyph for entries that never declared a kind.
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(-5.0, -2.5), pos + Vector2(5.0, -2.5), pos + Vector2(0.0, 4.5),
			]), color)


func _cardinal_label(degrees: float) -> String:
	var labels := {0.0: "N", 45.0: "NE", 90.0: "E", 135.0: "SE", 180.0: "S", 225.0: "SW", 270.0: "W", 315.0: "NW", 360.0: "N"}
	for key in labels.keys():
		if absf(wrapf(degrees - float(key), -180.0, 180.0)) < 1.0:
			return labels[key]
	return ""
