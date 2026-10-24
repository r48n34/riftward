class_name UIHudEdge
extends Control
## Full-screen edge feedback: low-health vignette, incoming-damage flash and
## shield-break tint. Purely decorative, driven by HUD vitals.

var health_ratio := 1.0
var damage_flash := 0.0
var shield_flash := 0.0
var _pulse := 0.0
var _active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)


func set_health_ratio(ratio: float) -> void:
	health_ratio = clampf(ratio, 0.0, 1.0)
	_refresh_processing()
	queue_redraw()


func flash_damage(strength: float = 0.7) -> void:
	damage_flash = maxf(damage_flash, clampf(strength, 0.0, 1.0))
	_refresh_processing()


func flash_shield(strength: float = 0.6) -> void:
	shield_flash = maxf(shield_flash, clampf(strength, 0.0, 1.0))
	_refresh_processing()


func _refresh_processing() -> void:
	var should_process := damage_flash > 0.0 or shield_flash > 0.0 or (health_ratio < 0.35 and not UIPalette.reduce_motion)
	if should_process != _active:
		_active = should_process
		set_process(should_process)
	queue_redraw()


func _process(delta: float) -> void:
	if damage_flash > 0.0:
		damage_flash = maxf(0.0, damage_flash - delta * 3.4)
	if shield_flash > 0.0:
		shield_flash = maxf(0.0, shield_flash - delta * 3.0)
	_pulse += delta
	_refresh_processing()
	queue_redraw()


func _draw() -> void:
	var width := size.x
	var height := size.y
	if width < 10.0:
		return
	var low_health := clampf((0.35 - health_ratio) / 0.35, 0.0, 1.0)
	var pulse := 0.75 + 0.25 * sin(_pulse * 4.2) if not UIPalette.reduce_motion else 1.0
	var red_alpha := maxf(damage_flash * 0.36, low_health * 0.26 * pulse)
	if red_alpha > 0.005:
		_draw_edge_bands(width, height, UIPalette.danger, red_alpha)
	if shield_flash > 0.005:
		_draw_edge_bands(width, height, UIPalette.blue, shield_flash * 0.4)


func _draw_edge_bands(width: float, height: float, color: Color, strength: float) -> void:
	var bands := 10
	var thickness := minf(height * 0.10, 92.0)
	for i in bands:
		var t := float(i) / float(bands)
		var alpha := strength * (1.0 - t) * (1.0 - t)
		var inset := thickness * t
		var band_color := UIPalette.alpha(color, alpha)
		# Top and bottom
		draw_rect(Rect2(0.0, inset, width, thickness / bands + 1.0), band_color)
		draw_rect(Rect2(0.0, height - inset - thickness / bands - 1.0, width, thickness / bands + 1.0), band_color)
		# Left and right
		var side_thickness := minf(width * 0.09, 120.0)
		var side_inset := side_thickness * t
		draw_rect(Rect2(side_inset, 0.0, side_thickness / bands + 1.0, height), band_color)
		draw_rect(Rect2(width - side_inset - side_thickness / bands - 1.0, 0.0, side_thickness / bands + 1.0, height), band_color)
