class_name CinemaRiftShot
extends UICinemaShot
## Act 02 — RIFT BREACH.
##
## The Reach tears open over the drop zone. Layered parallax ridges, a burning
## rift seam, arc discharge and drifting ash establish the world before the pod
## commits. Sky and sun colours come from the deployment brief (planet + map
## environment), so Cinder-4 and Frost-9 openings read differently.

var brief: Dictionary = {}

var _stars: Array = []
var _motes: Array = []
var _spires: Array = []
var _ridges: Array = []
var _rift_points: Array = []
var _branch_cracks: Array = []
var _debris: Array = []
var _rift_color := Color("c79cff")
var _sky_top := Color("101d21")
var _sky_mid := Color("24383a")
var _sky_horizon := Color("d9a173")
var _ground := Color("0b1114")
var _sun_color := Color("ffd9a0")
var _sky_texture: GradientTexture2D = null
var _seeded := false


func _on_shot_ready() -> void:
	shot_id = &"rift"
	static_pose_time = 1.35
	set_static_frame(UIPalette.reduce_motion)


func set_brief(value: Dictionary) -> void:
	brief = value if value != null else {}
	_rift_color = UIPalette.mix(UIPalette.violet, brief.get("planet_color", UIPalette.mint), 0.35)
	_sky_top = brief.get("sky_top", Color("101d21"))
	_sky_horizon = brief.get("sky_horizon", Color("d9a173"))
	_ground = brief.get("sky_ground", Color("0d1517"))
	_sun_color = brief.get("sun_color", Color("ffd9a0"))
	_sky_mid = UIPalette.mix(_sky_top, _sky_horizon, 0.42)
	_seed_scene()
	queue_redraw()


func _seed_scene() -> void:
	var rng := _seed_rng(brief.get("seed", 0))
	_stars.clear()
	for i in 90:
		_stars.append({
			"pos": Vector2(rng.randf(), rng.randf_range(0.02, 0.46)),
			"size": rng.randf_range(0.5, 1.6),
			"alpha": rng.randf_range(0.08, 0.5),
			"phase": rng.randf_range(0.0, TAU),
		})
	_motes.clear()
	for i in 46:
		_motes.append({
			"pos": Vector2(rng.randf(), rng.randf_range(0.35, 0.95)),
			"speed": rng.randf_range(0.006, 0.024),
			"size": rng.randf_range(0.6, 2.0),
			"alpha": rng.randf_range(0.05, 0.22),
			"phase": rng.randf_range(0.0, TAU),
		})
	_spires.clear()
	for i in 4:
		_spires.append({
			"x": rng.randf_range(0.64, 0.97),
			"height": rng.randf_range(0.08, 0.22),
			"width": rng.randf_range(0.0014, 0.0032),
			"phase": rng.randf_range(0.0, TAU),
		})
	_ridges.clear()
	for layer in 3:
		var points := PackedVector2Array()
		var steps := 40
		var base := 0.70 + float(layer) * 0.085
		var amplitude := 0.07 + float(layer) * 0.035
		var rng_layer := RandomNumberGenerator.new()
		rng_layer.seed = 917 + layer * 137 + int(StringName(brief.get("map_id", &"")).hash()) % 997
		var phase_a := rng_layer.randf_range(0.0, TAU)
		var phase_b := rng_layer.randf_range(0.0, TAU)
		for i in steps + 1:
			var t := float(i) / float(steps)
			var y := base
			y -= amplitude * (0.55 * sin(t * TAU * 1.2 + phase_a)
				+ 0.28 * sin(t * TAU * 2.9 + phase_b)
				+ 0.12 * sin(t * TAU * 6.4 + phase_a * 1.7))
			# Keep the left third calmer so the operation caption always reads.
			if t < 0.40:
				y = lerpf(base - amplitude * 0.25, y, 0.5 + t)
			points.append(Vector2(t, y))
		_ridges.append(points)
	_rift_points.clear()
	var rng_rift := RandomNumberGenerator.new()
	rng_rift.seed = 4242 + int(StringName(brief.get("map_id", &"")).hash()) % 7331
	var previous := 0.58
	for i in 19:
		var t := float(i) / 18.0
		var x := 0.565 + sin(t * 5.2 + rng_rift.randf_range(-0.35, 0.35)) * (0.012 + t * 0.022)
		x = lerpf(previous, x, 0.65)
		previous = x
		_rift_points.append(Vector2(x, 0.035 + t * 0.66))
	_branch_cracks.clear()
	for branch in 4:
		var anchor := int((0.18 + 0.16 * float(branch)) * float(_rift_points.size()))
		var start: Vector2 = _rift_points[clampi(anchor, 0, _rift_points.size() - 1)]
		var direction := -1.0 if branch % 2 == 0 else 1.0
		var points := PackedVector2Array([start])
		var cursor := start
		for step in 3:
			cursor += Vector2(
				direction * rng_rift.randf_range(0.02, 0.07),
				rng_rift.randf_range(0.01, 0.05) * (1.0 if step % 2 == 0 else 0.4)
			)
			points.append(Vector2(clampf(cursor.x, 0.0, 1.0), cursor.y))
		_branch_cracks.append(points)
	_debris.clear()
	for i in 26:
		_debris.append({
			"angle": rng_rift.randf_range(0.0, TAU),
			"radius": rng_rift.randf_range(0.55, 0.96),
			"size": rng_rift.randf_range(0.6, 2.4),
			"speed": rng_rift.randf_range(0.02, 0.09),
			"phase": rng_rift.randf_range(0.0, 1.0),
		})
	_seeded = true
	_build_sky_texture()


## Smooth vertical sky ramp. Drawn as one texture instead of colour bands, which
## removes the banding that a per-row draw would show on a 900px-tall viewport.
func _build_sky_texture() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, UIPalette.darken(UIPalette.mix(_sky_top, UIPalette.ink, 0.45), 0.05))
	gradient.set_color(1, _sky_horizon)
	gradient.add_point(0.62, _sky_mid)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 8
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	_sky_texture = texture


func _draw() -> void:
	var width := size.x
	var height := size.y
	if width < 40.0 or height < 40.0:
		return
	if not _seeded:
		_seed_scene()
	var time := draw_time()
	var horizon := height * 0.715
	_draw_sky(width, height, horizon, time)
	_draw_rift(width, height, horizon, time)
	_draw_ridges(width, height, horizon, time)
	_draw_spires(width, height, horizon, time)
	_draw_motes(width, height, time)
	_draw_foreground(width, height, horizon, time)
	_draw_frame_marks(width, height)


func _draw_sky(width: float, height: float, horizon: float, time: float) -> void:
	if _sky_texture != null:
		draw_texture_rect(_sky_texture, Rect2(0.0, 0.0, width, horizon + 2.0), false)
	else:
		var top := UIPalette.darken(UIPalette.mix(_sky_top, UIPalette.ink, 0.45), 0.05)
		_draw_vertical_gradient(Rect2(0.0, 0.0, width, horizon), top, _sky_mid, 88)
	_draw_vertical_gradient(
		Rect2(0.0, horizon * 0.62, width, horizon * 0.38 + 2.0),
		UIPalette.alpha(_sky_mid, 0.55),
		UIPalette.alpha(_sky_horizon, 0.42),
		32
	)
	# Distant eclipse: a dead moon eating the sun.
	var moon_center := Vector2(width * (0.76 + sin(time * 0.03) * 0.004), height * 0.265)
	var moon_radius := height * 0.082
	_draw_glow(moon_center, moon_radius * 3.4, UIPalette.alpha(_sun_color, 0.6), 20, 0.55)
	draw_circle(moon_center, moon_radius * 1.35, UIPalette.alpha(_sky_horizon, 0.06))
	draw_circle(moon_center, moon_radius, UIPalette.alpha(UIPalette.ink, 0.94))
	var rim := UIPalette.alpha(_sun_color, 0.72)
	draw_arc(moon_center, moon_radius, -2.5, 1.9, 48, rim, 2.0, true)
	draw_arc(moon_center, moon_radius * 0.97, -2.45, 1.8, 48, UIPalette.alpha(_sun_color, 0.25), 5.0, true)
	# Stars. They shimmer rather than move, so the frame stays quiet.
	for star in _stars:
		var twinkle := 0.6 + 0.4 * sin(time * 1.1 + float(star.phase))
		var pos := Vector2(float(star.pos.x) * width, float(star.pos.y) * height)
		draw_circle(pos, float(star.size), UIPalette.alpha(UIPalette.ivory, float(star.alpha) * twinkle))
	# Thin weather bands across the sun line.
	for i in 7:
		var t := float(i) / 6.0
		var y := horizon * lerpf(0.55, 0.94, t)
		var band_alpha := (0.05 + 0.07 * (1.0 - t)) * (0.7 + 0.3 * sin(time * 0.4 + t * 5.0))
		draw_rect(Rect2(0.0, y, width, height * 0.006), UIPalette.alpha(_sky_horizon, band_alpha))
	# Wind-torn cloud streaks, drawn as flattened translucent discs.
	for i in 9:
		var t := float(i) / 8.0
		var center := Vector2(
			fposmod(width * (0.10 + t * 0.85) + time * width * 0.004, width * 1.2) - width * 0.1,
			horizon * (0.46 + 0.34 * sin(t * 3.4 + 1.2))
		)
		draw_set_transform(center, 0.0, Vector2(3.4 + t * 1.2, 0.16))
		draw_circle(Vector2.ZERO, height * (0.03 + 0.02 * t), UIPalette.alpha(_sky_horizon, 0.035))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Ground haze under the cloud deck.
	draw_rect(Rect2(0.0, horizon - height * 0.09, width, height * 0.09), UIPalette.alpha(_sky_horizon, 0.05))


func _draw_rift(width: float, height: float, horizon: float, time: float) -> void:
	var open := clampf(time / 1.05, 0.0, 1.0)
	var points := PackedVector2Array()
	for point in _rift_points:
		points.append(Vector2(float(point.x) * width, float(point.y) * height))
	var pulse := 0.78 + 0.22 * sin(time * 6.8) + 0.08 * sin(time * 17.3)
	# Broad atmospheric bloom first, then the seam itself.
	for layer in range(5, 0, -1):
		var layer_width := float(layer) * 9.0 * open
		var layer_alpha := 0.018 + 0.02 * (1.0 - float(layer) / 5.0)
		draw_polyline(points, UIPalette.alpha(_rift_color, layer_alpha * 9.0), layer_width, true)
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var flicker := 0.55 + 0.45 * sin(time * 12.0 + float(i) * 1.7)
		draw_line(a, b, UIPalette.alpha(_rift_color, 0.55 * open * flicker), maxf(1.0, 3.2 * open), true)
		draw_line(a, b, UIPalette.alpha(UIPalette.ivory, 0.55 * open * flicker), maxf(1.0, 1.1 * open), true)
	# Branches of folded space.
	for crack in _branch_cracks:
		var crack_points := PackedVector2Array()
		for point in crack:
			crack_points.append(Vector2(float(point.x) * width, float(point.y) * height))
		draw_polyline(crack_points, UIPalette.alpha(_rift_color, 0.32 * open), 2.0, true)
	# Light spills out onto the ground haze.
	var base_point := Vector2(float(points[points.size() - 1].x), horizon + height * 0.02)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(base_point.x - width * 0.02, height * 0.62),
			Vector2(base_point.x + width * 0.02, height * 0.62),
			Vector2(base_point.x + width * 0.17, height * 0.94),
			Vector2(base_point.x - width * 0.17, height * 0.94),
		]),
		UIPalette.alpha(_rift_color, 0.055 * open)
	)
	_draw_glow(Vector2(base_point.x, horizon), height * 0.12 * open, UIPalette.alpha(_rift_color, 0.4), 12, 0.6)
	# Arc discharge: seeded by a quantum of time so it re-rolls a few times per
	# second like an actual electrical event.
	var arc_seed := int(floor(time * 2.6))
	if arc_seed % 3 != 0:
		var arc_rng := RandomNumberGenerator.new()
		arc_rng.seed = arc_seed * 7919 + 17
		var arc_start := points[clampi(int(float(points.size()) * 0.35), 0, points.size() - 1)]
		var arc_end := Vector2(
			arc_start.x + width * arc_rng.randf_range(-0.16, 0.18),
			horizon + height * arc_rng.randf_range(0.02, 0.16)
		)
		var arc_points := PackedVector2Array([arc_start])
		var cursor := arc_start
		var segments := 6
		for i in segments:
			var t := float(i + 1) / float(segments)
			var target := arc_start.lerp(arc_end, t)
			cursor = target + Vector2(arc_rng.randf_range(-1.0, 1.0) * width * 0.018, 0.0)
			arc_points.append(cursor)
		draw_polyline(arc_points, UIPalette.alpha(_rift_color, 0.42 * open), 1.4, true)
		draw_polyline(arc_points, UIPalette.alpha(UIPalette.ivory, 0.22 * open), 0.7, true)
	# Heat ripples hug the seam.
	for i in 3:
		var t := float(i) / 2.0
		var ripple_y := lerpf(horizon * 0.35, horizon, t)
		draw_arc(
			Vector2(base_point.x, ripple_y),
			width * (0.02 + t * 0.07) * (1.0 + 0.06 * pulse),
			PI + 0.35,
			TAU - 0.35,
			26,
			UIPalette.alpha(_rift_color, 0.10 * open),
			1.0,
			true
		)
	# Shock rings rolling across the drop zone.
	for ring in 2:
		var ring_t := fposmod(time * 0.35 + float(ring) * 0.5, 1.0)
		draw_set_transform(Vector2(base_point.x, horizon + height * 0.02), 0.0, Vector2(2.6, 0.22))
		draw_arc(Vector2.ZERO, width * (0.04 + ring_t * 0.23), 0.0, TAU, 48, UIPalette.alpha(_rift_color, 0.18 * (1.0 - ring_t) * open), 1.6, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Folded-space shards spat out of the tear.
	for shard in _debris:
		var rise := fposmod(float(shard.phase) + time * float(shard.speed), 1.0)
		var angle: float = float(shard.angle)
		var x := base_point.x + cos(angle) * width * (0.05 + rise * 0.24)
		var y := horizon + height * 0.02 - rise * height * 0.52
		var size := float(shard.size) * (1.0 - rise * 0.6)
		# Sub-pixel shards collapse to degenerate triangles, which the canvas
		# triangulator rejects; only draw visible fragments.
		if size < 1.2:
			continue
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(x, y - size * 2.2),
				Vector2(x + size, y + size),
				Vector2(x - size, y + size),
			]),
			UIPalette.alpha(UIPalette.mix(_rift_color, UIPalette.ivory, 0.25), 0.5 * (1.0 - rise) * open)
		)


func _draw_ridges(width: float, height: float, horizon: float, time: float) -> void:
	var rim := UIPalette.alpha(_rift_color, 0.30)
	for index in _ridges.size():
		var points: PackedVector2Array = _ridges[index]
		var layer: float = float(index) / 2.0
		var color := UIPalette.mix(_ground, UIPalette.ink, 0.30 + layer * 0.16)
		var drift := sin(time * 0.05 + float(index)) * width * 0.004 * (0.4 + layer)
		var screen := PackedVector2Array()
		for point in points:
			screen.append(Vector2(float(point.x) * width + drift, float(point.y) * height))
		_draw_ridge_fill(screen, height, color)
		if index == 1:
			draw_polyline(screen, rim, 1.2, true)
	# Foreground haze lip.
	draw_rect(Rect2(0.0, horizon + height * 0.145, width, height * 0.03), UIPalette.alpha(UIPalette.ink, 0.36))


func _draw_ridge_fill(points: PackedVector2Array, height: float, color: Color) -> void:
	if points.size() < 2:
		return
	var colors := PackedColorArray([color, color, color])
	var bottom := height + 12.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		if b.x <= a.x:
			continue
		var br := Vector2(b.x, bottom)
		var bl := Vector2(a.x, bottom)
		draw_primitive(PackedVector2Array([a, b, br]), colors, PackedVector2Array())
		draw_primitive(PackedVector2Array([a, br, bl]), colors, PackedVector2Array())


func _draw_spires(width: float, height: float, horizon: float, time: float) -> void:
	for spire in _spires:
		var x := float(spire.x) * width
		var top := horizon - float(spire.height) * height
		var base := horizon + height * 0.04
		var thickness := maxf(1.0, float(spire.width) * width)
		draw_line(Vector2(x, base), Vector2(x, top), UIPalette.alpha(UIPalette.ink, 0.88), thickness)
		draw_line(
			Vector2(x - thickness * 3.0, top + height * 0.016),
			Vector2(x + thickness * 3.0, top + height * 0.016),
			UIPalette.alpha(UIPalette.ink, 0.88),
			thickness * 0.7
		)
		var blink := 0.5 + 0.5 * sin(time * 1.4 + float(spire.phase))
		draw_circle(Vector2(x, top), maxf(1.4, width * 0.0018), UIPalette.alpha(_sun_color, 0.35 + 0.4 * blink))
		draw_circle(Vector2(x, top), maxf(3.0, width * 0.0045), UIPalette.alpha(_sun_color, 0.05 + 0.05 * blink))


func _draw_motes(width: float, height: float, time: float) -> void:
	for mote in _motes:
		var pos: Vector2 = mote.pos
		var x := fposmod(pos.x + time * float(mote.speed) * 0.6, 1.0) * width
		var y := pos.y * height - fposmod(time * float(mote.speed) * 0.22, 1.0) * height * 0.10
		y = fposmod(y, height)
		var wobble := sin(time * 0.8 + float(mote.phase)) * width * 0.004
		draw_circle(Vector2(x + wobble, y), float(mote.size), UIPalette.alpha(_sun_color, float(mote.alpha)))


## Foreground framing: dark rocks, a colony outpost silhouette and a left-side
## legibility scrim. The scrim is deliberately strongest at x=0 so the operation
## caption can sit over the art without a hard panel.
func _draw_foreground(width: float, height: float, horizon: float, time: float) -> void:
	for band in 22:
		var t := float(band) / 21.0
		var band_width := width * 0.62 / 22.0
		var alpha := 0.30 * (1.0 - t) * (1.0 - t)
		draw_rect(Rect2(t * width * 0.62, 0.0, band_width + 1.0, height), UIPalette.alpha(UIPalette.ink, alpha))
	# Colony outpost on the far ridge: five dark blocks and their windows.
	var outpost_x := width * 0.79
	var outpost_y := horizon + height * 0.012
	for index in 5:
		var block_width := width * (0.012 + 0.004 * float(index % 3))
		var block_height := height * (0.02 + 0.014 * float(index % 2))
		var x := outpost_x + float(index) * width * 0.019
		draw_rect(Rect2(x, outpost_y - block_height, block_width, block_height * 2.2), UIPalette.alpha(UIPalette.ink, 0.92))
		var blink := 0.5 + 0.5 * sin(time * 1.2 + float(index) * 1.9)
		draw_circle(Vector2(x + block_width * 0.5, outpost_y - block_height * 0.4), 1.3, UIPalette.alpha(_sun_color, 0.25 + 0.4 * blink))
	# Foreground rocks frame the title without covering the rift.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, height), Vector2(0.0, height * 0.84),
			Vector2(width * 0.10, height * 0.925), Vector2(width * 0.22, height * 0.90),
			Vector2(width * 0.31, height),
		]),
		UIPalette.alpha(UIPalette.ink, 0.92)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(width, height), Vector2(width, height * 0.89),
			Vector2(width * 0.88, height * 0.945), Vector2(width * 0.76, height * 0.93),
			Vector2(width * 0.68, height),
		]),
		UIPalette.alpha(UIPalette.ink, 0.92)
	)
	draw_line(Vector2(0.0, height * 0.84), Vector2(width * 0.10, height * 0.925), UIPalette.alpha(_rift_color, 0.20), 1.2)
	draw_line(Vector2(width, height * 0.89), Vector2(width * 0.88, height * 0.945), UIPalette.alpha(_rift_color, 0.20), 1.2)
	# Embers lifting off the rocks.
	for index in 9:
		var t := fposmod(time * (0.10 + float(index) * 0.012) + float(index) * 0.13, 1.0)
		var x := width * (0.05 + float(index) * 0.10) + sin(time + float(index)) * 6.0
		var y := height * 0.92 - t * height * 0.34
		draw_circle(Vector2(x, y), 0.9 + 1.2 * (1.0 - t), UIPalette.alpha(_sun_color, 0.25 * (1.0 - t)))


## Faint registration marks keep the frame feeling like captured footage. The
## loading chrome draws the heavier typography on top.
func _draw_frame_marks(width: float, height: float) -> void:
	var mark_color := UIPalette.alpha(_rift_color, 0.20)
	var inset := 34.0
	var length := 18.0
	draw_line(Vector2(inset, inset * 2.0), Vector2(inset + length, inset * 2.0), mark_color, 1.0)
	draw_line(Vector2(inset, inset * 2.0), Vector2(inset, inset * 2.0 + length), mark_color, 1.0)
	draw_line(Vector2(width - inset, height - inset * 2.6), Vector2(width - inset - length, height - inset * 2.6), mark_color, 1.0)
	draw_line(Vector2(width - inset, height - inset * 2.6), Vector2(width - inset, height - inset * 2.6 - length), mark_color, 1.0)
