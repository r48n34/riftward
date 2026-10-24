class_name UIHudDamageNumbers
extends Control
## Floating damage numbers. Gameplay calls show_number() with a world position;
## the HUD projects it through the active 3D camera.

var numbers: Array = []
var enabled := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)


func show_number(screen_position: Vector2, amount: int, crit: bool = false, killed: bool = false) -> void:
	if not enabled or amount <= 0:
		return
	numbers.append({
		"pos": screen_position + Vector2(randf_range(-8.0, 8.0), randf_range(-4.0, 4.0)),
		"text": str(amount),
		"age": 0.0,
		"crit": crit,
		"killed": killed,
	})
	if numbers.size() > 24:
		numbers.pop_front()
	set_process(true)
	queue_redraw()


func clear_numbers() -> void:
	numbers.clear()
	queue_redraw()
	set_process(false)


func _process(delta: float) -> void:
	var expired: Array = []
	for index in numbers.size():
		var number: Dictionary = numbers[index]
		number.age = float(number.age) + delta
		number.pos = Vector2(number.pos) + Vector2(0.0, -34.0 * delta)
		if float(number.age) > 0.85:
			expired.append(index)
	for index in range(expired.size() - 1, -1, -1):
		numbers.remove_at(expired[index])
	if numbers.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for number in numbers:
		var progress := clampf(float(number.age) / 0.85, 0.0, 1.0)
		var alpha := 1.0 - progress * progress
		var crit := bool(number.crit)
		var killed := bool(number.killed)
		var color := UIPalette.ivory
		var font_size := 16
		if crit:
			color = UIPalette.amber
			font_size = 20
		if killed:
			color = UIPalette.danger
			font_size = 22
		color = UIPalette.alpha(color, alpha)
		var world_pos: Vector2 = number.pos
		draw_string(UIFonts.mono(true), world_pos + Vector2(1.0, 1.0), String(number.text), HORIZONTAL_ALIGNMENT_CENTER, 60.0, font_size, UIPalette.alpha(UIPalette.ink, alpha * 0.8))
		draw_string(UIFonts.mono(true), world_pos, String(number.text), HORIZONTAL_ALIGNMENT_CENTER, 60.0, font_size, color)
