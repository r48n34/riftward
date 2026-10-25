class_name UIRoot
extends CanvasLayer
## The entire user interface shell. App instantiates this once at boot and routes
## lifecycle events here. UIRoot owns the theme, screen stack, HUD, overlays and
## accessibility state; it never assumes deployment or player nodes exist.

const SCREEN_PATHS := {
	&"main_menu": "res://ui/screens/main_menu.gd",
	&"quick_deploy": "res://ui/screens/quick_deploy.gd",
	&"hub": "res://ui/screens/hub.gd",
	&"loadout": "res://ui/screens/loadout.gd",
	&"locker": "res://ui/screens/locker.gd",
	&"skills": "res://ui/screens/skills.gd",
	&"squad": "res://ui/screens/squad.gd",
	&"outpost": "res://ui/screens/outpost.gd",
	&"codex": "res://ui/screens/codex.gd",
	&"settings": "res://ui/screens/settings_screen.gd",
}
const LOADING_PATH := "res://ui/screens/loading.gd"
const PAUSE_PATH := "res://ui/screens/pause.gd"
const RESULTS_PATH := "res://ui/screens/results.gd"
const INVENTORY_PATH := "res://ui/screens/inventory_overlay.gd"
const HUD_PATH := "res://ui/hud/hud_root.gd"

const MENU_SCREENS: Array[StringName] = [
	&"main_menu", &"quick_deploy", &"hub", &"loadout", &"locker", &"skills", &"squad", &"outpost", &"codex", &"settings"
]

var _root: Control = null
var _screen_host: Control = null
var _hud_host: Control = null
var _overlay_host: Control = null
var _toast_host: VBoxContainer = null
var _theme: Theme = null
var _screens: Dictionary = {}
var _current_screen: StringName = &""
var _screen_args: Dictionary = {}
var _history: Array[StringName] = []
var _loading: Node = null
var _pause: Node = null
var _results: Node = null
var _inventory: Control = null
var _hud: Control = null
var _hud_hidden_by_inventory := false
var _toast_count := 0
var _pending_notifications: Array = []
var _pending_radio: Array = []


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	UIPalette.apply_settings(App)
	_build_tree()
	_apply_ui_scale()
	_connect_bus()
	set_process_unhandled_input(true)


func _build_tree() -> void:
	_root = Control.new()
	_root.name = "UIRootContent"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_theme = UITheme.build()
	_root.theme = _theme
	add_child(_root)

	_screen_host = _make_host("ScreenHost")
	_hud_host = _make_host("HudHost")
	_hud_host.visible = false
	_overlay_host = _make_host("OverlayHost")
	_toast_host = VBoxContainer.new()
	_toast_host.name = "ToastHost"
	_toast_host.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_toast_host.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toast_host.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_host.add_theme_constant_override("separation", UIPalette.SP2)
	_toast_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_host.offset_left = -460.0
	_toast_host.offset_top = -220.0
	_toast_host.offset_right = -UIPalette.SP5
	_toast_host.offset_bottom = -UIPalette.SP5
	_root.add_child(_toast_host)


func _make_host(host_name: String) -> Control:
	var host := Control.new()
	host.name = host_name
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(host)
	return host


func _connect_bus() -> void:
	if EventBus == null:
		return
	EventBus.settings_changed.connect(_on_setting_changed)
	EventBus.notification_requested.connect(_on_notification_requested)
	EventBus.radio_message.connect(_on_radio_message)


# ---------------------------------------------------------------------------
# Public API expected by App
# ---------------------------------------------------------------------------

func show_main_menu() -> void:
	_clear_hud()
	_hide_overlays()
	_clear_toasts()
	_pending_notifications.clear()
	_pending_radio.clear()
	_history.clear()
	show_screen(&"main_menu", {})


func show_hub() -> void:
	_clear_hud()
	_hide_overlays()
	_clear_toasts()
	_pending_notifications.clear()
	_pending_radio.clear()
	_history = [&"hub"]
	show_screen(&"hub", {})


func show_loading(title: String, progress: float = 0.0, brief: Dictionary = {}) -> void:
	_clear_hud()
	_hide_results()
	_hide_pause()
	_clear_toasts()
	_screen_host.visible = false
	_ensure_loading()
	if _loading != null and _loading.has_method("present"):
		_loading.call("present", title, progress, brief)


func update_loading(progress: float, label: String) -> void:
	if _loading != null and _loading.has_method("update_loading"):
		_loading.call("update_loading", progress, label)


func hide_loading() -> void:
	if _loading != null and _loading.has_method("dismiss"):
		_loading.call("dismiss")


func get_loading_screen() -> Node:
	return _loading


func show_deployment_hud(player: Node) -> void:
	_hide_overlays()
	_screen_host.visible = false
	_clear_hud()
	if not ResourceLoader.exists(HUD_PATH):
		push_warning("[UIRoot] HUD script missing at %s" % HUD_PATH)
		return
	var script: Script = load(HUD_PATH)
	if script == null:
		return
	var hud = script.new()
	if not (hud is Control):
		return
	_hud = hud
	_hud_host.add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _hud.has_method("bind_player"):
		_hud.call("bind_player", player)
	if _hud.has_method("apply_settings"):
		_hud.call("apply_settings")
	_hud_host.visible = true
	if _hud is Node:
		(_hud as Node).process_mode = Node.PROCESS_MODE_PAUSABLE
	_flush_pending_events()


func show_results(result: Dictionary) -> void:
	_hide_loading()
	_clear_hud()
	_screen_host.visible = false
	_hide_pause()
	_ensure_results()
	if _results != null and _results.has_method("present"):
		_results.call("present", result)


func show_inventory(snapshot: Dictionary = {}) -> void:
	_ensure_inventory()
	if _inventory != null and _inventory.has_method("present"):
		_inventory.call("present", snapshot)
	if _inventory is CanvasItem:
		(_inventory as CanvasItem).visible = true
	# The paused inventory is the whole view: hide the live HUD so its panels do
	# not bleed through the scrim.
	if _hud_host != null and _hud_host.visible:
		_hud_hidden_by_inventory = true
		_hud_host.visible = false


func hide_inventory() -> void:
	if _inventory != null and is_instance_valid(_inventory) and _inventory.has_method("dismiss"):
		_inventory.call("dismiss")
	if _hud_hidden_by_inventory:
		_hud_hidden_by_inventory = false
		if _hud_host != null and _hud != null and is_instance_valid(_hud):
			_hud_host.visible = true


func get_inventory_overlay() -> Control:
	return _inventory


func show_pause(paused: bool) -> void:
	if paused:
		_ensure_pause()
		if _pause != null and _pause.has_method("present"):
			_pause.call("present")
		if _pause is CanvasItem:
			(_pause as CanvasItem).visible = true
	else:
		if _pause != null and _pause.has_method("dismiss"):
			_pause.call("dismiss")
		if _pause is CanvasItem:
			(_pause as CanvasItem).visible = false


func refresh() -> void:
	if _current_screen != &"" and _screens.has(_current_screen):
		var screen = _screens[_current_screen]
		if is_instance_valid(screen) and screen.visible and screen.has_method("refresh"):
			screen.call("refresh")
	if _hud != null and is_instance_valid(_hud) and _hud.visible and _hud.has_method("refresh"):
		_hud.call("refresh")


# ---------------------------------------------------------------------------
# Screen management
# ---------------------------------------------------------------------------

func show_screen(screen_id: StringName, args: Dictionary = {}) -> bool:
	var screen := _get_screen(screen_id)
	if screen == null:
		push_warning("[UIRoot] Screen unavailable: %s" % String(screen_id))
		_on_toast_requested("Screen unavailable", "The '%s' screen could not be loaded." % String(screen_id), &"error")
		return false
	if _current_screen == screen_id and is_instance_valid(screen):
		_screen_args = args
		_screen_host.visible = true
		if screen.has_method("enter"):
			screen.call("enter", args)
		return true
	for other_id in _screens.keys():
		if other_id == screen_id:
			continue
		var other = _screens[other_id]
		if is_instance_valid(other) and other.visible and other.has_method("exit"):
			other.call("exit")
	if _current_screen != &"" and _current_screen != screen_id and MENU_SCREENS.has(_current_screen) and _current_screen != &"main_menu":
		_history.append(_current_screen)
		if _history.size() > 12:
			_history.pop_front()
	_current_screen = screen_id
	_screen_args = args
	_screen_host.visible = true
	if screen.has_method("enter"):
		screen.call("enter", args)
	return true


func _get_screen(screen_id: StringName) -> Control:
	if _screens.has(screen_id):
		var cached = _screens[screen_id]
		if is_instance_valid(cached):
			return cached
		_screens.erase(screen_id)
	var path: String = SCREEN_PATHS.get(screen_id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var script: Script = load(path)
	if script == null:
		return null
	var instance = script.new()
	if not (instance is UIScreen):
		if instance is Node:
			(instance as Node).queue_free()
		push_warning("[UIRoot] %s does not extend UIScreen." % path)
		return null
	var screen := instance as UIScreen
	screen.screen_id = screen_id
	screen.navigate.connect(_on_screen_navigate)
	screen.toast_requested.connect(_on_toast_requested)
	_screen_host.add_child(screen)
	_screens[screen_id] = screen
	return screen


func _on_screen_navigate(target: StringName) -> void:
	match target:
		&"main_menu":
			if App != null:
				App.show_main_menu()
			else:
				show_main_menu()
		&"hub":
			if App != null:
				App.show_hub()
			else:
				show_hub()
		&"back":
			navigate_back()
		_:
			if MENU_SCREENS.has(target):
				show_screen(target, {"return_to": _current_screen})
			else:
				push_warning("[UIRoot] Unknown navigation target: %s" % String(target))


func navigate_back() -> void:
	if _current_screen == &"quick_deploy":
		if App != null and App.get_ui() == self:
			App.show_main_menu()
		else:
			show_main_menu()
		return
	if _current_screen == &"settings":
		var return_to: StringName = StringName(_screen_args.get("return_to", &"hub"))
		show_screen(return_to if return_to != &"" else &"hub", {})
		return
	if _history.size() > 1:
		_history.pop_back()
		var previous: StringName = _history[_history.size() - 1]
		show_screen(previous, {})
		return
	if App != null:
		App.show_hub()
	else:
		show_hub()


# ---------------------------------------------------------------------------
# Overlays
# ---------------------------------------------------------------------------

func _ensure_loading() -> void:
	if _loading != null and is_instance_valid(_loading):
		(_loading as CanvasItem).visible = true
		return
	_loading = _spawn_overlay(LOADING_PATH)
	if _loading != null:
		(_loading as CanvasItem).z_index = 10
		(_loading as CanvasItem).visible = false


func _ensure_pause() -> void:
	if _pause != null and is_instance_valid(_pause):
		return
	_pause = _spawn_overlay(PAUSE_PATH)
	if _pause != null:
		(_pause as CanvasItem).z_index = 5
		(_pause as CanvasItem).visible = false


func _ensure_results() -> void:
	if _results != null and is_instance_valid(_results):
		(_results as CanvasItem).visible = true
		return
	_results = _spawn_overlay(RESULTS_PATH)
	if _results != null:
		(_results as CanvasItem).z_index = 20
		(_results as CanvasItem).visible = false


func _ensure_inventory() -> void:
	if _inventory != null and is_instance_valid(_inventory):
		return
	_inventory = _spawn_overlay(INVENTORY_PATH) as Control
	if _inventory != null:
		_inventory.process_mode = Node.PROCESS_MODE_ALWAYS
		_inventory.mouse_filter = Control.MOUSE_FILTER_STOP
		_inventory.z_index = 15
		_inventory.visible = false


func _spawn_overlay(path: String) -> Node:
	if not ResourceLoader.exists(path):
		push_warning("[UIRoot] Overlay missing: %s" % path)
		return null
	var script: Script = load(path)
	if script == null:
		return null
	var node = script.new()
	if not (node is Control):
		if node is Node:
			(node as Node).queue_free()
		return null
	var control := node as Control
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	_overlay_host.add_child(control)
	return control


func _hide_overlays() -> void:
	_hide_loading()
	_hide_pause()
	_hide_results()
	_hide_inventory()


func _hide_loading() -> void:
	if _loading != null and is_instance_valid(_loading):
		(_loading as CanvasItem).visible = false


func _hide_pause() -> void:
	if _pause != null and is_instance_valid(_pause):
		(_pause as CanvasItem).visible = false


func _hide_results() -> void:
	if _results != null and is_instance_valid(_results):
		(_results as CanvasItem).visible = false


func _hide_inventory() -> void:
	if _inventory != null and is_instance_valid(_inventory):
		if _inventory.has_method("dismiss"):
			_inventory.call("dismiss")
		else:
			_inventory.visible = false


func _clear_hud() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null
	_hud_host.visible = false


# ---------------------------------------------------------------------------
# Settings / accessibility
# ---------------------------------------------------------------------------

func _apply_ui_scale() -> void:
	var window := get_window()
	if window != null:
		window.content_scale_factor = clampf(UIPalette.ui_scale, 0.75, 1.6)


func _on_setting_changed(key: String, value: Variant) -> void:
	match key:
		"reduce_motion":
			UIPalette.apply_settings(App)
			if _current_screen != &"settings":
				refresh()
		"high_contrast":
			UIPalette.apply_settings(App)
			_theme = UITheme.build()
			_root.theme = _theme
			if _current_screen != &"settings":
				refresh()
		"ui_scale":
			UIPalette.apply_settings(App)
			_apply_ui_scale()
		"damage_numbers", "subtitles", "camera_shake", "minimap", "bindings":
			UIPalette.apply_settings(App)
			if _hud != null and is_instance_valid(_hud) and _hud.has_method("apply_settings"):
				_hud.call("apply_settings")
		_:
			pass


# ---------------------------------------------------------------------------
# Input: menu back navigation (deployment pause is owned by App)
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if App != null and App.is_deployment_active():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if _current_screen == &"":
			return
		if _current_screen == &"main_menu":
			return
		if _current_screen == &"hub":
			if App != null:
				App.show_main_menu()
			get_viewport().set_input_as_handled()
			return
		navigate_back()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Toasts
# ---------------------------------------------------------------------------

func _on_toast_requested(title: String, message: String, severity: StringName = &"info") -> void:
	if _toast_host == null:
		return
	while _toast_host.get_child_count() >= 3:
		var oldest := _toast_host.get_child(0)
		_toast_host.remove_child(oldest)
		oldest.queue_free()
		_toast_count = maxi(0, _toast_count - 1)
	var severity_color := UIPalette.severity_color(severity)
	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_theme_stylebox_override(
		"panel",
		UITheme._box(UIPalette.alpha(UIPalette.ink, 0.94), UIPalette.alpha(severity_color, 0.65), UIPalette.R_MD, 1, Vector4(16, 12, 16, 12))
	)
	var icon_name := &"info"
	match severity:
		&"error":
			icon_name = &"warning"
		&"success":
			icon_name = &"shield-check"
		&"warning":
			icon_name = &"warning"
		&"loot":
			icon_name = &"star"
		&"rift":
			icon_name = &"bolt"
	toast.add_child(UIFactory.toast_row(icon_name, title, message, severity_color))
	_toast_host.add_child(toast)
	_toast_count += 1
	UIFactory.animate_in(toast)
	var tween := toast.create_tween()
	tween.tween_interval(3.2 if UIPalette.reduce_motion else 3.0)
	tween.tween_property(toast, "modulate:a", 0.0, UIPalette.motion(0.3)).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func() -> void:
		_toast_count = maxi(0, _toast_count - 1)
		if is_instance_valid(toast):
			toast.queue_free()
	)


func _clear_toasts() -> void:
	_toast_count = 0
	if _toast_host == null:
		return
	UIFactory.clear_children(_toast_host)


func _flush_pending_events() -> void:
	if _hud == null or not is_instance_valid(_hud):
		_pending_notifications.clear()
		_pending_radio.clear()
		return
	for entry in _pending_notifications:
		if _hud.has_method("notify"):
			_hud.call("notify", entry.get("title", ""), entry.get("message", ""), StringName(entry.get("severity", &"info")))
	_pending_notifications.clear()
	for entry in _pending_radio:
		if _hud.has_method("show_subtitle"):
			_hud.call("show_subtitle", entry.get("speaker", ""), entry.get("line", ""))
	_pending_radio.clear()


func _on_notification_requested(title: String, message: String, severity: StringName) -> void:
	# The in-game HUD renders its own notifications; menus use the toast stack.
	if _hud != null and is_instance_valid(_hud) and _hud.visible:
		return
	if _loading != null and is_instance_valid(_loading) and _loading.visible:
		if _pending_notifications.size() < 3:
			_pending_notifications.append({"title": title, "message": message, "severity": severity})
		return
	if _current_screen == &"main_menu" or _current_screen == &"hub":
		_on_toast_requested(title, message, severity)


func _on_radio_message(speaker: String, line: String) -> void:
	if _hud != null and is_instance_valid(_hud):
		return
	# Radio traffic during loading is buffered and delivered once the HUD exists.
	if (_loading != null and is_instance_valid(_loading) and _loading.visible) or _current_screen == &"loading":
		if _pending_radio.size() < 2:
			_pending_radio.append({"speaker": speaker, "line": line})
		return
	# Menu screens never show radio chatter as cards.


# ---------------------------------------------------------------------------
# Queries (test harness + future systems)
# ---------------------------------------------------------------------------

func current_screen() -> StringName:
	return _current_screen


func get_hud() -> Control:
	return _hud


func get_theme_resource() -> Theme:
	return _theme


func has_screen(screen_id: StringName) -> bool:
	return SCREEN_PATHS.has(screen_id)
