extends Node
## Application shell: boot, input map, settings, scene flow, deployment lifecycle.
## UI visuals and screens are owned by UIRoot; this service only routes.

signal booted

const UI_SCRIPT_PATH := "res://ui/ui_root.gd"
const DEPLOYMENT_SCRIPT_PATH := "res://features/run/deployment.gd"
const SETTINGS_PATH := "user://settings.cfg"

var ui: Node = null
var deployment: Node = null
var booted_once := false
var current_screen: StringName = &"boot"
var settings: Dictionary = {}
var _fallback_ui: CanvasLayer = null
var _loading := false
var _playtime_accum := 0.0
var input_ready := false
var inventory_open := false
var _pause_open := false
var _capture_deployment := false
var _capture_menu := false

## Single source of truth for gameplay defaults and the Settings reset button.
## Mouse buttons and joy axes are optional per action.
const ACTION_DEFAULTS: Array[Dictionary] = [
	{"action": &"move_forward", "keys": [KEY_W]},
	{"action": &"move_back", "keys": [KEY_S]},
	{"action": &"move_left", "keys": [KEY_A]},
	{"action": &"move_right", "keys": [KEY_D]},
	{"action": &"look_left", "joy_axes": [[JOY_AXIS_RIGHT_X, -1.0]]},
	{"action": &"look_right", "joy_axes": [[JOY_AXIS_RIGHT_X, 1.0]]},
	{"action": &"look_up", "joy_axes": [[JOY_AXIS_RIGHT_Y, -1.0]]},
	{"action": &"look_down", "joy_axes": [[JOY_AXIS_RIGHT_Y, 1.0]]},
	{"action": &"sprint", "keys": [KEY_SHIFT], "joy_buttons": [JOY_BUTTON_LEFT_STICK]},
	{"action": &"crouch", "keys": [KEY_CTRL], "joy_buttons": [JOY_BUTTON_B]},
	{"action": &"crouch_alt", "keys": [KEY_C]},
	{"action": &"jump", "keys": [KEY_SPACE], "joy_buttons": [JOY_BUTTON_A]},
	{"action": &"fire", "mouse": [MOUSE_BUTTON_LEFT], "joy_axes": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]},
	{"action": &"aim", "mouse": [MOUSE_BUTTON_RIGHT], "joy_axes": [[JOY_AXIS_TRIGGER_LEFT, 1.0]]},
	{"action": &"reload", "keys": [KEY_R], "joy_buttons": [JOY_BUTTON_X]},
	{"action": &"interact", "keys": [KEY_E], "joy_buttons": [JOY_BUTTON_Y]},
	{"action": &"revive", "keys": [KEY_E], "joy_buttons": [JOY_BUTTON_Y]},
	{"action": &"ability_1", "keys": [KEY_Q], "joy_buttons": [JOY_BUTTON_LEFT_SHOULDER]},
	{"action": &"ability_2", "keys": [KEY_F], "joy_buttons": [JOY_BUTTON_RIGHT_SHOULDER]},
	{"action": &"ultimate", "keys": [KEY_X], "joy_buttons": [JOY_BUTTON_DPAD_UP]},
	{"action": &"melee", "keys": [KEY_V], "joy_buttons": [JOY_BUTTON_RIGHT_STICK]},
	{"action": &"grenade", "keys": [KEY_G], "joy_buttons": [JOY_BUTTON_DPAD_DOWN]},
	{"action": &"weapon_1", "keys": [KEY_1]},
	{"action": &"weapon_2", "keys": [KEY_2]},
	{"action": &"weapon_3", "keys": [KEY_3]},
	{"action": &"weapon_4", "keys": [KEY_4]},
	{"action": &"weapon_swap", "mouse": [MOUSE_BUTTON_WHEEL_UP]},
	{"action": &"inventory", "keys": [KEY_I]},
	{"action": &"call_exfil", "keys": [KEY_H]},
	{"action": &"squad_command", "keys": [KEY_Z], "joy_buttons": [JOY_BUTTON_DPAD_LEFT]},
	{"action": &"pet_command", "keys": [KEY_B], "joy_buttons": [JOY_BUTTON_DPAD_RIGHT]},
	{"action": &"map", "keys": [KEY_M], "joy_buttons": [JOY_BUTTON_BACK]},
	{"action": &"pause", "keys": [KEY_ESCAPE], "joy_buttons": [JOY_BUTTON_START]},
	{"action": &"interact_hold", "keys": [KEY_E]},
]

const MOUSE_BUTTON_LABELS := {
	MOUSE_BUTTON_LEFT: "Mouse Left",
	MOUSE_BUTTON_RIGHT: "Mouse Right",
	MOUSE_BUTTON_MIDDLE: "Mouse Middle",
	MOUSE_BUTTON_WHEEL_UP: "Wheel Up",
	MOUSE_BUTTON_WHEEL_DOWN: "Wheel Down",
}

const DEFAULT_SETTINGS := {
	"master_volume": 0.9,
	"music_volume": 0.7,
	"sfx_volume": 0.9,
	"ui_volume": 0.8,
	"fov": 90.0,
	"mouse_sensitivity": 0.0022,
	"ads_sensitivity_scale": 0.7,
	"invert_y": false,
	"fullscreen": false,
	"vsync": true,
	"ui_scale": 1.0,
	"reduce_motion": false,
	"high_contrast": false,
	"damage_numbers": true,
	"subtitles": true,
	"camera_shake": 1.0,
	"quality": "high",
	"show_fps": false,
	"minimap": true,
	"bindings": {},
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	ensure_input_actions()
	_apply_audio_settings()
	_apply_display_settings()
	EventBus.deployment_ended.connect(_on_deployment_ended)


func boot() -> void:
	if booted_once:
		return
	booted_once = true
	_build_ui()
	call_deferred("_boot_deferred")


func _boot_deferred() -> void:
	await get_tree().process_frame
	var user_args := OS.get_cmdline_user_args()
	_capture_menu = "--capture-menu" in user_args
	_capture_deployment = "--smoke-capture" in user_args
	if "--inventory-smoke" in user_args:
		EventBus.player_spawned.connect(_run_inventory_smoke)
		start_deployment(&"salvage_sweep", 13579)
	elif "--shoot-smoke" in user_args:
		EventBus.player_spawned.connect(_run_shoot_smoke)
		start_deployment(&"salvage_sweep", 24680)
	elif "--smoke-deploy" in user_args or _capture_deployment:
		EventBus.player_spawned.connect(func(p: Node) -> void:
			print("[SMOKE] deployment player spawned: ", p)
			print("[SMOKE] seed=", RunState.run_seed, " contract=", RunState.contract_id)
		)
		start_deployment(&"salvage_sweep", 12345)
	else:
		show_main_menu()
		if _capture_menu:
			_capture_screen_after(1.2, "main_menu")
	booted.emit()


func _run_shoot_smoke(player: Node) -> void:
	await get_tree().create_timer(1.2).timeout
	if player == null or not is_instance_valid(player) or not is_deployment_active():
		print("[SHOOT-SMOKE] RESULT: FAIL - deployment not active")
		get_tree().quit(1)
		return
	var wc = player.get("weapon_controller")
	if wc == null:
		print("[SHOOT-SMOKE] RESULT: FAIL - no weapon controller")
		get_tree().quit(1)
		return
	var health = player.call("get_health_component") if player.has_method("get_health_component") else null
	if health != null:
		health.set_invulnerable(120.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var before: int = int(wc.get_hud_info().get("ammo", 0))
	Input.action_press("aim")
	for i in 6:
		await get_tree().physics_frame
	Input.action_press("fire")
	for i in 55:
		await get_tree().physics_frame
	Input.action_release("fire")
	await get_tree().physics_frame
	var after_fire: int = int(wc.get_hud_info().get("ammo", 0))
	Input.action_release("aim")
	# Slots must be exercised before reloading; reload deliberately blocks
	# weapon swaps until it completes.
	await _tap_action(&"weapon_1", 3)
	await _tap_action(&"weapon_2", 3)
	await _tap_action(&"weapon_3", 3)
	await _tap_action(&"weapon_4", 3)
	await _tap_action(&"fire", 4)
	await _tap_action(&"weapon_1", 3)
	await _tap_action(&"ability_1", 3)
	await _tap_action(&"ability_2", 3)
	await _tap_action(&"ultimate", 3)
	await _tap_action(&"reload", 3)
	await _tap_action(&"melee", 3)
	await _tap_action(&"grenade", 3)
	await _tap_action(&"squad_command", 3)
	await _tap_action(&"pet_command", 3)
	for i in 5:
		await get_tree().physics_frame
	var final_ammo: int = int(wc.get_hud_info().get("ammo", 0))
	var is_player_downed: bool = player.get("is_downed") == true
	print("[SHOOT-SMOKE] ammo_before=", before, " after_fire=", after_fire, " final=", final_ammo, " player_down=", is_player_downed)
	if after_fire >= before:
		print("[SHOOT-SMOKE] RESULT: FAIL - no shot fired")
		get_tree().quit(1)
	elif is_player_downed:
		print("[SHOOT-SMOKE] RESULT: FAIL - player downed during input smoke")
		get_tree().quit(1)
	else:
		print("[SHOOT-SMOKE] RESULT: PASS")
		get_tree().quit(0)


func _run_inventory_smoke(player: Node) -> void:
	await get_tree().create_timer(1.2).timeout
	if player == null or not is_instance_valid(player) or not is_deployment_active():
		print("[INVENTORY-SMOKE] RESULT: FAIL - deployment not active")
		get_tree().quit(1)
		return
	if not player.has_method("get_inventory_snapshot"):
		print("[INVENTORY-SMOKE] RESULT: FAIL - player has no inventory snapshot")
		get_tree().quit(1)
		return
	_inject_key(KEY_I, true)
	await get_tree().process_frame
	_inject_key(KEY_I, false)
	await get_tree().process_frame
	await get_tree().process_frame
	var overlay = ui.call("get_inventory_overlay") if ui != null and ui.has_method("get_inventory_overlay") else null
	var opened_ok: bool = inventory_open and get_tree().paused and overlay != null and overlay.visible
	var weapon_rows := int(overlay.call("get_weapon_row_count")) if overlay != null else 0
	var weapon_count := int((player.call("get_inventory_snapshot").get("weapons", []) as Array).size())
	print("[INVENTORY-SMOKE] opened=%s paused=%s overlay=%s weapon_rows=%d snapshot_weapons=%d" % [
		inventory_open, get_tree().paused, overlay != null, weapon_rows, weapon_count
	])
	_inject_key(KEY_I, true)
	await get_tree().process_frame
	_inject_key(KEY_I, false)
	await get_tree().process_frame
	await get_tree().process_frame
	var closed_ok: bool = not inventory_open and not get_tree().paused and (overlay == null or not overlay.visible)
	print("[INVENTORY-SMOKE] closed=%s paused=%s mouse=%d" % [not inventory_open, get_tree().paused, Input.get_mouse_mode()])
	if opened_ok and closed_ok and weapon_rows == 4 and weapon_count == 4:
		print("[INVENTORY-SMOKE] RESULT: PASS")
		get_tree().quit(0)
	else:
		print("[INVENTORY-SMOKE] RESULT: FAIL - opened_ok=%s closed_ok=%s" % [opened_ok, closed_ok])
		get_tree().quit(1)


func _inject_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap_action(action: StringName, frames: int = 2) -> void:
	Input.action_press(action)
	for i in frames:
		await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _capture_screen_after(seconds: float, label: String) -> void:
	await get_tree().create_timer(seconds).timeout
	if _capture_deployment and _deployment_is_active():
		var p = deployment.get("player")
		if p != null and is_instance_valid(p):
			print("[CAPTURE] player=", p.global_position, " on_floor=", p.is_on_floor(), " vel=", p.velocity)
			print("[CAPTURE] mask=", p.collision_mask, " layer=", p.collision_layer)
			var w = deployment.get("world")
			if w != null and w.has_method("sample_height"):
				print("[CAPTURE] ground=", w.sample_height(Vector2(p.global_position.x, p.global_position.z)))
			var wc = p.get("weapon_controller")
			if wc != null and wc.get("viewmodel_root") != null:
				print("[CAPTURE] viewmodel visible=", wc.viewmodel_root.visible, " pos=", wc.viewmodel_root.position, " scale=", wc.viewmodel_root.scale, " children=", wc.viewmodel_root.get_child_count())
				for child in wc.viewmodel_root.get_children():
					if child is Node3D:
						print("[CAPTURE]   model ", child.name, " visible=", child.visible)
	await RenderingServer.frame_post_draw
	_capture_viewport(label)
	if _capture_deployment:
		var p = deployment.get("player")
		if p != null and is_instance_valid(p):
			p.head.rotation.x = -0.5
			if ui != null:
				ui.visible = false
			await get_tree().create_timer(0.25).timeout
			await RenderingServer.frame_post_draw
			_capture_viewport(label + "_clear")
	get_tree().quit()


func _capture_viewport(label: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://tests/artifacts")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(label + ".png")
	var error := image.save_png(path)
	print("[CAPTURE] ", path, " error=", error)


func _build_ui() -> void:
	if ResourceLoader.exists(UI_SCRIPT_PATH):
		var script: Script = load(UI_SCRIPT_PATH)
		if script != null:
			var candidate = script.new()
			if candidate is CanvasLayer or candidate is Control:
				ui = candidate
				if ui is CanvasLayer:
					ui.layer = 10
				add_child(ui)
				return
	push_warning("[App] UIRoot not available; using fallback shell.")
	_build_fallback_ui()


func _build_fallback_ui() -> void:
	_fallback_ui = CanvasLayer.new()
	_fallback_ui.layer = 10
	add_child(_fallback_ui)
	var bg := ColorRect.new()
	bg.color = Color("0b1114")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fallback_ui.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fallback_ui.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	var title := Label.new()
	title.text = "RIFTWARD"
	title.add_theme_font_size_override("font_size", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Drop into the Reach. Build what survives."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("93a5a8"))
	box.add_child(subtitle)
	var deploy_btn := Button.new()
	deploy_btn.text = "  DEPLOY TO THE REACH  "
	deploy_btn.custom_minimum_size = Vector2(280, 52)
	deploy_btn.pressed.connect(func() -> void: start_deployment(&"salvage_sweep", 0))
	box.add_child(deploy_btn)
	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.pressed.connect(quit_to_desktop)
	box.add_child(quit_btn)


func _ui_call(method_name: StringName, args: Array = []) -> Variant:
	if ui != null and is_instance_valid(ui) and ui.has_method(method_name):
		return ui.callv(method_name, args)
	return null


func _set_fallback_visible(is_visible: bool) -> void:
	if _fallback_ui != null:
		_fallback_ui.visible = is_visible


func show_main_menu() -> void:
	_close_inventory_state()
	_free_deployment()
	current_screen = &"main_menu"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_set_fallback_visible(true)
	_ui_call("show_main_menu")
	_ui_call("refresh")
	AudioDirector.set_music_mood(&"menu")


func show_hub() -> void:
	_close_inventory_state()
	_free_deployment()
	current_screen = &"hub"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_set_fallback_visible(false)
	_ui_call("show_hub")
	_ui_call("refresh")
	AudioDirector.set_music_mood(&"hub")


func start_deployment(
	contract_id: StringName = &"salvage_sweep",
	seed_value: int = 0,
	threat: int = 1,
	mutators: Array = [],
	difficulty_id: StringName = &"",
	mode_id: StringName = &"normal"
) -> void:
	if _loading or _deployment_is_active():
		return
	if not ResourceLoader.exists(DEPLOYMENT_SCRIPT_PATH):
		EventBus.notification_requested.emit("Deployment unavailable", "The deployment scene is still being built.", &"error")
		AudioDirector.play_ui(&"ui_error")
		return
	var deployment_script: Script = load(DEPLOYMENT_SCRIPT_PATH)
	if deployment_script == null:
		return
	_loading = true
	current_screen = &"loading"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_set_fallback_visible(false)
	_ui_call("show_loading", ["Preparing the Reach", 0.0])
	AudioDirector.play_ui(&"ui_confirm")
	await get_tree().process_frame
	var instance = deployment_script.new()
	if not (instance is Node):
		_loading = false
		return
	deployment = instance
	deployment.name = "Deployment"
	add_child(deployment)
	if deployment.has_signal("progress_changed"):
		deployment.progress_changed.connect(_on_deployment_progress)
	if deployment.has_signal("ready_to_play"):
		deployment.ready_to_play.connect(_on_deployment_ready)
	if deployment.has_signal("finished"):
		deployment.finished.connect(_on_deployment_finished)
	if not difficulty_id.is_empty():
		ProfileState.set_last_difficulty(difficulty_id)
	ProfileState.set_last_mode(mode_id)
	if deployment.has_method("setup"):
		deployment.setup(contract_id, seed_value, threat, mutators, difficulty_id, mode_id)
	else:
		push_error("[App] Deployment has no setup() method.")
		_loading = false


func _deployment_is_active() -> bool:
	return deployment != null and is_instance_valid(deployment)


func _free_deployment() -> void:
	_loading = false
	if deployment != null and is_instance_valid(deployment):
		deployment.queue_free()
		deployment = null


func _on_deployment_progress(value: float, label: String) -> void:
	_ui_call("update_loading", [value, label])
	EventBus.loading_progress.emit(value, label)


func _on_deployment_ready(player: Node) -> void:
	_loading = false
	current_screen = &"deployment"
	_ui_call("hide_loading")
	_ui_call("show_deployment_hud", [player])
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	AudioDirector.play_ui(&"ui_confirm")
	AudioDirector.set_music_mood(&"deployment")
	if _capture_deployment:
		_capture_screen_after(2.0, "deployment")

func _on_deployment_ended(result: Dictionary) -> void:
	if not _deployment_is_active():
		return
	_close_inventory_state()
	var items: Array = result.get("items", [])
	result["progression"] = ProfileState.record_run(result, items)
	_free_deployment()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	current_screen = &"results"
	_ui_call("show_results", [result])
	AudioDirector.play_ui(&"ui_confirm")
	AudioDirector.set_music_mood(&"hub")


func _on_deployment_finished(result: Dictionary) -> void:
	# Deployment may report directly instead of via the bus.
	_on_deployment_ended(result)


func return_to_hub() -> void:
	show_hub()


func return_to_main_menu() -> void:
	ProfileState.save_now()
	show_main_menu()


func quit_to_desktop() -> void:
	ProfileState.save_now()
	save_settings()
	get_tree().quit()


func is_deployment_active() -> bool:
	return current_screen == &"deployment" and _deployment_is_active()


func set_pause(paused: bool) -> void:
	if not is_deployment_active():
		return
	if paused and inventory_open:
		set_inventory(false)
	_pause_open = paused
	get_tree().paused = paused
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED)
	_ui_call("show_pause", [paused])
	EventBus.game_paused.emit(paused)


func toggle_pause() -> void:
	set_pause(not get_tree().paused)


## Full-screen inventory/satchel. Pauses gameplay and releases the mouse; the
## overlay is owned by UIRoot and the close path is shared with Esc.
func set_inventory(open: bool) -> void:
	if not is_deployment_active():
		if not open and inventory_open:
			inventory_open = false
			_ui_call("hide_inventory")
		return
	if open:
		if _pause_open or inventory_open:
			return
		var player = deployment.get("player") if deployment != null else null
		if player != null and is_instance_valid(player):
			if bool(player.get("is_dead")) or bool(player.get("is_downed")):
				return
		var snapshot: Dictionary = {}
		if player != null and is_instance_valid(player) and player.has_method("get_inventory_snapshot"):
			snapshot = player.call("get_inventory_snapshot")
		inventory_open = true
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_ui_call("show_inventory", [snapshot])
		AudioDirector.play_ui(&"ui_click")
	else:
		if not inventory_open:
			_ui_call("hide_inventory")
			return
		inventory_open = false
		_ui_call("hide_inventory")
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		AudioDirector.play_ui(&"ui_click")


func toggle_inventory() -> void:
	set_inventory(not inventory_open)


func _close_inventory_state() -> void:
	if inventory_open:
		inventory_open = false
		_ui_call("hide_inventory")
	_pause_open = false
	if is_deployment_active() and get_tree().paused:
		get_tree().paused = false


func get_ui() -> Node:
	return ui


func get_deployment() -> Node:
	return deployment


func get_setting(key: String, fallback: Variant = null) -> Variant:
	return settings.get(key, DEFAULT_SETTINGS.get(key, fallback))


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_apply_setting(key, value)
	EventBus.settings_changed.emit(key, value)


func _apply_setting(key: String, value: Variant) -> void:
	match key:
		"fullscreen":
			_apply_display_settings()
		"vsync":
			_apply_display_settings()
		"master_volume", "music_volume", "sfx_volume", "ui_volume":
			_apply_audio_settings()
		_:
			pass


func _apply_audio_settings() -> void:
	AudioDirector.set_bus_volume("Master", float(get_setting("master_volume")))
	AudioDirector.set_bus_volume("Music", float(get_setting("music_volume")))
	AudioDirector.set_bus_volume("SFX", float(get_setting("sfx_volume")))
	AudioDirector.set_bus_volume("UI", float(get_setting("ui_volume")))


func _apply_display_settings() -> void:
	var window := get_window()
	if window == null:
		return
	var fullscreen := bool(get_setting("fullscreen"))
	window.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	if bool(get_setting("vsync")):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for key in DEFAULT_SETTINGS.keys():
			if cfg.has_section_key("settings", key):
				settings[key] = cfg.get_value("settings", key)
	_apply_saved_bindings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in settings.keys():
		cfg.set_value("settings", key, settings[key])
	cfg.save(SETTINGS_PATH)


func ensure_input_actions(force: bool = false) -> void:
	if input_ready and not force:
		return
	for entry in ACTION_DEFAULTS:
		var action: StringName = entry.get("action", &"")
		if action == &"":
			continue
		if force and InputMap.has_action(action):
			InputMap.action_erase_events(action)
		_add_action(
			action,
			entry.get("keys", []),
			entry.get("mouse", []),
			entry.get("joy_buttons", []),
			entry.get("joy_axes", [])
		)
	_set_deadzones()
	input_ready = true
	_apply_saved_bindings()


func _add_action(action: StringName, keys: Array, mouse_buttons: Array, joy_buttons: Array, joy_axes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	for button in mouse_buttons:
		var event := InputEventMouseButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)
	for button in joy_buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)
	for axis in joy_axes:
		var event := InputEventJoypadMotion.new()
		event.axis = axis[0]
		event.axis_value = axis[1]
		InputMap.action_add_event(action, event)


func _set_deadzones() -> void:
	for action in InputMap.get_actions():
		InputMap.action_set_deadzone(action, 0.2)


func rebind_action(action: StringName, event: InputEvent) -> bool:
	if not InputMap.has_action(action):
		return false
	if find_binding_conflict(event, action) != &"":
		return false
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	var bindings: Dictionary = settings.get("bindings", {})
	bindings[String(action)] = _event_to_dict(event)
	settings["bindings"] = bindings
	save_settings()
	EventBus.settings_changed.emit("bindings", bindings)
	return true


func find_binding_conflict(event: InputEvent, ignore_action: StringName = &"") -> StringName:
	if event == null:
		return &""
	for entry in ACTION_DEFAULTS:
		var action: StringName = entry.get("action", &"")
		if action == &"" or action == ignore_action:
			continue
		if _actions_share_binding_by_design(action, ignore_action):
			continue
		if not InputMap.has_action(action):
			continue
		for existing in InputMap.action_get_events(action):
			if _events_equal(existing, event):
				return action
	return &""


func _actions_share_binding_by_design(a: StringName, b: StringName) -> bool:
	# Interact and revive intentionally share E so a downed player can hold the
	# same key to self-revive.
	return (a == &"interact" and b == &"revive") or (a == &"revive" and b == &"interact")


func _events_equal(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	if a is InputEventKey and b is InputEventKey:
		var ak := int((a as InputEventKey).physical_keycode)
		if ak == 0:
			ak = int((a as InputEventKey).keycode)
		var bk := int((b as InputEventKey).physical_keycode)
		if bk == 0:
			bk = int((b as InputEventKey).keycode)
		return ak != 0 and ak == bk
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		var aa := a as InputEventJoypadMotion
		var bb := b as InputEventJoypadMotion
		return aa.axis == bb.axis and signf(aa.axis_value) == signf(bb.axis_value)
	return false


func get_action_binding_text(action: StringName, fallback: String = "Unbound") -> String:
	if not InputMap.has_action(action):
		return fallback
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			var code := int(key_event.physical_keycode)
			if code == 0:
				code = int(key_event.keycode)
			if code != 0:
				return OS.get_keycode_string(code)
		if event is InputEventMouseButton:
			var button := int((event as InputEventMouseButton).button_index)
			return String(MOUSE_BUTTON_LABELS.get(button, "Mouse %d" % button))
		if event is InputEventJoypadButton:
			return "Pad %s" % _joy_button_text((event as InputEventJoypadButton).button_index)
		if event is InputEventJoypadMotion:
			return "Pad Axis %d" % (event as InputEventJoypadMotion).axis
	return fallback


func reset_bindings() -> void:
	settings["bindings"] = {}
	for entry in ACTION_DEFAULTS:
		var action: StringName = entry.get("action", &"")
		if action != &"" and InputMap.has_action(action):
			InputMap.action_erase_events(action)
	input_ready = false
	ensure_input_actions(true)
	save_settings()
	EventBus.settings_changed.emit("bindings", {})
	EventBus.notification_requested.emit("Controls reset", "All keyboard and gamepad bindings restored to defaults.", &"success")


func _joy_button_text(button_index: int) -> String:
	match button_index:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_LEFT_STICK:
			return "LS"
		JOY_BUTTON_RIGHT_STICK:
			return "RS"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_BACK:
			return "Back"
		JOY_BUTTON_DPAD_UP:
			return "D-Pad Up"
		JOY_BUTTON_DPAD_DOWN:
			return "D-Pad Down"
		JOY_BUTTON_DPAD_LEFT:
			return "D-Pad Left"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-Pad Right"
		_:
			return str(button_index)


func _event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "physical_keycode": int(event.physical_keycode)}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button_index": int(event.button_index)}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button_index": int(event.button_index)}
	if event is InputEventJoypadMotion:
		return {"type": "joy_axis", "axis": int(event.axis), "axis_value": event.axis_value}
	return {}


func _dict_to_event(payload: Dictionary) -> InputEvent:
	match String(payload.get("type", "")):
		"key":
			var event := InputEventKey.new()
			event.physical_keycode = int(payload.get("physical_keycode", KEY_W))
			return event
		"mouse":
			var event := InputEventMouseButton.new()
			event.button_index = int(payload.get("button_index", MOUSE_BUTTON_LEFT))
			return event
		"joy_button":
			var event := InputEventJoypadButton.new()
			event.button_index = int(payload.get("button_index", JOY_BUTTON_A))
			return event
		"joy_axis":
			var event := InputEventJoypadMotion.new()
			event.axis = int(payload.get("axis", JOY_AXIS_LEFT_X))
			event.axis_value = float(payload.get("axis_value", 1.0))
			return event
	return null


func _apply_saved_bindings() -> void:
	var bindings: Dictionary = settings.get("bindings", {})
	if not input_ready and not InputMap.has_action("move_forward"):
		return
	for action in bindings.keys():
		if not InputMap.has_action(action):
			continue
		var event := _dict_to_event(bindings[action])
		if event != null:
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if not is_deployment_active():
		return
	if event.is_action_pressed("inventory"):
		if inventory_open:
			set_inventory(false)
		elif not _pause_open:
			set_inventory(true)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if inventory_open:
			set_inventory(false)
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if is_deployment_active() and not get_tree().paused:
		_playtime_accum += delta
		if _playtime_accum >= 10.0:
			ProfileState.mark_playtime(_playtime_accum)
			_playtime_accum = 0.0
			ProfileState.save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if has_node("/root/ProfileState"):
			ProfileState.mark_playtime(_playtime_accum)
			ProfileState.save_now()
		save_settings()
