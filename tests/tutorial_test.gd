extends Node3D
## Headless Field Training acceptance test: starts the tutorial deployment,
## drives the five guided stages through real gameplay hooks, completes exfil and
## verifies profile persistence.
##
## Run with:
##   godot --headless --path . res://tests/tutorial_test.tscn

const TIMEOUT_SECONDS := 90.0

var deployment: Deployment = null
var player: Player = null
var _checks := 0
var _failures: Array[String] = []
var _profile_backup: Dictionary = {}
var _result: Dictionary = {}
var _done := false


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[TUTORIAL-TEST] PASS: ", label)
	else:
		_failures.append(label)
		push_error("[TUTORIAL-TEST] FAIL: " + label)


func _run() -> void:
	print("[TUTORIAL-TEST] starting field training")
	var timeout := Timer.new()
	timeout.wait_time = TIMEOUT_SECONDS
	timeout.one_shot = true
	timeout.timeout.connect(func() -> void:
		if not _done:
			push_error("[TUTORIAL-TEST] TIMEOUT after %.0fs" % TIMEOUT_SECONDS)
			get_tree().quit(1)
	)
	add_child(timeout)
	timeout.start()
	_profile_backup = ProfileState.data.duplicate(true)
	await get_tree().process_frame
	RunState.run_ended.connect(func(result: Dictionary) -> void:
		_result = result
	)
	deployment = Deployment.new()
	deployment.name = "TutorialDeployment"
	add_child(deployment)
	deployment.ready_to_play.connect(func(p: Node) -> void: player = p as Player)
	deployment.setup(&"salvage_sweep", 7777, 1, [], &"patrol", &"tutorial")
	var waited := 0.0
	while player == null and waited < 40.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	_check(player != null, "tutorial deployment reached playable state")
	if player == null:
		_finish(timeout)
		return
	_check(RunState.is_tutorial(), "run is in tutorial mode")
	_check(get_tree().get_nodes_in_group("enemy_ai").is_empty(), "tutorial spawns no hostiles")
	_check(get_tree().get_nodes_in_group("allies").is_empty(), "tutorial does not spawn the squad")
	var director = deployment.get_tutorial_director()
	_check(director != null, "tutorial director exists")
	if director == null:
		_finish(timeout)
		return
	_check(int(director.call("get_stage_index")) == 0, "tutorial starts on stage 1")
	_check(String(director.call("get_stage_id")) == "move", "first stage is move/look")

	# Stage 1: move 12m.
	player.call("teleport_to", player.global_position + Vector3(12.0, 0.0, 0.0))
	await get_tree().create_timer(0.7).timeout
	_check(int(director.call("get_stage_index")) == 1, "movement completes stage 1")

	# Stage 2: land three hits on a training target through the real damage path.
	var targets: Array = director.get("targets")
	_check(not targets.is_empty(), "training targets spawned")
	if not targets.is_empty():
		var target = targets[0]
		var health = target.call("get_health_component")
		for i in 3:
			var data := DamageData.make(12.0, StatKeys.TEAM_PLAYER, StatKeys.DMG_KINETIC, player)
			data.hit_position = (target as Node3D).global_position
			health.take_damage(data)
		await get_tree().create_timer(0.7).timeout
	_check(int(director.call("get_stage_index")) == 2, "three target hits complete stage 2")

	# Stage 3: cast an ability.
	player.ability_manager.cast_ability(0)
	await get_tree().create_timer(0.7).timeout
	_check(int(director.call("get_stage_index")) == 3, "ability cast completes stage 3")

	# Stage 4: open the tutorial cache.
	var cache = director.get("tutorial_cache")
	_check(cache != null, "tutorial cache spawned")
	if cache != null:
		cache.call("interact", player)
	await get_tree().create_timer(0.7).timeout
	_check(int(director.call("get_stage_index")) == 4, "cache breach completes stage 4")

	# Stage 5: call exfil and finish the hold through the normal run clock.
	var beacon = director.get("beacon")
	_check(beacon != null, "training exfil beacon spawned")
	if beacon != null:
		deployment.request_extraction(beacon)
		await get_tree().physics_frame
		_check(RunState.extraction_state == &"holding", "exfil hold starts")
		RunState.extraction_timer = 0.05
		await get_tree().create_timer(0.6).timeout
	_check(not _result.is_empty(), "tutorial run produced a result")
	_check(bool(_result.get("tutorial", false)), "result carries the tutorial flag")
	_check(bool(_result.get("extracted", false)), "tutorial exfil counts as extraction")
	var progression: Dictionary = ProfileState.record_run(_result, _result.get("items", []))
	_check(bool(progression.get("tutorial", false)), "profile records the tutorial run")
	_check(ProfileState.get_tutorial_done(), "tutorial_done persists")
	ProfileState.data = _profile_backup.duplicate(true)
	_finish(timeout)


func _finish(timeout: Timer) -> void:
	_done = true
	if is_instance_valid(timeout):
		timeout.queue_free()
	if deployment != null and is_instance_valid(deployment):
		deployment.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("[TUTORIAL-TEST] checks=%d failures=0" % _checks)
		print("[TUTORIAL-TEST] RESULT: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			print("[TUTORIAL-TEST] Failure: ", failure)
		print("[TUTORIAL-TEST] checks=%d failures=%d" % [_checks, _failures.size()])
		print("[TUTORIAL-TEST] RESULT: FAIL")
		get_tree().quit(1)
