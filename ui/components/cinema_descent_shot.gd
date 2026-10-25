class_name CinemaDescentShot
extends UICinemaShot
## Act 03 — DROP DESCENT.
##
## First-person drop-pod footage: cloud decks tearing upward past the hull,
## speed streaks, a projected landing reticle and live telemetry tapes. Altitude
## is derived from the local shot clock, not the deployment progress, so the
## footage reads correctly even when the loader races or stalls.

var brief: Dictionary = {}

var _streaks: Array = []
var _clouds: Array = []
var _terrain_waves: Array = []
var _lights: Array = []
var _accent := Color("62e6c3")
var _danger := Color("ffb866")
var _sky := Color("0b1114")
var _sky_horizon := Color("d9a173")
var _seeded := false

const MONO_SMALL := 10
const MONO_MED := 12


func _on_shot_ready() -> void:
	shot_id = &"descent"
	static_pose_time = 1.15
	set_static_frame(UIPalette.reduce_motion)


func set_brief(value: Dictionary) -> void:
	brief = value if value != null else {}
	_accent = brief.get("planet_color", UIPalette.mint)
	_danger = brief.get("contract_color", UIPalette.amber)
	_sky = UIPalette.mix(brief.get("sky_top", Color("101d21")), UIPalette.ink, 0.45)
	_sky_horizon = brief.get("sky_horizon", Color("d9a173"))
	_seed_scene()
	queue_redraw()


func _seed_scene() -> void:
	var rng := _seed_rng(brief.get("seed", 0) + 11)
	_streaks.clear()
	for i in 96:
		_streaks.append({
			"angle": rng.randf_range(0.0, TAU),
			"phase": rng.randf_range(0.0, 1.0),
			"speed": rng.randf_range(0.55, 1.7),
			"length": rng.randf_range(0.04, 0.22),
			"alpha": rng.randf_range(0.05, 0.30),
			"width": rng.randf_range(0.7, 2.4),
		})
	_clouds.clear()
	for i in 30:
		_clouds.append({
			"pos": Vector2(rng.randf_range(-0.1, 1.1), rng.randf_range(0.05, 0.95)),
			"size": rng.randf_range(0.04, 0.15),
			"speed": rng.randf_range(0.10, 0.36),
			"alpha": rng.randf_range(0.05, 0.18),
			"phase": rng.randf_range(0.0, TAU),
		})
	_terrain_waves.clear()
	for layer in 3:
		var wave := PackedFloat32Array()
		var count := 48
		var rng_layer := RandomNumberGenerator.new()
		rng_layer.seed = 3001 + layer * 613
		var phase_a := rng_layer.randf_range(0.0, TAU)
		var phase_b := rng_layer.randf_range(0.0, TAU)
		for i in count + 1:
			var t := float(i) / float(count)
			wave.append(
				0.58 * sin(t * TAU * 1.3 + phase_a)
				+ 0.30 * sin(t * TAU * 3.1 + phase_b)
				+ 0.12 * sin(t * TAU * 7.3 + phase_a * 2.1)
			)
		_terrain_waves.append(wave)
	_lights.clear()
	for i in 28:
		_lights.append({
			"x": rng.randf_range(0.26, 0.78),
			"phase": rng.randf_range(0.0, TAU),
			"color": _danger if i % 3 != 0 else _accent,
		})
	_seeded = true


func _draw() -> void:
	var width := size.x
	var height := size.y
	if width < 40.0 or height < 40.0:
		return
	if not _seeded:
		_seed_scene()
	var time := draw_time()
	var fall := clampf(time / 1.55, 0.0, 1.0)
	var altitude := lerpf(6420.0, 240.0, _ease_in_out(fall))
	_draw_void(width, height)
	_draw_clouds(width, height, time)
	_draw_terrain(width, height, fall, time)
	_draw_speed_streaks(width, height, time)
	_draw_hull_frame(width, height, time)
	_draw_reticle(width, height, time, altitude)
	_draw_altitude_tape(width, height, fall, altitude)
	_draw_telemetry(width, height, altitude)


func _draw_void(width: float, height: float) -> void:
	var top := UIPalette.darken(_sky, 0.04)
	var bottom := UIPalette.mix(_sky, _accent, 0.16)
	_draw_vertical_gradient(Rect2(0.0, 0.0, width, height), top, bottom, 46)
	# The target zone burns through the cloud deck.
	var glow := Vector2(width * 0.52, height * 0.60)
	_draw_glow(glow, height * 0.34, UIPalette.alpha(_danger, 0.24), 16, 0.5)


func _draw_clouds(width: float, height: float, time: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for cloud in _clouds:
		var speed: float = float(cloud.speed)
		var y := fposmod(float(cloud.pos.y) + time * speed, 1.2) - 0.1
		var x := float(cloud.pos.x) + sin(time * 0.18 + float(cloud.phase)) * 0.015
		var center := Vector2(x * width, y * height)
		var radius := float(cloud.size) * height
		var color := UIPalette.alpha(UIPalette.mix(_sky, Color("cfd4c4"), 0.30), float(cloud.alpha))
		var lit := UIPalette.alpha(UIPalette.mix(_sky_horizon, Color("f0e2cf"), 0.45), float(cloud.alpha) * 0.55)
		draw_set_transform(center, 0.0, Vector2(2.3, 0.52))
		draw_circle(Vector2(radius * 0.05, radius * 0.18), radius, color)
		draw_circle(Vector2(radius * 0.62, radius * 0.24), radius * 0.60, color)
		draw_circle(Vector2(-radius * 0.55, radius * 0.26), radius * 0.54, color)
		# Lit upper deck catches the burning ground below.
		draw_circle(Vector2(0.0, -radius * 0.18), radius * 0.82, lit)
		draw_circle(Vector2(radius * 0.70, -radius * 0.12), radius * 0.42, lit)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_terrain(width: float, height: float, fall: float, time: float) -> void:
	var horizon := height * lerpf(0.44, 0.72, _ease_in_out(fall))
	# Runway / landing markings on the deck, converging toward the reticle.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(width * 0.52, horizon),
			Vector2(width * 0.80, height),
			Vector2(width * 0.30, height),
		]),
		UIPalette.alpha(_danger, 0.028)
	)
	for layer in 3:
		var wave: PackedFloat32Array = _terrain_waves[layer]
		var base := horizon + float(layer) * height * 0.075
		var amplitude := height * (0.035 + float(layer) * 0.028) * lerpf(0.7, 1.6, fall)
		var color := UIPalette.mix(UIPalette.mix(_sky, UIPalette.ink, 0.18), UIPalette.mix(_sky_horizon, UIPalette.ink, 0.55), 0.15 + float(layer) * 0.18)
		var points := PackedVector2Array()
		for i in wave.size():
			var t := float(i) / float(wave.size() - 1)
			points.append(Vector2(t * width, base - wave[i] * amplitude))
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
		if layer == 2:
			# Rim light on the near ridge catches the burning target zone.
			draw_polyline(points, UIPalette.alpha(_danger, 0.20), 1.2, true)
			var visibility := clampf((fall - 0.30) / 0.35, 0.0, 1.0)
			for light in _lights:
				var lx := float(light.x) * width
				var wave_index := clampi(int(float(light.x) * float(wave.size() - 1)), 0, wave.size() - 1)
				var ly := base - wave[wave_index] * amplitude - 3.0
				var blink := 0.65 + 0.35 * sin(time * 2.2 + float(light.phase))
				draw_circle(Vector2(lx, ly), 1.6, UIPalette.alpha(light.color, 0.55 * visibility * blink))
				draw_circle(Vector2(lx, ly), 4.6, UIPalette.alpha(light.color, 0.08 * visibility))
			# A beacon tower at the landing zone.
			var beacon_x := width * 0.52
			var beacon_y := base - wave[clampi(int(0.52 * float(wave.size() - 1)), 0, wave.size() - 1)] * amplitude
			draw_line(Vector2(beacon_x, beacon_y), Vector2(beacon_x, beacon_y - height * 0.05), UIPalette.alpha(UIPalette.ink, 0.9), 2.0)
			draw_circle(Vector2(beacon_x, beacon_y - height * 0.05), 2.0, UIPalette.alpha(_danger, 0.5 + 0.4 * sin(time * 3.0)))
	# Landing reticle bloom on the deck.
	var reticle_y := height * 0.76
	draw_set_transform(Vector2(width * 0.52, reticle_y), 0.0, Vector2(1.0, 0.26))
	draw_arc(Vector2.ZERO, width * lerpf(0.06, 0.17, fall), 0.0, TAU, 48, UIPalette.alpha(_danger, 0.55), 2.4, true)
	draw_arc(Vector2.ZERO, width * lerpf(0.03, 0.09, fall), 0.0, TAU, 40, UIPalette.alpha(_danger, 0.22), 1.0, true)
	draw_arc(Vector2.ZERO, width * lerpf(0.02, 0.05, fall), 0.0, TAU, 32, UIPalette.alpha(_accent, 0.18), 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_speed_streaks(width: float, height: float, time: float) -> void:
	var center := Vector2(width * 0.52, height * 0.42)
	var max_radius := Vector2(width, height).length() * 0.5
	for streak in _streaks:
		var angle: float = float(streak.angle)
		var speed: float = float(streak.speed)
		var phase := fposmod(float(streak.phase) + time * speed, 1.0)
		var start := center + Vector2(cos(angle), sin(angle)) * max_radius * (0.14 + phase * 0.92)
		var length := max_radius * float(streak.length) * (0.4 + phase)
		var end := start + Vector2(cos(angle), sin(angle)) * length
		var fade := sin(phase * PI)
		draw_line(start, end, UIPalette.alpha(UIPalette.ivory, float(streak.alpha) * fade), float(streak.width), true)


func _draw_hull_frame(width: float, height: float, time: float) -> void:
	var hull := UIPalette.alpha(UIPalette.ink, 0.92)
	var edge := UIPalette.alpha(_accent, 0.32)
	var highlight := UIPalette.alpha(UIPalette.ivory, 0.06)
	# Canopy shoulders.
	draw_colored_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(width * 0.24, 0), Vector2(width * 0.16, height * 0.17), Vector2(0, height * 0.24)]),
		hull
	)
	draw_colored_polygon(
		PackedVector2Array([Vector2(width, 0), Vector2(width * 0.76, 0), Vector2(width * 0.84, height * 0.17), Vector2(width, height * 0.24)]),
		hull
	)
	draw_line(Vector2(0, height * 0.24), Vector2(width * 0.16, height * 0.17), edge, 1.6)
	draw_line(Vector2(width, height * 0.24), Vector2(width * 0.84, height * 0.17), edge, 1.6)
	draw_line(Vector2(0, height * 0.25), Vector2(width * 0.16, height * 0.18), highlight, 3.0)
	draw_line(Vector2(width, height * 0.25), Vector2(width * 0.84, height * 0.18), highlight, 3.0)
	# Struts and bolts read as the inside of a pod.
	for side_value in [0.0, 1.0]:
		var side := float(side_value)
		var base_x := width * (0.02 if side == 0.0 else 0.98)
		var direction := 1.0 if side == 0.0 else -1.0
		draw_line(Vector2(base_x, height * 0.28), Vector2(base_x + direction * width * 0.055, height * 0.46), UIPalette.alpha(UIPalette.ink, 0.65), 8.0)
		draw_line(Vector2(base_x + direction * 3.0, height * 0.29), Vector2(base_x + direction * width * 0.055 + direction * 3.0, height * 0.455), highlight, 1.2)
		for bolt in 5:
			var t := (float(bolt) + 0.5) / 5.0
			var point := Vector2(base_x, height * 0.28).lerp(Vector2(base_x + direction * width * 0.055, height * 0.46), t)
			draw_circle(point, 1.5, UIPalette.alpha(_accent, 0.22))
	# Glass glare sweeping once as the pod rolls.
	var glare_offset := fposmod(time * 0.22, 1.6) - 0.3
	var glare_x := width * glare_offset
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(glare_x, 0.0),
			Vector2(glare_x + width * 0.09, 0.0),
			Vector2(glare_x + width * 0.02, height * 0.34),
			Vector2(glare_x - width * 0.03, height * 0.34),
		]),
		UIPalette.alpha(UIPalette.ivory, 0.018)
	)
	# Vignette corners under the frame.
	draw_rect(Rect2(0.0, 0.0, width, height), UIPalette.alpha(UIPalette.ink, 0.10))


func _draw_reticle(width: float, height: float, time: float, altitude: float) -> void:
	var center := Vector2(width * 0.52, height * 0.46) + Vector2(sin(time * 0.7) * 3.0, cos(time * 0.9) * 2.0)
	var bracket := width * 0.020
	var color := UIPalette.alpha(_accent, 0.42)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var c: Vector2 = center + Vector2(corner.x * bracket, corner.y * bracket)
		draw_line(c, c + Vector2(-corner.x * bracket * 0.55, 0), color, 1.2)
		draw_line(c, c + Vector2(0, -corner.y * bracket * 0.55), color, 1.2)
	draw_line(center - Vector2(7, 0), center + Vector2(7, 0), UIPalette.alpha(_accent, 0.28), 1.0)
	draw_line(center - Vector2(0, 7), center + Vector2(0, 7), UIPalette.alpha(_accent, 0.28), 1.0)
	draw_circle(center, 1.8, UIPalette.alpha(_danger, 0.7))
	var font := UIFonts.mono(false)
	if font != null:
		var label := "LOCK %d m" % int(round(altitude * 0.14))
		draw_string(font, center + Vector2(bracket + 8.0, -bracket + 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, MONO_SMALL, UIPalette.alpha(_accent, 0.55))
	# Turbulence warning flickers on a deterministic beat.
	if font != null and int(floor(time * 3.0)) % 7 == 3:
		draw_string(font, center + Vector2(-52.0, bracket + 30.0), "TURBULENCE", HORIZONTAL_ALIGNMENT_LEFT, -1, MONO_SMALL, UIPalette.alpha(_danger, 0.7))


func _draw_altitude_tape(width: float, height: float, fall: float, altitude: float) -> void:
	var x := width * 0.905
	var top := height * 0.24
	var bottom := height * 0.60
	var font := UIFonts.mono(false)
	var line_color := UIPalette.alpha(_accent, 0.26)
	draw_line(Vector2(x, top), Vector2(x, bottom), line_color, 1.0)
	var ticks := 22
	for i in ticks + 1:
		var t := float(i) / float(ticks)
		var y := lerpf(top, bottom, t)
		var major := i % 4 == 0
		draw_line(Vector2(x, y), Vector2(x + (12.0 if major else 6.0), y), line_color, 1.0)
		if major and font != null:
			var value := int(lerpf(6500.0, 0.0, t) / 50.0) * 50
			draw_string(font, Vector2(x + 18.0, y + 3.5), str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, MONO_SMALL, UIPalette.alpha(UIPalette.muted, 0.6))
	# Current altitude marker slides down as the pod falls.
	var marker_t := _ease_in_out(fall)
	var marker_y := lerpf(top, bottom, marker_t)
	draw_colored_polygon(
		PackedVector2Array([Vector2(x - 8.0, marker_y), Vector2(x - 1.0, marker_y - 4.0), Vector2(x - 1.0, marker_y + 4.0)]),
		UIPalette.alpha(_danger, 0.9)
	)
	draw_line(Vector2(x - 16.0, marker_y), Vector2(x, marker_y), UIPalette.alpha(_danger, 0.75), 1.2)
	if font != null:
		draw_string(font, Vector2(x + 6.0, top - 12.0), "AGL", HORIZONTAL_ALIGNMENT_LEFT, -1, MONO_SMALL, UIPalette.alpha(_accent, 0.6))
		draw_string(font, Vector2(x - 6.0, bottom + 20.0), "%d M" % int(round(altitude)), HORIZONTAL_ALIGNMENT_LEFT, -1, MONO_MED, UIPalette.alpha(UIPalette.ivory, 0.85))


func _draw_telemetry(width: float, height: float, altitude: float) -> void:
	var left := width * 0.055
	var top := height * 0.30
	var panel := Rect2(left - 16.0, top - 18.0, 232.0, 122.0)
	draw_rect(panel, UIPalette.alpha(UIPalette.ink, 0.52))
	draw_line(panel.position + Vector2(0, 0), panel.position + Vector2(0, panel.size.y), UIPalette.alpha(_accent, 0.6), 2.0)
	var font := UIFonts.mono(false)
	var bold := UIFonts.mono(true)
	if font == null or bold == null:
		return
	draw_string(font, Vector2(left, top - 2.0), "DROP POD // KESTREL-7", HORIZONTAL_ALIGNMENT_LEFT, -1, MONO_SMALL, UIPalette.alpha(_accent, 0.8))
	draw_string(bold, Vector2(left, top + 22.0), "ALT  %s M" % _format_altitude(altitude), HORIZONTAL_ALIGNMENT_LEFT, -1, MONO_MED, UIPalette.ivory)
	draw_string(font, Vector2(left, top + 40.0), "VEL  214 M/S", HORIZONTAL_ALIGNMENT_LEFT, -1, MONO_SMALL, UIPalette.muted)
	draw_string(font, Vector2(left, top + 56.0), "G    3.1", HORIZONTAL_ALIGNMENT_LEFT, -1, MONO_SMALL, UIPalette.muted)
	draw_string(font, Vector2(left, top + 72.0), "HULL 100%", HORIZONTAL_ALIGNMENT_LEFT, -1, MONO_SMALL, UIPalette.muted)
	draw_string(font, Vector2(left, top + 92.0), String(brief.get("map_name", "THE REACH")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, MONO_SMALL, UIPalette.alpha(_danger, 0.75))


func _format_altitude(value: float) -> String:
	var text := str(int(value))
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = " " + out
	return out


func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
