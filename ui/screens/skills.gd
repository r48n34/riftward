class_name SkillsScreen
extends UIScreen
## Discipline, attributes, ability loadout and perk tree. Every interaction
## writes to ProfileState (discipline, attribute points, perks, loadout).

const MechanicUnlocks := preload("res://features/player/mechanic_unlocks.gd")

const DISCIPLINES := [
	{"id": &"vanguard", "name": "Vanguard", "blurb": "Hold the line. Overshield, barriers, seismic force.", "icon": &"shield"},
	{"id": &"infiltrator", "name": "Infiltrator", "blurb": "Break sightlines. Cloak, reposition, strike first.", "icon": &"eye"},
	{"id": &"engineer", "name": "Engineer", "blurb": "Build the fight. Turrets, drones, overclocked weapons.", "icon": &"outpost"},
	{"id": &"pathfinder", "name": "Pathfinder", "blurb": "Read the Reach. Scan, gravity, precision damage.", "icon": &"target"},
]

const ATTRIBUTES := [
	{"id": &"power", "name": "Power", "icon": &"bolt", "blurb": "Weapon damage and ability power."},
	{"id": &"resolve", "name": "Resolve", "icon": &"heart", "blurb": "Health, shield and armour."},
	{"id": &"agility", "name": "Agility", "icon": &"arrow-up", "blurb": "Movement, handling and crit chance."},
	{"id": &"tech", "name": "Tech", "icon": &"crosshair", "blurb": "Cooldowns, status effects and luck."},
]

var _points_box: VBoxContainer = null
var _mechanics_host: VBoxContainer = null
var _discipline_host: HBoxContainer = null
var _attributes_host: VBoxContainer = null
var _loadout_host: VBoxContainer = null
var _abilities_host: VBoxContainer = null
var _perks_host: HBoxContainer = null


func _compose() -> void:
	var backdrop := UIBackdrop.new()
	backdrop.configure(UIBackdrop.Mood.HUB)
	add_child(backdrop)

	var shell := build_hub_shell(&"skills", "Skills & Discipline", "")
	var content: VBoxContainer = shell.content

	var scroll := UIFactory.vscroll()
	content.add_child(scroll)
	var body := UIFactory.scroll_content(scroll)
	body.add_theme_constant_override("separation", UIPalette.SP4)

	_points_box = UIFactory.vbox(0)
	body.add_child(_points_box)

	_mechanics_host = UIFactory.vbox(0)
	body.add_child(_mechanics_host)

	_discipline_host = UIFactory.hbox(UIPalette.SP3)
	body.add_child(_discipline_host)

	var middle := UIFactory.hbox(UIPalette.SP4)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(middle)
	middle.add_child(_build_attributes_column())
	middle.add_child(_build_ability_column())

	body.add_child(_build_perk_column())
	_refresh()


func _build_attributes_column() -> VBoxContainer:
	var column := UIFactory.vbox(UIPalette.SP3)
	column.custom_minimum_size.x = 430
	column.add_child(UIFactory.section_header("Attributes", "Warden Core"))
	var card := UIFactory.panel("Card")
	_attributes_host = UIFactory.vbox(UIPalette.SP2)
	card.add_child(_attributes_host)
	column.add_child(card)
	return column


func _build_ability_column() -> VBoxContainer:
	var column := UIFactory.vbox(UIPalette.SP3)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(UIFactory.section_header("Ability Loadout", "Active Kit"))
	var row := UIFactory.hbox(UIPalette.SP4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var loadout_card := UIFactory.panel("CardInset")
	loadout_card.custom_minimum_size.x = 232
	_loadout_host = UIFactory.vbox(UIPalette.SP3)
	loadout_card.add_child(_loadout_host)
	row.add_child(loadout_card)

	var pool_card := UIFactory.panel("Card")
	pool_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := UIFactory.vscroll()
	scroll.custom_minimum_size.y = 258
	_abilities_host = UIFactory.vbox(UIPalette.SP2)
	_abilities_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_abilities_host)
	pool_card.add_child(scroll)
	row.add_child(pool_card)
	column.add_child(row)
	return column


func _build_perk_column() -> VBoxContainer:
	var column := UIFactory.vbox(UIPalette.SP3)
	column.add_child(UIFactory.section_header("Perk Tree", "Discipline Paths"))
	var card := UIFactory.panel("Card")
	var scroll := UIFactory.hscroll()
	scroll.custom_minimum_size.y = 218
	_perks_host = UIFactory.hbox(UIPalette.SP2)
	_perks_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_perks_host)
	card.add_child(scroll)
	column.add_child(card)
	return column


# ---------------------------------------------------------------------------
# Refresh
# ---------------------------------------------------------------------------

func _refresh() -> void:
	if _points_box == null:
		return
	_build_points()
	_build_mechanics()
	_build_disciplines()
	_build_attributes()
	_build_loadout()
	_build_abilities()
	_build_perks()


func _build_points() -> void:
	UIFactory.clear_children(_points_box)
	var card := UIFactory.panel("CardInset")
	card.tooltip_text = "Each Warden level grants 1 skill point and 2 attribute points. Respec is not available in this build."
	var box := UIFactory.vbox(UIPalette.SP2)
	var row := UIFactory.hbox(UIPalette.SP5)
	row.add_child(UIFactory.stat_block(&"star", "Skill points", str(ProfileState.get_skill_points()), UIPalette.mint, 22))
	row.add_child(UIFactory.v_divider(UIPalette.line))
	row.add_child(UIFactory.stat_block(&"arrow-up", "Attribute points", str(ProfileState.get_attribute_points()), UIPalette.amber, 22))
	row.add_child(UIFactory.v_divider(UIPalette.line))
	row.add_child(UIFactory.stat_block(&"shield", "Warden level", str(ProfileState.get_level()), UIPalette.ivory, 22))
	row.add_child(UIFactory.v_divider(UIPalette.line))
	row.add_child(UIFactory.stat_block(&"users", "Perks acquired", str(ProfileState.get_skill_ranks().size()), UIPalette.violet, 22))
	row.add_child(UIFactory.spacer_h())
	box.add_child(row)

	var xp_target := ProfileState.get_xp_for_next_level()
	var xp_row := UIFactory.hbox(UIPalette.SP3)
	var xp_caption := UIFactory.icon_value(&"arrow-up", "XP", UIPalette.mint, 12)
	xp_caption.tooltip_text = "Warden XP"
	xp_row.add_child(xp_caption)
	var xp_bar := UIFactory.progress(ProfileState.get_xp_ratio() * 100.0, 100.0, "BarMint", 6)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.tooltip_text = "Warden XP" if xp_target <= 0 else "%d XP to level %d" % [maxi(0, xp_target - ProfileState.get_xp()), ProfileState.get_level() + 1]
	xp_row.add_child(xp_bar)
	var xp_text := "MAX" if xp_target <= 0 else "%d / %d" % [ProfileState.get_xp(), xp_target]
	var xp_value := UIFactory.label(xp_text, "MonoSmall", UIPalette.muted)
	xp_value.tooltip_text = "Warden XP"
	xp_row.add_child(xp_value)
	box.add_child(xp_row)

	var next_unlock := ProfileState.get_next_mechanic_unlock()
	if not next_unlock.is_empty():
		var next_row := UIFactory.icon_value(
			&"lock",
			"%s · L%d" % [String(next_unlock.get("name", "Mechanic")), int(next_unlock.get("level", 1))],
			UIPalette.amber,
			12
		)
		next_row.tooltip_text = "Next mechanic unlocks at Warden level %d." % int(next_unlock.get("level", 1))
		box.add_child(next_row)
	card.add_child(box)
	_points_box.add_child(card)


func _build_mechanics() -> void:
	if _mechanics_host == null:
		return
	UIFactory.clear_children(_mechanics_host)
	var section := UIFactory.vbox(UIPalette.SP2)
	section.add_child(UIFactory.section_header("Field Training", "Level Unlocks"))
	var card := UIFactory.panel("Card")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UIPalette.SP3)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for mechanic in MechanicUnlocks.ALL:
		var mechanic_id := StringName(mechanic.get("id", &""))
		var unlocked := ProfileState.is_mechanic_unlocked(mechanic_id)
		var row := UIFactory.panel("RowPanel")
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.tooltip_text = String(mechanic.get("description", ""))
		var box := UIFactory.hbox(UIPalette.SP2)
		var glyph := UIFactory.icon_or_null(_icon_for(StringName(mechanic.get("icon", &"bolt"))), 15, UIPalette.mint if unlocked else UIPalette.muted_dim)
		if glyph != null:
			box.add_child(glyph)
		var name_label := UIFactory.label(String(mechanic.get("name", "Mechanic")), "BodySmall", UIPalette.ivory if unlocked else UIPalette.muted_dim)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(name_label)
		if unlocked:
			box.add_child(UIFactory.icon(&"check", 14, UIPalette.mint))
		else:
			box.add_child(UIFactory.icon(&"lock", 12, UIPalette.muted_dim))
			box.add_child(UIFactory.label("L%d" % int(mechanic.get("level", 1)), "MonoSmall", UIPalette.amber))
		row.add_child(box)
		grid.add_child(row)
	card.add_child(grid)
	section.add_child(card)
	_mechanics_host.add_child(section)


## Content icon ids sometimes use abstract names; fall back through the shared
## ability-icon map, then to a neutral glyph.
func _icon_for(icon_name: StringName) -> StringName:
	if UIIcons.has_icon(icon_name):
		return icon_name
	return UIIcons.ability_icon(icon_name)


func _build_disciplines() -> void:
	UIFactory.clear_children(_discipline_host)
	var current := ProfileState.get_discipline()
	var group := ButtonGroup.new()
	for entry in DISCIPLINES:
		var discipline_id: StringName = entry.id
		var selected := discipline_id == current
		var accent := UIPalette.discipline_color(discipline_id)
		var card := UIFactory.card_button(true)
		card.button_group = group
		card.button_pressed = selected
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 84)
		card.tooltip_text = String(entry.blurb)
		card.pressed.connect(func() -> void: _set_discipline(discipline_id))
		var content := UIFactory.card_content(card)
		if content == null:
			continue
		var box := UIFactory.vbox(UIPalette.SP1)
		var head := UIFactory.hbox(UIPalette.SP2)
		var glyph := UIFactory.icon_or_null(StringName(entry.icon), 18, accent)
		if glyph != null:
			glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			head.add_child(glyph)
		var name_label := UIFactory.display_text(String(entry.name).to_upper(), 17, 650, accent)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		if selected:
			head.add_child(UIFactory.icon(&"check", 15, accent))
		box.add_child(head)
		content.add_child(box)
		UIFactory.passive_tree(content)
		_discipline_host.add_child(card)


func _build_attributes() -> void:
	UIFactory.clear_children(_attributes_host)
	var attributes := ProfileState.get_attributes()
	var points := ProfileState.get_attribute_points()
	for entry in ATTRIBUTES:
		var attr_id: StringName = entry.id
		var row := UIFactory.hbox(UIPalette.SP3)
		row.tooltip_text = String(entry.blurb)
		var glyph := UIFactory.icon_or_null(StringName(entry.icon), 18, UIPalette.mint)
		if glyph != null:
			glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(glyph)
		var name_label := UIFactory.label(String(entry.name), "TitleLabel")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var value := UIFactory.number_text(str(int(attributes.get(String(attr_id), 1))), 22, UIPalette.ivory)
		value.custom_minimum_size.x = 44
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		var plus := UIFactory.icon_button(&"plus", "Spend an attribute point on %s." % String(entry.name), "SecondaryButton", 34)
		plus.disabled = points <= 0
		plus.add_theme_color_override("icon_normal_color", UIPalette.mint)
		plus.add_theme_color_override("icon_hover_color", UIPalette.ivory)
		plus.add_theme_color_override("icon_focus_color", UIPalette.mint)
		plus.pressed.connect(func() -> void: _spend_attribute(attr_id))
		row.add_child(plus)
		_attributes_host.add_child(row)
		_attributes_host.add_child(UIFactory.divider(UIPalette.line_soft))


func _build_loadout() -> void:
	UIFactory.clear_children(_loadout_host)
	var equipped_head := UIFactory.hbox(UIPalette.SP2)
	equipped_head.add_child(UIFactory.icon(&"backpack", 13, UIPalette.mint))
	equipped_head.add_child(UIFactory.eyebrow("Equipped", UIPalette.mint))
	_loadout_host.add_child(equipped_head)
	var loadout := ProfileState.get_ability_loadout()
	for index in 2:
		var slot := UIFactory.vbox(3)
		var slot_badge := UIFactory.badge(str(index + 1), UIPalette.muted)
		slot_badge.tooltip_text = "Ability slot %d" % (index + 1)
		slot.add_child(slot_badge)
		var ability: AbilityData = null
		if index < loadout.size():
			ability = ContentDB.get_ability(loadout[index])
		slot.add_child(_loadout_slot(ability, index))
		_loadout_host.add_child(slot)
	_loadout_host.add_child(UIFactory.divider(UIPalette.line_soft))
	var ult_head := UIFactory.hbox(UIPalette.SP2)
	ult_head.add_child(UIFactory.icon(&"star", 13, UIPalette.amber))
	ult_head.add_child(UIFactory.eyebrow("Ultimate", UIPalette.amber))
	_loadout_host.add_child(ult_head)
	var ultimate := ProfileState.get_equipped_ultimate()
	if ultimate != null:
		var ult_card := UIFactory.tone_panel(ultimate.color, UIPalette.R_MD)
		ult_card.add_theme_stylebox_override(
			"panel",
			UITheme._box(UIPalette.alpha(ultimate.color, 0.08), UIPalette.alpha(ultimate.color, 0.45), UIPalette.R_MD, 1, Vector4(12, 9, 12, 9))
		)
		ult_card.tooltip_text = "Bound to your discipline"
		var ult_box := UIFactory.vbox(2)
		var ult_row := UIFactory.hbox(UIPalette.SP2)
		ult_row.add_child(UIFactory.icon(UIIcons.ability_icon(ultimate.icon), 15, ultimate.color))
		ult_row.add_child(UIFactory.label(ultimate.display_name, "TitleLabel", ultimate.color))
		ult_box.add_child(ult_row)
		ult_card.add_child(ult_box)
		_loadout_host.add_child(ult_card)
	else:
		_loadout_host.add_child(UIFactory.label("None", "BodySmall"))


func _loadout_slot(ability: AbilityData, index: int) -> PanelContainer:
	var card := UIFactory.panel("CardInset")
	if ability == null:
		card.add_child(UIFactory.empty_state(&"plus", "Empty", "Assign from the pool."))
		return card
	var box := UIFactory.vbox(5)
	var head := UIFactory.hbox(UIPalette.SP2)
	head.add_child(UIFactory.icon(UIIcons.ability_icon(ability.icon), 16, ability.color))
	head.add_child(UIFactory.label(ability.display_name, "TitleLabel", ability.color))
	box.add_child(head)
	var cd_row := UIFactory.icon_value(&"timer", "%.0fs" % ability.cooldown, UIPalette.muted, 12)
	cd_row.tooltip_text = "Cooldown"
	box.add_child(cd_row)
	var remove := UIFactory.inline_button("Remove", &"close")
	remove.pressed.connect(func() -> void: _remove_ability(index))
	box.add_child(remove)
	card.add_child(box)
	return card


func _build_abilities() -> void:
	UIFactory.clear_children(_abilities_host)
	var loadout := ProfileState.get_ability_loadout()
	var abilities: Array[AbilityData] = []
	for ability in ContentDB.abilities.values():
		if not ability.is_ultimate:
			abilities.append(ability)
	abilities.sort_custom(func(a: AbilityData, b: AbilityData) -> bool: return a.unlock_level < b.unlock_level)
	for ability in abilities:
		var unlocked := ProfileState.is_ability_unlocked(ability.id)
		var slot_index := loadout.find(ability.id)
		var row := UIFactory.panel("RowPanel")
		row.tooltip_text = ability.description
		var box := UIFactory.hbox(UIPalette.SP3)
		var glyph := UIFactory.icon(UIIcons.ability_icon(ability.icon), 18, ability.color if unlocked else UIPalette.muted_dim)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(glyph)
		var text := UIFactory.vbox(2)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_row := UIFactory.hbox(UIPalette.SP2)
		name_row.add_child(UIFactory.label(ability.display_name, "TitleLabel", UIPalette.ivory if unlocked else UIPalette.muted_dim))
		if slot_index >= 0:
			var slot_badge := UIFactory.badge(str(slot_index + 1), ability.color)
			slot_badge.tooltip_text = "Assigned to ability slot %d" % (slot_index + 1)
			name_row.add_child(slot_badge)
		text.add_child(name_row)
		var meta_row := UIFactory.hbox(UIPalette.SP3)
		var cd_row := UIFactory.icon_value(&"timer", "%.0fs" % ability.cooldown, UIPalette.muted, 11)
		cd_row.tooltip_text = "Cooldown"
		meta_row.add_child(cd_row)
		var discipline_row := UIFactory.icon_value(&"shield", String(ability.discipline).capitalize(), UIPalette.muted, 11)
		discipline_row.tooltip_text = "Discipline"
		meta_row.add_child(discipline_row)
		if not unlocked:
			var lock_row := UIFactory.icon_value(&"lock", "L%d" % ability.unlock_level, UIPalette.amber, 11)
			lock_row.tooltip_text = "Unlocks at Warden level %d" % ability.unlock_level
			meta_row.add_child(lock_row)
		text.add_child(meta_row)
		box.add_child(text)
		if unlocked:
			if slot_index >= 0:
				var remove := UIFactory.ghost_button("Remove")
				remove.custom_minimum_size = Vector2(0, 30)
				remove.pressed.connect(func() -> void: _remove_ability(slot_index))
				box.add_child(remove)
			else:
				var assign := UIFactory.secondary_button("Assign")
				assign.custom_minimum_size = Vector2(0, 30)
				assign.pressed.connect(func() -> void: _assign_ability(ability.id))
				box.add_child(assign)
		else:
			box.add_child(UIFactory.icon(&"lock", 16, UIPalette.muted_dim))
		row.add_child(box)
		_abilities_host.add_child(row)


func _build_perks() -> void:
	if _perks_host == null:
		return
	UIFactory.clear_children(_perks_host)
	var discipline := ProfileState.get_discipline()
	var perks: Array[PerkData] = ContentDB.get_perks_for_discipline(discipline)
	if perks.is_empty():
		_perks_host.add_child(UIFactory.empty_state(&"shield", "No perks", "ContentDB has no perks for this discipline yet."))
		return
	var owned := ProfileState.get_skill_ranks()
	var accent := UIPalette.discipline_color(discipline)
	for index in perks.size():
		var perk := perks[index]
		var is_owned := owned.has(String(perk.id))
		var can_buy := ProfileState.can_buy_perk(perk.id)
		var level_ok := ProfileState.get_level() >= perk.unlock_level
		var requires_owned := perk.requires == &"" or owned.has(String(perk.requires))
		var column := UIFactory.vbox(UIPalette.SP2)
		column.custom_minimum_size.x = 232
		var card := UIFactory.panel("CardInset")
		card.tooltip_text = perk.description
		var box := UIFactory.vbox(5)

		# Tier pips only, with lock/level icon state. No "TIER x · LV y" text.
		var tier_row := UIFactory.hbox(UIPalette.SP2)
		var tier_pips := UIFactory.pips(perk.tier, 4, perk.color, 6)
		tier_pips.tooltip_text = "Tier %d" % perk.tier
		tier_row.add_child(tier_pips)
		tier_row.add_child(UIFactory.spacer_h())
		if not level_ok:
			var gate_row := UIFactory.icon_value(&"lock", "L%d" % perk.unlock_level, UIPalette.amber, 11)
			gate_row.tooltip_text = "Unlocks at Warden level %d" % perk.unlock_level
			tier_row.add_child(gate_row)
		box.add_child(tier_row)

		var name_row := UIFactory.hbox(UIPalette.SP2)
		var perk_glyph := UIFactory.icon_or_null(UIIcons.ability_icon(perk.icon), 15, perk.color if is_owned else UIPalette.muted_dim)
		if perk_glyph != null:
			perk_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			name_row.add_child(perk_glyph)
		name_row.add_child(UIFactory.label(perk.display_name, "TitleLabel", ivory_or(perk.color, is_owned)))
		name_row.add_child(UIFactory.spacer_h())
		if is_owned:
			name_row.add_child(UIFactory.icon(&"check", 15, UIPalette.mint))
		box.add_child(name_row)
		box.add_child(UIFactory.label(UIPalette.format_stat_value(perk.stat, perk.value), "MonoSmall", perk.color))

		if is_owned:
			pass
		elif not level_ok:
			pass
		elif can_buy:
			var buy := UIFactory.primary_button("Learn", &"star")
			buy.custom_minimum_size = Vector2(0, 32)
			buy.tooltip_text = "Spend 1 skill point to learn %s." % perk.display_name
			buy.pressed.connect(func() -> void: _buy_perk(perk.id))
			box.add_child(buy)
		elif not requires_owned:
			var requires_row := UIFactory.icon_value(&"lock", String(perk.requires).replace("perk_", "").capitalize(), UIPalette.muted_dim, 11)
			requires_row.tooltip_text = "Requires this earlier perk."
			box.add_child(requires_row)
		else:
			var no_points := UIFactory.icon_value(&"star", "0", UIPalette.muted_dim, 11)
			no_points.tooltip_text = "No skill points available"
			box.add_child(no_points)
		card.add_child(box)
		column.add_child(card)
		_perks_host.add_child(column)
		if index < perks.size() - 1:
			var connector := UIFactory.vbox(0)
			connector.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var arrow := UIFactory.icon(&"chevron-right", 20, UIPalette.alpha(accent, 0.6))
			arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			connector.add_child(arrow)
			_perks_host.add_child(connector)


func ivory_or(color: Color, owned: bool) -> Color:
	return color if owned else UIPalette.muted


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _set_discipline(discipline_id: StringName) -> void:
	if discipline_id == ProfileState.get_discipline():
		return
	if ProfileState.set_discipline(discipline_id):
		AudioDirector.play_ui(&"ui_confirm")
		notify("Discipline committed", "Ultimate and starting loadout updated for %s." % String(discipline_id).capitalize(), &"success")
	refresh()


func _spend_attribute(attribute_id: StringName) -> void:
	if ProfileState.spend_attribute_point(attribute_id):
		AudioDirector.play_ui(&"ui_confirm")
		refresh()
	else:
		AudioDirector.play_ui(&"ui_error")
		notify("No points available", "Earn attribute points by levelling your Warden.", &"warning")


func _assign_ability(ability_id: StringName) -> void:
	var loadout := ProfileState.get_ability_loadout()
	if loadout.has(ability_id):
		return
	var next: Array = []
	for id in loadout:
		next.append(String(id))
	next.append(String(ability_id))
	if next.size() > 2:
		next = next.slice(next.size() - 2, next.size())
	if ProfileState.set_ability_loadout(next):
		AudioDirector.play_ui(&"ui_confirm")
		refresh()


func _remove_ability(index: int) -> void:
	var loadout := ProfileState.get_ability_loadout()
	if index < 0 or index >= loadout.size():
		return
	var next: Array = []
	for i in loadout.size():
		if i != index:
			next.append(String(loadout[i]))
	if next.is_empty():
		notify("Loadout needs one ability", "Assign a replacement before removing your last ability.", &"warning")
		return
	if ProfileState.set_ability_loadout(next):
		AudioDirector.play_ui(&"ui_click")
		refresh()


func _buy_perk(perk_id: StringName) -> void:
	if ProfileState.buy_perk(perk_id):
		AudioDirector.play_ui(&"ui_confirm")
		var perk := ContentDB.get_perk(perk_id)
		notify("Perk acquired", "%s is now active." % (perk.display_name if perk != null else String(perk_id)), &"success")
		refresh()
	else:
		AudioDirector.play_ui(&"ui_error")
		notify("Cannot learn perk", "Requires a skill point and the preceding perk.", &"error")


func _layout() -> void:
	if _nav_rail != null and is_instance_valid(_nav_rail):
		_nav_rail.custom_minimum_size.x = UIPalette.rail_width(viewport_width())
