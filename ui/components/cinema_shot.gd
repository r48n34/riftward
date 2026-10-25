class_name UICinemaShot
extends Control
## Base class for one shot in the loading cinema. Shots are code-drawn Control
## overlays: cheap, asset-free, deterministic, and testable in isolation.
##
## A shot only redraws while it is the active shot (and only when motion is
## allowed), so the loading screen never pays for invisible art. Static mode
## freezes the composition at `static_pose_time` for reduce-motion, skip and
## screenshots.

## Unique id used by the loading director and tests.
var shot_id: StringName = &""
## Normalised deployment progress, set by the loading director.
var progress := 0.0
## Freeze animation and draw the representative pose.
var static_frame := false
## Animation time used for the frozen pose.
var static_pose_time := 1.6
## Redraw budget: cinematic footage at 30 fps is plenty and keeps the generated
## terrain thread breathing during loading.
var redraw_hz := 30.0

var _local_time := 0.0
var _active := false
var _redraw_accum := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_apply_motion_state()
	_on_shot_ready()


## Subclasses override to build labels/hosts or prime cached data.
func _on_shot_ready() -> void:
	pass


## Set by the director whenever the shot becomes/ceases to be the on-screen act.
func set_active(is_active: bool) -> void:
	_active = is_active
	visible = is_active
	if is_active:
		_local_time = 0.0
		_redraw_accum = 0.0
		queue_redraw()
	_apply_motion_state()


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)


func set_static_frame(is_static: bool) -> void:
	static_frame = is_static
	_apply_motion_state()
	queue_redraw()


## Re-run the local animation clock (reactivation, screenshots).
func restart() -> void:
	_local_time = 0.0
	_redraw_accum = 0.0
	queue_redraw()


func get_shot_id() -> StringName:
	return shot_id


func get_local_time() -> float:
	return _local_time


func is_shot_active() -> bool:
	return _active


## True when the shot is drawing its frozen pose.
func is_frozen() -> bool:
	return static_frame or UIPalette.reduce_motion


func _apply_motion_state() -> void:
	var animate := _active and not is_frozen()
	set_process(animate)


func _process(delta: float) -> void:
	if not _active or is_frozen():
		return
	_local_time += delta
	_redraw_accum += delta
	var interval := 1.0 / maxf(1.0, redraw_hz)
	if _redraw_accum >= interval:
		_redraw_accum = 0.0
		queue_redraw()


## Time value subclasses should draw with. Frozen shots get a composed pose.
func draw_time() -> float:
	return static_pose_time if is_frozen() else _local_time


# ---------------------------------------------------------------------------
# Small shared drawing helpers
# ---------------------------------------------------------------------------

func _seed_rng(salt: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(shot_id.hash()) ^ (salt * 7919) ^ 0x5F17A11
	return rng


func _alpha(color: Color, value: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clampf(value, 0.0, 1.0))


## Filled vertical gradient built from horizontal bands. Bands are cheap and do
## not need a texture resource (which would need cleanup on screen teardown).
func _draw_vertical_gradient(rect: Rect2, top_color: Color, bottom_color: Color, bands: int = 40) -> void:
	var count := maxi(2, bands)
	for i in count:
		var t := float(i) / float(count - 1)
		var color := top_color.lerp(bottom_color, t)
		draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * t, rect.size.x, rect.size.y / float(count) + 1.0), color)


## Soft radial glow drawn as stacked circles (no texture asset required).
func _draw_glow(center: Vector2, radius: float, color: Color, rings: int = 14, strength: float = 0.5) -> void:
	for ring in range(rings, 0, -1):
		var t := float(ring) / float(rings)
		var alpha := strength * (1.0 - t) * (1.0 - t) * 0.6
		draw_circle(center, radius * t, Color(color.r, color.g, color.b, color.a * alpha))


## Horizontal hairline with a soft fade at both ends.
func _draw_fade_line(from: Vector2, to: Vector2, color: Color, width: float = 1.0, steps: int = 24) -> void:
	var count := maxi(2, steps)
	for i in count:
		var t0 := float(i) / float(count)
		var t1 := float(i + 1) / float(count)
		var segment_alpha := sin(t0 * PI)
		draw_line(from.lerp(to, t0), from.lerp(to, t1), _alpha(color, segment_alpha), width)
