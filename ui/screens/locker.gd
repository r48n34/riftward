class_name LockerScreen
extends UIScreen
## Locker: cosmetics per slot with a live Warden preview, and a salvage bench for
## scrapping surplus gear.

const TABS := [
	{"id": &"suit", "label": "Suits", "slot": "suit", "icon": &"helmet"},
	{"id": &"dye", "label": "Dyes", "slot": "dye", "icon": &"layers"},
	{"id": &"weapon_skin", "label": "Skins", "slot": "weapon_skin", "icon": &"crosshair"},
	{"id": &"pet_shell", "label": "Shells", "slot": "pet_shell", "icon": &"paw"},
	{"id": &"salvage", "label": "Salvage Bench", "slot": "", "icon": &"trash"},
]

const COSMETIC_ICONS := {
	"suit": &"helmet",
	"dye": &"layers",
	"weapon_skin": &"crosshair",
	"pet_shell": &"paw",
}

var _tab: StringName = &"suit"
var _grid: GridContainer = null
var _tiles_host: VBoxContainer = null
var _preview: UIWardenPreview = null
var _equipped_box: VBoxContainer = null
var _tab_host: HBoxContainer = null


func _compose() -> void:
	var backdrop := UIBackdrop.new()
	backdrop.configure(UIBackdrop.Mood.HUB)
	add_child(backdrop)

	var shell := build_hub_shell(&"locker", "Locker", "")
	var content: VBoxContainer = shell.content

	_tab_host = UIFactory.hbox(UIPalette.SP1)
	content.add_child(_tab_host)

	var body := UIFactory.hbox(UIPalette.SP4)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)

	var preview_scroll := UIFactory.vscroll()
	preview_scroll.custom_minimum_size.x = 372
	preview_scroll.size_flags_horizontal = Control.SIZE_FILL
	preview_scroll.add_child(_build_preview_column())
	body.add_child(preview_scroll)
	body.add_child(_build_tiles_column())
	_refresh()


func _build_preview_column() -> VBoxContainer:
	var column := UIFactory.vbox(UIPalette.SP3)
	column.custom_minimum_size.x = 372
	var preview_head := UIFactory.hbox(UIPalette.SP2)
	preview_head.add_child(UIFactory.icon(&"eye", 13, UIPalette.mint))
	preview_head.add_child(UIFactory.eyebrow("Warden Preview", UIPalette.mint))
	column.add_child(preview_head)
	var card := UIFactory.panel("Card")
	card.custom_minimum_size = Vector2(0, 328)
	_preview = UIWardenPreview.new()
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(_preview)
	_preview.custom_minimum_size = Vector2(0, 316)
	column.add_child(card)

	var equipped := UIFactory.panel("CardInset")
	_equipped_box = UIFactory.vbox(UIPalette.SP2)
	equipped.add_child(_equipped_box)
	column.add_child(equipped)
	column.add_child(UIFactory.help_note(
		"Cosmetic only",
		"Suits set armour plating colour, dyes set trim, skins set weapon accents.",
		&"info"
	))
	return column


func _build_tiles_column() -> VBoxContainer:
	var column := UIFactory.vbox(UIPalette.SP3)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := UIFactory.vscroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tiles_host = UIFactory.vbox(UIPalette.SP3)
	_tiles_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_tiles_host)
	column.add_child(scroll)
	return column


# ---------------------------------------------------------------------------
# Refresh
# ---------------------------------------------------------------------------

func _refresh() -> void:
	if _tiles_host == null or _preview == null:
		return
	_build_tabs()
	UIFactory.clear_children(_tiles_host)
	UIFactory.clear_children(_equipped_box)
	_preview.refresh()
	_refresh_preview_labels()
	var tab_def := _tab_def()
	if tab_def.slot == "":
		_build_salvage_bench()
	else:
		_build_cosmetic_grid(String(tab_def.slot))


func _tab_def() -> Dictionary:
	for entry in TABS:
		if entry.id == _tab:
			return entry
	return TABS[0]


func _tab_for_slot(slot: String) -> Dictionary:
	for entry in TABS:
		if String(entry.slot) == slot:
			return entry
	return TABS[0]


func _cosmetic_icon(slot: String) -> StringName:
	var icon_name: StringName = COSMETIC_ICONS.get(slot, &"star")
	return icon_name


func _build_tabs() -> void:
	if _tab_host == null:
		return
	UIFactory.clear_children(_tab_host)
	for entry in TABS:
		var tab_id: StringName = entry.id
		var button := UIFactory.icon_tab(StringName(entry.icon), String(entry.label), tab_id == _tab)
		button.pressed.connect(func() -> void: _select_tab(tab_id))
		_tab_host.add_child(button)


func _select_tab(tab_id: StringName) -> void:
	if tab_id == _tab:
		return
	_tab = tab_id
	refresh()


func _refresh_preview_labels() -> void:
	if _equipped_box == null:
		return
	var head := UIFactory.hbox(UIPalette.SP2)
	head.add_child(UIFactory.icon(&"check", 12, UIPalette.mint))
	head.add_child(UIFactory.eyebrow("Equipped", UIPalette.mint))
	_equipped_box.add_child(head)
	for slot in ["suit", "dye", "weapon_skin", "pet_shell"]:
		var cosmetic_id := ProfileState.get_equipped_cosmetic(slot)
		var cosmetic := ContentDB.get_cosmetic(StringName(cosmetic_id))
		var color := cosmetic.color if cosmetic != null else UIPalette.muted
		var accent := cosmetic.accent if cosmetic != null else UIPalette.muted_dim
		var row := UIFactory.hbox(UIPalette.SP2)
		row.add_child(UIFactory.medallion(_cosmetic_icon(slot), 26, color, 0.5))
		var name_label := UIFactory.label(cosmetic.display_name if cosmetic != null else "Default", "BodySmall")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var color_chip := ColorRect.new()
		color_chip.color = color
		color_chip.custom_minimum_size = Vector2(18, 18)
		color_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		color_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		color_chip.tooltip_text = "Cosmetic colour"
		row.add_child(color_chip)
		var accent_chip := ColorRect.new()
		accent_chip.color = accent
		accent_chip.custom_minimum_size = Vector2(5, 18)
		accent_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		accent_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(accent_chip)
		row.tooltip_text = slot.replace("_", " ").capitalize()
		_equipped_box.add_child(row)


func _build_cosmetic_grid(slot: String) -> void:
	var tab_def := _tab_for_slot(slot)
	var header := UIFactory.hbox(UIPalette.SP3)
	var title := UIFactory.vbox(2)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(UIFactory.eyebrow("Cosmetics", UIPalette.amber))
	title.add_child(UIFactory.heading(String(tab_def.label), "H2"))
	header.add_child(title)
	var unlocked_row := UIFactory.icon_value(&"check", str(_cosmetics_for_slot(slot).size()), UIPalette.mint, 12)
	unlocked_row.tooltip_text = "Unlocked cosmetics for this slot"
	header.add_child(unlocked_row)
	_tiles_host.add_child(header)

	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", UIPalette.SP3)
	_grid.add_theme_constant_override("v_separation", UIPalette.SP3)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.columns = _grid_columns()
	_tiles_host.add_child(_grid)

	var equipped_id := ProfileState.get_equipped_cosmetic(slot)
	var group := ButtonGroup.new()
	for cosmetic in _cosmetics_for_slot(slot):
		_grid.add_child(_build_cosmetic_tile(cosmetic, group, equipped_id))
	_layout()


func _cosmetics_for_slot(slot: String) -> Array:
	var out: Array = []
	for cosmetic in ContentDB.cosmetics.values():
		if String(cosmetic.slot) == slot:
			out.append(cosmetic)
	return out


func _build_cosmetic_tile(cosmetic: CosmeticData, group: ButtonGroup, equipped_id: String) -> Button:
	var unlocked_list := ProfileState.get_unlocked_cosmetics()
	var unlocked := true
	if not unlocked_list.is_empty():
		unlocked = String(cosmetic.id) in unlocked_list
	var is_equipped := String(cosmetic.id) == equipped_id
	var tile := UIFactory.card_button(true)
	tile.button_group = group
	tile.button_pressed = is_equipped
	tile.custom_minimum_size = Vector2(0, 190)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.disabled = not unlocked
	var unlock_text := cosmetic.unlock_text if not cosmetic.unlock_text.is_empty() else "%s cosmetic" % String(cosmetic.slot).replace("_", " ")
	tile.tooltip_text = _cosmetic_tooltip(cosmetic, unlocked, is_equipped, unlock_text)
	tile.pressed.connect(func() -> void: _equip_cosmetic(String(cosmetic.slot), String(cosmetic.id)))
	var content := UIFactory.card_content(tile)
	if content == null:
		return tile
	_set_content_margins(content, 10, 8, 10, 10)
	var box := UIFactory.vbox(6)
	box.add_child(_cosmetic_preview(cosmetic, is_equipped))

	var name_row := UIFactory.hbox(UIPalette.SP2)
	var name_label := UIFactory.label(cosmetic.display_name, "TitleLabel", UIPalette.ivory if unlocked else UIPalette.muted_dim)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_row.add_child(name_label)
	if is_equipped:
		var equipped_badge := UIFactory.badge("", UIPalette.mint, &"check")
		equipped_badge.tooltip_text = "Equipped"
		name_row.add_child(equipped_badge)
	elif not unlocked:
		var lock_badge := UIFactory.badge("", UIPalette.muted_dim, &"lock")
		lock_badge.tooltip_text = "Locked"
		name_row.add_child(lock_badge)
	box.add_child(name_row)
	content.add_child(box)
	UIFactory.passive_tree(content)
	return tile


func _cosmetic_preview(cosmetic: CosmeticData, is_equipped: bool) -> Control:
	var slot := String(cosmetic.slot)
	match slot:
		"suit", "dye":
			var preview := UIWardenPreview.new()
			preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
			preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
			if slot == "suit":
				preview.configure_preview(
					true,
					cosmetic.color,
					cosmetic.accent,
					Color.TRANSPARENT,
					Color.TRANSPARENT,
					Color.TRANSPARENT,
					Color.TRANSPARENT,
					Color.TRANSPARENT
				)
			else:
				preview.configure_preview(
					true,
					Color.TRANSPARENT,
					cosmetic.accent,
					cosmetic.color,
					Color.TRANSPARENT,
					Color.TRANSPARENT,
					Color.TRANSPARENT,
					Color.TRANSPARENT
				)
			_prepare_preview(preview, Vector2(0, 132))
			return preview
		"weapon_skin":
			var weapon := _preview_weapon()
			var art := UIItemArt.new()
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			art.size_flags_vertical = Control.SIZE_EXPAND_FILL
			art.configure(
				"weapon",
				_weapon_slot_id(weapon),
				String(weapon.id) if weapon != null else "",
				cosmetic.color,
				cosmetic.accent,
				true
			)
			_prepare_preview(art, Vector2(0, 132))
			return _preview_frame(art, cosmetic.color, is_equipped)
		"pet_shell":
			var pet_art := UIPetArt.new()
			pet_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pet_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pet_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
			pet_art.configure(_preview_pet_id(), 112, cosmetic.color, cosmetic.accent)
			_prepare_preview(pet_art, Vector2(0, 132))
			return _preview_frame(pet_art, cosmetic.color, is_equipped)
	return UIFactory.medallion(_cosmetic_icon(slot), 96, cosmetic.color, 0.5)


func _preview_frame(art: Control, accent: Color, selected: bool) -> PanelContainer:
	var frame := UIFactory.art_frame(art, accent, selected)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return frame


func _prepare_preview(control: Control, min_size: Vector2) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if control.is_inside_tree():
		_apply_preview_size(control, min_size)
	else:
		control.ready.connect(_apply_preview_size.bind(control, min_size), CONNECT_ONE_SHOT)


func _apply_preview_size(control: Control, min_size: Vector2) -> void:
	if not is_instance_valid(control):
		return
	control.custom_minimum_size = min_size
	if control is UIWardenPreview:
		control.set_process(false)
		control.refresh()


func _preview_weapon() -> WeaponData:
	var info := ItemFactory.describe(ProfileState.get_equipped_item(&"primary"))
	var equipped: WeaponData = info.get("weapon", null) as WeaponData
	if equipped != null:
		return equipped
	for weapon in ContentDB.weapons.values():
		return weapon as WeaponData
	return null


func _weapon_slot_id(weapon: WeaponData) -> String:
	if weapon == null:
		return "primary"
	return "primary" if String(weapon.slot) == "primary_2" else String(weapon.slot)


func _preview_pet_id() -> StringName:
	var active := ProfileState.get_active_pet()
	if ContentDB.get_pet(active) != null:
		return active
	for pet in ContentDB.pets.values():
		return pet.id
	return &""


func _cosmetic_tooltip(cosmetic: CosmeticData, unlocked: bool, is_equipped: bool, unlock_text: String) -> String:
	var lines: PackedStringArray = [cosmetic.display_name]
	if not cosmetic.description.is_empty():
		lines.append(cosmetic.description)
	lines.append(unlock_text)
	if is_equipped:
		lines.append("Equipped")
	elif not unlocked:
		lines.append("Locked")
	else:
		lines.append("Click to equip")
	return "\n".join(lines)


func _set_content_margins(content: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	content.add_theme_constant_override("margin_left", left)
	content.add_theme_constant_override("margin_top", top)
	content.add_theme_constant_override("margin_right", right)
	content.add_theme_constant_override("margin_bottom", bottom)


func _build_salvage_bench() -> void:
	var header := UIFactory.hbox(UIPalette.SP3)
	var title := UIFactory.vbox(2)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(UIFactory.eyebrow("Salvage Bench", UIPalette.amber))
	title.add_child(UIFactory.heading("Scrap surplus gear", "H2"))
	title.tooltip_text = "Scrapping returns 25% of an item's value. Equipped items must be removed in the Loadout first."
	header.add_child(title)
	var wallet := UIFactory.icon_value(&"coins", UIPalette.format_int(ProfileState.get_salvage()), UIPalette.amber, 13)
	wallet.tooltip_text = "Salvage available"
	header.add_child(wallet)
	_tiles_host.add_child(header)

	var items: Array = ProfileState.get_inventory()
	if items.is_empty():
		_tiles_host.add_child(UIFactory.empty_state(&"backpack", "Locker empty", "Recover gear on a deployment to fill the locker."))
		return
	var equipped_uids: Dictionary = {}
	for slot in StatKeys.EQUIP_SLOTS:
		var uid := ProfileState.get_equipped_uid(slot)
		if uid > 0:
			equipped_uids[uid] = true
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("rarity", 0)) > int(b.get("rarity", 0)))
	for item in items:
		_tiles_host.add_child(_build_salvage_row(item, equipped_uids.has(int(item.get("uid", 0)))))


func _build_salvage_row(item: Dictionary, equipped: bool) -> PanelContainer:
	var info := ItemFactory.describe(item)
	var rarity: Color = info.get("rarity_color", UIPalette.muted)
	var row_panel := UIFactory.panel("RowPanel")
	row_panel.tooltip_text = _salvage_tooltip(info)
	var row := UIFactory.hbox(UIPalette.SP3)
	var rarity_bar := ColorRect.new()
	rarity_bar.color = rarity
	rarity_bar.custom_minimum_size = Vector2(3, 0)
	rarity_bar.size_flags_vertical = Control.SIZE_FILL
	rarity_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rarity_bar)
	row.add_child(_salvage_art(info, rarity))
	row.add_child(UIFactory.label("%s" % info.get("display_name", "Unknown"), "TitleLabel", rarity))
	var level_row := UIFactory.icon_value(&"arrow-up", "L%d" % int(info.get("level", 1)), UIPalette.muted, 11)
	level_row.tooltip_text = "Item level"
	row.add_child(level_row)
	row.add_child(UIFactory.spacer_h())
	var value_row := UIFactory.icon_value(&"coins", UIPalette.format_int(int(info.get("value", 0))), UIPalette.muted, 12)
	value_row.tooltip_text = "Base value"
	row.add_child(value_row)
	if equipped:
		var equipped_badge := UIFactory.badge("", UIPalette.mint, &"check")
		equipped_badge.tooltip_text = "Equipped — unequip in the Loadout first."
		row.add_child(equipped_badge)
	else:
		var scrap_value := maxi(1, int(ItemFactory.item_value(item) * 0.25))
		var scrap_gain := UIFactory.icon_value(&"coins", "+%s" % UIPalette.format_int(scrap_value), UIPalette.amber, 12)
		scrap_gain.tooltip_text = "Salvage recovered"
		row.add_child(scrap_gain)
		var scrap := UIFactory.danger_button("Scrap", &"trash")
		scrap.custom_minimum_size = Vector2(0, 30)
		scrap.pressed.connect(func() -> void: _scrap_item(int(item.get("uid", 0)), scrap_value))
		row.add_child(scrap)
	row_panel.add_child(row)
	return row_panel


func _salvage_art(info: Dictionary, rarity: Color) -> PanelContainer:
	var art := UIItemArt.new()
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.configure(
		String(info.get("kind", "gear")),
		_item_slot_id(String(info.get("slot", ""))),
		String(info.get("base_id", "")),
		rarity,
		_item_art_accent(info),
		true
	)
	art.custom_minimum_size = Vector2(32, 28)
	var frame := UIFactory.art_frame(art, rarity, false)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame


func _item_slot_id(slot: String) -> String:
	return "primary" if slot == "primary_2" else slot


func _item_art_accent(info: Dictionary) -> Color:
	var weapon: WeaponData = info.get("weapon", null) as WeaponData
	if weapon != null:
		return weapon.accent
	var rarity: Color = info.get("rarity_color", UIPalette.muted_dim)
	return UIPalette.mix(rarity, UIPalette.ivory, 0.3)


func _salvage_tooltip(info: Dictionary) -> String:
	var lines: PackedStringArray = [
		"%s · %s · Level %d" % [
			String(info.get("rarity_name", "Common")),
			String(info.get("slot", "")).capitalize(),
			int(info.get("level", 1)),
		],
	]
	var description := String(info.get("description", ""))
	if not description.is_empty():
		lines.append(description)
	return "\n".join(lines)


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _equip_cosmetic(slot: String, cosmetic_id: String) -> void:
	if ProfileState.equip_cosmetic(slot, cosmetic_id):
		AudioDirector.play_ui(&"ui_confirm")
		notify("Cosmetic equipped", "%s is now active." % cosmetic_id.replace("_", " ").capitalize(), &"success")
	else:
		AudioDirector.play_ui(&"ui_error")
		notify("Cannot equip", "That cosmetic is not available for this slot.", &"error")
	refresh()


func _scrap_item(uid: int, value: int) -> void:
	if ProfileState.scrap_item(uid):
		AudioDirector.play_ui(&"ui_confirm")
		notify("Scrapped", "Recovered %s salvage." % UIPalette.format_int(value), &"loot")
	else:
		AudioDirector.play_ui(&"ui_error")
	refresh()


# ---------------------------------------------------------------------------
# Responsive
# ---------------------------------------------------------------------------

func _layout() -> void:
	if _nav_rail != null and is_instance_valid(_nav_rail):
		_nav_rail.custom_minimum_size.x = UIPalette.rail_width(viewport_width())
	if _grid != null and is_instance_valid(_grid):
		_grid.columns = _grid_columns()


func _grid_columns() -> int:
	var available := viewport_width() - UIPalette.rail_width(viewport_width()) - 384.0 - page_padding() * 2.0 - UIPalette.SP5
	if available >= 780.0:
		return 4
	if available >= 560.0:
		return 3
	return 2
