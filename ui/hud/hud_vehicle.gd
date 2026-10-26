class_name UIVehiclePanel
extends Control
## Code-drawn rideable HUD: an arc speed dial with a needle, the vehicle name and
## kind, a hull bar, a boost/stamina bar and the current gear/gait.
##
## Instantiated by DeploymentHud (Lead hook). Contract:
##   configure(snapshot)      first show and re-configure
##   update_snapshot(snapshot)  ~10 Hz while riding
##   show_panel() / hide_panel()
##   get_snapshot() / is_visible_panel()
## The panel starts hidden; configure() only stores data.

const PANEL_SIZE := Vector2(336.0, 142.0)
const DIAL_RADIUS := 45.0
const DIAL_START := deg_to_rad(140.0)
const DIAL_END := deg_to_rad(400.0)

var _snapshot: Dictionary = {}
var _accent: Color = Color("62e6c3")
var _displayed_kph: float = 0.0
var _panel_style: StyleBoxFlat = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = PANEL_SIZE
	if size.x < 2.0:
		size = PANEL_SIZE
	_panel_style = UITheme._box(
		UIPalette.alpha(UIPalette.ink, 0.82),
		UIPalette.alpha(UIPalette.line, 0.9),
		UIPalette.R_MD,
		1,
		Vector4(14.0, 12.0, 14.0, 12.0)
	)
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	var target := clampf(float(_snapshot.get("speed_kph", 0.0)), 0.0, 999.0)
	_displayed_kph = lerpf(_displayed_kph, target, clampf(delta * 8.0, 0.0, 1.0))
	if absf(_displayed_kph - target) < 0.4:
		_displayed_kph = target
	queue_redraw()


# --- public API ------------------------------------------------------------


func configure(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true) if snapshot != null else {}
	_accent = _resolve_accent(snapshot)
	_displayed_kph = float(_snapshot.get("speed_kph", 0.0))
	queue_redraw()


func update_snapshot(snapshot: Dictionary) -> void:
	if snapshot == null:
		return
	_snapshot = snapshot.duplicate(true)
	_accent = _resolve_accent(snapshot)
	queue_redraw()


func show_panel() -> void:
	visible = true
	queue_redraw()


func hide_panel() -> void:
	visible = false


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func is_visible_panel() -> bool:
	return visible


func get_accent() -> Color:
	return _accent


func _resolve_accent(snapshot: Dictionary) -> Color:
	if snapshot == null:
		return UIPalette.mint
	var raw: Variant = snapshot.get("accent", UIPalette.mint)
	if raw is Color:
		return raw as Color
	return UIPalette.mint


# --- drawing ---------------------------------------------------------------


func _draw() -> void:
	var width := size.x
	var height := size.y
	if width < 64.0 or height < 48.0:
		return
	if _panel_style != null:
		_panel_style.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	if _snapshot.is_empty():
		return
	var mono := UIFonts.mono(true)
	var mono_small := UIFonts.mono(false)
	var body := UIFonts.body(600)
	var body_small := UIFonts.body(500)
	if mono == null or body == null:
		return
	_draw_dial(mono, body_small)
	_draw_readout(mono, mono_small, body, body_small)


func _draw_dial(mono: Font, label_font: Font) -> void:
	var center := Vector2(66.0, 72.0)
	var max_kph := maxf(10.0, float(_snapshot.get("max_speed_kph", 120.0)))
	var fraction := clampf(_displayed_kph / max_kph, 0.0, 1.0)
	# Dial bed and ticks.
	draw_arc(center, DIAL_RADIUS, DIAL_START, DIAL_END, 44, UIPalette.alpha(UIPalette.line, 0.85), 6.0, true)
	draw_arc(center, DIAL_RADIUS - 8.0, DIAL_START, DIAL_END, 44, UIPalette.alpha(UIPalette.ink_deep, 0.55), 3.0, true)
	for tick in 11:
		var tick_fraction := float(tick) / 10.0
		var angle := lerpf(DIAL_START, DIAL_END, tick_fraction)
		var direction := Vector2(cos(angle), sin(angle))
		var inner := center + direction * (DIAL_RADIUS - 10.0)
		var outer := center + direction * (DIAL_RADIUS - 3.0)
		var tick_color := UIPalette.alpha(_accent if tick_fraction <= fraction else UIPalette.muted_dim, 0.9)
		draw_line(inner, outer, tick_color, 1.5, true)
	# Filled arc up to the current speed.
	if fraction > 0.001:
		draw_arc(center, DIAL_RADIUS, DIAL_START, lerpf(DIAL_START, DIAL_END, fraction), 44, _accent, 6.0, true)
	# Needle.
	var needle_angle := lerpf(DIAL_START, DIAL_END, fraction)
	var needle_direction := Vector2(cos(needle_angle), sin(needle_angle))
	draw_line(center, center + needle_direction * (DIAL_RADIUS - 14.0), UIPalette.ivory, 2.4, true)
	draw_circle(center, 4.5, _accent)
	draw_circle(center, 2.0, UIPalette.ink_deep)
	# Speed number + unit.
	var speed_text := "%d" % int(round(_displayed_kph))
	draw_string(mono, center + Vector2(-56.0, 22.0), speed_text, HORIZONTAL_ALIGNMENT_CENTER, 112.0, 24, UIPalette.ivory)
	draw_string(label_font, center + Vector2(-56.0, 38.0), "KM/H", HORIZONTAL_ALIGNMENT_CENTER, 112.0, 9, UIPalette.muted)


func _draw_readout(mono: Font, mono_small: Font, body: Font, body_small: Font) -> void:
	var left := 128.0
	var right := size.x - 14.0
	var bar_width := maxf(80.0, right - left)
	var name := String(_snapshot.get("name", "Vehicle")).to_upper()
	draw_string(body, Vector2(left, 24.0), name, HORIZONTAL_ALIGNMENT_LEFT, bar_width, 15, _accent)
	# Kind + gear/gait line.
	var kind := String(_snapshot.get("kind", "ground")).to_upper()
	var mode := "GEAR %d" % int(_snapshot.get("gear", 1))
	if kind == "BEAST":
		mode = "GAIT %s" % String(_snapshot.get("gait", "idle")).to_upper()
	elif kind == "AIR":
		mode = "THROTTLE"
	draw_string(body_small, Vector2(left, 39.0), kind, HORIZONTAL_ALIGNMENT_LEFT, 70.0, 10, UIPalette.muted)
	draw_string(mono_small, Vector2(left + 74.0, 39.0), mode, HORIZONTAL_ALIGNMENT_RIGHT, bar_width - 74.0, 10, UIPalette.muted)

	# Hull bar.
	var health := maxf(0.0, float(_snapshot.get("health", 1.0)))
	var max_health := maxf(1.0, float(_snapshot.get("max_health", 1.0)))
	var hull_ratio := clampf(health / max_health, 0.0, 1.0)
	var hull_color := UIPalette.mint
	if hull_ratio <= 0.25:
		hull_color = UIPalette.danger
	elif hull_ratio <= 0.55:
		hull_color = UIPalette.amber
	draw_string(body_small, Vector2(left, 54.0), "HULL", HORIZONTAL_ALIGNMENT_LEFT, 60.0, 9, UIPalette.muted)
	draw_string(mono_small, Vector2(left, 54.0), "%d / %d" % [int(ceil(health)), int(ceil(max_health))], HORIZONTAL_ALIGNMENT_RIGHT, bar_width, 9, UIPalette.ivory)
	draw_rect(Rect2(left, 58.0, bar_width, 6.0), UIPalette.alpha(UIPalette.ink_deep, 0.9))
	draw_rect(Rect2(left, 58.0, bar_width * hull_ratio, 6.0), hull_color)
	draw_line(Vector2(left, 58.0), Vector2(left + bar_width * hull_ratio, 58.0), UIPalette.alpha(UIPalette.ivory, 0.4), 1.0)

	# Boost / stamina bar.
	var boost := clampf(float(_snapshot.get("boost", 1.0)), 0.0, 1.0)
	var boost_label := "STAMINA" if kind == "BEAST" else "BOOST"
	draw_string(body_small, Vector2(left, 76.0), boost_label, HORIZONTAL_ALIGNMENT_LEFT, 70.0, 9, UIPalette.muted)
	draw_string(mono_small, Vector2(left, 76.0), "%d%%" % int(round(boost * 100.0)), HORIZONTAL_ALIGNMENT_RIGHT, bar_width, 9, _accent)
	draw_rect(Rect2(left, 80.0, bar_width, 4.0), UIPalette.alpha(UIPalette.ink_deep, 0.9))
	draw_rect(Rect2(left, 80.0, bar_width * boost, 4.0), UIPalette.alpha(_accent, 0.9))

	# Status chips: weapon lock, occupied, wrecked, docked.
	var status := ""
	var status_color := UIPalette.amber
	if bool(_snapshot.get("destroyed", false)):
		status = "WRECKED"
		status_color = UIPalette.danger
	elif bool(_snapshot.get("docked", false)):
		status = "DOCKED"
		status_color = UIPalette.mint
	elif bool(_snapshot.get("weapon_locked", false)):
		status = "WEAPONS LOCKED"
		status_color = UIPalette.amber
	if not status.is_empty():
		draw_string(mono_small, Vector2(left, size.y - 12.0), status, HORIZONTAL_ALIGNMENT_LEFT, bar_width, 10, status_color)
	else:
		var speed_ratio := clampf(_displayed_kph / maxf(10.0, float(_snapshot.get("max_speed_kph", 120.0))), 0.0, 1.0)
		draw_string(mono_small, Vector2(left, size.y - 12.0), "MAX %d KM/H" % int(round(float(_snapshot.get("max_speed_kph", 0.0)))), HORIZONTAL_ALIGNMENT_LEFT, bar_width, 9, UIPalette.muted_dim)
		draw_rect(Rect2(right - 34.0, size.y - 18.0, 34.0 * speed_ratio, 3.0), UIPalette.alpha(_accent, 0.6))
