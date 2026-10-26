class_name CinemaInsertionShot
extends UICinemaShot
## Deployment-feed insert — the pod ramp drops and the Warden rises to standing.
##
## A short, loud punctuation beat that sits between the drop descent and the
## touchdown reveal: hull ribs frame a widening ramp opening, floodlight pours
## through, the floor grating and the first-person arms climb into frame, and
## the visor edges close in as the camera rises to eye height. Code-drawn like
## every other loading-cinema shot, so it renders identically in headless tests.

var brief: Dictionary = {}

var _accent := Color("62e6c3")
var _danger := Color("ffb866")
var _sky := Color("0b1114")
var _motes: Array = []
var _seeded := false


func _on_shot_ready() -> void:
	shot_id = &"insertion"
	static_pose_time = 1.1
	set_static_frame(UIPalette.reduce_motion)


func set_brief(value: Dictionary) -> void:
	brief = value if value != null else {}
	_accent = brief.get("planet_color", UIPalette.mint)
	_danger = brief.get("contract_color", UIPalette.amber)
	_sky = UIPalette.mix(brief.get("sky_top", Color("101d21")), UIPalette.ink, 0.4)
	_seed_scene()
	queue_redraw()


func _seed_scene() -> void:
	var rng := _seed_rng(brief.get("seed", 0) + 41)
	_motes.clear()
	for i in 46:
		_motes.append({
			"pos": Vector2(rng.randf_range(-0.2, 1.2), rng.randf_range(0.0, 1.0)),
			"speed": rng.randf_range(0.10, 0.42),
			"size": rng.randf_range(0.6, 2.2),
			"alpha": rng.randf_range(0.05, 0.26),
			"drift": rng.randf_range(0.0, TAU),
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
	var open := _ease_out(clampf(time / 0.85, 0.0, 1.0))
	var rise := _ease_in_out(clampf((time - 0.15) / 1.05, 0.0, 1.0))
	_draw_exterior(width, height, open, time)
	_draw_ramp(width, height, open, time)
	_draw_light_spill(width, height, open, time)
	_draw_hull(width, height, open, time)
	_draw_first_person(width, height, open, rise, time)
	_draw_motes(width, height, time, open)
	_draw_visor(width, height, rise, time)
	_draw_interior_telemetry(width, height, time)


## World beyond the ramp: a dark sky that warms toward the landing shelf.
func _draw_exterior(width: float, height: float, open: float, time: float) -> void:
	var top := UIPalette.darken(_sky, 0.08)
	var horizon := UIPalette.mix(_sky, _danger, 0.22)
	var ground := UIPalette.mix(_sky, UIPalette.ink, 0.28)
	_draw_vertical_gradient(Rect2(0.0, 0.0, width, height * 0.64), top, horizon, 32)
	_draw_vertical_gradient(Rect2(0.0, height * 0.64, width, height * 0.36), horizon, ground, 20)
	# Distant ridge silhouettes settle the drop zone.
	for layer in 2:
		var y := height * (0.54 + float(layer) * 0.035)
		var points := PackedVector2Array()
		var count := 24
		for i in count + 1:
			var t := float(i) / float(count)
			var offset := sin(t * TAU * (1.4 + float(layer)) + float(layer) * 2.0) * height * 0.035
			points.append(Vector2(width * t, y + offset))
		points.append(Vector2(width, height * 0.64))
		points.append(Vector2(0.0, height * 0.64))
		draw_colored_polygon(points, UIPalette.alpha(UIPalette.ink, 0.34 - float(layer) * 0.12))
	# Drop-zone marker lights.
	for i in 5:
		var t := float(i) / 4.0
		var x := width * (0.34 + t * 0.32)
		var y := height * (0.56 + sin(time * 1.2 + t * 5.0) * 0.002)
		draw_circle(Vector2(x, y), 1.6, UIPalette.alpha(_danger, 0.25 * open))


## The ramp itself: hazard-striped treads receding through the opening.
func _draw_ramp(width: float, height: float, open: float, time: float) -> void:
	var center_x := width * 0.5
	var threshold_y := height * 0.50
	var floor_y := height * 1.02
	var half_near := width * 0.16
	var half_far := width * lerpf(0.012, 0.11, open)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(center_x - half_far, threshold_y),
			Vector2(center_x + half_far, threshold_y),
			Vector2(center_x + half_near, floor_y),
			Vector2(center_x - half_near, floor_y),
		]),
		UIPalette.alpha(UIPalette.mix(UIPalette.ink, _danger, 0.06), 0.96)
	)
	for i in 7:
		var t := float(i) / 6.0
		var scroll := fposmod(time * 0.55 + t, 1.0)
		var y := threshold_y + (floor_y - threshold_y) * scroll
		var width_t := lerpf(half_far, half_near, scroll)
		var stripe := 0.22 if i % 2 == 0 else 0.10
		draw_line(
			Vector2(center_x - width_t, y),
			Vector2(center_x + width_t, y),
			UIPalette.alpha(_danger, stripe * open),
			2.0 + scroll * 2.0
		)
	# Guide rails along both edges.
	for side in [-1.0, 1.0]:
		var s := float(side)
		draw_line(
			Vector2(center_x + half_far * s, threshold_y),
			Vector2(center_x + half_near * s, floor_y),
			UIPalette.alpha(_accent, 0.35 * open),
			1.4
		)


func _draw_light_spill(width: float, height: float, open: float, time: float) -> void:
	var center := Vector2(width * 0.5, height * 0.62)
	var glow := width * lerpf(0.10, 0.42, open)
	_draw_glow(center, glow, UIPalette.alpha(_danger, 0.30 * open), 18, 0.55)
	# Volumetric shaft pouring through the opening.
	for layer in range(5, 0, -1):
		var spread := width * 0.06 * float(layer)
		var alpha := 0.018 * (1.0 - float(layer) / 5.0) * open
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(width * 0.5 - spread * 0.4, height * 0.12),
				Vector2(width * 0.5 + spread * 0.4, height * 0.12),
				Vector2(width * 0.5 + spread * 2.0, height * 0.86),
				Vector2(width * 0.5 - spread * 2.0, height * 0.86),
			]),
			UIPalette.alpha(UIPalette.mix(_danger, UIPalette.ivory, 0.4), alpha * 6.0)
		)
	# The pod's own warning strobe at the threshold.
	var pulse := 0.5 + 0.5 * sin(time * 8.0)
	draw_rect(Rect2(0.0, height * 0.485, width, 2.0), UIPalette.alpha(_danger, 0.16 + 0.18 * pulse * open))


func _draw_hull(width: float, height: float, open: float, time: float) -> void:
	var center_x := width * 0.5
	var hull := UIPalette.alpha(UIPalette.ink, 0.97)
	var inner := UIPalette.mix(UIPalette.ink, _accent, 0.05)
	# Left and right hull slabs slide out of frame as the ramp opens.
	var inner_edge := width * lerpf(0.28, 0.44, open)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(center_x - inner_edge, height * 0.06),
			Vector2(center_x - inner_edge * 0.86, height * 0.50), Vector2(center_x - width * 0.16, height),
			Vector2(0.0, height),
		]),
		hull
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(width, 0.0), Vector2(center_x + inner_edge, height * 0.06),
			Vector2(center_x + inner_edge * 0.86, height * 0.50), Vector2(center_x + width * 0.16, height),
			Vector2(width, height),
		]),
		hull
	)
	# Frame ribs with accent piping.
	for side in [-1.0, 1.0]:
		var s := float(side)
		for rib in 4:
			var t := 0.10 + float(rib) * 0.20
			var x := center_x + s * inner_edge * lerpf(1.0, 0.74, t)
			draw_line(
				Vector2(x, height * (0.08 + t * 0.44)),
				Vector2(x - s * width * 0.03, height * (0.16 + t * 0.42)),
				UIPalette.alpha(inner, 0.9),
				width * 0.014
			)
		draw_line(
			Vector2(center_x + s * inner_edge, height * 0.06),
			Vector2(center_x + s * inner_edge * 0.86, height * 0.50),
			UIPalette.alpha(_accent, 0.30 * (0.4 + 0.6 * open)),
			2.0
		)
	# Ceiling gantry and pod lamp.
	draw_rect(Rect2(width * 0.18, 0.0, width * 0.64, height * 0.075), UIPalette.alpha(UIPalette.ink, 0.96))
	draw_rect(Rect2(width * 0.18, height * 0.072, width * 0.64, 1.0), UIPalette.alpha(_accent, 0.22))
	for i in 7:
		var t := float(i) / 6.0
		draw_circle(Vector2(width * lerpf(0.22, 0.78, t), height * 0.038), 1.6, UIPalette.alpha(_danger, 0.30))
	var lamp_center := Vector2(width * 0.5, height * 0.036)
	draw_circle(lamp_center, width * 0.026, UIPalette.alpha(_danger, 0.16 * (0.5 + 0.5 * open)))
	draw_circle(lamp_center, width * 0.008, UIPalette.alpha(UIPalette.ivory, 0.75))
	# Floor grating beneath the feet.
	for i in 8:
		var t := float(i) / 7.0
		var y := height * (0.90 + t * 0.10)
		draw_line(Vector2(0.0, y), Vector2(width, y), UIPalette.alpha(UIPalette.line, 0.30))


## First-person arms and weapon rising into frame with the standing motion.
func _draw_first_person(width: float, height: float, open: float, rise: float, time: float) -> void:
	var body := UIPalette.alpha(UIPalette.ink, 0.98)
	var glove := UIPalette.mix(UIPalette.ink, _accent, 0.10)
	var rim := UIPalette.alpha(UIPalette.mix(_accent, UIPalette.ivory, 0.35), 0.55)
	var base_y := height * lerpf(1.16, 0.94, rise)
	var bob := sin(time * 3.1) * height * lerpf(0.0, 0.004, rise)
	for side in [-1.0, 1.0]:
		var s := float(side)
		var shoulder := Vector2(width * (0.5 + s * 0.30), base_y + bob)
		var elbow := Vector2(width * (0.5 + s * 0.19), base_y + height * 0.10)
		var wrist := Vector2(width * (0.5 + s * 0.115), base_y - height * 0.02)
		draw_line(shoulder, elbow, body, width * 0.055)
		draw_line(elbow, wrist, body, width * 0.040)
		draw_circle(wrist, width * 0.028, glove)
		draw_line(wrist + Vector2(s * width * 0.012, 0.0), wrist + Vector2(s * width * 0.012, -height * 0.03), rim, 1.2)
	# Rifle silhouette held low, muzzle catching the ramp light.
	var muzzle := Vector2(width * 0.56, base_y - height * 0.10)
	draw_line(Vector2(width * 0.42, base_y - height * 0.05), muzzle, UIPalette.alpha(UIPalette.ink, 0.99), width * 0.034)
	draw_line(Vector2(width * 0.44, base_y - height * 0.058), muzzle, UIPalette.alpha(_accent, 0.22), 1.4)
	draw_circle(muzzle, 1.8, UIPalette.alpha(_danger, 0.5 * open))
	# Chest rig and shoulder line at the very bottom.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(width * 0.18, height), Vector2(width * 0.82, height),
			Vector2(width * 0.68, height * 0.965), Vector2(width * 0.32, height * 0.965),
		]),
		UIPalette.alpha(UIPalette.ink, 0.92)
	)


func _draw_motes(width: float, height: float, time: float, open: float) -> void:
	for mote in _motes:
		var pos: Vector2 = mote.pos
		var x := fposmod(float(pos.x) + sin(time * 0.4 + float(mote.drift)) * 0.03, 1.2) * width
		var travel := fposmod(float(pos.y) + time * float(mote.speed) * 0.18, 1.0)
		var y := lerpf(height * 0.98, height * 0.16, travel)
		var alpha := float(mote.alpha) * open * (1.0 - travel * 0.4)
		draw_circle(Vector2(x, y), float(mote.size), UIPalette.alpha(_danger, alpha))


## Helmet visor edges close in as the Warden comes upright.
func _draw_visor(width: float, height: float, rise: float, time: float) -> void:
	var inset := width * lerpf(0.20, 0.045, rise)
	var top := height * lerpf(0.26, 0.05, rise)
	var bottom := height * lerpf(0.70, 0.94, rise)
	var edge := UIPalette.alpha(UIPalette.ink, 0.82)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(width, 0.0), Vector2(width, top),
			Vector2(width - inset, top + height * 0.06), Vector2(inset, top + height * 0.06), Vector2(0.0, top),
		]),
		edge
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, height), Vector2(width, height), Vector2(width, bottom),
			Vector2(width - inset, bottom - height * 0.05), Vector2(inset, bottom - height * 0.05), Vector2(0.0, bottom),
		]),
		edge
	)
	# Visor seam highlights.
	var seam := UIPalette.alpha(_accent, 0.18 + 0.08 * sin(time * 1.6))
	_draw_fade_line(Vector2(inset, bottom - height * 0.05), Vector2(width - inset, bottom - height * 0.05), seam, 1.2, 26)


func _draw_interior_telemetry(width: float, height: float, time: float) -> void:
	# A small diegetic readout on the pod wall, left of the ramp.
	var origin := Vector2(width * 0.055, height * 0.62)
	var rows := 4
	for row in rows:
		var y := origin.y + float(row) * 15.0
		var length := width * (0.035 + 0.02 * sin(time * 1.1 + float(row) * 0.7))
		draw_rect(Rect2(origin.x, y, length, 2.0), UIPalette.alpha(_accent, 0.20))
	for pip in 3:
		var lit := 1.0 if fmod(time * 2.0 + float(pip) * 0.33, 1.0) > 0.4 else 0.25
		draw_rect(
			Rect2(origin.x + float(pip) * 7.0, origin.y - 12.0, 4.0, 4.0),
			UIPalette.alpha(_danger, 0.35 * lit)
		)
	# Ramp edge warning text bars on the right.
	var right := Vector2(width * 0.90, height * 0.60)
	for row in 3:
		draw_rect(
			Rect2(right.x, right.y + float(row) * 11.0, width * 0.045, 2.0),
			UIPalette.alpha(_danger, 0.14)
		)


func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)


func _ease_in_out(t: float) -> float:
	var value := clampf(t, 0.0, 1.0)
	return value * value * (3.0 - 2.0 * value)
