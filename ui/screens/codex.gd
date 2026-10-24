class_name CodexScreen
extends UIScreen
## Codex and records: career ledger, enemy catalogue, rift mods, mutators and a
## field guide. Pure read-only presentation of ContentDB + ProfileState.

const TABS := [
	{"id": &"records", "label": "Records", "icon": &"book"},
	{"id": &"enemies", "label": "Bestiary", "icon": &"skull"},
	{"id": &"rift_mods", "label": "Rift Mods", "icon": &"bolt"},
	{"id": &"mutators", "label": "Mutators", "icon": &"warning"},
	{"id": &"guide", "label": "Field Guide", "icon": &"map"},
]

const NOTES := [
	{
		"title": "The Reach",
		"icon": &"map",
		"body": "A folded frontier of canyons, bloom-choked basins and glass plains. It looks different every drop because it is. Nothing out here stays where you left it.",
	},
	{
		"title": "The Collapse",
		"icon": &"warning",
		"body": "Around the twelve-minute mark the Reach starts folding in on itself. The safe zone contracts, the storm eats the map edge-first, and exfil becomes the only objective that matters.",
	},
	{
		"title": "Salvage & Extraction",
		"icon": &"cache",
		"body": "Everything you recover rides in the satchel. Extract and it is yours; die and the Reach keeps it. Base modules like the Armory and Infirmary soften that loss.",
	},
	{
		"title": "Wardens & Driftlings",
		"icon": &"users",
		"body": "Wardens bring guns and abilities to the drop. Driftlings are small, loyal, and occasionally the reason you survive. Both rank up at the outpost.",
	},
	{
		"title": "Threat & Mutators",
		"icon": &"skull",
		"body": "Higher threat means elites, heavier reinforcements and richer contracts. Mutators stack reward bonuses on top — and change how the Reach fights back.",
	},
]

const CONTROLS := [
	{"icon": &"arrow-up", "label": "Move", "binding": "WASD"},
	{"icon": &"bolt", "label": "Sprint", "binding": "Shift"},
	{"icon": &"chevron-down", "label": "Crouch", "binding": "Ctrl"},
	{"icon": &"arrow-up-right", "label": "Jump", "binding": "Space"},
	{"icon": &"crosshair", "label": "Fire", "binding": "Mouse 1"},
	{"icon": &"target", "label": "Aim", "binding": "Mouse 2"},
	{"icon": &"refresh", "label": "Reload", "binding": "R"},
	{"icon": &"eye", "label": "Use", "binding": "E"},
	{"icon": &"shield", "label": "AB1", "binding": "Q"},
	{"icon": &"shield-check", "label": "AB2", "binding": "F"},
	{"icon": &"star", "label": "ULT", "binding": "X"},
	{"icon": &"rocket", "label": "Nade", "binding": "G"},
	{"icon": &"arrow-right", "label": "Melee", "binding": "V"},
	{"icon": &"map", "label": "Map", "binding": "M"},
	{"icon": &"pause", "label": "Pause", "binding": "Esc"},
	{"icon": &"users", "label": "Squad", "binding": "Z"},
]

var _tab: StringName = &"records"
var _tab_host: HBoxContainer = null
var _content_host: VBoxContainer = null
var _grid: GridContainer = null


func _compose() -> void:
	var backdrop := UIBackdrop.new()
	backdrop.configure(UIBackdrop.Mood.HUB)
	add_child(backdrop)

	var shell := build_hub_shell(&"codex", "Codex", "")
	var content: VBoxContainer = shell.content
	_tab_host = UIFactory.hbox(UIPalette.SP1)
	content.add_child(_tab_host)
	var scroll := UIFactory.vscroll()
	content.add_child(scroll)
	_content_host = UIFactory.vbox(UIPalette.SP4)
	_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content_host)
	_refresh()


func _refresh() -> void:
	if _content_host == null:
		return
	_build_tabs()
	UIFactory.clear_children(_content_host)
	match _tab:
		&"records":
			_build_records()
		&"enemies":
			_build_bestiary()
		&"rift_mods":
			_build_rift_mods()
		&"mutators":
			_build_mutators()
		_:
			_build_guide()


func _build_tabs() -> void:
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
	_refresh()


# ---------------------------------------------------------------------------
# Records
# ---------------------------------------------------------------------------

func _build_records() -> void:
	var records := ProfileState.get_records()
	_content_host.add_child(UIFactory.section_header("Career Ledger", "", null, &"book"))
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", UIPalette.SP3)
	_grid.add_theme_constant_override("v_separation", UIPalette.SP3)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_host.add_child(_grid)
	_grid.columns = _grid_columns()
	_grid.add_child(_record_card(&"home", "Deployments", str(int(records.get("deployments", 0))), "Times dropped into the Reach.", UIPalette.mint))
	_grid.add_child(_record_card(&"exfil", "Extractions", str(int(records.get("extractions", 0))), "Returns through the exfil gate.", UIPalette.blue))
	_grid.add_child(_record_card(&"warning", "Deaths", str(int(records.get("deaths", 0))), "Runs lost to the Reach.", UIPalette.danger))
	_grid.add_child(_record_card(&"coins", "Best haul", UIPalette.format_int(int(records.get("best_extraction", 0))), "Highest single extraction value.", UIPalette.amber))
	_grid.add_child(_record_card(&"target", "Kills", str(int(records.get("kills", 0))), "Confirmed eliminations.", UIPalette.ivory))
	_grid.add_child(_record_card(&"skull", "Bosses", str(int(records.get("bosses", 0))), "Boss-class signatures ended.", UIPalette.violet))
	_grid.add_child(_record_card(&"star", "Total salvage", UIPalette.format_int(int(records.get("total_salvage", 0))), "Lifetime extracted value.", UIPalette.sun))
	_grid.add_child(_record_card(&"check", "Contracts", str(int(ProfileState.data.get("contracts_completed", 0))), "Contracts fully completed.", UIPalette.mint))

	var level_card := UIFactory.panel("Card")
	var level_box := UIFactory.vbox(UIPalette.SP2)
	var level_row := UIFactory.hbox(UIPalette.SP3)
	level_row.add_child(UIFactory.icon(&"arrow-up", 18, UIPalette.mint))
	level_row.add_child(UIFactory.display_text("Level %d" % ProfileState.get_level(), 28, 600))
	level_row.add_child(UIFactory.spacer_h())
	var xp_target := ProfileState.get_xp_for_next_level()
	var xp_value := UIFactory.icon_value(&"timer", "MAX" if xp_target <= 0 else "%d / %d" % [ProfileState.get_xp(), xp_target], UIPalette.muted, 12)
	xp_value.tooltip_text = "Warden experience"
	level_row.add_child(xp_value)
	level_box.add_child(level_row)
	var ratio := 1.0 if xp_target <= 0 else clampf(float(ProfileState.get_xp()) / float(xp_target), 0.0, 1.0)
	level_box.add_child(UIFactory.progress(ratio * 100.0, 100.0, "BarMint", 6))
	var meta_row := UIFactory.hbox(UIPalette.SP5)
	var discipline_row := UIFactory.icon_value(&"shield", String(ProfileState.get_discipline()).capitalize(), UIPalette.mint, 13)
	discipline_row.tooltip_text = "Discipline"
	meta_row.add_child(discipline_row)
	var playtime_row := UIFactory.icon_value(&"timer", UIPalette.format_duration(ProfileState.get_playtime()), UIPalette.muted, 13)
	playtime_row.tooltip_text = "Playtime"
	meta_row.add_child(playtime_row)
	var profile_row := UIFactory.icon_value(&"info", ProfileState.get_profile_id(), UIPalette.muted_dim, 13)
	profile_row.tooltip_text = "Profile id"
	meta_row.add_child(profile_row)
	level_box.add_child(meta_row)
	level_card.add_child(level_box)
	_content_host.add_child(level_card)


func _record_card(icon_name: StringName, title: String, value_text: String, description: String, accent: Color) -> PanelContainer:
	var card := UIFactory.panel("Card")
	card.custom_minimum_size = Vector2(0, 108)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = description
	var box := UIFactory.vbox(UIPalette.SP2)
	var top := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon_or_null(icon_name, 16, accent)
	if glyph != null:
		top.add_child(glyph)
	top.add_child(UIFactory.label(title.to_upper(), "StatLabel"))
	top.add_child(UIFactory.spacer_h())
	box.add_child(top)
	box.add_child(UIFactory.number_text(value_text, 26, accent))
	card.add_child(box)
	return card


# ---------------------------------------------------------------------------
# Bestiary
# ---------------------------------------------------------------------------

func _build_bestiary() -> void:
	_content_host.add_child(UIFactory.section_header("Bestiary", "", null, &"skull"))
	var factions: Array = [&"ashen", &"bloom", &"choir"]
	for faction in factions:
		var enemies: Array = ContentDB.get_all_enemies_of_faction(faction)
		if enemies.is_empty():
			continue
		var accent := UIPalette.faction_color(faction)
		var header := UIFactory.hbox(UIPalette.SP2)
		var squiggle := ColorRect.new()
		squiggle.color = accent
		squiggle.custom_minimum_size = Vector2(4, 18)
		squiggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		squiggle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(squiggle)
		header.add_child(UIFactory.heading(String(faction).capitalize(), "H3"))
		header.tooltip_text = _faction_blurb(faction)
		_content_host.add_child(header)
		var grid := GridContainer.new()
		grid.add_theme_constant_override("h_separation", UIPalette.SP3)
		grid.add_theme_constant_override("v_separation", UIPalette.SP3)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.columns = 2 if viewport_width() >= 1360.0 else 1
		_content_host.add_child(grid)
		for enemy in enemies:
			grid.add_child(_enemy_card(enemy, accent))
	# Elites and bosses.
	var specials: Array = []
	for enemy in ContentDB.enemies.values():
		if enemy.elite or enemy.boss:
			specials.append(enemy)
	if not specials.is_empty():
		_content_host.add_child(UIFactory.section_header("Elite Signatures", "", null, &"warning"))
		var special_grid := GridContainer.new()
		special_grid.add_theme_constant_override("h_separation", UIPalette.SP3)
		special_grid.add_theme_constant_override("v_separation", UIPalette.SP3)
		special_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		special_grid.columns = 2 if viewport_width() >= 1360.0 else 1
		_content_host.add_child(special_grid)
		for enemy in specials:
			special_grid.add_child(_enemy_card(enemy, UIPalette.faction_color(enemy.faction)))


func _faction_blurb(faction: StringName) -> String:
	match faction:
		&"ashen":
			return "Scavenger clans that strip the Reach for parts and grudges."
		&"bloom":
			return "A fast-growing alien ecology with teeth and opinions."
		&"choir":
			return "Signal-born constructs that believe the rift is a hymn."
		_:
			return ""


func _enemy_card(enemy: EnemyData, accent: Color) -> PanelContainer:
	var card := UIFactory.panel("CardInset")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UIFactory.vbox(UIPalette.SP2)
	var head := UIFactory.hbox(UIPalette.SP2)
	var swatch := ColorRect.new()
	swatch.color = enemy.body_color
	swatch.custom_minimum_size = Vector2(10, 10)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(swatch)
	head.add_child(UIFactory.label(enemy.display_name, "TitleLabel"))
	head.add_child(UIFactory.spacer_h())
	if enemy.boss:
		head.add_child(UIFactory.badge("BOSS", UIPalette.danger))
	elif enemy.elite:
		head.add_child(UIFactory.badge("ELITE", UIPalette.amber))
	box.add_child(head)

	var stats := UIFactory.hbox(UIPalette.SP4)
	var role_row := UIFactory.icon_value(&"users", String(enemy.role).capitalize(), accent, 12)
	role_row.tooltip_text = "Role · %s" % ("ranged" if enemy.ranged else "melee")
	stats.add_child(role_row)
	var health_row := UIFactory.icon_value(&"heart-pulse", str(int(enemy.max_health)), accent, 12)
	health_row.tooltip_text = "Health"
	stats.add_child(health_row)
	var damage_row := UIFactory.icon_value(&"crosshair", str(int(enemy.damage)), UIPalette.ivory, 12)
	damage_row.tooltip_text = "Damage"
	stats.add_child(damage_row)
	box.add_child(stats)

	var rewards := UIFactory.hbox(UIPalette.SP4)
	var xp_row := UIFactory.icon_value(&"arrow-up", str(enemy.xp), UIPalette.mint, 11)
	xp_row.tooltip_text = "XP reward"
	rewards.add_child(xp_row)
	var loot_row := UIFactory.icon_value(&"coins", str(enemy.salvage), UIPalette.amber, 11)
	loot_row.tooltip_text = "Salvage"
	rewards.add_child(loot_row)
	var speed_row := UIFactory.icon_value(&"bolt", "%.1f" % enemy.move_speed, UIPalette.muted, 11)
	speed_row.tooltip_text = "Move speed"
	rewards.add_child(speed_row)
	box.add_child(rewards)
	card.add_child(box)
	return card


# ---------------------------------------------------------------------------
# Rift mods & mutators
# ---------------------------------------------------------------------------

func _build_rift_mods() -> void:
	var header := UIFactory.section_header("Rift Mods", "", null, &"bolt")
	header.tooltip_text = "Rift mods attach to a deployment and persist only for that run. Recovered mods are listed at extraction."
	_content_host.add_child(header)
	var grid := GridContainer.new()
	grid.add_theme_constant_override("h_separation", UIPalette.SP3)
	grid.add_theme_constant_override("v_separation", UIPalette.SP3)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = _grid_columns()
	_content_host.add_child(grid)
	for mod in ContentDB.rift_mods.values():
		var card := UIFactory.panel("Card")
		card.custom_minimum_size = Vector2(0, 104)
		card.tooltip_text = mod.description
		var box := UIFactory.vbox(UIPalette.SP2)
		var head := UIFactory.hbox(UIPalette.SP2)
		var glyph := UIFactory.icon(&"bolt", 15, mod.color)
		if glyph != null:
			head.add_child(glyph)
		head.add_child(UIFactory.label(mod.display_name, "TitleLabel", mod.color))
		head.add_child(UIFactory.spacer_h())
		head.add_child(UIFactory.badge(UIPalette.format_stat_value(mod.stat, mod.value), mod.color))
		box.add_child(head)
		card.add_child(box)
		grid.add_child(card)


func _build_mutators() -> void:
	var header := UIFactory.section_header("Mutators", "", null, &"warning")
	header.tooltip_text = "Mutators are optional deployment hazards. Each one raises threat and improves extraction rewards."
	_content_host.add_child(header)
	var grid := GridContainer.new()
	grid.add_theme_constant_override("h_separation", UIPalette.SP3)
	grid.add_theme_constant_override("v_separation", UIPalette.SP3)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = _grid_columns()
	_content_host.add_child(grid)
	for mutator in ContentDB.mutators.values():
		var card := UIFactory.panel("CardInset")
		card.custom_minimum_size = Vector2(0, 116)
		card.tooltip_text = mutator.description
		var box := UIFactory.vbox(UIPalette.SP2)
		var head := UIFactory.hbox(UIPalette.SP2)
		head.add_child(UIFactory.label(mutator.display_name, "TitleLabel", mutator.color))
		head.add_child(UIFactory.spacer_h())
		head.add_child(UIFactory.badge("+%d THREAT" % mutator.threat_bonus, mutator.color))
		box.add_child(head)
		var reward_line := UIFactory.hbox(UIPalette.SP4)
		var reward_row := UIFactory.icon_value(&"coins", "+%d%%" % int(round(mutator.reward_bonus * 100.0)), UIPalette.amber, 12)
		reward_row.tooltip_text = "Reward bonus"
		reward_line.add_child(reward_row)
		if mutator.enemy_health_mult > 1.0:
			var health_row := UIFactory.icon_value(&"heart-pulse", "+%d%%" % int(round((mutator.enemy_health_mult - 1.0) * 100.0)), UIPalette.danger, 12)
			health_row.tooltip_text = "Enemy health"
			reward_line.add_child(health_row)
		if mutator.enemy_damage_mult > 1.0:
			var damage_row := UIFactory.icon_value(&"crosshair", "+%d%%" % int(round((mutator.enemy_damage_mult - 1.0) * 100.0)), UIPalette.danger, 12)
			damage_row.tooltip_text = "Enemy damage"
			reward_line.add_child(damage_row)
		if mutator.elite_chance_bonus > 0.0:
			var elite_row := UIFactory.icon_value(&"star", "+%d%%" % int(round(mutator.elite_chance_bonus * 100.0)), UIPalette.violet, 12)
			elite_row.tooltip_text = "Elite chance"
			reward_line.add_child(elite_row)
		box.add_child(reward_line)
		card.add_child(box)
		grid.add_child(card)


# ---------------------------------------------------------------------------
# Field guide
# ---------------------------------------------------------------------------

func _build_guide() -> void:
	var header := UIFactory.section_header("Field Guide", "", null, &"map")
	_content_host.add_child(header)
	for note in NOTES:
		var card := UIFactory.panel("Card")
		card.tooltip_text = String(note.body)
		var row := UIFactory.hbox(UIPalette.SP3)
		var note_glyph := UIFactory.icon_or_null(StringName(note.icon), 18, UIPalette.amber)
		if note_glyph != null:
			note_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(note_glyph)
		row.add_child(UIFactory.heading(String(note.title), "H3"))
		card.add_child(row)
		_content_host.add_child(card)

	var controls_header := UIFactory.section_header("Controls", "", null, &"gamepad")
	controls_header.tooltip_text = "Default bindings. Bindings can be changed in Settings."
	_content_host.add_child(controls_header)
	var controls := UIFactory.panel("Card")
	var controls_box := UIFactory.vbox(UIPalette.SP2)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", UIPalette.SP5)
	grid.add_theme_constant_override("v_separation", UIPalette.SP2)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in CONTROLS:
		var cell := UIFactory.hbox(UIPalette.SP2)
		var glyph := UIFactory.icon_or_null(StringName(entry.icon), 13, UIPalette.muted_dim)
		if glyph != null:
			glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cell.add_child(glyph)
		cell.add_child(UIFactory.label(String(entry.label), "Micro"))
		cell.add_child(UIFactory.spacer_h())
		cell.add_child(UIFactory.label(String(entry.binding), "MonoValue"))
		grid.add_child(cell)
	controls_box.add_child(grid)
	controls.add_child(controls_box)
	_content_host.add_child(controls)


func _grid_columns() -> int:
	var width := viewport_width()
	if width >= 1900.0:
		return 4
	if width >= 1360.0:
		return 3
	return 2


func _layout() -> void:
	if _nav_rail != null and is_instance_valid(_nav_rail):
		_nav_rail.custom_minimum_size.x = UIPalette.rail_width(viewport_width())
	if _grid != null and is_instance_valid(_grid):
		_grid.columns = _grid_columns()
