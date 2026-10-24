class_name UIHudAbilities
extends Control
## Bottom-centre ability tray: two actives plus the discipline ultimate with
## cooldown sweeps, charges and key hints.

var abilities: Array = []

const KEY_HINTS := ["Q", "F", "X"]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(360, 104)


func set_abilities(new_abilities: Array) -> void:
	abilities = new_abilities
	visible = not abilities.is_empty()
	queue_redraw()


func _draw() -> void:
	if abilities.is_empty():
		return
	var width := size.x
	var height := size.y
	var count := mini(abilities.size(), 3)
	var chip := 54.0
	var gap := 12.0
	var total := float(count) * chip + float(maxi(0, count - 1)) * gap
	var start_x := (width - total) * 0.5
	var chip_y := height - chip - 18.0

	for index in count:
		var ability: Dictionary = abilities[index]
		var x := start_x + float(index) * (chip + gap)
		var is_ultimate := bool(ability.get("is_ultimate", false))
		var chip_size := chip + (6.0 if is_ultimate else 0.0)
		var rect := Rect2(Vector2(x, chip_y - (chip_size - chip)), Vector2(chip_size, chip_size))
		var cooldown := maxf(0.0, float(ability.get("cooldown", 0.0)))
		var cooldown_total := maxf(0.001, float(ability.get("cooldown_total", cooldown)))
		var ready := bool(ability.get("ready", cooldown <= 0.0))
		var accent := UIPalette.amber if is_ultimate else UIPalette.mint
		if not ready:
			accent = UIPalette.muted_dim

		# Chip body.
		draw_rect(rect, UIPalette.alpha(UIPalette.ink, 0.78))
		draw_rect(rect, UIPalette.alpha(accent, 0.85 if ready else 0.45), false, 1.5 if ready else 1.0)
		if is_ultimate:
			draw_rect(rect.grow(2.0), UIPalette.alpha(UIPalette.amber, 0.35), false, 1.0)

		# Icon.
		var icon_name: StringName = ability.get("icon", &"bolt")
		var texture := UIIcons.get_icon(UIIcons.ability_icon(icon_name))
		if texture != null:
			var icon_size := 22.0 if not is_ultimate else 26.0
			var icon_rect := Rect2(rect.position + (rect.size - Vector2(icon_size, icon_size)) * 0.5, Vector2(icon_size, icon_size))
			var tint := UIPalette.ivory if ready else UIPalette.alpha(UIPalette.muted, 0.55)
			draw_texture_rect(texture, icon_rect, false, tint)

		# Cooldown sweep (fills from the bottom up).
		if not ready and cooldown_total > 0.0:
			var ratio := clampf(cooldown / cooldown_total, 0.0, 1.0)
			var sweep_height := rect.size.y * ratio
			draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - sweep_height), Vector2(rect.size.x, sweep_height)), UIPalette.alpha(UIPalette.ink, 0.68))
			draw_string(UIFonts.mono(true), rect.position + Vector2(0.0, rect.size.y * 0.5 + 6.0), "%.0f" % ceil(cooldown), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 16, UIPalette.ivory)

		# Charges.
		var charges := int(ability.get("charges", 0))
		if charges > 1 and ready:
			draw_string(UIFonts.mono(true), rect.position + Vector2(rect.size.x - 18.0, 15.0), "x%d" % charges, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, accent)

		# Key hint.
		draw_string(UIFonts.mono(false), rect.position + Vector2(6.0, 13.0), KEY_HINTS[index] if index < KEY_HINTS.size() else "", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UIPalette.muted)
		if is_ultimate:
			draw_string(UIFonts.body(600), rect.position + Vector2(6.0, rect.size.y - 6.0), "ULT", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIPalette.amber)

		# Label.
		var name_text := String(ability.get("name", "")).to_upper()
		draw_string(UIFonts.body(600), Vector2(x - 14.0, height - 3.0), name_text, HORIZONTAL_ALIGNMENT_CENTER, chip_size + 28.0, 9, UIPalette.ivory if ready else UIPalette.muted_dim)
