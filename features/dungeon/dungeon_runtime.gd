extends Node3D
## DUNGEON RUNTIME — owns one generated under-reach instance: encounter spawns,
## loot, boss, clear state and the start/exit anchors. Deployment handles the
## player teleport, HUD state and rewards; this node owns the instance content.

signal boss_defeated(runtime: Node)
signal cleared_changed(is_cleared: bool)

const BuilderScript := preload("res://features/dungeon/dungeon_builder.gd")
const LootCacheScript := preload("res://features/run/loot_cache.gd")
const ENEMY_SCRIPT_PATH := "res://features/ai/enemy_agent.gd"

var deployment: Node = null
var theme: Dictionary = {}
var threat := 1
var entrance_index := 0
var builder: Node3D = null
var active := false
var cleared := false

var _spawned := false
var _hostiles: Array[Node] = []
var _boss: Node = null
var _loot_caches: Array[Node] = []
var _origin := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func setup(p_deployment: Node, p_theme: Dictionary, p_threat: int, p_index: int) -> void:
	deployment = p_deployment
	theme = p_theme.duplicate(true) if p_theme is Dictionary else {}
	threat = maxi(1, p_threat)
	entrance_index = p_index


func build(seed_value: int, origin: Vector3) -> bool:
	_origin = origin
	_rng.seed = seed_value * 6151 + 31
	builder = BuilderScript.new()
	builder.name = "DungeonInstance"
	add_child(builder)
	var ok: bool = builder.call("generate", seed_value, theme, threat, origin)
	return ok


func enter(_player: Node) -> Vector3:
	if not _spawned:
		_spawn_encounter()
	active = true
	return get_start_global_position()


func leave() -> void:
	active = false


func _spawn_encounter() -> void:
	_spawned = true
	if builder == null:
		return
	var enemy_script: Script = load(ENEMY_SCRIPT_PATH)
	if enemy_script == null:
		return
	var rooms: Array = builder.call("get_room_centers")
	var boss_room: Vector3 = builder.call("get_boss_position")
	for i in range(1, maxi(1, rooms.size() - 1)):
		var room_center: Vector3 = rooms[i]
		var pack := clampi(1 + threat / 2, 1, 4)
		for k in pack:
			var data := _pick_enemy()
			if data == null:
				continue
			var angle := TAU * float(k) / float(pack) + float(i) * 0.7
			var offset := Vector3(cos(angle) * 3.6, 0.2, sin(angle) * 3.6)
			_spawn_enemy(enemy_script, data, _local_to_global(room_center + offset))
	# Boss room: one elite guard and the theme boss.
	var elite := _pick_elite()
	if elite != null:
		_spawn_enemy(enemy_script, elite, _local_to_global(boss_room + Vector3(4.0, 0.2, 3.0)))
	var boss_data := ContentDB.get_enemy(StringName(theme.get("boss_id", &"")))
	if boss_data != null:
		_boss = _spawn_enemy(enemy_script, boss_data, _local_to_global(boss_room + Vector3(0.0, 0.4, 0.0)))
		if _boss != null and deployment != null and deployment.has_method("register_boss"):
			deployment.call("register_boss", _boss)
	# Loot: side-room caches plus a boss reward cache.
	var loot_positions: Array = builder.call("get_loot_positions")
	var payload: Dictionary = {}
	if deployment != null and deployment.has_method("build_dungeon_cache_payload"):
		payload = deployment.call("build_dungeon_cache_payload")
	for i in loot_positions.size():
		_spawn_cache(_local_to_global(loot_positions[i]), payload, i)
	if _boss != null:
		_spawn_cache(_local_to_global(boss_room + Vector3(-5.0, 0.2, 4.0)), payload, 900)


func _pick_enemy() -> EnemyData:
	var pool: Array = theme.get("enemy_pool", [])
	if pool.is_empty():
		return null
	return ContentDB.get_enemy(StringName(pool[_rng.randi_range(0, pool.size() - 1)]))


func _pick_elite() -> EnemyData:
	var pool: Array = theme.get("elite_pool", [])
	if pool.is_empty():
		return null
	return ContentDB.get_enemy(StringName(pool[_rng.randi_range(0, pool.size() - 1)]))


func _spawn_enemy(script: Script, data: EnemyData, position: Vector3) -> Node:
	var enemy = script.new()
	if not (enemy is Node3D):
		return null
	add_child(enemy)
	(enemy as Node3D).global_position = position
	if enemy.has_method("setup"):
		enemy.call("setup", data, threat)
	if enemy.has_signal("defeated"):
		enemy.defeated.connect(_on_enemy_defeated)
	_hostiles.append(enemy)
	return enemy


func _spawn_cache(position: Vector3, payload: Dictionary, index: int) -> Node:
	var cache = LootCacheScript.new()
	if not (cache is Node3D):
		return null
	cache.name = "DungeonCache_%d" % index
	add_child(cache)
	cache.call("setup", StringName("dungeon_cache_%d" % index), position, null, payload)
	_loot_caches.append(cache)
	return cache


func _on_enemy_defeated(enemy: Node) -> void:
	_hostiles.erase(enemy)
	if enemy == _boss:
		cleared = true
		cleared_changed.emit(true)
		boss_defeated.emit(self)
		if deployment != null and deployment.has_method("on_dungeon_boss_defeated"):
			deployment.call("on_dungeon_boss_defeated", self)


func _local_to_global(local: Vector3) -> Vector3:
	if builder == null:
		return _origin + local
	return (builder as Node3D).global_position + local


func get_start_global_position() -> Vector3:
	if builder == null:
		return _origin
	return _local_to_global(builder.call("get_start_position"))


func get_exit_global_position() -> Vector3:
	if builder == null:
		return _origin
	return _local_to_global(builder.call("get_exit_position"))


func get_boss_global_position() -> Vector3:
	if builder == null:
		return _origin
	return _local_to_global(builder.call("get_boss_position"))


func get_theme_id() -> StringName:
	return StringName(theme.get("id", &"")) if builder != null else &""


func get_display_name() -> String:
	return String(theme.get("display_name", "Rift Vault"))


func get_nav_region() -> NavigationRegion3D:
	if builder == null:
		return null
	return builder.call("get_nav_region") as NavigationRegion3D


func get_hostile_count() -> int:
	var alive := 0
	for enemy in _hostiles:
		if enemy != null and is_instance_valid(enemy):
			if not (enemy.has_method("is_alive") and not bool(enemy.call("is_alive"))):
				alive += 1
	return alive


func get_loot_cache_count() -> int:
	return _loot_caches.size()


func get_boss_node() -> Node:
	return _boss


func is_cleared() -> bool:
	return cleared


func despawn() -> void:
	for enemy in _hostiles:
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
	_hostiles.clear()
	for cache in _loot_caches:
		if cache != null and is_instance_valid(cache):
			cache.queue_free()
	_loot_caches.clear()
	active = false
