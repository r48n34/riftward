extends SceneTree
## Deployment integration smoke for the enemy system.
## Boots the real `features/run/deployment.gd` headless through App, waits for
## the deployment to become playable, then validates that EnemyAgents spawned by
## the deployment are correctly configured, are damaging the player, and that a
## player-pipeline kill increments RunState/loot without ending the run.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path D:\godotGa\game \
##       --script res://features/ai/deployment_smoke.gd
##
## Exits 0 on pass, 1 on failure/timeout.

const CONTRACT_ID: StringName = &"salvage_sweep"
const RUN_SEED := 24680
const THREAT := 2
const READY_TIMEOUT_FRAMES := 5400   # ~90 s at 60 Hz
const PLAY_FRAMES := 300             # ~5 s of live simulation after ready

var _phase: int = 0
var _physics: int = 0
var _play_frames: int = 0
var _failures: Array[String] = []
var _checks: int = 0
var _manifested := false
var _ready_frames := -1
var _kills_before_kill := 0
var _kill_events: int = 0
var _spawned_enemies: Array[Node] = []
var _test_enemy: Node = null

var _app: Node = null
var _rs: Node = null
var _bus: Node = null
var _cdb: Node = null
var _player: Node = null


func _initialize() -> void:
	print("==================================================================")
	print("[DEPLOY SMOKE] RIFTWARD deployment <-> enemy AI integration")
	print("==================================================================")


func _process(_delta: float) -> bool:
	if _phase == 0:
		_boot()
	return false


func _physics_process(_delta: float) -> bool:
	if _phase == 1:
		_physics += 1
		if _manifested:
			_ready_frames = _physics
			_on_ready()
			_phase = 2
			_physics = 0
		elif _physics >= READY_TIMEOUT_FRAMES:
			_fail("deployment never became playable within %d physics frames" % READY_TIMEOUT_FRAMES)
			_finish()
		return false
	if _phase == 2:
		_play_frames += 1
		if _play_frames == 30:
			_bring_enemy_into_view()
		if _play_frames % 60 == 0:
			_print_status()
		if _play_frames == PLAY_FRAMES:
			_test_player_kill()
		if _play_frames >= PLAY_FRAMES + 90:
			_final_checks()
			_finish()
	return false


func _bring_enemy_into_view() -> void:
	# World terrain + 20 m separates the drop zone patrols from the player, so
	# pick one live deployment enemy and place it at fighting distance to prove
	# the live damage pipeline against the real Player in this deployment.
	if _player == null or not is_instance_valid(_player):
		return
	for enemy in _spawned_enemies:
		if is_instance_valid(enemy) and enemy is Node3D and enemy.has_method("is_alive") and bool(enemy.call("is_alive")):
			_test_enemy = enemy
			break
	if _test_enemy == null:
		return
	var origin: Vector3 = (_player as Node3D).global_position
	var target: Vector3 = origin + Vector3(6.0, 0.0, 2.0)
	var query := PhysicsRayQueryParameters3D.create(target + Vector3.UP * 4.0, target + Vector3.DOWN * 20.0, 1)
	var hit := (_test_enemy as Node3D).get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var landed: Vector3 = hit["position"]
		target = landed + Vector3.UP * 0.1
	(_test_enemy as Node3D).global_position = target
	if _test_enemy is CharacterBody3D:
		(_test_enemy as CharacterBody3D).velocity = Vector3.ZERO
	print("[DEPLOY SMOKE] pulled %s to %.1f m from the player for live combat" % [
		String(_test_enemy.call("get_display_name")),
		_test_enemy.global_position.distance_to(origin)
	])


# ---------------------------------------------------------------------------
# Boot / readiness
# ---------------------------------------------------------------------------

func _boot() -> void:
	_phase = 1
	_app = root.get_node_or_null("/root/App")
	_rs = root.get_node_or_null("/root/RunState")
	_bus = root.get_node_or_null("/root/EventBus")
	_cdb = root.get_node_or_null("/root/ContentDB")
	_check(_app != null, "App autoload available")
	_check(_rs != null, "RunState autoload available")
	_check(_bus != null, "EventBus autoload available")
	_check(_cdb != null, "ContentDB autoload available")
	if _app == null or _rs == null or _bus == null or _cdb == null:
		_finish()
		return
	_bus.connect("player_spawned", Callable(self, "_on_player_spawned"))
	_bus.connect("enemy_killed", Callable(self, "_on_enemy_killed"))
	_bus.connect("deployment_ended", Callable(self, "_on_deployment_ended"))
	print("[DEPLOY SMOKE] starting deployment contract=%s seed=%d threat=%d" % [
		String(CONTRACT_ID), RUN_SEED, THREAT
	])
	_app.call("start_deployment", CONTRACT_ID, RUN_SEED, THREAT, [])


func _on_player_spawned(player: Node) -> void:
	_player = player
	_manifested = true
	print("[DEPLOY SMOKE] player_spawned: ", player, " groups=", player.get_groups())


func _on_enemy_killed(enemy_name: String, _position: Vector3, is_boss: bool) -> void:
	_kill_events += 1
	print("[DEPLOY SMOKE] enemy_killed: %s boss=%s" % [enemy_name, str(is_boss)])


func _on_deployment_ended(result: Dictionary) -> void:
	_fail("deployment ended unexpectedly during enemy smoke: %s" % str(result.get("reason", "?")))


func _on_ready() -> void:
	print("[DEPLOY SMOKE] deployment ready after %d physics frames" % _ready_frames)
	_check(_player != null and is_instance_valid(_player), "real Player spawned")
	_check(_player != null and _player.is_in_group("player"), "player in group 'player'")
	_spawned_enemies = get_nodes_in_group("enemy_ai")
	print("[DEPLOY SMOKE] enemy_ai count=%d" % _spawned_enemies.size())
	_check(_spawned_enemies.size() > 0, "deployment spawned EnemyAgents")
	var bosses := 0
	var elites := 0
	var archetypes: Dictionary = {}
	var bad_contract := 0
	var navigators := 0
	for enemy in _spawned_enemies:
		if not is_instance_valid(enemy) or not (enemy is Node3D):
			continue
		if enemy.is_in_group("enemy_boss"):
			bosses += 1
		elif enemy.is_in_group("enemy_elite"):
			elites += 1
		var data = enemy.call("get_enemy_data") if enemy.has_method("get_enemy_data") else null
		if data is EnemyData:
			var id := String(data.id)
			archetypes[id] = int(archetypes.get(id, 0)) + 1
		else:
			bad_contract += 1
		var health := CombatUtils.find_health(enemy)
		if health == null or health.team != StatKeys.TEAM_ENEMY:
			bad_contract += 1
		var weak := enemy.get_node_or_null("Weakpoint")
		if weak == null or not weak.has_meta("weakpoint_mult"):
			bad_contract += 1
		if enemy.has_method("uses_navigation") and bool(enemy.call("uses_navigation")):
			navigators += 1
	print("[DEPLOY SMOKE] archetypes=%s bosses=%d elites=%d navigators=%d contract_errors=%d" % [
		str(archetypes), bosses, elites, navigators, bad_contract
	])
	_check(bad_contract == 0, "all deployment enemies satisfy the health/weakpoint contract")
	_check(archetypes.size() >= 2, "deployment spawned multiple archetypes, not all fallbacks (%s)" % str(archetypes))
	_check(int(_rs.get("kills")) == 0, "run starts with zero kills")
	_kills_before_kill = 0


# ---------------------------------------------------------------------------
# Live assertions
# ---------------------------------------------------------------------------

func _print_status() -> void:
	var alive := 0
	for enemy in _spawned_enemies:
		if is_instance_valid(enemy) and enemy.has_method("is_alive") and bool(enemy.call("is_alive")):
			alive += 1
	var player_health := CombatUtils.find_health(_player) if _player != null else null
	var health_text := "n/a"
	if player_health != null:
		health_text = "hp %.0f/%.0f shield %.0f/%.0f" % [
			player_health.health, player_health.max_health, player_health.shield, player_health.max_shield
		]
	print("[DEPLOY SMOKE] t+%d frames alive=%d kills=%d loot=%d player=%s" % [
		_play_frames, alive, int(_rs.get("kills")),
		get_nodes_in_group("loot_drop").size(), health_text
	])
	if _test_enemy != null and is_instance_valid(_test_enemy) and _test_enemy.has_method("get_debug_info"):
		var info: Dictionary = _test_enemy.call("get_debug_info")
		print("[DEPLOY SMOKE]   test_enemy state=%s visible=%s shots=%d distance=%.1f m" % [
			String(info["state"]),
			str(info["visible"]),
			int(info["shots"]),
			(_test_enemy as Node3D).global_position.distance_to((_player as Node3D).global_position),
		])


func _test_player_kill() -> void:
	if _spawned_enemies.is_empty():
		return
	var target: Node = null
	for enemy in _spawned_enemies:
		if is_instance_valid(enemy) and enemy.has_method("is_alive") and bool(enemy.call("is_alive")):
			target = enemy
			break
	if target == null:
		_fail("no living deployment enemy available for kill simulation")
		return
	_kills_before_kill = int(_rs.get("kills"))
	var loot_before := get_nodes_in_group("loot_drop").size()
	var display := String(target.call("get_display_name")) if target.has_method("get_display_name") else "?"
	var data := DamageData.make(999999.0, StatKeys.TEAM_PLAYER, StatKeys.DMG_BALLISTIC, _player)
	if target is Node3D:
		data.hit_position = (target as Node3D).global_position + Vector3.UP
	var applied := CombatUtils.apply_hit(target, data)
	print("[DEPLOY SMOKE] simulated player kill on %s -> %s" % [display, str(applied)])
	_check(int(_rs.get("kills")) == _kills_before_kill + 1, "player-pipeline kill incremented RunState.kills")
	_check(get_nodes_in_group("loot_drop").size() > loot_before, "killed enemy dropped loot into the deployment")


func _final_checks() -> void:
	_check(_kill_events >= 1, "EventBus.enemy_killed fired during deployment")
	var player_health := CombatUtils.find_health(_player) if _player != null else null
	if player_health != null:
		var damaged := player_health.health < player_health.max_health or player_health.shield < player_health.max_shield
		_check(damaged, "deployment enemies damaged the real Player (hp %.0f shield %.0f)" % [
			player_health.health, player_health.shield
		])
	else:
		_check(false, "player health resolvable")
	# The run must still be live after enemy deaths (enemy death never ends it).
	_check(bool(_rs.get("active")), "run still active after enemy death")


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

func _fail(message: String) -> void:
	_failures.append(message)
	push_error("[DEPLOY SMOKE] FAIL: " + message)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_fail(message)


func _finish() -> void:
	var exit_code := 0 if _failures.is_empty() else 1
	print("------------------------------------------------------------------")
	print("[DEPLOY SMOKE] checks=%d failures=%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("[DEPLOY SMOKE]   FAILED: " + failure)
	print("[DEPLOY SMOKE] RESULT: " + ("PASS" if exit_code == 0 else "FAIL"))
	print("------------------------------------------------------------------")
	quit(exit_code)
