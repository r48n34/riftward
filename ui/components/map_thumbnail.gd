class_name UIMapThumbnail
extends Control
## Cheap top-down tactical-map thumbnail for map/difficulty cards. Reads the
## ContentDB map preset (planet/fluid/environment) and precomputes seeded contour
## polygons, fluid shapes, roads and POI/exfil markers on configure/resize only.
## It never touches WorldBuilder or generates a world.

var map_id: StringName = &""
var show_markers := true

var _preset: Dictionary = {}
var _seed := 0
var _terrain := Color("2b4446")
var _terrain_dark := Color("17282b")
var _terrain_line := Color(0.6, 0.8, 0.75, 0.4)
var _water := Color("2c6d84")
var _lava := Color("b34a28")
var _accent := UIPalette.mint
var _danger := UIPalette.danger
var _contours: Array[PackedVector2Array] = []
var _ridges: Array[PackedVector2Array] = []
var _roads: Array[PackedVector2Array] = []
var _fluids: Array[Dictionary] = []
var _markers: Array[Dictionary] = []
var _bg_style: StyleBoxFlat
var _terrain_style: StyleBoxFlat
var _build_size := Vector2(-1, -1)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(160, 90)
	_bg_style = UITheme._box(
		UIPalette.alpha(UIPalette.ink, 0.82),
		UIPalette.alpha(UIPalette.line, 0.75),
		6,
		1,
		Vector4.ZERO
	)
	_terrain_style = UITheme._box(UIPalette.surface, Color.TRANSPARENT, 4, 0, Vector4.ZERO)
	resized.connect(_on_resized)


func configure(map_id: StringName, size: Vector2 = Vector2(160, 90), show_markers: bool = true) -> void:
	self.map_id = map_id
	self.show_markers = show_markers
	var target := Vector2(maxf(24.0, size.x), maxf(14.0, size.y))
	custom_minimum_size = target
	if not is_inside_tree():
		self.size = target
	_preset = {}
	if ContentDB != null:
		_preset = ContentDB.get_map_preset(map_id)
	_build_geometry()
	queue_redraw()


func get_map_id() -> StringName:
	return map_id


func _on_resized() -> void:
	if size == _build_size:
		return
	_build_geometry()
	queue_redraw()


# ---------------------------------------------------------------------------
# Deterministic geometry (configure/resize only)
# ---------------------------------------------------------------------------

func _build_geometry() -> void:
	_build_size = size
	_contours.clear()
	_ridges.clear()
	_roads.clear()
	_fluids.clear()
	_markers.clear()
	var map_color: Color = UIPalette.muted
	if _preset.has("color"):
		map_color = _preset["color"]
	var planet: Dictionary = {}
	if _preset.get("planet", {}) is Dictionary:
		planet = _preset["planet"]
	var planet_color: Color = planet.get("color", map_color)
	var biome := int(_preset.get("biome_index", 0))
	var biome_color := planet_color
	var terrain_tints: Array = planet.get("terrain_tint", []) if planet.get("terrain_tint", []) is Array else []
	if biome >= 0 and biome < terrain_tints.size():
		var tint: Color = terrain_tints[biome]
		biome_color = UIPalette.mix(planet_color, tint, 0.4)
	var environment: Dictionary = {}
	if _preset.get("environment", {}) is Dictionary:
		environment = _preset["environment"]
	var fog_color: Color = environment.get("fog_color", Color.TRANSPARENT)
	_terrain = UIPalette.mix(UIPalette.surface, biome_color, 0.3)
	if _preset.is_empty():
		_terrain = UIPalette.mix(UIPalette.surface, UIPalette.muted, 0.2)
	_terrain_dark = UIPalette.darken(_terrain, 0.28)
	_terrain_line = UIPalette.alpha(UIPalette.mix(UIPalette.line, biome_color, 0.4), 0.55)
	if fog_color.a > 0.001:
		_terrain = UIPalette.mix(_terrain, fog_color, 0.1)
	_water = UIPalette.mix(UIPalette.blue, planet_color, 0.3)
	if StringName(planet.get("hazard", &"none")) == &"deep_water":
		_water = UIPalette.mix(_water, Color("63d6e6"), 0.45)
	_lava = UIPalette.mix(UIPalette.amber, UIPalette.danger, 0.45)
	_accent = map_color
	if _accent.a <= 0.001:
		_accent = UIPalette.mint
	_seed = int(_preset.get("world_seed_salt", 0))
	if _seed == 0:
		_seed = absi(String(map_id).hash())
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	_build_contours(rng, biome)
	_build_ridges(rng)
	_build_roads(rng)
	_build_fluid(rng)
	if show_markers:
		_build_markers(rng)


func _build_contours(rng: RandomNumberGenerator, biome: int) -> void:
	var center := Vector2(rng.randf_range(0.34, 0.66), rng.randf_range(0.36, 0.64))
	var base := rng.randf_range(0.11, 0.18)
	var count := 3 + (biome % 2)
	var phase_a := rng.randf_range(0.0, TAU)
	var phase_b := rng.randf_range(0.0, TAU)
	for ring in count:
		var radius := base + float(ring) * rng.randf_range(0.07, 0.1)
		var points := PackedVector2Array()
		for index in 18:
			var angle := TAU * float(index) / 18.0
			var wobble := 1.0 + sin(angle * 3.0 + phase_a) * 0.08 + sin(angle * 5.0 + phase_b) * 0.045
			var point := center + Vector2(cos(angle), sin(angle)) * radius * wobble
			points.append(Vector2(clampf(point.x, 0.03, 0.97), clampf(point.y, 0.05, 0.95)))
		_contours.append(points)


func _build_ridges(rng: RandomNumberGenerator) -> void:
	for ridge in 2:
		var points := PackedVector2Array()
		var phase := rng.randf_range(0.0, TAU)
		var amplitude := rng.randf_range(0.025, 0.06)
		var vertical := ridge == 1
		for index in 8:
			var t := float(index) / 7.0
			if vertical:
				var x := clampf(0.2 + rng.randf_range(0.0, 0.6) + sin(t * 4.0 + phase) * amplitude, 0.06, 0.94)
				points.append(Vector2(x, 0.04 + t * 0.92))
			else:
				var y := clampf(0.2 + rng.randf_range(0.0, 0.6) + sin(t * 4.0 + phase) * amplitude, 0.06, 0.94)
				points.append(Vector2(0.04 + t * 0.92, y))
		_ridges.append(points)


func _build_roads(rng: RandomNumberGenerator) -> void:
	for road_index in 2:
		var points := PackedVector2Array()
		var phase := rng.randf_range(0.0, TAU)
		var amplitude := rng.randf_range(0.03, 0.08)
		var vertical := road_index == 1
		var baseline := rng.randf_range(0.24, 0.76)
		for index in 8:
			var t := float(index) / 7.0
			var wobble := sin(t * 5.0 + phase) * amplitude + rng.randf_range(-0.018, 0.018)
			if vertical:
				points.append(Vector2(clampf(baseline + wobble, 0.08, 0.92), 0.02 + t * 0.96))
			else:
				points.append(Vector2(0.02 + t * 0.96, clampf(baseline + wobble, 0.08, 0.92)))
		_roads.append(points)


func _build_fluid(rng: RandomNumberGenerator) -> void:
	var fluid: Dictionary = {}
	if _preset.get("fluid", {}) is Dictionary:
		fluid = _preset["fluid"]
	var has_water := bool(fluid.get("water", false))
	var has_lava := bool(fluid.get("lava", false))
	if not has_water and not has_lava:
		return
	var puddles := 1
	if rng.randf() > 0.5:
		puddles = 2
	for index in puddles:
		var kind := "water"
		if has_water and has_lava:
			kind = "water" if index % 2 == 0 else "lava"
		elif has_lava:
			kind = "lava"
		var center := Vector2(rng.randf_range(0.18, 0.82), rng.randf_range(0.2, 0.8))
		var rx := rng.randf_range(0.1, 0.22)
		var ry := rng.randf_range(0.08, 0.16)
		_fluids.append({"points": _blob(center, rx, ry, rng), "kind": kind})


func _build_markers(rng: RandomNumberGenerator) -> void:
	var poi_count := clampi(int(_preset.get("extra_pois", 2)) + 2, 3, 6)
	for index in poi_count:
		var marker_type := "poi" if index % 3 != 1 else "cache"
		_markers.append({
			"pos": Vector2(rng.randf_range(0.12, 0.88), rng.randf_range(0.14, 0.86)),
			"type": marker_type,
		})
	_markers.append({
		"pos": Vector2(rng.randf_range(0.18, 0.82), rng.randf_range(0.16, 0.42)),
		"type": "elite",
	})
	var exfil_left := rng.randf() > 0.5
	_markers.append({
		"pos": Vector2(0.16 if exfil_left else 0.84, rng.randf_range(0.78, 0.9)),
		"type": "exfil",
	})


func _blob(center: Vector2, rx: float, ry: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var phase_a := rng.randf_range(0.0, TAU)
	var phase_b := rng.randf_range(0.0, TAU)
	var points := PackedVector2Array()
	for index in 16:
		var angle := TAU * float(index) / 16.0
		var wobble := 1.0 + sin(angle * 3.0 + phase_a) * 0.14 + sin(angle * 5.0 + phase_b) * 0.07
		var point := center + Vector2(cos(angle) * rx, sin(angle) * ry) * wobble
		points.append(Vector2(clampf(point.x, 0.04, 0.96), clampf(point.y, 0.05, 0.95)))
	return points


# ---------------------------------------------------------------------------
# Draw
# ---------------------------------------------------------------------------

func _draw() -> void:
	if size.x < 8.0 or size.y < 6.0:
		return
	draw_style_box(_bg_style, Rect2(Vector2.ZERO, size))
	var map_rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	if map_rect.size.x < 4.0 or map_rect.size.y < 4.0:
		return
	_terrain_style.bg_color = _terrain
	draw_style_box(_terrain_style, map_rect)
	# Faint tactical grid.
	var grid_color := UIPalette.alpha(_terrain_line, 0.35)
	for index in 4:
		var x := map_rect.position.x + map_rect.size.x * float(index + 1) / 5.0
		draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), grid_color, 1.0)
	for index in 3:
		var y := map_rect.position.y + map_rect.size.y * float(index + 1) / 4.0
		draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), grid_color, 1.0)
	# Fluid bodies sit under the contour/road network.
	for body in _fluids:
		var points := _map_points(body["points"], map_rect)
		var kind := String(body["kind"])
		var fill := _water if kind == "water" else _lava
		draw_colored_polygon(points, UIPalette.alpha(fill, 0.82))
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, UIPalette.alpha(UIPalette.brighten(fill, 0.25), 0.7), 1.0, true)
		var center := _polygon_center(points)
		if kind == "water":
			draw_line(center + Vector2(-4, 0), center + Vector2(4, 0), UIPalette.alpha(UIPalette.ivory, 0.35), 1.0)
			draw_line(center + Vector2(-2, 2.2), center + Vector2(2, 2.2), UIPalette.alpha(UIPalette.ivory, 0.25), 1.0)
		else:
			draw_arc(center, 3.0, 0.0, TAU, 12, UIPalette.alpha(UIPalette.amber, 0.6), 1.0, true)
	# Elevation contours.
	for contour in _contours:
		draw_polyline(_map_points(contour, map_rect), _terrain_line, 1.0, true)
	for ridge in _ridges:
		draw_polyline(_map_points(ridge, map_rect), UIPalette.alpha(_terrain_line, 0.7), 1.0, true)
	# Road network: dark bed, light running surface, dashed centre when roomy.
	var road_bed := maxf(1.6, minf(size.x, size.y) * 0.025)
	for road in _roads:
		var points := _map_points(road, map_rect)
		draw_polyline(points, UIPalette.alpha(UIPalette.ink, 0.7), road_bed, true)
		draw_polyline(points, UIPalette.alpha(UIPalette.ivory, 0.3), maxf(1.0, road_bed * 0.42), true)
		if map_rect.size.x > 72.0:
			for index in points.size() - 1:
				draw_dashed_line(points[index], points[index + 1], UIPalette.alpha(_accent, 0.45), 1.0, 3.0)
	if show_markers:
		_draw_markers(map_rect)
	# Edge frame + compass tick.
	draw_rect(map_rect, UIPalette.alpha(_accent, 0.4), false, 1.0)
	_draw_compass(map_rect)
	# Subtle scanlines keep the tactical-terminal feel at card sizes.
	if size.y > 42.0:
		for index in 4:
			var y := map_rect.position.y + map_rect.size.y * (0.2 + float(index) * 0.2)
			draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), UIPalette.alpha(UIPalette.ivory, 0.02), 1.0)


func _draw_markers(map_rect: Rect2) -> void:
	var unit := clampf(minf(map_rect.size.x, map_rect.size.y) * 0.075, 1.4, 4.5)
	for marker in _markers:
		var normalized: Vector2 = marker["pos"]
		var position := map_rect.position + normalized * map_rect.size
		var marker_type := String(marker["type"])
		var shadow := UIPalette.alpha(UIPalette.ink, 0.8)
		match marker_type:
			"poi", "cache":
				var tint := _accent if marker_type == "poi" else UIPalette.amber
				var diamond := PackedVector2Array([
					position + Vector2(0, -unit),
					position + Vector2(unit, 0),
					position + Vector2(0, unit),
					position + Vector2(-unit, 0),
				])
				draw_colored_polygon(diamond, tint)
				var outline := diamond.duplicate()
				outline.append(diamond[0])
				draw_polyline(outline, shadow, 1.0, true)
				draw_circle(position, maxf(0.6, unit * 0.28), UIPalette.alpha(UIPalette.ink, 0.8))
			"elite":
				var triangle := PackedVector2Array([
					position + Vector2(0, -unit * 1.15),
					position + Vector2(unit, unit * 0.85),
					position + Vector2(-unit, unit * 0.85),
				])
				draw_colored_polygon(triangle, _danger)
				var outline := triangle.duplicate()
				outline.append(triangle[0])
				draw_polyline(outline, shadow, 1.0, true)
				draw_circle(position + Vector2(0, unit * 0.15), maxf(0.5, unit * 0.24), UIPalette.ivory)
			"exfil":
				draw_circle(position, unit * 1.05, UIPalette.alpha(UIPalette.ink, 0.7))
				draw_arc(position, unit * 1.05, 0.0, TAU, 16, _accent, 1.2, true)
				draw_circle(position, maxf(0.7, unit * 0.34), _accent)
				draw_line(
					position + Vector2(-unit * 0.6, unit * 1.7),
					position + Vector2(0, unit * 1.1),
					UIPalette.alpha(_accent, 0.85),
					1.2,
					true
				)
				draw_line(
					position + Vector2(0, unit * 1.1),
					position + Vector2(unit * 0.6, unit * 1.7),
					UIPalette.alpha(_accent, 0.85),
					1.2,
					true
				)


func _draw_compass(map_rect: Rect2) -> void:
	var unit := clampf(minf(map_rect.size.x, map_rect.size.y) * 0.07, 1.4, 4.0)
	var origin := map_rect.position + Vector2(unit * 2.0, unit * 2.0)
	var tint := UIPalette.alpha(_accent, 0.55)
	draw_line(origin + Vector2(0, unit), origin + Vector2(0, -unit), tint, 1.0, true)
	draw_line(origin + Vector2(0, -unit), origin + Vector2(-unit * 0.45, 0), tint, 1.0, true)
	draw_line(origin + Vector2(0, -unit), origin + Vector2(unit * 0.45, 0), tint, 1.0, true)
	draw_circle(origin + Vector2(0, unit * 1.5), 0.8, tint)


func _map_points(points: PackedVector2Array, rect: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		out.append(rect.position + point * rect.size)
	return out


static func _polygon_center(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var center := Vector2.ZERO
	for point in points:
		center += point
	return center / float(points.size())
