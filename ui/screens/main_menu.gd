class_name MainMenuScreen
extends UIScreen
## Title / profile screen. Quick Deploy is the dominant call to action: one big
## mint button that opens the preflight, with the remembered drop previewed as an
## icon strip underneath. The hub, settings and quit stay deliberately secondary.

const CTA_MIN_SIZE := Vector2(430, 88)

var _wordmark: Label = null
var _editing_callsign := false
var _callsign_edit: LineEdit = null
var _quick_button: Button = null
var _glow: PanelContainer = null


func _compose() -> void:
	var backdrop := UIBackdrop.new()
	backdrop.configure(UIBackdrop.Mood.MENU)
	add_child(backdrop)

	var page := build_page(UIPalette.SP4, UIPalette.SP4, UIPalette.SP3)

	# --- Top bar: brand + icon utilities -----------------------------------
	var top := UIFactory.hbox(UIPalette.SP2)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var brand_row := UIFactory.hbox(UIPalette.SP2)
	brand_row.add_child(UIFactory.icon(&"outpost", 18, UIPalette.mint))
	brand_row.add_child(UIFactory.label("FRONTIER OPERATIONS", "Eyebrow", UIPalette.mint))
	brand_row.add_child(UIFactory.label("·  WAYSTATION KESTREL", "EyebrowMuted"))
	top.add_child(brand_row)
	top.add_child(UIFactory.spacer_h())
	var settings_button := UIFactory.icon_button(&"settings", "Settings")
	settings_button.pressed.connect(func() -> void: go(&"settings"))
	top.add_child(settings_button)
	var quit_button := UIFactory.icon_button(&"exit", "Quit to desktop")
	quit_button.pressed.connect(func() -> void:
		if App != null:
			App.quit_to_desktop()
	)
	top.add_child(quit_button)
	page.add_child(top)

	# --- Hero --------------------------------------------------------------
	page.add_child(UIFactory.spacer_v())

	var hero := UIFactory.vbox(UIPalette.SP3)
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var season_row := UIFactory.hbox(UIPalette.SP2)
	season_row.add_child(UIFactory.badge("SEASON 01 · THE REACH", UIPalette.amber, &"star"))
	season_row.add_child(UIFactory.badge("SOLO WARDEN PROFILE", UIPalette.mint, &"shield-check"))
	hero.add_child(season_row)

	_wordmark = UIFactory.display_text("RIFTWARD", UIPalette.FONT_WORDMARK + 8, 700)
	hero.add_child(_wordmark)

	var tagline_row := UIFactory.hbox(UIPalette.SP3)
	tagline_row.add_child(UIFactory.fixed_spacer(52, 0))
	var rule := ColorRect.new()
	rule.color = UIPalette.mint
	rule.custom_minimum_size = Vector2(44, 3)
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tagline_row.add_child(rule)
	var tagline := UIFactory.display_text("DROP INTO THE REACH.", 22, 600)
	tagline.add_theme_color_override("font_color", UIPalette.ivory)
	tagline_row.add_child(tagline)
	var tail := UIFactory.display_text("BUILD WHAT SURVIVES.", 22, 400)
	tail.add_theme_color_override("font_color", UIPalette.muted)
	tagline_row.add_child(tail)
	hero.add_child(UIFactory.pad(tagline_row, 0, 0, 0, 2))

	hero.add_child(UIFactory.pad(_build_quick_deploy(), 52, UIPalette.SP4, 0, 0))
	page.add_child(hero)

	page.add_child(UIFactory.spacer_v())

	# --- Footer: profile card + build status -------------------------------
	var footer := UIFactory.hbox(UIPalette.SP5)
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_build_profile_card())
	footer.add_child(UIFactory.spacer_h())
	footer.add_child(_build_status_column())
	page.add_child(footer)

	# Start the CTA breathing only once the screen is fully inside the tree.
	if not UIPalette.reduce_motion:
		_pulse_glow.call_deferred()


# ---------------------------------------------------------------------------
# Quick Deploy CTA
# ---------------------------------------------------------------------------

func _build_quick_deploy() -> VBoxContainer:
	var block := UIFactory.vbox(UIPalette.SP2)

	_glow = _build_glow_frame()
	block.add_child(_glow)

	block.add_child(_build_remembered_line())

	var secondary := UIFactory.hbox(UIPalette.SP3)
	var hub_button := UIFactory.ghost_button("Enter Hub", &"home")
	hub_button.custom_minimum_size = Vector2(0, 40)
	hub_button.tooltip_text = "Enter Hub — contract board, mutators, loadout and outpost."
	hub_button.pressed.connect(_on_enter_hub)
	secondary.add_child(hub_button)
	var training_label := "Replay Field Training" if ProfileState.get_tutorial_done() else "First Drop · Field Training"
	var training_button := UIFactory.ghost_button(training_label, &"training")
	training_button.custom_minimum_size = Vector2(0, 40)
	training_button.tooltip_text = "Field Training — a guided five-stage onboarding run. Move, shoot, cast, loot, extract."
	training_button.pressed.connect(func() -> void:
		if App != null:
			App.start_tutorial()
	)
	secondary.add_child(training_button)
	var hint := UIFactory.label("Full contract board · mutators · loadout", "Micro", UIPalette.muted_dim)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	secondary.add_child(hint)
	block.add_child(secondary)

	return block


func _build_glow_frame() -> PanelContainer:
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	frame.add_theme_stylebox_override(
		"panel",
		UITheme._box(
			UIPalette.alpha(UIPalette.mint, 0.05),
			UIPalette.alpha(UIPalette.mint, 0.55),
			UIPalette.R_XL,
			2,
			Vector4(7, 7, 7, 7)
		)
	)
	_quick_button = UIFactory.quick_deploy_button("QUICK DEPLOY", &"play")
	_quick_button.custom_minimum_size = CTA_MIN_SIZE
	_quick_button.tooltip_text = _quick_deploy_tooltip()
	_quick_button.pressed.connect(_on_quick_deploy)
	frame.add_child(_quick_button)
	return frame


func _pulse_glow() -> void:
	if _glow == null or not is_instance_valid(_glow) or not _glow.is_inside_tree():
		return
	if _glow.has_meta("pulse"):
		return
	if UIPalette.reduce_motion:
		_glow.self_modulate.a = 0.9
		return
	_glow.set_meta("pulse", true)
	_glow.self_modulate.a = 0.6
	var tween := _glow.create_tween()
	tween.set_loops()
	tween.tween_property(_glow, "self_modulate:a", 1.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_glow, "self_modulate:a", 0.55, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Visual preview of the drop Quick Deploy will prefill in the preflight: map
## thumbnail, planet medallion, difficulty chip and the ContentDB mode clock.
func _build_remembered_line() -> HBoxContainer:
	var difficulty := _remembered_difficulty()
	var preset := _remembered_preset(difficulty)
	var mode := _remembered_mode()
	var mode_data := ContentDB.get_game_mode(mode)
	var row := UIFactory.hbox(UIPalette.SP3)
	row.tooltip_text = "Remembered from your last drop. Quick Deploy opens the preflight with these selections."

	var map_id := StringName(preset.get("id", &""))
	if map_id != &"":
		var thumb := UIMapThumbnail.new()
		thumb.configure(map_id, Vector2(56, 34))
		thumb.custom_minimum_size = Vector2(56, 34)
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.tooltip_text = "Map: %s — %s" % [
			String(preset.get("display_name", "Verdant Verge")),
			String(preset.get("subtitle", "Reach frontier")),
		]
		row.add_child(thumb)

	var map_chip := UIFactory.icon_value(&"map", String(preset.get("display_name", "Verdant Verge")), UIPalette.mint, 12)
	map_chip.tooltip_text = "Map: %s — %s" % [
		String(preset.get("display_name", "Verdant Verge")),
		String(preset.get("subtitle", "Reach frontier")),
	]
	row.add_child(map_chip)

	var planet := ContentDB.get_planet(StringName(preset.get("planet_id", &"")))
	if not planet.is_empty():
		var planet_medallion := UIFactory.medallion(
			_safe_icon(StringName(planet.get("icon", &"planet")), &"planet"),
			24,
			planet.get("color", UIPalette.violet)
		)
		planet_medallion.tooltip_text = "Planet: %s — %s" % [
			String(planet.get("display_name", "Planet")),
			String(planet.get("subtitle", "")),
		]
		row.add_child(planet_medallion)
		row.add_child(UIFactory.label(String(planet.get("display_name", "Planet")), "Micro", UIPalette.muted))

	var difficulty_chip := UIFactory.icon_value(
		StringName(difficulty.get("icon", &"shield")),
		"%s · T%d" % [String(difficulty.get("display_name", "Patrol")), int(difficulty.get("threat", 1))],
		difficulty.get("color", UIPalette.ivory),
		12
	)
	difficulty_chip.tooltip_text = String(difficulty.get("description", "Difficulty sets enemy density, elites and rewards."))
	row.add_child(difficulty_chip)

	var clock := ContentDB.get_mode_clock(mode)
	if clock.is_empty():
		clock = String(mode_data.get("clock", "18:00"))
	var mode_name := _mode_label(mode_data)
	var scale := float(mode_data.get("time_scale", 1.0))
	var mode_text := "%s · %s" % [mode_name, clock]
	if scale > 1.0:
		mode_text += " · ×%.0f" % scale
	var mode_chip := UIFactory.icon_value(
		_safe_icon(StringName(mode_data.get("icon", &"timer")), &"timer"),
		mode_text,
		mode_data.get("color", UIPalette.muted),
		12
	)
	mode_chip.tooltip_text = "Mode: %s. %s" % [
		mode_name,
		String(mode_data.get("description", "Remembered from your last drop.")),
	]
	row.add_child(mode_chip)
	return row


func _quick_deploy_tooltip() -> String:
	var difficulty := _remembered_difficulty()
	var preset := _remembered_preset(difficulty)
	var mode := _remembered_mode()
	var mode_data := ContentDB.get_game_mode(mode)
	var clock := ContentDB.get_mode_clock(mode)
	if clock.is_empty():
		clock = String(mode_data.get("clock", "18:00"))
	return "Quick Deploy — opens the preflight with your remembered drop: %s · %s (T%d) · %s (%s clock)." % [
		String(preset.get("display_name", "Verdant Verge")),
		String(difficulty.get("display_name", "Patrol")),
		int(difficulty.get("threat", 1)),
		_mode_label(mode_data),
		clock,
	]


func _remembered_difficulty() -> Dictionary:
	var difficulty := ContentDB.get_difficulty(ProfileState.get_last_difficulty())
	if difficulty.is_empty():
		var difficulties := ContentDB.get_difficulties()
		difficulty = difficulties[0] if not difficulties.is_empty() else {}
	return difficulty


func _remembered_preset(difficulty: Dictionary) -> Dictionary:
	var preset := ContentDB.get_map_preset(ProfileState.get_last_map())
	if preset.is_empty():
		preset = ContentDB.get_map_preset(StringName(difficulty.get("map_preset", &"")))
	if preset.is_empty() and RunState.active:
		preset = ContentDB.get_map_preset(RunState.get_map_preset_id())
	if preset.is_empty():
		var presets := ContentDB.get_map_presets()
		preset = presets[0] if not presets.is_empty() else {}
	return preset


func _remembered_mode() -> StringName:
	var mode := ProfileState.get_last_mode()
	if ContentDB.get_game_mode(mode).is_empty():
		var modes := ContentDB.get_game_modes()
		return StringName(modes[0].get("id", &"normal")) if not modes.is_empty() else &"normal"
	return mode


func _mode_label(mode: Dictionary) -> String:
	var out := String(mode.get("display_name", mode.get("name", ""))).strip_edges()
	return out if not out.is_empty() else "Normal"


func _safe_icon(icon_name: StringName, fallback: StringName) -> StringName:
	if UIIcons.has_icon(icon_name):
		return icon_name
	return fallback if UIIcons.has_icon(fallback) else &"bolt"


# ---------------------------------------------------------------------------
# Profile card (compact)
# ---------------------------------------------------------------------------

func _build_profile_card() -> PanelContainer:
	var card := UIFactory.panel("Card")
	card.custom_minimum_size = Vector2(348, 0)
	var box := UIFactory.vbox(UIPalette.SP2)

	var header := UIFactory.hbox(UIPalette.SP2)
	header.add_child(UIFactory.eyebrow("Warden Profile", UIPalette.mint))
	header.add_child(UIFactory.spacer_h())
	header.add_child(UIFactory.badge("LV %02d" % ProfileState.get_level(), UIPalette.ivory))
	box.add_child(header)

	if _editing_callsign:
		var edit_row := UIFactory.hbox(UIPalette.SP2)
		_callsign_edit = LineEdit.new()
		_callsign_edit.text = ProfileState.get_callsign()
		_callsign_edit.placeholder_text = "Callsign"
		_callsign_edit.max_length = 20
		_callsign_edit.custom_minimum_size = Vector2(0, 36)
		_callsign_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_callsign_edit.text_submitted.connect(func(_text: String) -> void: _save_callsign())
		edit_row.add_child(_callsign_edit)
		var save := UIFactory.primary_button("Save")
		save.custom_minimum_size = Vector2(66, 36)
		save.pressed.connect(_save_callsign)
		edit_row.add_child(save)
		var cancel := UIFactory.ghost_button("Cancel")
		cancel.custom_minimum_size = Vector2(0, 36)
		cancel.pressed.connect(func() -> void:
			_editing_callsign = false
			_callsign_edit = null
			refresh()
		)
		edit_row.add_child(cancel)
		box.add_child(edit_row)
	else:
		_callsign_edit = null
		var name_row := UIFactory.hbox(UIPalette.SP2)
		var callsign := UIFactory.display_text(ProfileState.get_callsign(), 28, 600)
		name_row.add_child(callsign)
		var edit := UIFactory.inline_button("Change")
		edit.tooltip_text = "Edit callsign"
		edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		edit.pressed.connect(func() -> void:
			_editing_callsign = true
			refresh()
		)
		name_row.add_child(edit)
		box.add_child(name_row)

	var meta := UIFactory.hbox(UIPalette.SP2)
	var discipline := ProfileState.get_discipline()
	meta.add_child(UIFactory.badge(String(discipline).capitalize(), UIPalette.discipline_color(discipline), &"shield"))
	meta.add_child(UIFactory.spacer_h())
	var xp_target := ProfileState.get_xp_for_next_level()
	var xp_text := "MAX LEVEL" if xp_target <= 0 else "%s / %s XP" % [
		UIPalette.format_int(ProfileState.get_xp()),
		UIPalette.format_int(xp_target),
	]
	var xp_chip := UIFactory.icon_value(&"star", xp_text, UIPalette.muted, 11)
	xp_chip.tooltip_text = "Level progress toward the next Warden level."
	meta.add_child(xp_chip)
	box.add_child(meta)

	var ratio := 1.0
	if xp_target > 0:
		ratio = clampf(float(ProfileState.get_xp()) / float(xp_target), 0.0, 1.0)
	box.add_child(UIFactory.progress(ratio * 100.0, 100.0, "BarMint", 4))
	box.add_child(UIFactory.divider(UIPalette.line_soft))

	var wallet := UIFactory.hbox(UIPalette.SP4)
	wallet.add_child(_wallet_chip(&"coins", UIPalette.format_int(ProfileState.get_salvage()), UIPalette.amber, "Salvage"))
	wallet.add_child(_wallet_chip(&"core", UIPalette.format_int(ProfileState.get_cores()), UIPalette.violet, "Cores"))
	wallet.add_child(_wallet_chip(&"users", "%d / 2" % ProfileState.get_active_allies().size(), UIPalette.mint, "Active squad"))
	box.add_child(wallet)

	var records := ProfileState.get_records()
	box.add_child(UIFactory.label(
		"Deployments %d · Extractions %d · Kills %d · Best %s" % [
			int(records.get("deployments", 0)),
			int(records.get("extractions", 0)),
			int(records.get("kills", 0)),
			UIPalette.format_int(int(records.get("best_extraction", 0))),
		],
		"Micro",
		UIPalette.muted_dim
	))

	card.add_child(box)
	return card


func _wallet_chip(icon_name: StringName, value_text: String, accent: Color, tooltip: String) -> HBoxContainer:
	var chip := UIFactory.icon_value(icon_name, value_text, accent, 13, 13)
	chip.tooltip_text = tooltip
	return chip


func _build_status_column() -> VBoxContainer:
	var box := UIFactory.vbox(4)
	box.alignment = BoxContainer.ALIGNMENT_END
	box.size_flags_horizontal = Control.SIZE_SHRINK_END

	var profile_id := ProfileState.get_profile_id()
	var id_label := UIFactory.label("PROFILE  " + profile_id.to_upper(), "Micro", UIPalette.muted_dim)
	id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(id_label)

	var status := UIFactory.hbox(UIPalette.SP2)
	status.alignment = BoxContainer.ALIGNMENT_END
	status.add_child(UIFactory.label("SIGNAL", "Micro", UIPalette.muted_dim))
	status.add_child(UIFactory.label("● UPLINK STABLE", "Micro", UIPalette.mint))
	box.add_child(status)

	var version := String(ProjectSettings.get_setting("application/config/version", "0.0"))
	var build := UIFactory.label("RIFTWARD v%s · Godot 4.7 · Frontier Ops" % version, "Micro", UIPalette.muted_dim)
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(build)
	return box


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _on_enter_hub() -> void:
	if App != null:
		App.show_hub()
	else:
		go(&"hub")


func _on_quick_deploy() -> void:
	# Quick Deploy opens the preflight screen; the actual drop happens there.
	go(&"quick_deploy")


func _save_callsign() -> void:
	var text := _callsign_edit.text if _callsign_edit != null else ""
	text = text.strip_edges()
	if text.is_empty():
		notify("Callsign required", "Enter a name between 1 and 20 characters.", &"warning")
		return
	ProfileState.set_callsign(text)
	ProfileState.save_now()
	_editing_callsign = false
	notify("Callsign updated", "You are now %s." % ProfileState.get_callsign(), &"success")
	refresh()


func first_focus_control() -> Control:
	if _quick_button != null and is_instance_valid(_quick_button) and _quick_button.is_inside_tree():
		return _quick_button
	return super.first_focus_control()


# ---------------------------------------------------------------------------
# Responsive
# ---------------------------------------------------------------------------

func _layout() -> void:
	if _wordmark == null or not is_instance_valid(_wordmark):
		return
	var width := viewport_width()
	var size := clampi(int(width * 0.082), 62, 124)
	_wordmark.add_theme_font_size_override("font_size", size)
