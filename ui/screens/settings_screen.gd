class_name SettingsScreen
extends UIScreen
## Full-screen settings page. Reuses UISettingsPanel so pause and menus stay in
## sync. Entered with {"return_to": <screen_id>} so Back returns where you came from.

var _panel: UISettingsPanel = null


func _compose() -> void:
	var backdrop := UIBackdrop.new()
	backdrop.configure(UIBackdrop.Mood.HUB)
	add_child(backdrop)

	var page := build_page(UIPalette.SP5, UIPalette.SP5, UIPalette.SP3)

	var top_row := UIFactory.hbox(UIPalette.SP4)
	var back := UIFactory.ghost_button("Back", &"chevron-left")
	back.pressed.connect(func() -> void: go(&"back"))
	top_row.add_child(back)
	top_row.add_child(UIFactory.spacer_h())
	top_row.add_child(wallet_row())
	page.add_child(top_row)

	# One title only: the page already lives under Settings.
	var title_row := UIFactory.hbox(UIPalette.SP2)
	var glyph := UIFactory.icon_or_null(&"settings", 22, UIPalette.mint)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(glyph)
	title_row.add_child(UIFactory.heading("Settings", "H1"))
	page.add_child(title_row)

	var scroll := UIFactory.vscroll()
	page.add_child(scroll)
	var center_row := UIFactory.hbox(0, BoxContainer.ALIGNMENT_CENTER)
	center_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center_row)
	var host := UIFactory.vbox(0)
	host.custom_minimum_size = Vector2(1080, 0)
	center_row.add_child(host)
	_panel = UISettingsPanel.new()
	host.add_child(_panel)
	host.add_child(UIFactory.fixed_spacer(0, UIPalette.SP5))


func first_focus_control() -> Control:
	if _panel != null and is_instance_valid(_panel):
		var found := UIFactory.focus_first(_panel)
		if found != null:
			return found
	return super.first_focus_control()


# ---------------------------------------------------------------------------
# Test / automation accessors (delegate to the reusable settings panel)
# ---------------------------------------------------------------------------

func get_settings_panel() -> UISettingsPanel:
	return _panel


## Interactive control for a setting key, e.g. "window_mode" or "render_scale".
func get_control(key: String) -> Control:
	if _panel != null and is_instance_valid(_panel):
		return _panel.get_control(key)
	return null


func get_option_control(key: String) -> OptionButton:
	if _panel != null and is_instance_valid(_panel):
		return _panel.get_option_control(key)
	return null


func _layout() -> void:
	pass
