class_name LoadoutScreen
extends UIScreen
## Loadout / gear management. Equips real inventory items through ProfileState,
## previews derived stats, compares against the currently equipped piece and
## supports scrapping gear for salvage.

const SLOT_DEFS := [
	{"id": &"primary", "label": "Primary Weapon 1", "icon": &"target", "kind": "weapon"},
	{"id": &"primary_2", "label": "Primary Weapon 2", "icon": &"crosshair", "kind": "weapon"},
	{"id": &"sidearm", "label": "Sidearm", "icon": &"ammo", "kind": "weapon"},
	{"id": &"helmet", "label": "Helmet", "icon": &"helmet", "kind": "gear"},
	{"id": &"chest", "label": "Chest", "icon": &"shield", "kind": "gear"},
	{"id": &"legs", "label": "Legs", "icon": &"legs", "kind": "gear"},
	{"id": &"cloak", "label": "Cloak", "icon": &"layers", "kind": "gear"},
	{"id": &"charm", "label": "Charm", "icon": &"star", "kind": "gear"},
]

var _active_slot: StringName = &"primary"
var _selected_uid := 0
var _list_host: VBoxContainer = null
var _detail_host: VBoxContainer = null
var _detail_actions: VBoxContainer = null
var _slots_host: VBoxContainer = null
var _stats_host: VBoxContainer = null


func _compose() -> void:
	var backdrop := UIBackdrop.new()
	backdrop.configure(UIBackdrop.Mood.HUB)
	add_child(backdrop)

	var shell := build_hub_shell(&"loadout", "Loadout", "")
	var content: VBoxContainer = shell.content

	_stats_host = UIFactory.vbox(UIPalette.SP3)
	content.add_child(_stats_host)

	var body := UIFactory.hbox(UIPalette.SP4)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)

	var left := UIFactory.vbox(UIPalette.SP3)
	left.custom_minimum_size.x = 380
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(UIFactory.section_header("Equipped", "", null, &"backpack"))
	var slot_scroll := UIFactory.vscroll()
	slot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slots_host = UIFactory.vbox(UIPalette.SP2)
	_slots_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_scroll.add_child(_slots_host)
	left.add_child(slot_scroll)
	body.add_child(left)

	body.add_child(_build_inventory_column())
	body.add_child(_build_detail_column())
	_refresh()


func _build_stats_strip() -> PanelContainer:
	var card := UIFactory.panel("CardInset")
	var stats: Dictionary = ProfileState.get_preview_stats()
	var primary := ProfileState.get_equipped_item(&"primary")
	var primary_info := ItemFactory.describe(primary)
	var dps := 0.0
	if not primary_info.is_empty():
		dps = float(primary_info.get("stats", {}).get("dps", 0.0))
	var row := UIFactory.hbox(UIPalette.SP5)
	row.add_child(UIFactory.stat_block(&"heart-pulse", "Health", str(int(stats.get(StatKeys.HEALTH_MAX, 100))), UIPalette.mint, 22))
	row.add_child(UIFactory.stat_block(&"shield", "Shield", str(int(stats.get(StatKeys.SHIELD_MAX, 50))), UIPalette.blue, 22))
	row.add_child(UIFactory.stat_block(&"shield-check", "Armor", str(int(stats.get(StatKeys.ARMOR, 10))), UIPalette.ivory, 22))
	row.add_child(UIFactory.stat_block(&"target", "Primary DPS", str(int(dps)), UIPalette.amber, 22))
	row.add_child(UIFactory.stat_block(&"crosshair", "Crit chance", "%.1f%%" % (float(stats.get(StatKeys.CRIT_CHANCE, 0.05)) * 100.0), UIPalette.violet, 22))
	row.add_child(UIFactory.stat_block(&"star", "Luck", "%.2f" % float(stats.get(StatKeys.LUCK, 0.0)), UIPalette.sun, 22))
	row.add_child(UIFactory.spacer_h())
	var locker_row := UIFactory.icon_value(&"backpack", str(ProfileState.get_inventory_size()), UIPalette.muted, 13)
	locker_row.tooltip_text = "Items in locker. Set bonuses and affixes apply immediately."
	row.add_child(locker_row)
	card.add_child(row)
	return card


func _icon_value_tip(icon_name: StringName, value_text: String, accent: Color, tooltip: String) -> HBoxContainer:
	var row := UIFactory.icon_value(icon_name, value_text, accent, 12)
	row.tooltip_text = tooltip
	return row


# ---------------------------------------------------------------------------
# Slots
# ---------------------------------------------------------------------------

func _build_slots() -> void:
	_slots_host.add_child(_category_header(&"target", "Weapons"))
	for slot_def in SLOT_DEFS:
		if slot_def.kind != "weapon":
			continue
		_slots_host.add_child(_build_slot_card(slot_def))
	_slots_host.add_child(_build_knife_card())
	_slots_host.add_child(UIFactory.fixed_spacer(0, UIPalette.SP2))
	_slots_host.add_child(_category_header(&"shield", "Gear"))
	for slot_def in SLOT_DEFS:
		if slot_def.kind != "gear":
			continue
		_slots_host.add_child(_build_slot_card(slot_def))


func _category_header(icon_name: StringName, text: String) -> HBoxContainer:
	var row := UIFactory.hbox(6)
	var glyph := UIFactory.icon_or_null(icon_name, 12, UIPalette.muted_dim)
	if glyph != null:
		row.add_child(glyph)
	row.add_child(UIFactory.label(text, "StatLabel"))
	return row


func _build_slot_card(slot_def: Dictionary) -> Button:
	var slot_id: StringName = slot_def.id
	var item := ProfileState.get_equipped_item(slot_id)
	var info := ItemFactory.describe(item)
	var active := slot_id == _active_slot
	var card := UIFactory.card_button(true)
	card.button_pressed = active
	card.custom_minimum_size = Vector2(0, 88)
	card.tooltip_text = _slot_tooltip(slot_def, info)
	card.pressed.connect(func() -> void: _select_slot(slot_id))
	var content := UIFactory.card_content(card)
	if content == null:
		return card
	_set_card_margins(content, 14, 10, 14, 10)
	var row := UIFactory.hbox(UIPalette.SP3)
	row.add_child(_slot_art(slot_def, info, active))
	var accent: Color = UIPalette.muted_dim if info.is_empty() else info.get("rarity_color", UIPalette.muted_dim)
	var text := UIFactory.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := UIFactory.display_text(
		"Empty" if info.is_empty() else String(info.get("display_name", "Unknown")),
		18,
		600,
		accent
	)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(name_label)
	if info.is_empty():
		text.add_child(UIFactory.label("No %s equipped" % String(slot_def.label).to_lower(), "Micro", UIPalette.muted_dim))
	else:
		text.add_child(UIFactory.label(_slot_meta_text(slot_def, info), "Micro", UIPalette.muted))
		var stats_row := UIFactory.hbox(UIPalette.SP3)
		var weapon_stats: Dictionary = info.get("stats", {})
		if String(info.get("kind", "")) == "weapon":
			stats_row.add_child(_icon_value_tip(&"target", "%d DPS" % int(weapon_stats.get("dps", 0.0)), accent, "Damage per second"))
			stats_row.add_child(_icon_value_tip(&"ammo", "%d" % int(weapon_stats.get("magazine", 0)), UIPalette.muted, "Magazine size"))
		else:
			stats_row.add_child(_icon_value_tip(&"shield-check", "%d ARM" % int(info.get("armor", 0.0)), accent, "Armor"))
		text.add_child(stats_row)
	row.add_child(text)
	row.add_child(UIFactory.icon(&"chevron-right", 16, UIPalette.muted_dim))
	content.add_child(row)
	UIFactory.passive_tree(content)
	return card


func _slot_art(slot_def: Dictionary, info: Dictionary, selected: bool = false) -> PanelContainer:
	if info.is_empty():
		var empty := UIItemArt.new()
		empty.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		empty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty.configure(
			String(slot_def.kind),
			_art_slot_id(String(slot_def.id)),
			"",
			UIPalette.muted_dim,
			UIPalette.muted_dim,
			false
		)
		empty.custom_minimum_size = Vector2(52, 44)
		var empty_frame := UIFactory.art_frame(empty, UIPalette.line, false)
		empty_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return empty_frame
	var art := _item_art(info, Vector2(52, 44))
	var rarity: Color = info.get("rarity_color", UIPalette.muted_dim)
	var frame := UIFactory.art_frame(art, rarity, selected)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame


func _slot_meta_text(slot_def: Dictionary, info: Dictionary) -> String:
	if String(info.get("kind", "")) == "weapon":
		var weapon: WeaponData = info.get("weapon", null) as WeaponData
		var style := "Weapon"
		if weapon != null:
			style = String(weapon.style).replace("_", " ").capitalize()
		return "%s · %s" % [style, String(slot_def.label)]
	return "%s · %s" % [String(slot_def.label), String(info.get("rarity_name", "")).to_upper()]


func _slot_tooltip(slot_def: Dictionary, info: Dictionary) -> String:
	var lines: PackedStringArray = [String(slot_def.label)]
	if info.is_empty():
		lines.append("Empty slot. Select it, then equip an item from your locker.")
	else:
		lines.append("%s · Level %d" % [String(info.get("rarity_name", "Common")), int(info.get("level", 1))])
		var description := String(info.get("description", ""))
		if not description.is_empty():
			lines.append(description)
	return "\n".join(lines)


func _item_tooltip(info: Dictionary) -> String:
	var lines: PackedStringArray = [
		"%s · %s · Level %d" % [
			String(info.get("rarity_name", "")),
			String(info.get("slot", "")).capitalize(),
			int(info.get("level", 1)),
		],
	]
	var description := String(info.get("description", ""))
	if not description.is_empty():
		lines.append(description)
	return "\n".join(lines)


func _slot_short_label(slot_id: StringName) -> String:
	if slot_id == StatKeys.SLOT_PRIMARY:
		return "P1"
	if slot_id == StatKeys.SLOT_PRIMARY_2:
		return "P2"
	if slot_id == StatKeys.SLOT_SIDEARM:
		return "SIDEARM"
	return String(slot_id).replace("_", " ").to_upper()


func _item_art(info: Dictionary, art_size: Vector2, compact: bool = false) -> UIItemArt:
	var art := UIItemArt.new()
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.configure(
		String(info.get("kind", "gear")),
		_art_slot_id(String(info.get("slot", ""))),
		String(info.get("base_id", "")),
		info.get("rarity_color", UIPalette.muted_dim),
		_art_accent(info),
		compact
	)
	art.custom_minimum_size = art_size
	return art


func _art_tile(info: Dictionary, art_size: Vector2, selected: bool = false, compact: bool = false) -> PanelContainer:
	var art := _item_art(info, art_size, compact)
	var rarity: Color = info.get("rarity_color", UIPalette.muted_dim)
	var frame := UIFactory.art_frame(art, rarity, selected)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame


func _art_accent(info: Dictionary) -> Color:
	var weapon: WeaponData = info.get("weapon", null) as WeaponData
	if weapon != null:
		return weapon.accent
	var rarity: Color = info.get("rarity_color", UIPalette.muted_dim)
	return UIPalette.mix(rarity, UIPalette.ivory, 0.3)


func _art_slot_id(slot: String) -> String:
	return "primary" if slot == "primary_2" else slot


func _set_card_margins(content: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	content.add_theme_constant_override("margin_left", left)
	content.add_theme_constant_override("margin_top", top)
	content.add_theme_constant_override("margin_right", right)
	content.add_theme_constant_override("margin_bottom", bottom)


## The close-combat knife is issued equipment, not a locker item: it cannot be
## unequipped, scrapped or replaced.
func _build_knife_card() -> PanelContainer:
	var card := UIFactory.panel("CardInset")
	card.tooltip_text = "Every Warden carries a Combat Knife in weapon slot 4.\n55 damage · 2.8 m reach · no ammo. Issued equipment: cannot be unequipped, scrapped or replaced."
	var content := UIFactory.hbox(UIPalette.SP3)
	var knife_art := UIItemArt.new()
	knife_art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	knife_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	knife_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knife_art.configure("knife", "primary", "knife", UIPalette.mint, UIPalette.mint, false)
	knife_art.custom_minimum_size = Vector2(52, 44)
	var knife_frame := UIFactory.art_frame(knife_art, UIPalette.mint, false)
	knife_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(knife_frame)
	var text := UIFactory.vbox(3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_row := UIFactory.hbox(UIPalette.SP2)
	title_row.add_child(UIFactory.display_text("Combat Knife", 18, 600, UIPalette.mint))
	title_row.add_child(UIFactory.badge("SLOT 4", UIPalette.muted))
	text.add_child(title_row)
	text.add_child(UIFactory.label("55 DMG  ·  2.8 M  ·  NO AMMO  ·  ISSUED", "Micro", UIPalette.muted))
	content.add_child(text)
	card.add_child(UIFactory.pad(content, 14, 10, 14, 10))
	return card


# ---------------------------------------------------------------------------
# Inventory / detail columns
# ---------------------------------------------------------------------------

func _build_inventory_column() -> VBoxContainer:
	var column := UIFactory.vbox(UIPalette.SP3)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var unequip := UIFactory.ghost_button("Unequip", &"close")
	unequip.tooltip_text = "Remove the equipped item from this slot."
	unequip.pressed.connect(_on_unequip)
	column.add_child(UIFactory.section_header(_slot_label(_active_slot), "Locker Contents", unequip, _slot_icon(_active_slot)))

	var scroll := UIFactory.vscroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_host = UIFactory.vbox(UIPalette.SP2)
	_list_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_host)
	column.add_child(scroll)
	return column


func _build_detail_column() -> VBoxContainer:
	var column := UIFactory.vbox(UIPalette.SP2)
	column.custom_minimum_size.x = 346
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var detail_head := UIFactory.hbox(UIPalette.SP2)
	detail_head.add_child(UIFactory.icon(&"info", 12, UIPalette.amber))
	detail_head.add_child(UIFactory.eyebrow("Item Detail", UIPalette.amber))
	column.add_child(detail_head)
	var scroll := UIFactory.vscroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_host = UIFactory.vbox(UIPalette.SP3)
	_detail_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail_host)
	column.add_child(scroll)
	column.add_child(UIFactory.divider(UIPalette.line_soft))
	_detail_actions = UIFactory.vbox(UIPalette.SP2)
	column.add_child(_detail_actions)
	return column


# ---------------------------------------------------------------------------
# Data refresh
# ---------------------------------------------------------------------------

func _refresh() -> void:
	if _slots_host == null or _list_host == null or _detail_host == null:
		return
	UIFactory.clear_children(_slots_host)
	UIFactory.clear_children(_list_host)
	UIFactory.clear_children(_detail_host)
	if _detail_actions != null:
		UIFactory.clear_children(_detail_actions)
	if _stats_host != null:
		UIFactory.clear_children(_stats_host)
		_stats_host.add_child(_build_stats_strip())
	_build_slots()
	_build_item_list()
	_build_detail()
	_build_detail_actions()


func _slot_label(slot_id: StringName) -> String:
	for slot_def in SLOT_DEFS:
		if slot_def.id == slot_id:
			return String(slot_def.label)
	return "Slot"


func _slot_icon(slot_id: StringName) -> StringName:
	for slot_def in SLOT_DEFS:
		if slot_def.id == slot_id:
			return StringName(slot_def.icon)
	return &"backpack"


func _items_for_slot(slot_id: StringName) -> Array:
	var out: Array = []
	var lookup_slot := String(StatKeys.SLOT_PRIMARY) if slot_id == StatKeys.SLOT_PRIMARY_2 else String(slot_id)
	for item in ProfileState.get_inventory():
		if String(item.get("slot", "")) == lookup_slot:
			out.append(item)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("rarity", 0)) > int(b.get("rarity", 0))
	)
	return out


func _equipped_weapon_slot_for_uid(uid: int) -> StringName:
	for slot in [StatKeys.SLOT_PRIMARY, StatKeys.SLOT_PRIMARY_2, StatKeys.SLOT_SIDEARM]:
		if ProfileState.get_equipped_uid(slot) == uid:
			return slot
	return &""


func _ensure_selection() -> void:
	var items := _items_for_slot(_active_slot)
	if items.is_empty():
		_selected_uid = 0
		return
	var still_valid := false
	for item in items:
		if int(item.get("uid", 0)) == _selected_uid:
			still_valid = true
			break
	if not still_valid:
		var equipped := ProfileState.get_equipped_uid(_active_slot)
		_selected_uid = equipped if equipped > 0 else int(items[0].get("uid", 0))


func _build_item_list() -> void:
	_ensure_selection()
	var items := _items_for_slot(_active_slot)
	if items.is_empty():
		_list_host.add_child(UIFactory.empty_state(&"backpack", "Nothing in this slot", "Loot or scrap gear to fill it."))
		return
	var group := ButtonGroup.new()
	for item in items:
		var uid := int(item.get("uid", 0))
		var info := ItemFactory.describe(item)
		var row := UIFactory.card_button(true)
		row.button_group = group
		row.button_pressed = uid == _selected_uid
		row.custom_minimum_size = Vector2(0, 62)
		row.tooltip_text = _item_tooltip(info)
		var content := UIFactory.card_content(row)
		if content == null:
			continue
		_set_card_margins(content, 12, 8, 12, 8)
		var box := UIFactory.hbox(UIPalette.SP3)
		var rarity: Color = info.get("rarity_color", UIPalette.muted)
		var bar := ColorRect.new()
		bar.color = rarity
		bar.custom_minimum_size = Vector2(3, 0)
		bar.size_flags_vertical = Control.SIZE_FILL
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bar)
		box.add_child(_art_tile(info, Vector2(48, 40), uid == _selected_uid, false))
		var text := UIFactory.vbox(2)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title_row := UIFactory.hbox(UIPalette.SP2)
		title_row.add_child(UIFactory.label(String(info.get("display_name", "Unknown")), "TitleLabel", rarity))
		if uid == ProfileState.get_equipped_uid(_active_slot):
			var equipped_icon := UIFactory.icon(&"check", 14, UIPalette.mint)
			equipped_icon.tooltip_text = "Equipped in this slot"
			title_row.add_child(equipped_icon)
		else:
			var other_slot := _equipped_weapon_slot_for_uid(uid)
			if other_slot != &"":
				var other_badge := UIFactory.badge(_slot_short_label(other_slot), UIPalette.muted_dim, &"layers")
				other_badge.tooltip_text = "Equipped in %s" % _slot_label(other_slot)
				title_row.add_child(other_badge)
		text.add_child(title_row)
		var meta_row := UIFactory.hbox(UIPalette.SP3)
		meta_row.add_child(_icon_value_tip(&"arrow-up", "L%d" % int(info.get("level", 1)), UIPalette.muted, "Item level"))
		meta_row.add_child(_icon_value_tip(&"coins", UIPalette.format_int(int(info.get("value", 0))), UIPalette.amber, "Scrap value"))
		text.add_child(meta_row)
		box.add_child(text)
		if info.get("kind") == "weapon":
			box.add_child(_icon_value_tip(&"target", "%d" % int(info.get("stats", {}).get("dps", 0.0)), UIPalette.muted, "DPS"))
		else:
			box.add_child(_icon_value_tip(&"shield-check", "%d" % int(info.get("armor", 0.0)), UIPalette.muted, "Armor"))
		content.add_child(box)
		UIFactory.passive_tree(content)
		row.pressed.connect(func() -> void:
			_selected_uid = uid
			refresh()
		)
		_list_host.add_child(row)


func _build_detail() -> void:
	var item := ProfileState.get_item(_selected_uid)
	if item.is_empty():
		_detail_host.add_child(UIFactory.empty_state(&"info", "Select an item", "Inspect, equip or scrap locker gear."))
		return
	var info := ItemFactory.describe(item)
	var rarity: Color = info.get("rarity_color", UIPalette.muted)
	var card := UIFactory.panel("Card")
	card.tooltip_text = _item_tooltip(info)
	var box := UIFactory.vbox(UIPalette.SP3)
	var hero := UIFactory.hbox(UIPalette.SP3)
	hero.add_child(_art_tile(info, Vector2(104, 76), false, false))
	var hero_text := UIFactory.vbox(3)
	hero_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_text.add_child(UIFactory.badge(String(info.get("rarity_name", "Common")).to_upper(), rarity))
	var name_label := UIFactory.display_text(String(info.get("display_name", "Unknown")), 24, 600, rarity)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_text.add_child(name_label)
	var sub_row := UIFactory.hbox(UIPalette.SP3)
	var slot_glyph := UIFactory.icon_or_null(_slot_icon(StringName(info.get("slot", ""))), 13, UIPalette.muted)
	if slot_glyph != null:
		sub_row.add_child(slot_glyph)
	sub_row.add_child(_icon_value_tip(&"arrow-up", "L%d" % int(info.get("level", 1)), UIPalette.muted, "Item level"))
	hero_text.add_child(sub_row)
	hero.add_child(hero_text)
	box.add_child(hero)
	box.add_child(UIFactory.divider(UIPalette.line_soft))

	var weapon_stats: Dictionary = info.get("stats", {})
	if info.get("kind") == "weapon":
		var stat_grid := GridContainer.new()
		stat_grid.columns = 3
		stat_grid.add_theme_constant_override("h_separation", UIPalette.SP4)
		stat_grid.add_theme_constant_override("v_separation", UIPalette.SP2)
		stat_grid.add_child(_detail_stat(&"target", "%.1f" % float(weapon_stats.get("damage", 0.0)), "Damage per shot"))
		stat_grid.add_child(_detail_stat(&"crosshair", "%.0f" % float(weapon_stats.get("dps", 0.0)), "Damage per second"))
		stat_grid.add_child(_detail_stat(&"ammo", str(int(weapon_stats.get("magazine", 0))), "Magazine size"))
		stat_grid.add_child(_detail_stat(&"refresh", "%.2fs" % float(weapon_stats.get("reload", 0.0)), "Reload time"))
		stat_grid.add_child(_detail_stat(&"bolt", str(int(weapon_stats.get("rpm", 0))), "Rounds per minute"))
		box.add_child(stat_grid)
	else:
		var stat_grid := GridContainer.new()
		stat_grid.columns = 2
		stat_grid.add_theme_constant_override("h_separation", UIPalette.SP4)
		stat_grid.add_theme_constant_override("v_separation", UIPalette.SP2)
		stat_grid.add_child(_detail_stat(&"shield-check", str(int(info.get("armor", 0.0))), "Armor"))
		for stat_name in weapon_stats.keys():
			var stat_key := StringName(stat_name)
			stat_grid.add_child(_detail_stat(
				&"shield",
				UIPalette.format_stat_value(stat_key, float(weapon_stats[stat_name])),
				String(stat_name).replace("_", " ").capitalize()
			))
		box.add_child(stat_grid)

	var affixes: Array = info.get("affixes", [])
	if not affixes.is_empty():
		box.add_child(UIFactory.divider(UIPalette.line_soft))
		box.add_child(_section_eyebrow(&"star", "Affixes", UIPalette.mint))
		box.add_child(_affix_chips(affixes))

	var set_id := String(info.get("set_id", ""))
	if not set_id.is_empty():
		box.add_child(UIFactory.divider(UIPalette.line_soft))
		box.add_child(_section_eyebrow(&"layers", "Set Bonus", UIPalette.violet))
		box.add_child(_set_chips(set_id))

	box.add_child(UIFactory.divider(UIPalette.line_soft))
	box.add_child(_comparison_block(info, int(info.get("uid", 0))))
	card.add_child(box)
	_detail_host.add_child(card)


func _detail_stat(icon_name: StringName, value_text: String, tooltip: String) -> HBoxContainer:
	var row := UIFactory.icon_value(icon_name, value_text, UIPalette.ivory, 13)
	row.tooltip_text = tooltip
	return row


func _build_detail_actions() -> void:
	if _detail_actions == null:
		return
	var item := ProfileState.get_item(_selected_uid)
	if item.is_empty():
		_detail_actions.add_child(UIFactory.label("Select an item.", "Micro", UIPalette.muted_dim))
		return
	var info := ItemFactory.describe(item)
	var uid := int(info.get("uid", 0))
	var equipped := uid == ProfileState.get_equipped_uid(_active_slot)
	var action_row := UIFactory.hbox(UIPalette.SP2)
	var equip := UIFactory.icon_button(
		&"check",
		"Equipped in %s" % _slot_label(_active_slot) if equipped else "Equip %s in %s." % [String(info.get("display_name", "item")), _slot_label(_active_slot)],
		"PrimaryButton",
		48
	)
	equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip.disabled = equipped
	if not equipped:
		equip.pressed.connect(_on_equip.bind(uid, _active_slot))
	action_row.add_child(equip)
	var scrap := UIFactory.icon_button(
		&"trash",
		"Unequip this item before scrapping it." if equipped else "Scrap for %s salvage (25%% of value)." % UIPalette.format_int(maxi(1, int(int(info.get("value", 0)) * 0.25))),
		"DangerButton",
		48
	)
	scrap.disabled = equipped
	if not equipped:
		scrap.pressed.connect(_on_scrap.bind(uid))
	action_row.add_child(scrap)
	_detail_actions.add_child(action_row)

	var value_row := UIFactory.hbox(UIPalette.SP2)
	var scrap_value := UIFactory.icon_value(&"coins", UIPalette.format_int(int(info.get("value", 0))), UIPalette.amber, 12)
	scrap_value.tooltip_text = "Scrap returns 25% of the item's value"
	value_row.add_child(scrap_value)
	value_row.add_child(UIFactory.spacer_h())
	value_row.add_child(UIFactory.label("25% SALVAGE RETURN", "Micro", UIPalette.muted_dim))
	_detail_actions.add_child(value_row)


func _section_eyebrow(icon_name: StringName, text: String, accent: Color) -> HBoxContainer:
	var head := UIFactory.hbox(UIPalette.SP2)
	head.add_child(UIFactory.icon(icon_name, 12, accent))
	head.add_child(UIFactory.eyebrow(text, accent))
	return head


func _chip_flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return flow


func _affix_chips(affixes: Array) -> HFlowContainer:
	var flow := _chip_flow()
	for affix in affixes:
		var value_text := String(affix.get("value_text", ""))
		var chip := UIFactory.chip(value_text, UIPalette.mint)
		chip.tooltip_text = "%s\n%s" % [String(affix.get("display_name", "Affix")), value_text]
		flow.add_child(chip)
	return flow


func _set_chips(set_id: String) -> HFlowContainer:
	var flow := _chip_flow()
	var set_chip := UIFactory.chip(set_id.to_upper(), UIPalette.violet)
	set_chip.tooltip_text = "Set bonus: equip 3 pieces of %s." % set_id.replace("_", " ").capitalize()
	flow.add_child(set_chip)
	var bonuses: Array = ProfileState.SET_BONUSES.get(set_id, [])
	if bonuses.is_empty():
		flow.add_child(UIFactory.chip("NO SET DATA", UIPalette.muted_dim))
		return flow
	var parts: PackedStringArray = []
	for entry in bonuses:
		parts.append(UIPalette.format_stat_value(StringName(entry.stat), float(entry.value)))
	var bonus_chip := UIFactory.chip("3 PCS · " + " · ".join(parts), UIPalette.violet)
	bonus_chip.tooltip_text = "Equip 3 pieces of %s to activate these bonuses." % set_id.replace("_", " ").capitalize()
	flow.add_child(bonus_chip)
	return flow


func _comparison_block(info: Dictionary, uid: int) -> VBoxContainer:
	var box := UIFactory.vbox(3)
	var head := UIFactory.hbox(UIPalette.SP2)
	head.add_child(UIFactory.icon(&"refresh", 12, UIPalette.muted_dim))
	head.add_child(UIFactory.eyebrow("Vs equipped", UIPalette.muted))
	box.add_child(head)
	if uid == ProfileState.get_equipped_uid(_active_slot):
		box.add_child(_icon_value_tip(&"check", "Equipped", UIPalette.mint, "Currently equipped in this slot"))
		return box
	var equipped := ItemFactory.describe(ProfileState.get_equipped_item(_active_slot))
	if equipped.is_empty():
		box.add_child(_icon_value_tip(&"arrow-up", "Slot empty — upgrade", UIPalette.mint, "Nothing equipped in this slot"))
		return box
	var current_stats: Dictionary = equipped.get("stats", {})
	var new_stats: Dictionary = info.get("stats", {})
	var is_weapon := String(info.get("kind", "")) == "weapon"
	var keys: Array = ["dps", "damage"] if is_weapon else ["armor"]
	var compared := false
	for key in keys:
		var current_value := _pick_value(current_stats, equipped, key)
		var new_value := _pick_value(new_stats, info, key)
		if current_value <= 0.0 and new_value <= 0.0:
			continue
		var delta := new_value - current_value
		var color := UIPalette.mint if delta > 0.0 else (UIPalette.danger if delta < 0.0 else UIPalette.muted)
		var sign_text := "+" if delta > 0.0 else ""
		box.add_child(UIFactory.stat_line(String(key).to_upper(), "%s%.0f" % [sign_text, delta], color))
		compared = true
	if not compared:
		box.add_child(UIFactory.label("No comparable stats.", "BodySmall"))
	return box


func _pick_value(stats: Dictionary, info: Dictionary, key: String) -> float:
	if key == "armor":
		return float(info.get("armor", 0.0))
	return float(stats.get(key, 0.0))


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _select_slot(slot_id: StringName) -> void:
	_active_slot = slot_id
	_selected_uid = 0
	refresh()


func _on_equip(uid: int, target_slot: StringName = &"") -> void:
	if ProfileState.equip_item(uid, target_slot):
		AudioDirector.play_ui(&"ui_confirm")
		notify("Loadout updated", "Item equipped. Derived stats have been recalculated.", &"success")
	else:
		AudioDirector.play_ui(&"ui_error")
		notify("Cannot equip", "That item does not fit this slot.", &"error")
	refresh()


func _on_unequip() -> void:
	if ProfileState.get_equipped_uid(_active_slot) <= 0:
		notify("Nothing equipped", "There is no item in this slot.", &"warning")
		return
	ProfileState.unequip_slot(_active_slot)
	AudioDirector.play_ui(&"ui_click")
	refresh()


func _on_scrap(uid: int) -> void:
	var item := ProfileState.get_item(uid)
	if item.is_empty():
		return
	var value := maxi(1, int(ItemFactory.item_value(item) * 0.25))
	if ProfileState.scrap_item(uid):
		AudioDirector.play_ui(&"ui_confirm")
		var message := "Recovered %s salvage." % UIPalette.format_int(value)
		notify("Item scrapped", message, &"loot")
		_selected_uid = 0
	else:
		AudioDirector.play_ui(&"ui_error")
		notify("Cannot scrap", "Unequip the item first.", &"error")
	refresh()


func first_focus_control() -> Control:
	return super.first_focus_control()
