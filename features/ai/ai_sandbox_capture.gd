extends SceneTree
## Windowed screenshot harness for the AI sandbox (visual regression aid).
## Run (windowed — needs a rendering device):
##   Godot_v4.7.2-stable_win64_console.exe --path D:\godotGa\game \
##       --script res://features/ai/ai_sandbox_capture.gd
## Writes PNGs to res://features/ai/preview_shots/ and quits.

const SHOT_DIR := "res://features/ai/preview_shots"
const CAPTURE_FRAMES := [46, 96, 156, 216]
const QUIT_FRAME := 236

var _frames: int = 0
var _sandbox: Node = null
var _camera: Camera3D = null
var _shot_index: int = 0

const CAMERA_SETUPS := [
	{"pos": Vector3(24.0, 13.0, 26.0), "look": Vector3(0.0, 1.0, -5.0)},
	{"pos": Vector3(15.0, 5.0, 15.0), "look": Vector3(0.0, 1.4, -8.0)},
	{"pos": Vector3(5.0, 2.4, 9.0), "look": Vector3(0.0, 1.5, -10.0)},
	{"pos": Vector3(-17.0, 8.0, 3.0), "look": Vector3(0.0, 2.4, -17.0)},
]
const SHOT_NAMES := [
	"shot_00_arena_overview.png",
	"shot_01_enemy_midrange.png",
	"shot_02_combat_low_angle.png",
	"shot_03_boss_warden.png",
]


func _initialize() -> void:
	print("[CAPTURE] initializing AI sandbox screenshot run")
	var absolute_dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var packed: PackedScene = load("res://features/ai/ai_sandbox.tscn")
	if packed == null:
		push_error("[CAPTURE] failed to load ai_sandbox.tscn")
		quit(1)
		return
	_sandbox = packed.instantiate()
	root.add_child(_sandbox)
	_camera = Camera3D.new()
	_camera.name = "CaptureCamera"
	_camera.fov = 62.0
	_camera.near = 0.05
	_camera.far = 600.0
	root.add_child(_camera)
	# Camera3D.current must be set once the node is inside the active scene tree,
	# otherwise the Player's first-person camera stays active.
	_camera.set_deferred("current", true)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_apply_camera(0)
		_camera.current = true
	if _frames == 3 and _sandbox != null and _sandbox.has_method("_spawn_boss"):
		_sandbox.call("_spawn_boss")
	if _shot_index < CAPTURE_FRAMES.size() and _frames == CAPTURE_FRAMES[_shot_index]:
		_capture(_shot_index)
		_shot_index += 1
		if _shot_index < CAMERA_SETUPS.size():
			_apply_camera(_shot_index)
	if _frames >= QUIT_FRAME:
		print("[CAPTURE] done, shots=%d" % _shot_index)
		quit(0)
		return true
	return false


func _apply_camera(index: int) -> void:
	if _camera == null or index < 0 or index >= CAMERA_SETUPS.size():
		return
	var setup: Dictionary = CAMERA_SETUPS[index]
	_camera.global_position = setup["pos"]
	_camera.look_at(setup["look"], Vector3.UP)


func _capture(index: int) -> void:
	if index < 0 or index >= SHOT_NAMES.size():
		return
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("[CAPTURE] viewport texture unavailable")
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		push_error("[CAPTURE] empty screenshot image")
		return
	var path: String = SHOT_DIR + "/" + String(SHOT_NAMES[index])
	var error := image.save_png(path)
	print("[CAPTURE] saved %s (%dx%d) error=%d" % [path, image.get_width(), image.get_height(), error])
