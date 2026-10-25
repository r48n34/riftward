class_name CinemaTouchdownShot
extends UICinemaShot
## Act 04 — TOUCHDOWN.
##
## The pod's ramp drops and the Warden steps into the light. A short, bright
## punctuation beat: door slabs slide apart, dust blows out, and the silhouette
## of the player's suit is backlit by the deployment floodlights.

var brief: Dictionary = {}

var _accent := Color("62e6c3")
var _danger := Color("ffb866")
var _sky := Color("0b1114")
var _dust: Array = []
var _seeded := false


func _on_shot_ready() -> void:
	shot_id = &"touchdown"
	static_pose_time = 1.2
	set_static_frame(UIPalette.reduce_motion)


func set_brief(value: Dictionary) -> void:
	brief = value if value != null else {}
	_accent = brief.get("planet_color", UIPalette.mint)
	_danger = brief.get("contract_color", UIPalette.amber)
	_sky = UIPalette.mix(brief.get("sky_top", Color("101d21")), UIPalette.ink, 0.35)
	_seed_scene()
	queue_redraw()


func _seed_scene() -> void:
	var rng := _seed_rng(brief.get("seed", 0) + 29)
	_dust.clear()
	for i in 60:
		_dust.append({
			"pos": Vector2(rng.randf(), rng.randf_range(0.55, 0.95)),
			"speed": rng.randf_range(0.02, 0.12),
			"size": rng.randf_range(0.7, 2.4),
			"alpha": rng.randf_range(0.05, 0.3),
			"phase": rng.randf_range(0.0, TAU),
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
	var open := _ease_out(clampf(time / 0.75, 0.0, 1.0))
	_draw_ground(width, height, time)
	_draw_floodlight(width, height, open, time)
	_draw_pod_frame(width, height, open, time)
	_draw_warden(width, height, open, time)
	_draw_dust(width, height, time, open)
	_draw_lens_artifacts(width, height, open, time)


func _draw_ground(width: float, height: float, time: float) -> void:
	var horizon := height * 0.62
	var top := UIPalette.darken(_sky, 0.06)
	var mid := UIPalette.mix(_sky, _danger, 0.18)
	_draw_vertical_gradient(Rect2(0.0, 0.0, width, horizon), top, mid, 38)
	_draw_vertical_gradient(Rect2(0.0, horizon, width, height - horizon), UIPalette.mix(_sky, UIPalette.ink, 0.35), UIPalette.alpha(UIPalette.ink, 0.98), 26)
	# Runway light strips leading away from the pod.
	for i in 7:
		var t := float(i) / 6.0
		var y := horizon + height * (0.02 + t * 0.25)
		var strip_width := width * (0.10 + t * 0.28)
		var alpha := 0.08 * (1.0 - t) * (0.7 + 0.3 * sin(time * 1.4 + t * 4.0))
		draw_rect(Rect2(width * 0.5 - strip_width * 0.5, y, strip_width, 2.0), UIPalette.alpha(_danger, alpha))
	# Ground haze.
	for i in 10:
		var t := float(i) / 9.0
		var y := horizon + height * (0.01 + t * 0.22)
		draw_rect(Rect2(0.0, y, width, height * 0.012), UIPalette.alpha(_danger, 0.02 + 0.02 * (1.0 - t)))


func _draw_floodlight(width: float, height: float, open: float, time: float) -> void:
	var center_x := width * 0.5
	var ground := height * 0.78
	var half := width * lerpf(0.012, 0.085, open)
	var top := height * 0.10
	# Light volume, drawn as stacked translucent wedges.
	for layer in range(6, 0, -1):
		var layer_half := half * float(layer) / 6.0
		var alpha := 0.012 + 0.008 * (1.0 - float(layer) / 6.0)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(center_x - layer_half * 0.35, top),
				Vector2(center_x + layer_half * 0.35, top),
				Vector2(center_x + layer_half * 2.0, ground),
				Vector2(center_x - layer_half * 2.0, ground),
			]),
			UIPalette.alpha(UIPalette.mix(_accent, UIPalette.ivory, 0.35), alpha * 6.0)
		)
	var core := UIPalette.alpha(UIPalette.mix(_accent, UIPalette.ivory, 0.6), 0.55 * open)
	draw_rect(Rect2(center_x - half * 0.22, top, half * 0.44, ground - top), core)
	draw_circle(Vector2(center_x, ground - height * 0.04), half * 1.6, UIPalette.alpha(_accent, 0.10 * open))
	_draw_glow(Vector2(center_x, ground - height * 0.05), half * 4.0, UIPalette.alpha(_danger, 0.22 * open), 16, 0.5)
	# Volumetric dust in the beam.
	for i in 18:
		var t := float(i) / 17.0
		var drift := fposmod(time * (0.03 + t * 0.05) + t, 1.0)
		var x := center_x + (t - 0.5) * half * 3.2 + sin(time + t * 8.0) * 6.0
		var y := lerpf(ground, top, drift)
		draw_circle(Vector2(x, y), 1.2 + 1.8 * (1.0 - t), UIPalette.alpha(UIPalette.ivory, 0.06 * open))


func _draw_pod_frame(width: float, height: float, open: float, time: float) -> void:
	var hull := UIPalette.alpha(UIPalette.ink, 0.96)
	var inner := UIPalette.mix(UIPalette.ink, _danger, 0.06)
	var edge := UIPalette.alpha(_danger, 0.55)
	var door_half := width * lerpf(0.10, 0.26, open)
	# Two door slabs slide apart, leaving the floodlit exit between them.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0, 0), Vector2(width * 0.5 - door_half, height * 0.12),
			Vector2(width * 0.5 - door_half * 0.82, height * 0.86), Vector2(0, height),
		]),
		hull
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(width, 0), Vector2(width * 0.5 + door_half, height * 0.12),
			Vector2(width * 0.5 + door_half * 0.82, height * 0.86), Vector2(width, height),
		]),
		hull
	)
	# Inner faces catch the floodlight.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(width * 0.5 - door_half, height * 0.12),
			Vector2(width * 0.5 - door_half - width * 0.055, height * 0.16),
			Vector2(width * 0.5 - door_half * 0.82 - width * 0.04, height * 0.84),
			Vector2(width * 0.5 - door_half * 0.82, height * 0.86),
		]),
		inner
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(width * 0.5 + door_half, height * 0.12),
			Vector2(width * 0.5 + door_half + width * 0.055, height * 0.16),
			Vector2(width * 0.5 + door_half * 0.82 + width * 0.04, height * 0.84),
			Vector2(width * 0.5 + door_half * 0.82, height * 0.86),
		]),
		inner
	)
	for side_value in [-1.0, 1.0]:
		var side := float(side_value)
		var x := width * 0.5 + door_half * side
		var inner_x := width * 0.5 + (door_half + width * 0.055) * side
		draw_line(Vector2(x, height * 0.12), Vector2(x * 0.994 + width * 0.003, height * 0.86), edge, 2.0)
		draw_line(Vector2(inner_x, height * 0.16), Vector2(inner_x * 0.993 + width * 0.004, height * 0.84), UIPalette.alpha(UIPalette.ivory, 0.12), 1.0)
		# Hazard stripes along the inner face.
		for stripe in 5:
			var t := 0.20 + float(stripe) * 0.12
			var y0 := height * lerpf(0.12, 0.86, t)
			var y1 := y0 + height * 0.035
			var x0 := lerpf(x, inner_x, 0.25)
			var x1 := lerpf(x, inner_x, 0.95)
			draw_line(Vector2(x0, y0), Vector2(x1, y1), UIPalette.alpha(_danger, 0.16), 2.0)
	# Top gantry beam.
	draw_rect(Rect2(width * 0.18, height * 0.055, width * 0.64, height * 0.045), hull)
	draw_line(Vector2(width * 0.22, height * 0.098), Vector2(width * 0.78, height * 0.098), UIPalette.alpha(_accent, 0.18), 1.0)
	for i in 9:
		var t := float(i) / 8.0
		draw_circle(Vector2(width * lerpf(0.20, 0.80, t), height * 0.078), 1.5, UIPalette.alpha(_danger, 0.3))
	# Overhead lamp.
	draw_circle(Vector2(width * 0.5, height * 0.083), 14.0, UIPalette.alpha(_accent, 0.16 * open))
	draw_circle(Vector2(width * 0.5, height * 0.083), 4.0, UIPalette.alpha(UIPalette.ivory, 0.7 * open))
	# Ramp foreground with weathering.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(width * 0.30, height), Vector2(width * 0.70, height),
			Vector2(width * 0.59, height * 0.88), Vector2(width * 0.41, height * 0.88),
		]),
		UIPalette.alpha(UIPalette.ink, 0.75)
	)
	for i in 6:
		var t := float(i) / 5.0
		draw_line(
			Vector2(width * lerpf(0.31, 0.69, t), height),
			Vector2(width * lerpf(0.41, 0.59, t), height * 0.885),
			UIPalette.alpha(UIPalette.line, 0.25),
			1.0
		)
	# Wind-blown grit at the threshold.
	for i in 12:
		var t := float(i) / 11.0
		var x := width * 0.5 + sin(t * 20.0 + time * 2.0) * width * 0.16
		var y := height * lerpf(0.82, 0.78, t)
		draw_circle(Vector2(x, y), 1.0, UIPalette.alpha(_danger, 0.12))


func _draw_warden(width: float, height: float, open: float, time: float) -> void:
	var ground := height * 0.795
	var scale := height * 0.30
	var center := Vector2(width * 0.5, ground)
	# Silhouette grows into frame as the light comes up.
	var rise := _ease_out(clampf((open - 0.15) / 0.85, 0.0, 1.0))
	scale *= lerpf(0.82, 1.0, rise)
	var body := UIPalette.alpha(UIPalette.ink, 0.94)
	var rim := UIPalette.alpha(UIPalette.mix(_accent, UIPalette.ivory, 0.45), 0.8)
	var accent := UIPalette.alpha(_accent, 0.9)
	var p := func(nx: float, ny: float) -> Vector2:
		return center + Vector2(nx * scale, -ny * scale)
	# Legs.
	draw_colored_polygon(PackedVector2Array([p.call(-0.16, 0.0), p.call(-0.03, 0.0), p.call(-0.05, 0.40), p.call(-0.17, 0.40)]), body)
	draw_colored_polygon(PackedVector2Array([p.call(0.03, 0.0), p.call(0.16, 0.0), p.call(0.17, 0.40), p.call(0.05, 0.40)]), body)
	# Torso and head.
	draw_colored_polygon(
		PackedVector2Array([
			p.call(-0.15, 0.36), p.call(0.15, 0.36), p.call(0.19, 0.66),
			p.call(0.12, 0.76), p.call(-0.12, 0.76), p.call(-0.19, 0.66),
		]),
		body
	)
	draw_colored_polygon(
		PackedVector2Array([p.call(-0.08, 0.75), p.call(0.08, 0.75), p.call(0.075, 0.88), p.call(-0.075, 0.88)]),
		body
	)
	# Rim light on the exit side.
	draw_line(p.call(0.15, 0.38), p.call(0.19, 0.66), rim, 2.0)
	draw_line(p.call(0.19, 0.66), p.call(0.12, 0.76), rim, 1.6)
	draw_line(p.call(0.08, 0.75), p.call(0.075, 0.88), rim, 1.4)
	draw_line(p.call(0.16, 0.04), p.call(0.17, 0.38), UIPalette.alpha(UIPalette.ivory, 0.25), 1.2)
	# Visor and chest light.
	draw_rect(Rect2(p.call(-0.055, 0.83), Vector2(scale * 0.11, scale * 0.02)), accent)
	draw_circle(p.call(0.0, 0.60), scale * 0.024, accent)
	draw_circle(p.call(0.0, 0.60), scale * 0.06, UIPalette.alpha(_accent, 0.16))
	# Rifle held low across the body.
	draw_line(p.call(-0.24, 0.40), p.call(0.30, 0.52), UIPalette.alpha(UIPalette.ink, 0.98), scale * 0.045)
	draw_line(p.call(-0.19, 0.415), p.call(0.22, 0.505), UIPalette.alpha(_accent, 0.28), scale * 0.008)
	draw_circle(p.call(0.24, 0.505), scale * 0.018, UIPalette.alpha(_danger, 0.7))
	# Shoulder pauldrons.
	draw_circle(p.call(-0.17, 0.70), scale * 0.045, body)
	# Shadow pooling under the boots.
	draw_set_transform(Vector2(center.x, center.y + 4.0), 0.0, Vector2(3.0, 0.32))
	draw_circle(Vector2.ZERO, scale * 0.24, UIPalette.alpha(UIPalette.ink, 0.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Driftling companion arcs out of the pod.
	var drone_t := clampf((time - 0.45) / 1.2, 0.0, 1.0)
	var drone_pos := center + Vector2(scale * (0.34 + 0.22 * drone_t), -scale * (0.78 + 0.18 * sin(drone_t * PI)))
	draw_circle(drone_pos, scale * 0.045, UIPalette.alpha(_accent, 0.55 * drone_t))
	draw_circle(drone_pos, scale * 0.018, UIPalette.alpha(UIPalette.ivory, 0.85 * drone_t))


func _draw_dust(width: float, height: float, time: float, open: float) -> void:
	for mote in _dust:
		var pos: Vector2 = mote.pos
		var x := fposmod(float(pos.x) + sin(time * 0.5 + float(mote.phase)) * 0.05, 1.0) * width
		var y := float(pos.y) * height - fposmod(time * float(mote.speed) * 0.25, 1.0) * height * 0.18
		draw_circle(Vector2(x, y), float(mote.size), UIPalette.alpha(_danger, float(mote.alpha) * open))
	# Expanding shockwave rings at the ramp.
	for ring in 2:
		var t := fposmod(time * 0.45 + float(ring) * 0.5, 1.0)
		var radius := width * (0.05 + t * 0.24)
		draw_set_transform(Vector2(width * 0.5, height * 0.81), 0.0, Vector2(2.4, 0.28))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, UIPalette.alpha(_danger, 0.16 * (1.0 - t) * open), 1.6, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_lens_artifacts(width: float, height: float, open: float, time: float) -> void:
	var center := Vector2(width * 0.5, height * 0.44)
	for i in 4:
		var offset := Vector2(sin(time * 0.3 + float(i) * 1.7), cos(time * 0.24 + float(i) * 2.1)) * width * (0.06 + float(i) * 0.05)
		draw_circle(center + offset, width * (0.02 + float(i) * 0.014), UIPalette.alpha(_accent, 0.028 * open))
	# Horizontal anamorphic flare, faded at both ends so it reads as lens light
	# rather than a UI separator.
	var flare_alpha := 0.18 * open * (0.7 + 0.3 * sin(time * 2.0))
	var flare_color := UIPalette.alpha(UIPalette.mix(_accent, UIPalette.ivory, 0.4), flare_alpha)
	_draw_fade_line(Vector2(0.0, center.y), Vector2(width, center.y), flare_color, 1.4, 30)
	_draw_fade_line(
		Vector2(width * 0.12, center.y),
		Vector2(width * 0.88, center.y),
		UIPalette.alpha(_accent, flare_alpha * 0.22),
		7.0,
		24
	)


func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)
