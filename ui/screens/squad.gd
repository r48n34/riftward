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
	row.add_child(UIFactory.stat_block(&"users", "Active Wardens", "%d/2" % ProfileState.get_active_allies().size(), UIPalette.mint, 20))
	var pet := ContentDB.get_pet(ProfileState.get_active_pet())
	row.add_child(UIFactory.stat_block(&"paw", "Companion", pet.display_name if pet != null else "None", UIPalette.amber, 20))
	row.add_child(UIFactory.stat_block(&"core", "Cores available", UIPalette.format_int(ProfileState.get_cores()), UIPalette.violet, 20))
	row.add_child(UIFactory.stat_block(&"shield", "Barracks", "T%d" % ProfileState.get_base_tier(&"barracks"), UIPalette.blue, 20))
	row.add_child(UIFactory.spacer_h())
	card.add_child(row)
	_header_host.add_child(card)


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
	card.custom_minimum_size = Vector2(0, 156)
	var box := UIFactory.vbox(UIPalette.SP2)
	box.add_child(_slot_badge(index))
	if ally == null:
		var empty := UIFactory.empty_state(&"users", "Empty", "Assign a Warden below.")
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(empty)
		card.add_child(box)
		return card
	var accent := ally.color
	var head := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon(&"users", 18, accent)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(glyph)
	head.add_child(UIFactory.display_text(ally.display_name, 22, 600, accent))
	head.add_child(UIFactory.spacer_h())
	head.add_child(UIFactory.badge(String(ally.role).capitalize(), accent))
	box.add_child(head)
	var weapon := ContentDB.get_weapon(ally.weapon_id)
	var ability := ContentDB.get_ability(ally.ability_effect)
	var weapon_row := UIFactory.icon_value(&"target", weapon.display_name if weapon != null else String(ally.weapon_id), UIPalette.muted, 13)
	weapon_row.tooltip_text = "Weapon"
	box.add_child(weapon_row)
	var ability_row := UIFactory.icon_value(&"bolt", ability.display_name if ability != null else String(ally.ability_effect), UIPalette.muted, 13)
	ability_row.tooltip_text = "Signature ability"
	box.add_child(ability_row)
	box.add_child(UIFactory.spacer_v())
	var footer := UIFactory.hbox(UIPalette.SP2)
	var rank_pips := UIFactory.pips(ProfileState.get_ally_rank(ally.id), 5, accent)
	rank_pips.tooltip_text = "Warden rank %d / 5" % ProfileState.get_ally_rank(ally.id)
	footer.add_child(rank_pips)
	footer.add_child(UIFactory.spacer_h())
	var remove := UIFactory.ghost_button("Stand down")
	remove.custom_minimum_size = Vector2(0, 30)
	remove.disabled = ProfileState.get_active_allies().size() <= 1
	remove.tooltip_text = "At least one Warden must remain on active duty."
	remove.pressed.connect(func() -> void: _remove_ally(ally.id))
	footer.add_child(remove)
	box.add_child(footer)
	card.add_child(box)
	return card


func _active_pet_card() -> PanelContainer:
	var card := UIFactory.panel("Card")
	card.custom_minimum_size = Vector2(0, 156)
	var box := UIFactory.vbox(UIPalette.SP2)
	var slot_badge := UIFactory.badge("", UIPalette.muted, &"paw")
	slot_badge.tooltip_text = "Companion slot"
	box.add_child(slot_badge)
	var pet := ContentDB.get_pet(ProfileState.get_active_pet())
	if pet == null:
		box.add_child(UIFactory.empty_state(&"paw", "No companion", "Select a Driftling below."))
		card.add_child(box)
		return card
	var accent := pet.color
	var head := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon(&"paw", 18, accent)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(glyph)
	head.add_child(UIFactory.display_text(pet.display_name, 22, 600, accent))
	head.add_child(UIFactory.spacer_h())
	head.add_child(UIFactory.badge(String(pet.role).capitalize(), accent))
	box.add_child(head)
	card.tooltip_text = pet.description
	box.add_child(UIFactory.spacer_v())
	var footer := UIFactory.hbox(UIPalette.SP2)
	var rank_pips := UIFactory.pips(ProfileState.get_pet_rank(pet.id), 5, accent)
	rank_pips.tooltip_text = "Companion rank %d / 5" % ProfileState.get_pet_rank(pet.id)
	footer.add_child(rank_pips)
	footer.add_child(UIFactory.spacer_h())
	var effect_row := UIFactory.icon_value(&"bolt", String(pet.effect).replace("_", " ").capitalize(), UIPalette.muted, 12)
	effect_row.tooltip_text = "Ability effect"
	footer.add_child(effect_row)
	box.add_child(footer)
	card.add_child(box)
	return card


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
	var box := UIFactory.vbox(UIPalette.SP2)

	var head := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon(&"users", 20, accent)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(glyph)
	head.add_child(UIFactory.display_text(ally.display_name, 22, 600, UIPalette.ivory))
	head.add_child(UIFactory.spacer_h())
	if active:
		var active_badge := UIFactory.badge("", UIPalette.mint, &"check")
		active_badge.tooltip_text = "Active in your squad"
		head.add_child(active_badge)
	head.add_child(UIFactory.badge(String(ally.role).capitalize(), accent))
	box.add_child(head)
	box.add_child(UIFactory.divider(UIPalette.line_soft))
	var weapon := ContentDB.get_weapon(ally.weapon_id)
	var ability := ContentDB.get_ability(ally.ability_effect)
	var weapon_row := UIFactory.icon_value(&"target", weapon.display_name if weapon != null else "Unknown weapon", accent, 13)
	weapon_row.tooltip_text = "Weapon"
	box.add_child(weapon_row)
	var ability_row := UIFactory.icon_value(&"bolt", ability.display_name if ability != null else "Unknown ability", UIPalette.ivory, 13)
	ability_row.tooltip_text = "Signature ability"
	box.add_child(ability_row)
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
	card.add_child(box)
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
	var box := UIFactory.vbox(UIPalette.SP2)
	var head := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon(&"paw", 18, accent)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(glyph)
	head.add_child(UIFactory.display_text(pet.display_name, 20, 600, UIPalette.ivory))
	head.add_child(UIFactory.spacer_h())
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
	card.add_child(box)
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
