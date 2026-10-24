class_name EnemySpawner
extends Node3D
## Bounded enemy spawning helper for deployments and sandboxes.
## Owns no deployment logic: add it under the actors root, call setup(threat),
## then spawn_group/spawn_one/spawn_wave. Agents become children of this node so
## loot drops and death VFX resolve against a stable world parent.

signal enemy_spawned(agent: EnemyAgent)
signal group_spawned(agents: Array)
signal enemy_defeated(agent: EnemyAgent)

const MAX_THREAT := 4

@export var threat: int = 1
@export var face_player_on_spawn: bool = true
@export var default_elite_chance_bonus: float = 0.0

var _rng := RandomNumberGenerator.new()
var _content_db: Node = null
var _player: Node3D = null
var _defeated: int = 0


func _ready() -> void:
	_rng.randomize()
	_content_db = get_node_or_null("/root/ContentDB")


func setup(p_threat: int) -> void:
	threat = clampi(p_threat, 1, MAX_THREAT)


## Spawns `count` agents of one archetype in a loose ring around origin.
## Signature matches the shared task: spawn_group(data, origin, count, threat).
func spawn_group(
	data: EnemyData,
	origin: Vector3,
	count: int,
	threat_override: int = -1
) -> Array[EnemyAgent]:
	var spawned: Array[EnemyAgent] = []
	for i in maxi(0, count):
		var angle := TAU * float(i) / maxf(1.0, float(count))
		var radius := 2.2 + float(i % 2) * 1.3
		var offset := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var agent := spawn_one(data, origin + offset, threat_override)
		if agent != null:
			spawned.append(agent)
	group_spawned.emit(spawned)
	return spawned


func spawn_one(
	data: EnemyData,
	spawn_position: Vector3,
	threat_override: int = -1,
	elite_mod: StringName = &""
) -> EnemyAgent:
	if data == null:
		return null
	var effective_threat := threat_override if threat_override > 0 else threat
	if not data.elite and _roll_elite_chance(effective_threat):
		elite_mod = _random_elite_mod()
	var agent := EnemyAgent.new()
	agent.name = "Enemy_%s_%d" % [String(data.id), get_child_count()]
	agent.setup(data, effective_threat, elite_mod)
	agent.position = _snapped_position(spawn_position)
	add_child(agent)
	agent.defeated.connect(_on_agent_defeated)
	if face_player_on_spawn:
		_face_player(agent)
	enemy_spawned.emit(agent)
	return agent


## Spawns `count` random non-boss archetypes from a roster (EnemyData entries).
func spawn_wave(
	roster: Array,
	origin: Vector3,
	count: int,
	threat_override: int = -1
) -> Array[EnemyAgent]:
	var candidates: Array[EnemyData] = []
	for entry in roster:
		if entry is EnemyData:
			candidates.append(entry as EnemyData)
	if candidates.is_empty():
		candidates = _default_roster(threat_override if threat_override > 0 else threat)
	if candidates.is_empty():
		return []
	var spawned: Array[EnemyAgent] = []
	for i in maxi(0, count):
		var data := candidates[_rng.randi_range(0, candidates.size() - 1)]
		var angle := _rng.randf_range(0.0, TAU)
		var radius := _rng.randf_range(3.0, 9.0)
		var offset := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var agent := spawn_one(data, origin + offset, threat_override)
		if agent != null:
			spawned.append(agent)
	group_spawned.emit(spawned)
	return spawned


func spawn_boss(origin: Vector3, boss_id: StringName = &"") -> EnemyAgent:
	var data := _find_boss(boss_id)
	if data == null:
		return null
	return spawn_one(data, origin, threat, &"")


func get_alive_agents() -> Array[EnemyAgent]:
	var alive: Array[EnemyAgent] = []
	for child in get_children():
		if child is EnemyAgent and (child as EnemyAgent).is_alive():
			alive.append(child as EnemyAgent)
	return alive


func get_alive_count() -> int:
	return get_alive_agents().size()


func get_defeated_count() -> int:
	return _defeated


func _snapped_position(spawn_position: Vector3) -> Vector3:
	if not is_inside_tree():
		return spawn_position
	var from := spawn_position + Vector3.UP * 3.0
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 30.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return spawn_position
	var landed: Vector3 = hit["position"]
	return landed + Vector3.UP * 0.05


func _face_player(agent: EnemyAgent) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null or not is_instance_valid(_player):
		return
	var offset := _player.global_position - agent.global_position
	offset.y = 0.0
	if offset.length_squared() < 0.01:
		return
	agent.rotation.y = atan2(-offset.x, -offset.z)


func _roll_elite_chance(p_threat: int) -> bool:
	var chance := 0.04 + 0.05 * float(maxi(0, p_threat - 1)) + default_elite_chance_bonus
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null and run_state.has_method("get_mutator_multiplier"):
		chance += float(run_state.call("get_mutator_multiplier", "elite_chance", 0.0)) - 1.0
	return _rng.randf() < clampf(chance, 0.0, 0.6)


func _random_elite_mod() -> StringName:
	var options: Array[StringName] = [
		EnemyAgent.AFFIX_ARMORED,
		EnemyAgent.AFFIX_SHIELDED,
		EnemyAgent.AFFIX_BERSERK,
		EnemyAgent.AFFIX_VOLATILE,
	]
	return options[_rng.randi_range(0, options.size() - 1)]


func _default_roster(p_threat: int) -> Array[EnemyData]:
	if _content_db == null:
		_content_db = get_node_or_null("/root/ContentDB")
	if _content_db == null:
		return []
	var out: Array[EnemyData] = []
	for data in _content_db.get("enemies").values():
		if data is EnemyData and not (data as EnemyData).boss and not (data as EnemyData).elite:
			out.append(data as EnemyData)
	return out


func _find_boss(boss_id: StringName) -> EnemyData:
	if _content_db == null:
		_content_db = get_node_or_null("/root/ContentDB")
	var enemies: Dictionary = _content_db.get("enemies") if _content_db != null else {}
	if boss_id != &"":
		var direct = enemies.get(boss_id)
		if direct is EnemyData:
			return direct as EnemyData
	for data in enemies.values():
		if data is EnemyData and (data as EnemyData).boss:
			return data as EnemyData
	return null


func _on_agent_defeated(agent: EnemyAgent) -> void:
	_defeated += 1
	enemy_defeated.emit(agent)
