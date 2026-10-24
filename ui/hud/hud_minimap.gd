class_name UIHudMinimap
extends Control
## Live tactical minimap. One script powers both the always-on top-left map and
## the expanded full-screen map (`expanded = true`). Data comes from
## Deployment.get_tactical_data(); drawing is north-up with the player centered.

const VISIBLE_RADIUS := 220.0
const PANEL_RADIUS := 10.0

var expanded := false
var data: Dictionary = {}

var _panel_style: StyleBoxFlat
var _texture: Texture2D = null
var _last_signature := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expanded:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		custom_minimum_size = Vector2(400, 300)
	else:
		custom_minimum_size = Vector2(216, 216)
	_panel_style = UITheme._box(
		UIPalette.alpha(UIPalette.ink, 0.78),
		UIPalette.alpha(UIPalette.line, 0.95),
		PANEL_RADIUS,
		1,
		Vector4(0, 0, 0, 0)
	)


func set_data(payload: Dictionary) -> void:
	data = payload
	var signature := _signature(payload)
	if signature != _last_signature or not expanded:
		_last_signature = signature
		queue_redraw()


func _signature(payload: Dictionary) -> String:
	if payload.is_empty():
		return "empty"
	var player: Vector3 = payload.get("player_position", Vector3.ZERO)
	var hostiles: Array = payload.get("hostiles", [])
	return "%s|%d|%d|%d|%s|%s" % [
		str(Vector2(player.x, player.z)),
		int(payload.get("player_yaw", 0.0) * 100.0),
		hostiles.size(),
		int(float(payload.get("time_left", 0.0))),
		String(payload.get("map_name", "")),
		String(payload.get("mode_name", "")),
	]


func get_map_texture() -> Texture2D:
	return data.get("map_texture", null) as Texture2D


func _draw() -> void:
	if expanded:
		_draw_expanded()
	else:
		_draw_small()


# ---------------------------------------------------------------------------
# Small always-on minimap
# ---------------------------------------------------------------------------

func _draw_small() -> void:
	var map_rect := Rect2(Vector2.ZERO, size)
	if _panel_style != null:
		_panel_style.draw(get_canvas_item(), map_rect)
	var inner := map_rect.grow(-8.0)
	var center := inner.get_center()
	var half_extent := minf(inner.size.x, inner.size.y) * 0.5

	_draw_map_crop(inner)
	_draw_grid(inner, 3)
	_draw_markers(center, half_extent, false)
	_draw_player_arrow(center, inner.size.y * 0.08)
	_draw_frame_marks(inner)

	# Header strip: map identity from tactical data, with a north indicator.
	var header := String(data.get("map_name", "")).to_upper()
	if header.is_empty():
		header = "REACH MAP"
	var mode_name := String(data.get("mode_name", "")).to_upper()
	if not mode_name.is_empty():
		header += " · " + mode_name
	if header.length() > 26:
		header = header.substr(0, 25) + "…"
	draw_string(UIFonts.mono(true), Vector2(12.0, 18.0), header, HORIZONTAL_ALIGNMENT_LEFT, size.x - 40.0, 9, UIPalette.mint)
	draw_string(UIFonts.mono(false), Vector2(0.0, 18.0), "N", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 12.0, 9, UIPalette.ivory)
	# Scale bar (220 m across the visible radius).
	var bar_width := 34.0
	var bar_y := size.y - 12.0
	draw_line(Vector2(12.0, bar_y), Vector2(12.0 + bar_width, bar_y), UIPalette.alpha(UIPalette.ivory, 0.8), 1.0)
	draw_line(Vector2(12.0, bar_y - 3.0), Vector2(12.0, bar_y), UIPalette.alpha(UIPalette.ivory, 0.8), 1.0)
	draw_line(Vector2(12.0 + bar_width, bar_y - 3.0), Vector2(12.0 + bar_width, bar_y), UIPalette.alpha(UIPalette.ivory, 0.8), 1.0)
	draw_string(UIFonts.mono(false), Vector2(12.0 + bar_width + 5.0, bar_y + 1.0), "100 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIPalette.muted)
	# M hint.
	draw_string(UIFonts.mono(false), Vector2(0.0, size.y - 12.0), "M", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 12.0, 9, UIPalette.muted)
	# Extraction state.
	if String(data.get("extraction_state", "inactive")) == "holding":
		draw_string(UIFonts.mono(true), Vector2(0.0, size.y - 24.0), "EXFIL HOLD", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 12.0, 9, UIPalette.amber)


# ---------------------------------------------------------------------------
# Expanded map
# ---------------------------------------------------------------------------

func _draw_expanded() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UIPalette.ink)
	var title_y := 34.0
	var map_name := String(data.get("map_name", "")).to_upper()
	var title := "REACH TACTICAL MAP" if map_name.is_empty() else map_name
	draw_string(UIFonts.display(600), Vector2(48.0, title_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UIPalette.ivory)
	var meta: PackedStringArray = []
	var mode_name := String(data.get("mode_name", "")).to_upper()
	if not mode_name.is_empty():
		meta.append(mode_name)
	meta.append(String(data.get("difficulty_name", "Patrol")).to_upper())
	meta.append(UIPalette.format_time(float(data.get("time_left", 0.0))))
	meta.append("M TO CLOSE")
	draw_string(UIFonts.mono(false), Vector2(0.0, title_y), "  ·  ".join(meta), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 48.0, 11, UIPalette.muted)

	var map_size_px := minf(size.x * 0.64, size.y * 0.72)
	var map_origin := Vector2((size.x - map_size_px) * 0.5, (size.y - map_size_px) * 0.5 + 12.0)
	var map_rect := Rect2(map_origin, Vector2(map_size_px, map_size_px))
	draw_rect(map_rect.grow(6.0), UIPalette.alpha(UIPalette.ink, 0.7))
	draw_rect(map_rect, UIPalette.alpha(UIPalette.surface, 0.9))
	_draw_full_map(map_rect)
	_draw_grid(map_rect, 6)
	_draw_world_markers(map_rect, true)
	_draw_safe_radius(map_rect)
	_draw_player_world_arrow(map_rect)
	# Frame.
	draw_rect(map_rect, UIPalette.alpha(UIPalette.mint, 0.55), false, 1.0)
	var center_top := Vector2(map_rect.get_center().x - 4.0, map_rect.position.y - 8.0)
	draw_string(UIFonts.mono(true), center_top, "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIPalette.ivory)
	draw_string(UIFonts.mono(true), Vector2(map_rect.get_center().x - 4.0, map_rect.end.y + 16.0), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIPalette.muted)
	draw_string(UIFonts.mono(true), Vector2(map_rect.position.x - 14.0, map_rect.get_center().y + 4.0), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIPalette.muted)
	draw_string(UIFonts.mono(true), Vector2(map_rect.end.x + 6.0, map_rect.get_center().y + 4.0), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIPalette.muted)
	_draw_legend(Rect2(map_rect.end.x + 28.0, map_rect.position.y, minf(240.0, size.x - map_rect.end.x - 48.0), map_rect.size.y))


func _draw_full_map(map_rect: Rect2) -> void:
	if _texture == null:
		_texture = data.get("map_texture", null) as Texture2D
	if _texture == null:
		return
	draw_texture_rect(_texture, map_rect, false, UIPalette.alpha(Color.WHITE, 0.92))


func _draw_legend(area: Rect2) -> void:
	if area.size.x < 80.0:
		return
	var font := UIFonts.mono(false)
	var entries := [
		{"label": "OBJECTIVE", "color": UIPalette.mint, "kind": &"objective"},
		{"label": "EXFIL", "color": UIPalette.amber, "kind": &"exfil"},
		{"label": "CACHE", "color": UIPalette.violet, "kind": &"cache"},
		{"label": "BOUNTY", "color": UIPalette.danger, "kind": &"bounty"},
		{"label": "SHRINE", "color": UIPalette.violet, "kind": &"shrine"},
		{"label": "SUPPLY", "color": UIPalette.amber, "kind": &"supply"},
		{"label": "BUILDING", "color": UIPalette.muted, "kind": &"building"},
		{"label": "HOSTILE", "color": UIPalette.danger, "kind": &""},
		{"label": "ALLY", "color": UIPalette.blue, "kind": &""},
	]
	var y := area.position.y + 16.0
	draw_string(UIFonts.body(600), Vector2(area.position.x, y), "LEGEND", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIPalette.ivory)
	y += 22.0
	for entry in entries:
		var color: Color = entry.color
		var legend_pos := Vector2(area.position.x + 5.0, y - 3.0)
		var kind := StringName(entry.get("kind", &""))
		if kind.is_empty():
			draw_circle(legend_pos, 3.5, color)
		else:
			_draw_marker_shape(legend_pos, kind, color, false)
		draw_string(font, Vector2(area.position.x + 18.0, y), String(entry.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIPalette.muted)
		y += 18.0
	y += 8.0
	draw_string(UIFonts.mono(true), Vector2(area.position.x, y), "SAFE RADIUS  %d m" % int(data.get("safe_radius", 2000.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIPalette.amber)
	y += 18.0
	draw_string(font, Vector2(area.position.x, y), "LIVE HOSTILES  %d" % (data.get("hostiles", []) as Array).size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIPalette.danger)


# ---------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------

func _draw_map_crop(inner: Rect2) -> void:
	var texture := data.get("map_texture", null) as Texture2D
	if texture == null:
		draw_rect(inner, UIPalette.alpha(UIPalette.surface, 0.88))
		return
	_texture = texture
	var tex_size := float(texture.get_width())
	var map_size := maxf(200.0, float(data.get("map_size", 1800.0)))
	var player: Vector3 = data.get("player_position", Vector3.ZERO)
	var half := map_size * 0.5
	var ppm := tex_size / map_size
	var center_px := Vector2((player.x + half) * ppm, (player.z + half) * ppm)
	var src_half := VISIBLE_RADIUS * ppm
	var src_rect := Rect2(center_px - Vector2(src_half, src_half), Vector2(src_half, src_half) * 2.0)
	var clipped := src_rect.intersection(Rect2(Vector2.ZERO, Vector2(tex_size, tex_size)))
	draw_rect(inner, UIPalette.alpha(UIPalette.ink, 0.65))
	if clipped.size.x <= 1.0 or clipped.size.y <= 1.0:
		return
	var unit := inner.size / src_rect.size
	var dest := Rect2(
		inner.position + (clipped.position - src_rect.position) * unit.x,
		clipped.size * unit
	)
	draw_texture_rect_region(texture, dest, clipped, Color.WHITE)


func _draw_grid(area: Rect2, divisions: int) -> void:
	for i in range(1, divisions):
		var t := float(i) / float(divisions)
		var x := lerpf(area.position.x, area.end.x, t)
		var y := lerpf(area.position.y, area.end.y, t)
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), UIPalette.alpha(UIPalette.line, 0.18), 1.0)
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), UIPalette.alpha(UIPalette.line, 0.18), 1.0)


func _draw_frame_marks(area: Rect2) -> void:
	var color := UIPalette.alpha(UIPalette.mint, 0.55)
	var length := 10.0
	draw_line(area.position, area.position + Vector2(length, 0.0), color, 1.0)
	draw_line(area.position, area.position + Vector2(0.0, length), color, 1.0)
	draw_line(Vector2(area.end.x, area.position.y), Vector2(area.end.x - length, area.position.y), color, 1.0)
	draw_line(Vector2(area.end.x, area.position.y), Vector2(area.end.x, area.position.y + length), color, 1.0)
	draw_line(area.end, area.end - Vector2(length, 0.0), color, 1.0)
	draw_line(area.end, area.end - Vector2(0.0, length), color, 1.0)
	draw_line(Vector2(area.position.x, area.end.y), Vector2(area.position.x + length, area.end.y), color, 1.0)
	draw_line(Vector2(area.position.x, area.end.y), Vector2(area.position.x, area.end.y - length), color, 1.0)


func _draw_markers(center: Vector2, half_extent: float, clamp_edges: bool) -> void:
	var player: Vector3 = data.get("player_position", Vector3.ZERO)
	var scale := half_extent / VISIBLE_RADIUS
	for marker in data.get("markers", []):
		if not (marker is Dictionary):
			continue
		var world: Vector3 = marker.get("position", Vector3.ZERO)
		var offset := Vector2(world.x - player.x, world.z - player.z) * scale
		var kind := StringName(marker.get("kind", &"poi"))
		var color: Color = marker.get("color", UIPalette.mint)
		var clamped := false
		if offset.length() > half_extent * 0.94:
			if clamp_edges and (kind == &"objective" or kind == &"exfil" or kind == &"shrine" or kind == &"cache" or kind == &"bounty" or kind == &"supply"):
				offset = offset.normalized() * half_extent * 0.94
				clamped = true
			else:
				continue
		var pos := center + offset
		_draw_marker_shape(pos, kind, color, clamped)
	for hostile in data.get("hostiles", []):
		if not (hostile is Vector3):
			continue
		var offset := Vector2(hostile.x - player.x, hostile.z - player.z) * scale
		if offset.length() > half_extent * 0.96:
			continue
		draw_circle(center + offset, 2.0, UIPalette.danger)
	for ally in data.get("allies", []):
		if not (ally is Vector3):
			continue
		var offset := Vector2(ally.x - player.x, ally.z - player.z) * scale
		if offset.length() > half_extent * 0.96:
			continue
		draw_circle(center + offset, 2.4, UIPalette.blue)
	var boss = data.get("boss_position", null)
	if boss is Vector3:
		var offset := Vector2(boss.x - player.x, boss.z - player.z) * scale
		if offset.length() <= half_extent * 0.98:
			draw_colored_polygon(PackedVector2Array([
				center + offset + Vector2(0.0, -6.0),
				center + offset + Vector2(5.0, 4.0),
				center + offset + Vector2(-5.0, 4.0),
			]), UIPalette.danger)


func _draw_marker_shape(pos: Vector2, kind: StringName, color: Color, clamped: bool) -> void:
	match kind:
		&"objective", &"supply":
			draw_circle(pos, 3.2, color)
			draw_circle(pos, 1.3, UIPalette.ink)
		&"exfil":
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(0.0, -4.0), pos + Vector2(4.0, 2.6), pos + Vector2(-4.0, 2.6),
			]), color)
		&"shrine":
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(0.0, -4.5), pos + Vector2(3.5, 0.0), pos + Vector2(0.0, 4.5), pos + Vector2(-3.5, 0.0),
			]), color)
		&"cache":
			draw_rect(Rect2(pos - Vector2(2.8, 2.8), Vector2(5.6, 5.6)), color, true)
			draw_rect(Rect2(pos - Vector2(1.1, 1.1), Vector2(2.2, 2.2)), UIPalette.ink, true)
		&"bounty":
			draw_line(pos + Vector2(-3.2, -3.2), pos + Vector2(3.2, 3.2), color, 1.6)
			draw_line(pos + Vector2(-3.2, 3.2), pos + Vector2(3.2, -3.2), color, 1.6)
		&"building":
			draw_rect(Rect2(pos - Vector2(2.6, 2.6), Vector2(5.2, 5.2)), UIPalette.alpha(color, 0.85), false, 1.2)
		_:
			draw_rect(Rect2(pos - Vector2(2.2, 2.2), Vector2(4.4, 4.4)), color, true)
	if clamped:
		draw_circle(pos, 5.5, UIPalette.alpha(color, 0.25))


func _draw_player_arrow(center: Vector2, length: float) -> void:
	var yaw := float(data.get("player_yaw", 0.0))
	var dir := Vector2(-sin(yaw), -cos(yaw)).normalized()
	var right := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([
		center + dir * length,
		center - dir * (length * 0.45) + right * (length * 0.55),
		center - dir * (length * 0.2),
		center - dir * (length * 0.45) - right * (length * 0.55),
	]), UIPalette.ivory)
	var cone := PackedVector2Array([
		center,
		center + dir.rotated(0.36) * (length * 1.35),
		center + dir.rotated(-0.36) * (length * 1.35),
	])
	draw_colored_polygon(cone, UIPalette.alpha(UIPalette.mint, 0.10))


func _draw_world_markers(map_rect: Rect2, clamp_edges: bool) -> void:
	var map_size := maxf(200.0, float(data.get("map_size", 1800.0)))
	var half := map_size * 0.5
	for marker in data.get("markers", []):
		if not (marker is Dictionary):
			continue
		var world: Vector3 = marker.get("position", Vector3.ZERO)
		var unit := Vector2((world.x + half) / map_size, (world.z + half) / map_size)
		if unit.x < 0.0 or unit.x > 1.0 or unit.y < 0.0 or unit.y > 1.0:
			if not clamp_edges:
				continue
			unit = Vector2(clampf(unit.x, 0.02, 0.98), clampf(unit.y, 0.02, 0.98))
		_draw_marker_shape(map_rect.position + unit * map_rect.size, StringName(marker.get("kind", &"poi")), marker.get("color", UIPalette.mint), false)
	var player: Vector3 = data.get("player_position", Vector3.ZERO)
	for hostile in data.get("hostiles", []):
		if not (hostile is Vector3):
			continue
		var unit := Vector2((hostile.x + half) / map_size, (hostile.z + half) / map_size)
		if unit.x < 0.0 or unit.x > 1.0 or unit.y < 0.0 or unit.y > 1.0:
			continue
		draw_circle(map_rect.position + unit * map_rect.size, 2.2, UIPalette.danger)
	for ally in data.get("allies", []):
		if not (ally is Vector3):
			continue
		var unit := Vector2((ally.x + half) / map_size, (ally.z + half) / map_size)
		if unit.x < 0.0 or unit.x > 1.0 or unit.y < 0.0 or unit.y > 1.0:
			continue
		draw_circle(map_rect.position + unit * map_rect.size, 2.6, UIPalette.blue)
	var boss = data.get("boss_position", null)
	if boss is Vector3:
		var unit := Vector2((boss.x + half) / map_size, (boss.z + half) / map_size)
		if unit.x >= 0.0 and unit.x <= 1.0 and unit.y >= 0.0 and unit.y <= 1.0:
			var pos := map_rect.position + unit * map_rect.size
			draw_colored_polygon(PackedVector2Array([pos + Vector2(0.0, -7.0), pos + Vector2(6.0, 5.0), pos + Vector2(-6.0, 5.0)]), UIPalette.danger)
	if player == Vector3.ZERO and not data.has("player_position"):
		return


func _draw_player_world_arrow(map_rect: Rect2) -> void:
	var map_size := maxf(200.0, float(data.get("map_size", 1800.0)))
	var half := map_size * 0.5
	var player: Vector3 = data.get("player_position", Vector3.ZERO)
	var unit := Vector2((player.x + half) / map_size, (player.z + half) / map_size)
	var pos := map_rect.position + Vector2(clampf(unit.x, 0.0, 1.0), clampf(unit.y, 0.0, 1.0)) * map_rect.size
	var yaw := float(data.get("player_yaw", 0.0))
	var dir := Vector2(-sin(yaw), -cos(yaw)).normalized()
	var right := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([
		pos + dir * 9.0,
		pos - dir * 4.0 + right * 5.0,
		pos - dir * 4.0 - right * 5.0,
	]), UIPalette.ivory)


func _draw_safe_radius(map_rect: Rect2) -> void:
	if not bool(data.get("storm_active", false)):
		return
	var map_size := maxf(200.0, float(data.get("map_size", 1800.0)))
	var half := map_size * 0.5
	var radius := float(data.get("safe_radius", 2000.0))
	if radius >= half:
		return
	var center := map_rect.get_center()
	var radius_px := radius / map_size * map_rect.size.x
	draw_arc(center, radius_px, 0.0, TAU, 64, UIPalette.alpha(UIPalette.danger, 0.55), 1.5)
