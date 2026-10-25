extends Node
## FIELD TRAINING DIRECTOR — a five-stage guided onboarding run.
##
## The director observes real gameplay (movement, weapon hits, ability casts,
## cache opens, exfil hold) and broadcasts the current stage to the HUD. It never
## fakes completion: every stage is proven by the actual player action. The run
## ends through the normal extraction path, so results/profile persistence stay
## on the same contract as a real deployment.

const STAGES: Array[Dictionary] = [
	{
		"id": &"move", "title": "MOVE & LOOK", "icon": &"arrow-up",
		"body": "Move with WASD and look with the mouse. Cross 10 meters to continue.",
		"hint": "WASD · MOUSE",
	},
	{
		"id": &"fire", "title": "AIM & FIRE", "icon": &"crosshair",
		"body": "Hold RMB to aim and LMB to fire. Land three hits on a training target.",
		"hint": "RMB AIM · LMB FIRE",
	},
	{
		"id": &"ability", "title": "FIELD ABILITY", "icon": &"shield",
		"body": "Press Q to cast your first field ability.",
		"hint": "Q · ABILITY",
	},
	{
		"id": &"loot", "title": "RECOVER SALVAGE", "icon": &"cache",
		"body": "Walk to the marked cache and press E to breach it.",
		"hint": "E · BREACH",
	},
	{
		"id": &"exfil", "title": "CALL EXFIL", "icon": &"exfil",
		"body": "Stand on the exfil pad and call the dropship, then hold the pad.",
		"hint": "E / H · EXFIL",
	},
]

var deployment: Node = null
var player: Node = null
var targets: Array[Node] = []
var tutorial_cache: Node = null
var beacon: Node = null
var stage_index: int = -1
var stage_complete: bool = false

var _start_position := Vector3.ZERO
var _start_yaw := 0.0
var _hits := 0
var _shots := 0
var _ability_cast := false
var _cache_opened := false
var _exfil_started := false
var _tick := 0.0
var _look_accum := 0.0


func setup(p_deployment: Node, p_player: Node, p_targets: Array, p_cache: Node, p_beacon: Node) -> void:
	deployment = p_deployment
	player = p_player
	targets.clear()
	for target in p_targets:
		if target is Node:
			targets.append(target)
	tutorial_cache = p_cache
	beacon = p_beacon
	if player is Node3D:
		_start_position = (player as Node3D).global_position
	if player != null and "yaw" in player:
		_start_yaw = float(player.get("yaw"))
	_connect_signals()
	_advance_stage()


func _connect_signals() -> void:
	if player != null and is_instance_valid(player):
		var controller = player.get("weapon_controller")
		if controller != null and controller.has_signal("shot_fired"):
			controller.shot_fired.connect(_on_shot_fired)
		var abilities = player.get("ability_manager")
		if abilities != null and abilities.has_signal("ability_cast"):
			abilities.ability_cast.connect(_on_ability_cast)
	for target in targets:
		if target != null and is_instance_valid(target) and target.has_signal("hit_target"):
			target.hit_target.connect(_on_target_hit)
	if tutorial_cache != null and is_instance_valid(tutorial_cache) and tutorial_cache.has_signal("opened"):
		tutorial_cache.opened.connect(_on_cache_opened)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	if stage_index < 0 or stage_index >= STAGES.size():
		return
	var stage: Dictionary = STAGES[stage_index]
	var stage_id := StringName(stage.get("id", &""))
	match stage_id:
		&"move":
			var moved := (player as Node3D).global_position.distance_to(_start_position)
			var yaw := 0.0
			if "yaw" in player:
				yaw = float(player.get("yaw"))
			_look_accum = maxf(_look_accum, absf(angle_difference(_start_yaw, yaw)))
			var progress := clampf(maxf(moved / 10.0, _look_accum / 1.35), 0.0, 1.0)
			_emit_progress(progress)
			if moved >= 10.0 or _look_accum >= 1.35:
				_complete_stage()
		&"fire":
			_emit_progress(clampf(float(_hits) / 3.0, 0.0, 1.0))
			if _hits >= 3:
				_complete_stage()
		&"ability":
			_emit_progress(1.0 if _ability_cast else 0.0)
			if _ability_cast:
				_complete_stage()
		&"loot":
			var opened := _cache_opened
			if not opened and tutorial_cache != null and is_instance_valid(tutorial_cache):
				opened = bool(tutorial_cache.get("is_open"))
			_emit_progress(1.0 if opened else 0.0)
			if opened:
				_complete_stage()
		&"exfil":
			var holding := RunState.extraction_state == &"holding"
			if holding and not _exfil_started:
				_exfil_started = true
			_emit_progress(1.0 if holding else 0.0)
			if holding:
				# The run ends through RunState's normal exfil timer; the result
				# carries the tutorial flag and the profile records completion.
				stage_complete = true


func _advance_stage() -> void:
	stage_index += 1
	stage_complete = false
	if stage_index >= STAGES.size():
		EventBus.tutorial_stage_changed.emit({"complete": true, "index": stage_index, "total": STAGES.size()})
		return
	var stage: Dictionary = STAGES[stage_index]
	EventBus.tutorial_stage_changed.emit({
		"complete": false,
		"index": stage_index,
		"total": STAGES.size(),
		"title": String(stage.get("title", "Training")),
		"body": String(stage.get("body", "")),
		"hint": String(stage.get("hint", "")),
		"icon": String(stage.get("icon", &"info")),
		"progress": 0.0,
	})
	EventBus.notification_requested.emit(
		"FIELD TRAINING %d/%d" % [stage_index + 1, STAGES.size()],
		String(stage.get("body", "")),
		&"info"
	)


func _complete_stage() -> void:
	if stage_complete:
		return
	stage_complete = true
	var stage: Dictionary = STAGES[stage_index] if stage_index >= 0 and stage_index < STAGES.size() else {}
	EventBus.notification_requested.emit(
		"STAGE COMPLETE",
		String(stage.get("title", "Training stage")) + " secured.",
		&"success"
	)
	AudioDirector.play_ui(&"ui_confirm")
	_advance_stage()


func _emit_progress(value: float) -> void:
	if stage_index < 0 or stage_index >= STAGES.size():
		return
	var stage: Dictionary = STAGES[stage_index]
	EventBus.tutorial_stage_changed.emit({
		"complete": false,
		"index": stage_index,
		"total": STAGES.size(),
		"title": String(stage.get("title", "Training")),
		"body": String(stage.get("body", "")),
		"hint": String(stage.get("hint", "")),
		"icon": String(stage.get("icon", &"info")),
		"progress": clampf(value, 0.0, 1.0),
	})


func _on_shot_fired(_info: Dictionary = {}) -> void:
	_shots += 1


func _on_target_hit() -> void:
	_hits += 1


func _on_ability_cast(_slot: int, _ability_id: StringName) -> void:
	_ability_cast = true


func _on_cache_opened(_cache: Node, _by: Node) -> void:
	_cache_opened = true


func get_stage_index() -> int:
	return stage_index


func get_stage_total() -> int:
	return STAGES.size()


func get_stage_id() -> StringName:
	if stage_index < 0 or stage_index >= STAGES.size():
		return &""
	return StringName(STAGES[stage_index].get("id", &""))
