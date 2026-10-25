extends Node3D
## WORLD PREVIEW ??standalone windowed viewer for the procedural frontier.
##
## Controls: click to capture mouse, WASD + Q/E fly, Shift = fast, F12 = save
## screenshot, Esc = free the mouse. Or run with:
##   godot --path <project> res://features/world/world_preview.tscn -- --capture
## to render a handful of framed 1600x900 screenshots into
## res://features/world/preview_shots/ and quit (useful for visual QA).

const WorldBuilderScript := preload("res://features/world/world_builder.gd")

@export var world_seed := 12345
@export var capture_dir := "res://features/world/preview_shots"
@export var auto_capture := false
@export var fly_speed := 34.0

var _world = null
var _camera: Camera3D
var _hud: Label
var _capture := false
var _yaw := 0.2
var _pitch := -0.28
var _generated := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_capture = auto_capture or args.has("--capture")
	var preset_id: StringName = &""
	for i in args.size():
		if String(args[i]) == "--preset" and i + 1 < args.size():
			preset_id = StringName(String(args[i + 1]))
	_build_view()
	_world = WorldBuilderScript.new()
	_world.name = "World"
	add_child(_world)
	if preset_id != &"" and ContentDB != null:
		var preset: Dictionary = ContentDB.get_map_preset(preset_id)
		if not preset.is_empty():
			_world.apply_preset(preset)
			capture_dir = "%s/%s" % [capture_dir, String(preset_id)]
	_world.generation_progress.connect(_on_progress)
	_world.generation_finished.connect(_on_generation_finished)
	await _world.generate(world_seed)
	_generated = true
	_place_overview_camera()
	if _capture:
		await _capture_shots()
	else:
		_hud.text = "RIFTWARD — world preview\nLMB capture mouse · WASD/QE fly · Shift fast · F12 screenshot · Esc release"
		print("[world-preview] ready. WASD/QE fly, F12 screenshot.")


func _build_view() -> void:
	_camera = Camera3D.new()
	_camera.name = "PreviewCamera"
	_camera.fov = 72.0
	_camera.near = 0.1
	_camera.far = 5000.0
	_camera.position = Vector3(0.0, 220.0, 620.0)
	add_child(_camera)
	_camera.current = true

	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	_hud = Label.new()
	_hud.name = "Status"
	_hud.position = Vector2(24.0, 20.0)
	_hud.add_theme_font_size_override("font_size", 18)
	_hud.add_theme_color_override("font_color", Color(0.93, 0.96, 0.92))
	_hud.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.09))
	_hud.add_theme_constant_override("outline_size", 6)
	_hud.text = "Generating RIFTWARD frontier..."
	layer.add_child(_hud)


func _place_overview_camera() -> void:
	_camera.position = Vector3(240.0, 265.0, 640.0)
	_camera.look_at(Vector3(-40.0, 10.0, -220.0), Vector3.UP)


func _on_progress(value: float, label: String) -> void:
	if _hud != null:
		_hud.text = "Generating RIFTWARD frontier...  %d%%\n%s" % [int(value * 100.0), label]
	print("[world-preview] %3d%% %s" % [int(value * 100.0), label])


func _on_generation_finished(ok: bool) -> void:
	print("[world-preview] generation_finished(%s) stats=%s" % [str(ok), JSON.stringify(_world.get_generation_stats())])


func _process(delta: float) -> void:
	if _capture or _camera == null:
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var input := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W):
			input.z -= 1.0
		if Input.is_physical_key_pressed(KEY_S):
			input.z += 1.0
		if Input.is_physical_key_pressed(KEY_A):
			input.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			input.x += 1.0
		if Input.is_physical_key_pressed(KEY_E):
			input.y += 1.0
		if Input.is_physical_key_pressed(KEY_Q):
			input.y -= 1.0
		var speed := fly_speed
		if Input.is_physical_key_pressed(KEY_SHIFT):
			speed *= 4.0
		if input.length_squared() > 0.0:
			var dir := _camera.global_basis * input.normalized()
			_camera.position += dir * speed * delta
	# Keep the camera above the ground when possible.
	if _world != null and _world.is_generated():
		var ground: float = _world.sample_height(Vector2(_camera.position.x, _camera.position.z))
		if _camera.position.y < ground + 2.0:
			_camera.position.y = ground + 2.0


func _unhandled_input(event: InputEvent) -> void:
	if _capture:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * 0.0022
		_pitch = clampf(_pitch - motion.relative.y * 0.0022, -1.45, 1.45)
		_camera.rotation = Vector3(_pitch, _yaw, 0.0)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and (event as InputEventKey).pressed:
		var key := (event as InputEventKey).keycode
		if key == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif key == KEY_F12:
			_save_screenshot("res://features/world/preview_shots/manual_%d.png" % Time.get_ticks_msec())


func _save_screenshot(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("[world-preview] saved %s (err=%d)" % [path, err])


func _capture_shots() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _hud != null:
		_hud.visible = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
	var shots := _vantage_points()
	for i in shots.size():
		var shot: Dictionary = shots[i]
		_camera.position = shot["pos"]
		_camera.look_at(shot["look"], Vector3.UP)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path := "%s/shot_%02d_%s.png" % [capture_dir, i, String(shot["name"])]
		var img := get_viewport().get_texture().get_image()
		var err := img.save_png(path)
		print("[world-preview] captured %s (%dx%d, err=%d)" % [path, img.get_width(), img.get_height(), err])
	print("[world-preview] capture complete")
	get_tree().quit(0)


func _vantage_points() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"name": "overview", "pos": Vector3(250.0, 270.0, 650.0), "look": Vector3(-60.0, 15.0, -220.0)})
	var spawns: Array = _world.get_spawn_points()
	if spawns.size() > 0:
		var sp: Vector3 = spawns[0]
		out.append({"name": "dropzone", "pos": sp + Vector3(38.0, 7.0, 46.0), "look": sp + Vector3(0.0, 2.0, 0.0)})
	var pois: Array = _world.get_pois()
	var warden := Vector3.ZERO
	var relay := Vector3.ZERO
	for poi in pois:
		if String(poi["type"]) == "warden_outpost":
			warden = poi["position"]
		elif String(poi["type"]) == "relay_spire" and relay == Vector3.ZERO:
			relay = poi["position"]
	if warden != Vector3.ZERO:
		out.append({"name": "warden_outpost", "pos": warden + Vector3(78.0, 20.0, 92.0), "look": warden + Vector3(0.0, 26.0, 0.0)})
	if relay != Vector3.ZERO:
		out.append({"name": "relay_spire", "pos": relay + Vector3(58.0, 14.0, 62.0), "look": relay + Vector3(0.0, 22.0, 0.0)})
	var exfils: Array = _world.get_exfil_points()
	if exfils.size() > 0:
		var ex: Vector3 = exfils[0]["position"]
		out.append({"name": "exfil_pad", "pos": ex + Vector3(-48.0, 24.0, 58.0), "look": ex + Vector3(0.0, 5.0, 0.0)})
	# Ashen canyon POI (vault sits in the mesas).
	for poi in pois:
		if String(poi["type"]) == "vault":
			var vp: Vector3 = poi["position"]
			out.append({"name": "ashen_canyon", "pos": vp + Vector3(-70.0, 26.0, 82.0), "look": vp + Vector3(0.0, 6.0, 0.0)})
			break
	# Sky/planet study shot.
	var sky_center := Vector3(0.0, 30.0, 0.0)
	out.append({"name": "planet_sky", "pos": sky_center + Vector3(0.0, 60.0, 0.0), "look": sky_center + Vector3(0.38, 0.44, -0.81) * 900.0})
	# Fluid basin study (water or lava).
	var basins: Array = _world.get_fluid_basins()
	if not basins.is_empty():
		var basin: Dictionary = basins[0]
		var bc: Vector2 = basin.get("center", Vector2.ZERO)
		var level := float(basin.get("level", 0.0))
		out.append({
			"name": "fluid_basin",
			"pos": Vector3(bc.x + 46.0, level + 22.0, bc.y + 56.0),
			"look": Vector3(bc.x, level, bc.y),
		})
	# Interior study: stand inside the first enterable POI.
	var interiors: Array = _world.get_interior_pois()
	if not interiors.is_empty():
		var interior_poi: Dictionary = interiors[0]
		var spawns_inside: Array = (interior_poi.get("interior", {}) as Dictionary).get("spawns", [])
		if not spawns_inside.is_empty():
			var inside: Vector3 = spawns_inside[0]
			out.append({"name": "interior", "pos": inside + Vector3(0.0, 1.7, 0.0), "look": inside + Vector3(4.0, 1.2, -4.0)})
	return out

