class_name SquadScreen
extends UIScreen
## Squad management: two active Wardens plus one Driftling companion. Assignment
## and rank upgrades go through ProfileState so deployment reads the same data.

var _active_host: HBoxContainer = null
var _wardens_host: GridContainer = null
var _pets_host: HBoxContainer = null
var _header_host: VBoxContainer = null


func _compose() -> void:
	var backdrop := UIBackdrop.new()
	backdrop.configure(UIBackdrop.Mood.HUB)
	add_child(backdrop)

	var shell := build_hub_shell(&"squad", "Squad", "")
	var content: VBoxContainer = shell.content

	var scroll := UIFactory.vscroll()
	content.add_child(scroll)
	var body := UIFactory.scroll_content(scroll)
	body.add_theme_constant_override("separation", UIPalette.SP4)

	_header_host = UIFactory.vbox(UIPalette.SP3)
	body.add_child(_header_host)

	_active_host = UIFactory.hbox(UIPalette.SP3)
	_active_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_active_host)

	var warden_header := UIFactory.section_header("Wardens", "", _assigned_chip(), &"users")
	warden_header.tooltip_text = "Assign up to 2 Wardens to your deployment. Higher ranks improve their combat behaviour."
	body.add_child(warden_header)

	_wardens_host = GridContainer.new()
	_wardens_host.add_theme_constant_override("h_separation", UIPalette.SP4)
	_wardens_host.add_theme_constant_override("v_separation", UIPalette.SP4)
	_wardens_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_wardens_host)

	var pet_header := UIFactory.section_header("Driftlings", "", _companion_chip(), &"paw")
	pet_header.tooltip_text = "One active companion. Upgrades cost cores."
	body.add_child(pet_header)

	_pets_host = UIFactory.hbox(UIPalette.SP4)
	_pets_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_pets_host)
	body.add_child(UIFactory.fixed_spacer(0, UIPalette.SP4))
	_refresh()


func _assigned_chip() -> HBoxContainer:
	var row := UIFactory.icon_value(&"users", "%d/2" % ProfileState.get_active_allies().size(), UIPalette.mint, 12)
	row.tooltip_text = "Wardens assigned"
	return row


func _companion_chip() -> HBoxContainer:
	var has_pet := ProfileState.get_active_pet() != &""
	var row := UIFactory.icon_value(&"paw", "1/1" if has_pet else "0/1", UIPalette.amber, 12)
	row.tooltip_text = "Companion assigned"
	return row


func _refresh() -> void:
	if _active_host == null:
		return
	UIFactory.clear_children(_header_host)
	UIFactory.clear_children(_active_host)
	UIFactory.clear_children(_wardens_host)
	UIFactory.clear_children(_pets_host)
	_build_header()
	_build_active_strip()
	_build_wardens()
	_build_pets()
	_layout()


func _build_header() -> void:
	var card := UIFactory.panel("CardInset")
	card.tooltip_text = "Wardens bring their own weapon and signature ability. Higher ranks improve their combat behaviour."
	var row := UIFactory.hbox(UIPalette.SP5)
	row.add_child(_medallion_stat(&"users", "Active Wardens", "%d/2" % ProfileState.get_active_allies().size(), UIPalette.mint))
	var pet := ContentDB.get_pet(ProfileState.get_active_pet())
	row.add_child(_medallion_stat(&"paw", "Companion", pet.display_name if pet != null else "None", UIPalette.amber))
	row.add_child(_medallion_stat(&"core", "Cores available", UIPalette.format_int(ProfileState.get_cores()), UIPalette.violet))
	row.add_child(_medallion_stat(&"shield", "Barracks", "T%d" % ProfileState.get_base_tier(&"barracks"), UIPalette.blue))
	row.add_child(UIFactory.spacer_h())
	card.add_child(row)
	_header_host.add_child(card)


func _medallion_stat(icon_name: StringName, label_text: String, value_text: String, accent: Color) -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP2)
	row.tooltip_text = label_text
	row.add_child(UIFactory.medallion(icon_name, 32, accent, 0.5))
	var text := UIFactory.vbox(2)
	text.add_child(UIFactory.label(label_text.to_upper(), "StatLabel"))
	text.add_child(UIFactory.number_text(value_text, 18, accent))
	row.add_child(text)
	return row


func _build_active_strip() -> void:
	var active := ProfileState.get_active_allies()
	for index in 2:
		var ally: AllyData = null
		if index < active.size():
			ally = ContentDB.get_ally(active[index])
		_active_host.add_child(_active_slot_card(ally, index))
	var pet_slot := _active_pet_card()
	pet_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_host.add_child(pet_slot)


func _slot_badge(index: int) -> PanelContainer:
	var badge := UIFactory.badge(str(index + 1), UIPalette.muted)
	badge.tooltip_text = "Squad slot %d" % (index + 1)
	return badge


func _active_slot_card(ally: AllyData, index: int) -> PanelContainer:
	var card := UIFactory.panel("Card")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 200)
	var box := UIFactory.vbox(UIPalette.SP2)
	var top := UIFactory.hbox(UIPalette.SP2)
	top.add_child(_slot_badge(index))
	top.add_child(UIFactory.spacer_h())
	box.add_child(top)
	if ally == null:
		var empty := _empty_portrait(&"users", "Empty", "Assign a Warden below.", UIPalette.muted_dim)
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(empty)
		card.add_child(box)
		return card
	var accent := ally.color
	var row := UIFactory.hbox(UIPalette.SP3)
	var portrait := _ally_portrait(ally, 92)
	row.add_child(UIFactory.art_frame(portrait, accent, true))
	var text := UIFactory.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := UIFactory.hbox(UIPalette.SP2)
	var name_label := UIFactory.display_text(ally.display_name, 22, 600, accent)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_row.add_child(name_label)
	name_row.add_child(UIFactory.badge(String(ally.role).capitalize(), accent))
	text.add_child(name_row)
	var weapon := ContentDB.get_weapon(ally.weapon_id)
	var ability := ContentDB.get_ability(ally.ability_effect)
	text.add_child(_weapon_row(weapon, accent))
	text.add_child(_ability_row(ability, accent))
	text.add_child(UIFactory.spacer_v())
	var footer := UIFactory.hbox(UIPalette.SP2)
	var rank_pips := UIFactory.pips(ProfileState.get_ally_rank(ally.id), 5, accent)
	rank_pips.tooltip_text = "Warden rank %d / 5" % ProfileState.get_ally_rank(ally.id)
	footer.add_child(rank_pips)
	footer.add_child(UIFactory.spacer_h())
	var remove := UIFactory.ghost_button("Stand down", &"close")
	remove.custom_minimum_size = Vector2(0, 30)
	remove.disabled = ProfileState.get_active_allies().size() <= 1
	remove.tooltip_text = "Stand %s down. At least one Warden must remain on active duty." % ally.display_name
	remove.pressed.connect(func() -> void: _remove_ally(ally.id))
	footer.add_child(remove)
	text.add_child(footer)
	row.add_child(text)
	box.add_child(row)
	card.add_child(box)
	return card


func _active_pet_card() -> PanelContainer:
	var card := UIFactory.panel("Card")
	card.custom_minimum_size = Vector2(0, 200)
	var box := UIFactory.vbox(UIPalette.SP2)
	var top := UIFactory.hbox(UIPalette.SP2)
	var slot_badge := UIFactory.badge("", UIPalette.muted, &"paw")
	slot_badge.tooltip_text = "Companion slot"
	top.add_child(slot_badge)
	top.add_child(UIFactory.spacer_h())
	box.add_child(top)
	var pet := ContentDB.get_pet(ProfileState.get_active_pet())
	if pet == null:
		box.add_child(_empty_portrait(&"paw", "No companion", "Select a Driftling below.", UIPalette.muted_dim))
		card.add_child(box)
		return card
	var accent := pet.color
	card.tooltip_text = pet.description
	var row := UIFactory.hbox(UIPalette.SP3)
	row.add_child(UIFactory.art_frame(_pet_portrait(pet, 92), accent, true))
	var text := UIFactory.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := UIFactory.hbox(UIPalette.SP2)
	var name_label := UIFactory.display_text(pet.display_name, 22, 600, accent)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_row.add_child(name_label)
	name_row.add_child(UIFactory.badge(String(pet.role).capitalize(), accent))
	text.add_child(name_row)
	var effect_row := UIFactory.icon_value(&"bolt", String(pet.effect).replace("_", " ").capitalize(), accent, 12)
	effect_row.tooltip_text = "Ability effect"
	text.add_child(effect_row)
	var cooldown_row := UIFactory.icon_value(&"timer", "%.0fs" % pet.cooldown, UIPalette.muted, 12)
	cooldown_row.tooltip_text = "Ability cooldown"
	text.add_child(cooldown_row)
	text.add_child(UIFactory.spacer_v())
	var footer := UIFactory.hbox(UIPalette.SP2)
	var rank_pips := UIFactory.pips(ProfileState.get_pet_rank(pet.id), 5, accent)
	rank_pips.tooltip_text = "Companion rank %d / 5" % ProfileState.get_pet_rank(pet.id)
	footer.add_child(rank_pips)
	footer.add_child(UIFactory.spacer_h())
	footer.add_child(UIFactory.label("ACTIVE", "Micro", UIPalette.mint))
	text.add_child(footer)
	row.add_child(text)
	box.add_child(row)
	card.add_child(box)
	return card


func _empty_portrait(icon_name: StringName, title_text: String, hint_text: String, accent: Color) -> VBoxContainer:
	var box := UIFactory.vbox(UIPalette.SP2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var placeholder := UIFactory.medallion(icon_name, 84, accent, 0.45, false)
	placeholder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(placeholder)
	var title := UIFactory.label(title_text, "TitleLabel", UIPalette.muted_dim)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var hint := UIFactory.label(hint_text, "Micro", UIPalette.muted_dim)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	return box


func _ally_portrait(ally: AllyData, diameter: int) -> UIAllyPortrait:
	var portrait := UIAllyPortrait.new()
	portrait.configure(ally.id, diameter)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hold_art_size(portrait, Vector2(diameter, diameter))
	return portrait


func _pet_portrait(pet: PetData, diameter: int) -> UIPetArt:
	var portrait := UIPetArt.new()
	portrait.configure(pet.id, diameter)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hold_art_size(portrait, Vector2(diameter, diameter))
	return portrait


func _weapon_row(weapon: WeaponData, accent: Color) -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP2)
	row.tooltip_text = "Weapon"
	var art := UIItemArt.new()
	art.configure(
		"weapon",
		_weapon_slot_id(weapon),
		String(weapon.id) if weapon != null else "",
		UIPalette.muted_dim,
		accent,
		true
	)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hold_art_size(art, Vector2(30, 24))
	row.add_child(art)
	var name_label := UIFactory.label(weapon.display_name if weapon != null else "Unknown weapon", "BodySmall", UIPalette.muted)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	return row


func _ability_row(ability: AbilityData, accent: Color) -> HBoxContainer:
	var row := UIFactory.hbox(UIPalette.SP2)
	row.tooltip_text = "Signature ability"
	if ability == null:
		row.add_child(UIFactory.label("No signature ability", "BodySmall", UIPalette.muted_dim))
		return row
	row.add_child(UIFactory.medallion(UIIcons.ability_icon(ability.icon), 24, ability.color, 0.5))
	var name_label := UIFactory.label(ability.display_name, "BodySmall", ability.color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	var cooldown := UIFactory.icon_value(&"timer", "%.0fs" % ability.cooldown, UIPalette.muted, 11)
	cooldown.tooltip_text = "Ability cooldown"
	row.add_child(cooldown)
	return row


func _weapon_slot_id(weapon: WeaponData) -> String:
	if weapon == null:
		return "primary"
	return "primary" if String(weapon.slot) == "primary_2" else String(weapon.slot)


func _hold_art_size(control: Control, min_size: Vector2) -> void:
	control.custom_minimum_size = min_size
	if control.is_inside_tree():
		control.custom_minimum_size = min_size
	else:
		control.ready.connect(_apply_art_size.bind(control, min_size), CONNECT_ONE_SHOT)


func _apply_art_size(control: Control, min_size: Vector2) -> void:
	if is_instance_valid(control):
		control.custom_minimum_size = min_size


func _build_wardens() -> void:
	var allies: Array = ContentDB.allies.values()
	allies.sort_custom(func(a: AllyData, b: AllyData) -> bool: return String(a.display_name) < String(b.display_name))
	for ally in allies:
		_wardens_host.add_child(_warden_card(ally))


func _warden_card(ally: AllyData) -> PanelContainer:
	var accent := ally.color
	var active := ProfileState.get_active_allies().has(ally.id)
	var rank := ProfileState.get_ally_rank(ally.id)
	var card := UIFactory.panel("Card")
	card.custom_minimum_size = Vector2(0, 204)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = String(ally.description) + "\n" + String(ally.passive_text)
	var row := UIFactory.hbox(UIPalette.SP3)

	var portrait_frame := UIFactory.art_frame(_ally_portrait(ally, 64), accent, active)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(portrait_frame)

	var box := UIFactory.vbox(UIPalette.SP2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UIFactory.hbox(UIPalette.SP2)
	var name_label := UIFactory.display_text(ally.display_name, 22, 600, UIPalette.ivory)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(name_label)
	if active:
		var active_badge := UIFactory.badge("", UIPalette.mint, &"check")
		active_badge.tooltip_text = "Active in your squad"
		head.add_child(active_badge)
	head.add_child(UIFactory.badge(String(ally.role).capitalize(), accent))
	box.add_child(head)
	box.add_child(UIFactory.divider(UIPalette.line_soft))
	var weapon := ContentDB.get_weapon(ally.weapon_id)
	var ability := ContentDB.get_ability(ally.ability_effect)
	box.add_child(_weapon_row(weapon, accent))
	box.add_child(_ability_row(ability, accent))
	box.add_child(UIFactory.spacer_v())

	var footer := UIFactory.hbox(UIPalette.SP2)
	var rank_pips := UIFactory.pips(rank, 5, accent)
	rank_pips.tooltip_text = "Warden rank %d / 5" % rank
	footer.add_child(rank_pips)
	footer.add_child(UIFactory.spacer_h())
	var upgrade_cost := 1 + rank
	var cost_row := UIFactory.icon_value(&"core", str(upgrade_cost), UIPalette.violet, 12)
	cost_row.tooltip_text = "Upgrade cost"
	footer.add_child(cost_row)
	var upgrade := UIFactory.secondary_button("Upgrade", &"arrow-up")
	upgrade.custom_minimum_size = Vector2(0, 32)
	upgrade.disabled = rank >= 5 or ProfileState.get_cores() < upgrade_cost
	upgrade.tooltip_text = "Upgrade to rank %d." % mini(5, rank + 1) if rank < 5 else "Maximum rank."
	upgrade.pressed.connect(func() -> void: _upgrade_ally(ally.id, rank))
	footer.add_child(upgrade)
	var assign := UIFactory.ghost_button("Stand down") if active else UIFactory.primary_button("Assign")
	assign.custom_minimum_size = Vector2(0, 32)
	assign.pressed.connect(func() -> void: _toggle_ally(ally.id))
	footer.add_child(assign)
	box.add_child(footer)
	row.add_child(box)
	card.add_child(row)
	return card


func _build_pets() -> void:
	var pets: Array = ContentDB.pets.values()
	pets.sort_custom(func(a: PetData, b: PetData) -> bool: return String(a.display_name) < String(b.display_name))
	for pet in pets:
		_pets_host.add_child(_pet_card(pet))


func _pet_card(pet: PetData) -> PanelContainer:
	var accent := pet.color
	var active := pet.id == ProfileState.get_active_pet()
	var rank := ProfileState.get_pet_rank(pet.id)
	var card := UIFactory.panel("Card")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 178)
	card.tooltip_text = pet.description
	var row := UIFactory.hbox(UIPalette.SP3)
	row.add_child(UIFactory.art_frame(_pet_portrait(pet, 64), accent, active))
	var box := UIFactory.vbox(UIPalette.SP2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UIFactory.hbox(UIPalette.SP2)
	var name_label := UIFactory.display_text(pet.display_name, 20, 600, UIPalette.ivory)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(name_label)
	if active:
		var active_badge := UIFactory.badge("", UIPalette.mint, &"check")
		active_badge.tooltip_text = "Active companion"
		head.add_child(active_badge)
	head.add_child(UIFactory.badge(String(pet.role).capitalize(), accent))
	box.add_child(head)
	var effect_row := UIFactory.icon_value(&"bolt", String(pet.effect).replace("_", " ").capitalize(), accent, 13)
	effect_row.tooltip_text = "Ability effect"
	box.add_child(effect_row)
	var cooldown_row := UIFactory.icon_value(&"timer", "%.0fs" % pet.cooldown, UIPalette.muted, 12)
	cooldown_row.tooltip_text = "Ability cooldown"
	box.add_child(cooldown_row)
	box.add_child(UIFactory.spacer_v())
	var footer := UIFactory.hbox(UIPalette.SP2)
	var rank_pips := UIFactory.pips(rank, 5, accent)
	rank_pips.tooltip_text = "Companion rank %d / 5" % rank
	footer.add_child(rank_pips)
	footer.add_child(UIFactory.spacer_h())
	var upgrade_cost := 1 + rank
	var cost_row := UIFactory.icon_value(&"core", str(upgrade_cost), UIPalette.violet, 12)
	cost_row.tooltip_text = "Upgrade cost"
	footer.add_child(cost_row)
	var upgrade := UIFactory.secondary_button("Upgrade", &"arrow-up")
	upgrade.custom_minimum_size = Vector2(0, 30)
	upgrade.disabled = rank >= 5 or ProfileState.get_cores() < upgrade_cost
	upgrade.pressed.connect(func() -> void: _upgrade_pet(pet.id, rank))
	footer.add_child(upgrade)
	var choose := UIFactory.primary_button("Active" if active else "Deploy")
	choose.custom_minimum_size = Vector2(0, 30)
	choose.disabled = active
	choose.pressed.connect(func() -> void: _set_active_pet(pet.id))
	footer.add_child(choose)
	box.add_child(footer)
	row.add_child(box)
	card.add_child(row)
	return card


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _toggle_ally(ally_id: StringName) -> void:
	var active := ProfileState.get_active_allies()
	var ids: Array = []
	for id in active:
		if id != ally_id:
			ids.append(String(id))
	if active.has(ally_id):
		if ids.is_empty():
			notify("Squad needs a Warden", "Assign another Warden before standing this one down.", &"warning")
			return
	else:
		if ids.size() >= 2:
			notify("Squad full", "Stand down a Warden before assigning another.", &"warning")
			return
		ids.append(String(ally_id))
	if ProfileState.set_active_allies(ids):
		AudioDirector.play_ui(&"ui_confirm")
		notify("Squad updated", "Active Wardens set to %d." % ids.size(), &"success")
	refresh()


func _remove_ally(ally_id: StringName) -> void:
	_toggle_ally(ally_id)


func _upgrade_ally(ally_id: StringName, rank: int) -> void:
	if ProfileState.upgrade_ally(ally_id):
		AudioDirector.play_ui(&"ui_confirm")
		notify("Warden promoted", "Rank %d reached." % mini(5, rank + 1), &"success")
	else:
		AudioDirector.play_ui(&"ui_error")
		notify("Upgrade failed", "Not enough cores.", &"error")
	refresh()


func _set_active_pet(pet_id: StringName) -> void:
	if ProfileState.set_active_pet(pet_id):
		AudioDirector.play_ui(&"ui_confirm")
		var pet := ContentDB.get_pet(pet_id)
		notify("Companion changed", "%s is now deployed with you." % (pet.display_name if pet != null else String(pet_id)), &"success")
	refresh()


func _upgrade_pet(pet_id: StringName, rank: int) -> void:
	if ProfileState.upgrade_pet(pet_id):
		AudioDirector.play_ui(&"ui_confirm")
		notify("Driftling upgraded", "Rank %d reached." % mini(5, rank + 1), &"success")
	else:
		AudioDirector.play_ui(&"ui_error")
		notify("Upgrade failed", "Not enough cores.", &"error")
	refresh()


func _layout() -> void:
	if _nav_rail != null and is_instance_valid(_nav_rail):
		_nav_rail.custom_minimum_size.x = UIPalette.rail_width(viewport_width())
	if _wardens_host != null and is_instance_valid(_wardens_host):
		_wardens_host.columns = 2 if viewport_width() >= 1360.0 else 1
