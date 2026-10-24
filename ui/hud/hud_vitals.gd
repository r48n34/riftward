class_name UIHudVitals
extends Control
## Bottom-left health and shield readout with low-health urgency.

var health := 100.0
var max_health := 100.0
var shield := 50.0
var max_shield := 50.0
var armor := 0.0
var shield_regen_delay := 0.0

var _panel_style: StyleBoxFlat = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(330, 108)
	_panel_style = UITheme._box(UIPalette.alpha(UIPalette.ink, 0.72), UIPalette.alpha(UIPalette.line, 0.85), UIPalette.R_MD, 1, Vector4(0, 0, 0, 0))


func set_values(new_health: float, new_max_health: float, new_shield: float, new_max_shield: float, new_armor: float = 0.0) -> void:
	health = maxf(0.0, new_health)
	max_health = maxf(1.0, new_max_health)
	shield = maxf(0.0, new_shield)
	max_shield = maxf(1.0, new_max_shield)
	armor = new_armor
	queue_redraw()


func _draw() -> void:
	var width := size.x
	var height := size.y
	if width < 40.0:
		return
	if _panel_style != null:
		_panel_style.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))

	var font := UIFonts.mono(true)
	var label_font := UIFonts.body(600)
	var pad := 16.0
	var health_ratio := clampf(health / max_health, 0.0, 1.0)
	var shield_ratio := clampf(shield / max_shield, 0.0, 1.0) if max_shield > 0.0 else 0.0

	# Header.
	draw_string(label_font, Vector2(pad, pad + 9.0), "WARDEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIPalette.muted)
	if armor > 0.0:
		draw_string(label_font, Vector2(0.0, pad + 9.0), "ARMOR %d" % int(armor), HORIZONTAL_ALIGNMENT_RIGHT, width - pad, 10, UIPalette.muted)

	# Shield bar.
	var shield_y := pad + 18.0
	var bar_width := width - pad * 2.0
	draw_string(UIFonts.body(500), Vector2(pad, shield_y + 10.0), "SHIELD", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIPalette.blue)
	draw_string(font, Vector2(0.0, shield_y + 11.0), "%d / %d" % [int(ceil(shield)), int(max_shield)], HORIZONTAL_ALIGNMENT_RIGHT, width - pad, 11, UIPalette.ivory)
	draw_rect(Rect2(pad, shield_y + 15.0, bar_width, 5.0), UIPalette.alpha(UIPalette.ink, 0.9))
	draw_rect(Rect2(pad, shield_y + 15.0, bar_width * shield_ratio, 5.0), UIPalette.blue)
	draw_line(Vector2(pad, shield_y + 15.0), Vector2(pad + bar_width * shield_ratio, shield_y + 15.0), UIPalette.alpha(UIPalette.ivory, 0.5), 1.0)

	# Health bar (bigger, colour shifts with danger).
	var health_y := shield_y + 28.0
	var health_color := UIPalette.mint
	if health_ratio <= 0.25:
		health_color = UIPalette.danger
	elif health_ratio <= 0.5:
		health_color = UIPalette.amber
	var pulse := 1.0
	if health_ratio <= 0.25 and not UIPalette.reduce_motion:
		pulse = 0.72 + 0.28 * absf(sin(Time.get_ticks_msec() * 0.004))
	health_color = UIPalette.alpha(health_color, pulse)
	draw_string(UIFonts.body(500), Vector2(pad, health_y + 12.0), "HEALTH", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIPalette.muted)
	draw_string(font, Vector2(0.0, health_y + 22.0), "%d" % int(ceil(health)), HORIZONTAL_ALIGNMENT_RIGHT, width - pad, 24, health_color)
	draw_rect(Rect2(pad, height - 20.0, bar_width, 9.0), UIPalette.alpha(UIPalette.ink, 0.9))
	draw_rect(Rect2(pad, height - 20.0, bar_width * health_ratio, 9.0), health_color)
	draw_line(Vector2(pad, height - 20.0), Vector2(pad + bar_width * health_ratio, height - 20.0), UIPalette.alpha(UIPalette.ivory, 0.35), 1.0)
