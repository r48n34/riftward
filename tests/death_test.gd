extends Node3D
## Headless death/downed/results-path test.

var deployment: Deployment = null
var player: Player = null
var _failures: Array[String] = []
var _checks: int = 0
var _result: Dictionary = {}
var _player_died := false


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[DEATH-TEST] PASS: ", label)
	else:
		_failures.append(label)
		push_error("[DEATH-TEST] FAIL: " + label)


func _run() -> void:
	await get_tree().process_frame
	RunState.run_ended.connect(func(result: Dictionary) -> void: _result = result)
	deployment = Deployment.new()
	deployment.name = "DeathTestDeployment"
	add_child(deployment)
	deployment.ready_to_play.connect(func(p: Node) -> void:
		player = p as Player
		if player != null:
			player.died.connect(func() -> void: _player_died = true)
	)
	deployment.setup(&"salvage_sweep", 424242, 1, [])
	var waited := 0.0
	while player == null and waited < 40.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	_check(player != null, "player spawned")
	if player == null:
		_finish()
		return
	_check(not player.is_downed, "player starts alive")
	player.health_component.kill()
	await get_tree().physics_frame
	_check(player.is_downed, "lethal damage enters downed state")
	_check(player.revive_charges >= 0, "revive charges initialized")
	player.bleedout_left = 0.05
	await get_tree().create_timer(0.4).timeout
	_check(player.is_dead, "bleedout ends in permanent death")
	_check(_player_died, "player death signal emitted")
	var waited_result := 0.0
	while _result.is_empty() and waited_result < 6.0:
		await get_tree().create_timer(0.25).timeout
		waited_result += 0.25
	_check(not _result.is_empty(), "deployment produces a result")
	_check(not bool(_result.get("extracted", true)), "death result is not an extraction")
	_check(String(_result.get("reason", "")).length() > 0, "death result has a reason")
	await get_tree().create_timer(0.3).timeout
	_finish()


func _finish() -> void:
	if deployment != null and is_instance_valid(deployment):
		deployment.queue_free()
	print("[DEATH-TEST] Checks: %d, Failures: %d" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("[DEATH-TEST] RESULT: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			print("[DEATH-TEST] Failure: ", failure)
		print("[DEATH-TEST] RESULT: FAIL")
		get_tree().quit(1)
