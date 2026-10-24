class_name UIHudWeapon
extends Control
## Bottom-right weapon block: name, slot, rarity, ammo and reload / grenade state.

var weapon_name := "LATTICE AR"
var weapon_slot := "PRIMARY"
var weapon_slot_label := "PRIMARY 1"
var rarity_color := Color("a7b4b6")
var ammo := 30
var reserve := 210
var mag_size := 30
var reloading := false
var reload_progress := 0.0
var grenade_name := "Frag"
var grenade_charges := 2
var melee_ready := true
var is_melee := false
var weapon_slots: Array = []
var inventory_key := "I"

var _panel_style: StyleBoxFlat = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(336, 150)
	_panel_style = UITheme._box(UIPalette.alpha(UIPalette.ink, 0.72), UIPalette.alpha(UIPalette.line, 0.85), UIPalette.R_MD, 1, Vector4(0, 0, 0, 0))
	set_process(true)


func set_weapon(data: Dictionary) -> void:
	weapon_name = String(data.get("weapon_name", weapon_name)).to_upper()
	if weapon_name.is_empty():
		weapon_name = "UNARMED"
	weapon_slot = String(data.get("weapon_slot", weapon_slot)).to_upper()
	weapon_slot_label = String(data.get("weapon_slot_label", weapon_slot)).to_upper()
	is_melee = bool(data.get("is_melee", false))
	weapon_slots = data.get("weapon_slots", [])
	inventory_key = String(data.get("inventory_key", inventory_key))
	rarity_color = data.get("rarity_color", rarity_color)
	ammo = int(data.get("ammo", ammo))
	reserve = int(data.get("reserve", reserve))
	mag_size = maxi(1, int(data.get("mag_size", mag_size)))
	reloading = bool(data.get("reloading", false))
	reload_progress = clampf(float(data.get("reload_progress", 0.0)), 0.0, 1.0)
	grenade_name = String(data.get("grenade_name", grenade_name))
	grenade_charges = int(data.get("grenade_charges", grenade_charges))
	queue_redraw()


func _process(_delta: float) -> void:
	if reloading:
		queue_redraw()


func _draw() -> void:
	var width := size.x
	var height := size.y
	if width < 40.0:
		return
	if _panel_style != null:
		_panel_style.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))

	var pad := 16.0
	var label_font := UIFonts.body(600)
	var mono_font := UIFonts.mono(true)
	var mono_regular := UIFonts.mono(false)

	# Rarity strip + slot.
	draw_rect(Rect2(pad, pad + 2.0, 3.0, 12.0), rarity_color)
	draw_string(label_font, Vector2(pad + 9.0, pad + 12.0), weapon_slot_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIPalette.muted)
	_draw_slot_rail(width, pad)
	var ammo_color := UIPalette.ivory
	if not is_melee:
		if ammo <= 0:
			ammo_color = UIPalette.danger
		elif ammo <= mag_size / 5:
			ammo_color = UIPalette.amber

	# Weapon name.
	draw_string(UIFonts.display(600), Vector2(pad + 9.0, pad + 36.0), weapon_name, HORIZONTAL_ALIGNMENT_LEFT, width - pad - 92.0, 18, UIPalette.ivory)

	# Big ammo / melee readout.
	if is_melee:
		draw_string(mono_font, Vector2(pad + 6.0, height - 30.0), "∞", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, UIPalette.mint)
		draw_string(mono_regular, Vector2(pad + 46.0, height - 32.0), "MELEE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIPalette.muted)
	else:
		var ammo_text := "%d" % ammo
		var ammo_width := font_string_width(mono_font, ammo_text, 38)
		draw_string(mono_font, Vector2(pad + 6.0, height - 30.0), ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, ammo_color)
		draw_string(mono_regular, Vector2(pad + 10.0 + ammo_width, height - 32.0), "/ %d" % reserve, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIPalette.muted)

	# Reload bar or ready tick.
	var bar_width := width - pad * 2.0 - 90.0
	var bar_rect := Rect2(pad, height - 18.0, maxf(40.0, bar_width), 4.0)
	draw_rect(bar_rect, UIPalette.alpha(UIPalette.ink, 0.9))
	if reloading:
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * reload_progress, bar_rect.size.y)), UIPalette.amber)
		draw_string(label_font, Vector2(bar_rect.end.x + 12.0, height - 8.0), "RELOADING", HORIZONTAL_ALIGNMENT_RIGHT, width - pad - (bar_rect.end.x + 12.0), 9, UIPalette.amber)
	else:
		var fill := 1.0 if is_melee else clampf(float(ammo) / float(mag_size), 0.0, 1.0)
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * fill, bar_rect.size.y)), UIPalette.alpha(UIPalette.mint, 0.75))
		draw_string(label_font, Vector2(bar_rect.end.x + 12.0, height - 8.0), "READY", HORIZONTAL_ALIGNMENT_RIGHT, width - pad - (bar_rect.end.x + 12.0), 9, UIPalette.muted)

	# Grenade chip.
	var grenade_y := height - 42.0
	var chip_rect := Rect2(width - pad - 104.0, grenade_y, 104.0, 22.0)
	draw_rect(chip_rect, UIPalette.alpha(UIPalette.surface_high, 0.85))
	draw_rect(chip_rect, UIPalette.alpha(UIPalette.line, 0.9), false, 1.0)
	var grenade_color := UIPalette.amber if grenade_charges > 0 else UIPalette.muted_dim
	draw_circle(chip_rect.position + Vector2(13.0, 11.0), 4.0, grenade_color)
	draw_string(mono_regular, Vector2(chip_rect.position.x + 22.0, chip_rect.position.y + 15.0), grenade_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 60.0, 9, UIPalette.ivory)
	draw_string(mono_font, Vector2(chip_rect.position.x + 88.0, chip_rect.position.y + 15.0), "x%d" % grenade_charges, HORIZONTAL_ALIGNMENT_RIGHT, 12.0, 10, grenade_color)


func _draw_slot_rail(width: float, pad: float) -> void:
	var count := maxi(4, weapon_slots.size())
	var chip_w := 20.0
	var gap := 3.0
	var start_x := width - pad - float(count) * chip_w - float(count - 1) * gap
	var y := pad - 2.0
	var label_font := UIFonts.mono(true)
	for i in count:
		var active := false
		if i < weapon_slots.size() and weapon_slots[i] is Dictionary:
			active = bool((weapon_slots[i] as Dictionary).get("active", false))
		var rect := Rect2(start_x + float(i) * (chip_w + gap), y, chip_w, 14.0)
		draw_rect(rect, UIPalette.alpha(UIPalette.ink, 0.85))
		draw_rect(rect, UIPalette.alpha(UIPalette.mint if active else UIPalette.line, 0.9), false, 1.0)
		draw_string(
			label_font,
			Vector2(rect.position.x + 7.0, rect.position.y + 11.0),
			str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			9,
			UIPalette.mint if active else UIPalette.muted
		)


func font_string_width(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
