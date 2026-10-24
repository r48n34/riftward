class_name InventoryOverlay
extends Control
## Paused in-deployment inventory: four weapon slots, equipped gear and the
## run satchel. Read-only; it never mutates loadout or loot state.

var _snapshot: Dictionary = {}
var _body_host: VBoxContainer = null
var _footer: HBoxContainer = null
var _close_button: Button = null
var _weapon_rows := 0
var _loot_rows := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()
	dismiss()


func present(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true) if snapshot != null else {}
	visible = true
	_rebuild()
	if not get_tree().paused:
		UIFactory.animate_in(self)
	if _close_button != null:
		_close_button.grab_focus()


func dismiss() -> void:
	if _close_button != null and is_instance_valid(_close_button) and _close_button.has_focus():
		_close_button.release_focus()
	visible = false


func refresh() -> void:
	if visible:
		_rebuild()


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func get_weapon_row_count() -> int:
	return _weapon_rows


func get_loot_row_count() -> int:
	return _loot_rows


func _build_shell() -> void:
	var scrim := ColorRect.new()
	scrim.color = UIPalette.alpha(UIPalette.ink, 0.9)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", UIPalette.SP3)
	margin.add_theme_constant_override("margin_right", UIPalette.SP3)
	margin.add_theme_constant_override("margin_top", UIPalette.SP3)
	margin.add_theme_constant_override("margin_bottom", UIPalette.SP3)
	add_child(margin)

	var frame := UIFactory.panel("ModalPanel")
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(frame)
	var shell := UIFactory.vbox(UIPalette.SP4)
	frame.add_child(shell)

	var header := UIFactory.hbox(UIPalette.SP4)
	var glyph := UIFactory.icon_or_null(&"backpack", 28, UIPalette.mint)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(glyph)
	var title_box := UIFactory.vbox(2)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_child(UIFactory.heading("Field Inventory", "H1"))
	title_box.add_child(UIFactory.label("Loadout and satchel · gameplay paused", "BodySmall", UIPalette.muted))
	header.add_child(title_box)
	_close_button = UIFactory.secondary_button("Close", &"close")
	_close_button.custom_minimum_size = Vector2(140, 44)
	_close_button.tooltip_text = "Close the inventory and resume the deployment."
	_close_button.pressed.connect(_on_close_pressed)
	header.add_child(_close_button)
	shell.add_child(header)
	shell.add_child(UIFactory.divider(UIPalette.line_soft))

	_body_host = UIFactory.vbox(UIPalette.SP4)
	_body_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(_body_host)

	_footer = UIFactory.hbox(UIPalette.SP3)
	shell.add_child(_footer)
	_build_footer()


func _rebuild() -> void:
	if _body_host == null:
		return
	UIFactory.clear_children(_body_host)
	_weapon_rows = 0
	_loot_rows = 0
	var columns := UIFactory.hbox(UIPalette.SP4)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_host.add_child(columns)
	columns.add_child(_build_weapons_column())
	columns.add_child(UIFactory.v_divider(UIPalette.line_soft))
	columns.add_child(_build_gear_column())
	columns.add_child(UIFactory.v_divider(UIPalette.line_soft))
	columns.add_child(_build_satchel_column())
	_build_footer()


func _build_footer() -> void:
	if _footer == null:
		return
	UIFactory.clear_children(_footer)
	var key := String(_snapshot.get("inventory_key", "I"))
	_footer.add_child(UIFactory.key_hint(key))
	_footer.add_child(UIFactory.label("or", "Micro", UIPalette.muted_dim))
	_footer.add_child(UIFactory.key_hint("ESC"))
	_footer.add_child(UIFactory.label("to close", "Micro", UIPalette.muted_dim))
	_footer.add_child(UIFactory.spacer_h())
	_footer.add_child(UIFactory.label("Items in the satchel are secured only on a successful extraction.", "Micro", UIPalette.muted_dim))


func _column(title: String, icon_name: StringName, accent: Color, min_width: float, expand: bool = false) -> VBoxContainer:
	var column := UIFactory.vbox(UIPalette.SP3)
	column.custom_minimum_size.x = min_width
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if expand:
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon_or_null(icon_name, 16, accent)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(glyph)
	head.add_child(UIFactory.eyebrow(title, accent))
	column.add_child(head)
	return column


func _build_weapons_column() -> VBoxContainer:
	var column := _column("Weapons · 4 Slots", &"target", UIPalette.mint, 360.0)
	var weapons: Array = _snapshot.get("weapons", [])
	if weapons.is_empty():
		column.add_child(UIFactory.empty_state(&"target", "No weapons", "The Deployment could not resolve the loadout."))
		return column
	for weapon in weapons:
		if not (weapon is Dictionary):
			continue
		column.add_child(_weapon_row(weapon))
		_weapon_rows += 1
	return column


func _weapon_row(weapon: Dictionary) -> PanelContainer:
	var rarity: Color = weapon.get("rarity_color", UIPalette.muted)
	var active := bool(weapon.get("active", false))
	var card := UIFactory.panel("CardInset")
	if active:
		card.add_theme_stylebox_override(
			"panel",
			UITheme._box(UIPalette.alpha(rarity, 0.10), UIPalette.alpha(rarity, 0.7), UIPalette.R_MD, 1, Vector4(14, 10, 14, 10))
		)
	else:
		card.add_theme_stylebox_override(
			"panel",
			UITheme._box(UIPalette.alpha(UIPalette.ink, 0.35), UIPalette.alpha(UIPalette.line, 0.5), UIPalette.R_MD, 1, Vector4(14, 10, 14, 10))
		)
	var row := UIFactory.hbox(UIPalette.SP3)
	var pip := ColorRect.new()
	pip.color = rarity
	pip.custom_minimum_size = Vector2(3, 30)
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pip)
	var text := UIFactory.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_row := UIFactory.hbox(UIPalette.SP2)
	title_row.add_child(UIFactory.label(String(weapon.get("slot_label", "SLOT")), "Micro", UIPalette.muted_dim))
	if bool(weapon.get("is_melee", false)):
		title_row.add_child(UIFactory.label("ISSUED", "Micro", UIPalette.mint))
	if active:
		title_row.add_child(UIFactory.badge("ACTIVE", UIPalette.mint))
	text.add_child(title_row)
	text.add_child(UIFactory.label(String(weapon.get("name", "Weapon")), "TitleLabel", rarity))
	var meta := UIFactory.hbox(UIPalette.SP3)
	var melee := bool(weapon.get("is_melee", false))
	if melee:
		meta.add_child(UIFactory.icon_value(&"target", "MELEE", UIPalette.mint, 12))
		meta.add_child(UIFactory.icon_value(&"ammo", "∞", UIPalette.ivory, 12))
	else:
		meta.add_child(UIFactory.icon_value(&"ammo", "%d / %d" % [int(weapon.get("ammo", 0)), int(weapon.get("reserve", 0))], UIPalette.ivory, 12))
		meta.add_child(UIFactory.icon_value(&"target", "%d DMG" % int(weapon.get("damage", 0)), UIPalette.muted, 12))
	text.add_child(meta)
	row.add_child(text)
	card.add_child(row)
	return card


func _build_gear_column() -> VBoxContainer:
	var column := _column("Equipped Gear", &"shield-check", UIPalette.mint, 300.0)
	var gear: Array = _snapshot.get("gear", [])
	if gear.is_empty():
		column.add_child(UIFactory.empty_state(&"shield", "No gear", "No armor signals resolved."))
		return column
	for entry in gear:
		if not (entry is Dictionary):
			continue
		column.add_child(_gear_row(entry))
	return column


func _gear_row(entry: Dictionary) -> PanelContainer:
	var rarity: Color = entry.get("rarity_color", UIPalette.muted)
	var card := UIFactory.panel("RowPanel")
	var row := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon_or_null(_gear_icon(String(entry.get("slot", ""))), 14, rarity)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
	var text := UIFactory.vbox(1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UIFactory.label(String(entry.get("label", "Gear")), "Micro", UIPalette.muted_dim))
	var empty := bool(entry.get("empty", false))
	text.add_child(UIFactory.label(String(entry.get("name", "Empty")), "BodySmall", UIPalette.muted_dim if empty else rarity))
	row.add_child(text)
	if not empty:
		row.add_child(UIFactory.icon_value(&"shield-check", "%d" % int(entry.get("armor", 0.0)), rarity, 12))
	card.add_child(row)
	return card


func _gear_icon(slot: String) -> StringName:
	match slot:
		"helmet":
			return &"helmet"
		"chest":
			return &"shield"
		"legs":
			return &"legs"
		"cloak":
			return &"layers"
		"charm":
			return &"star"
	return &"shield"


func _build_satchel_column() -> VBoxContainer:
	var column := _column("Satchel · Loot", &"coins", UIPalette.amber, 430.0, true)
	var totals := UIFactory.hbox(UIPalette.SP4)
	totals.add_child(UIFactory.stat_block(&"coins", "Salvage", UIPalette.format_int(int(_snapshot.get("satchel_salvage", 0))), UIPalette.amber, 22))
	totals.add_child(UIFactory.stat_block(&"core", "Cores", str(int(_snapshot.get("satchel_cores", 0))), UIPalette.violet, 22))
	totals.add_child(UIFactory.stat_block(&"backpack", "Items", str((_snapshot.get("satchel_items", []) as Array).size()), UIPalette.mint, 22))
	column.add_child(totals)
	column.add_child(UIFactory.divider(UIPalette.line_soft))
	var items: Array = _snapshot.get("satchel_items", [])
	if items.is_empty():
		column.add_child(UIFactory.empty_state(&"backpack", "Satchel empty", "Loot caches, elites and objective sites feed this list."))
	else:
		var item_scroll := UIFactory.vscroll()
		item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(item_scroll)
		var item_box := UIFactory.vbox(UIPalette.SP2)
		item_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_scroll.add_child(item_box)
		for item in items:
			if not (item is Dictionary):
				continue
			item_box.add_child(_loot_row(item))
			_loot_rows += 1
	var rift_mods: Array = _snapshot.get("rift_mods", [])
	if not rift_mods.is_empty():
		column.add_child(UIFactory.divider(UIPalette.line_soft))
		var mod_head := UIFactory.hbox(UIPalette.SP2)
		mod_head.add_child(UIFactory.icon(&"bolt", 12, UIPalette.violet))
		mod_head.add_child(UIFactory.eyebrow("Rift Mods", UIPalette.violet))
		column.add_child(mod_head)
		var mod_row := UIFactory.hbox(UIPalette.SP2)
		for mod_id in rift_mods:
			var mod := ContentDB.get_rift_mod(StringName(mod_id))
			if mod != null:
				mod_row.add_child(UIFactory.badge(mod.display_name, mod.color, &"bolt"))
		column.add_child(mod_row)
	var identity := UIFactory.hbox(UIPalette.SP4)
	identity.add_child(UIFactory.icon_value(&"flag", "EXTRACTIONS %d" % int(_snapshot.get("extractions", 0)), UIPalette.muted, 12))
	identity.add_child(UIFactory.icon_value(&"timer", UIPalette.format_time(float(_snapshot.get("time_left", 0.0))), UIPalette.amber, 12))
	identity.add_child(UIFactory.icon_value(&"skull", "%d KILLS" % int(_snapshot.get("kills", 0)), UIPalette.ivory, 12))
	column.add_child(UIFactory.divider(UIPalette.line_soft))
	column.add_child(identity)
	return column


func _loot_row(item: Dictionary) -> PanelContainer:
	var info := ItemFactory.describe(item)
	var rarity: Color = info.get("rarity_color", UIPalette.muted)
	var card := UIFactory.panel("RowPanel")
	var row := UIFactory.hbox(UIPalette.SP2)
	var pip := ColorRect.new()
	pip.color = rarity
	pip.custom_minimum_size = Vector2(3, 26)
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pip)
	var text := UIFactory.vbox(1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := UIFactory.label(String(info.get("display_name", "Unknown item")), "BodySmall", rarity)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(name_label)
	var meta_text := "%s · %s" % [
		String(info.get("rarity_name", "Common")),
		String(info.get("slot", "")).capitalize(),
	]
	var affixes: Array = info.get("affixes", [])
	if not affixes.is_empty():
		meta_text += " · " + String(affixes[0].get("value_text", ""))
	text.add_child(UIFactory.label(meta_text, "Micro", UIPalette.muted_dim))
	row.add_child(text)
	row.add_child(UIFactory.icon_value(&"coins", UIPalette.format_int(int(info.get("value", 0))), UIPalette.amber, 12))
	card.add_child(row)
	return card


func _on_close_pressed() -> void:
	if App != null:
		App.set_inventory(false)
	else:
		dismiss()
