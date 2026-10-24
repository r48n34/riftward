class_name CompanionManager
extends Node
## Spawns and owns the squad for a deployment: up to two active Wardens from
## ProfileState plus the active Driftling pet. Drop this node under the run /
## deployment root and call setup(player) once the Player exists:
##
##   var companions := CompanionManager.new()
##   deployment.add_child(companions)
##   companions.setup(player)
##
## UI / player commands go through issue_squad_command(); HUD squad widgets can
## read get_squad_status() (name, role, rank, health, downed, disabled...).

signal squad_changed(allies: Array, pet: Node)
signal ally_extracted(ally: Node)

const AllyAgentScript := preload("res://features/companions/ally_agent.gd")
const PetAgentScript := preload("res://features/companions/pet_agent.gd")

const FALLBACK_ALLIES: Array[StringName] = [&"mara_voss", &"irie_sol"]
const FALLBACK_PET: StringName = &"mote"
const MAX_ALLIES := 2

var player: Node = null

var _allies: Array[Node] = []
var _pet: Node = null
var _spawn_parent: Node3D = null
var _spawned: bool = false


func _ready() -> void:
	add_to_group("companion_manager")
	if player != null and not _spawned:
		spawn_squad()


func setup(p_player: Node) -> void:
	player = p_player
	if is_inside_tree() and not _spawned:
		spawn_squad()


func spawn_squad() -> void:
	if _spawned:
		return
	_spawned = true
	_spawn_parent = _resolve_spawn_parent()
	if _spawn_parent == null:
		push_warning("[CompanionManager] no Node3D parent available; squad not spawned.")
		return
	var ally_ids := _active_ally_ids()
	for index in ally_ids.size():
		var ally := _spawn_ally(ally_ids[index], index)
		if ally != null:
			_allies.append(ally)
	_pet = _spawn_pet(_active_pet_id())
	squad_changed.emit(get_allies(), _pet)


func respawn_squad() -> void:
	cleanup()
	_spawned = false
	spawn_squad()


func cleanup() -> void:
	for ally in _allies:
		if is_instance_valid(ally):
			ally.queue_free()
	_allies.clear()
	if _pet != null and is_instance_valid(_pet):
		_pet.queue_free()
	_pet = null


func get_allies() -> Array[Node]:
	var result: Array[Node] = []
	for ally in _allies:
		if is_instance_valid(ally):
			result.append(ally)
	return result


func get_pet() -> Node:
	return _pet if _pet != null and is_instance_valid(_pet) else null


func get_ally(ally_id: StringName) -> Node:
	for ally in _allies:
		if not is_instance_valid(ally):
			continue
		if ally.has_method("get_ally_data"):
			var data = ally.call("get_ally_data")
			if data is AllyData and (data as AllyData).id == ally_id:
				return ally
	return null


## HUD / squad screen payload. Includes a "kind" key so UI can tell pets apart.
func get_squad_status() -> Array[Dictionary]:
	var status: Array[Dictionary] = []
	for ally in get_allies():
		if ally.has_method("get_status"):
			var entry: Dictionary = ally.call("get_status")
			entry["kind"] = "ally"
			status.append(entry)
	var pet := get_pet()
	if pet != null and pet.has_method("get_status"):
		var pet_entry: Dictionary = pet.call("get_status")
		pet_entry["kind"] = "pet"
		status.append(pet_entry)
	return status


func issue_squad_command(command: StringName, target: Node = null) -> void:
	for ally in get_allies():
		if ally.has_method("issue_command"):
			ally.call("issue_command", command, target)


func command_ally(index: int, command: StringName, target: Node = null) -> bool:
	var allies := get_allies()
	if index < 0 or index >= allies.size():
		return false
	var ally := allies[index]
	if ally.has_method("issue_command"):
		ally.call("issue_command", command, target)
		return true
	return false


func is_spawned() -> bool:
	return _spawned


# ---------------------------------------------------------------------------
# Spawning helpers
# ---------------------------------------------------------------------------

func _active_ally_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in ProfileState.get_active_allies():
		if ids.size() >= MAX_ALLIES:
			break
		if ContentDB.get_ally(id) != null:
			ids.append(id)
	if ids.is_empty():
		for fallback in FALLBACK_ALLIES:
			if ContentDB.get_ally(fallback) != null:
				ids.append(fallback)
			if ids.size() >= MAX_ALLIES:
				break
	return ids


func _active_pet_id() -> StringName:
	var pet_id := ProfileState.get_active_pet()
	if pet_id == &"" or ContentDB.get_pet(pet_id) == null:
		pet_id = FALLBACK_PET
	return pet_id


func _spawn_ally(ally_id: StringName, index: int) -> Node:
	var data: AllyData = ContentDB.get_ally(ally_id)
	if data == null:
		push_warning("[CompanionManager] unknown ally id: %s" % String(ally_id))
		return null
	var ally := AllyAgentScript.new()
	ally.name = "Ally_%s" % String(data.id)
	_spawn_parent.add_child(ally)
	ally.setup(data, player, ProfileState.get_ally_rank(ally_id))
	ally.set_formation_index(index)
	ally.global_position = _squad_spawn_point(index)
	if ally.has_signal("extracted"):
		ally.connect("extracted", _on_ally_extracted)
	return ally


func _spawn_pet(pet_id: StringName) -> Node:
	var data: PetData = ContentDB.get_pet(pet_id)
	if data == null:
		push_warning("[CompanionManager] unknown pet id: %s" % String(pet_id))
		return null
	var pet := PetAgentScript.new()
	pet.name = "Pet_%s" % String(data.id)
	_spawn_parent.add_child(pet)
	pet.setup(data, player, ProfileState.get_pet_rank(pet_id))
	pet.global_position = _squad_spawn_point(MAX_ALLIES) + Vector3.UP * 1.7
	return pet


func _resolve_spawn_parent() -> Node3D:
	if player != null and is_instance_valid(player) and player.has_method("get_effect_parent"):
		var effects = player.call("get_effect_parent")
		if effects is Node3D and is_instance_valid(effects):
			return effects as Node3D
	var parent := get_parent()
	if parent is Node3D:
		return parent as Node3D
	if is_inside_tree() and get_tree().current_scene is Node3D:
		return get_tree().current_scene as Node3D
	return null


func _squad_spawn_point(index: int) -> Vector3:
	var origin := Vector3.ZERO
	var forward := Vector3.FORWARD
	if player != null and is_instance_valid(player) and player is Node3D:
		var player_node := player as Node3D
		origin = player_node.global_position
		if player.has_method("get_forward"):
			var facing = player.call("get_forward")
			if facing is Vector3:
				var flat := facing as Vector3
				flat.y = 0.0
				if flat.length_squared() > 0.01:
					forward = flat.normalized()
		else:
			var basis_forward := -player_node.global_transform.basis.z
			basis_forward.y = 0.0
			if basis_forward.length_squared() > 0.01:
				forward = basis_forward.normalized()
	var right := forward.cross(Vector3.UP)
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	right = right.normalized()
	var lateral := -2.0 if index % 2 == 0 else 2.0
	var depth := 2.4 + 1.0 * float(int(index / 2))
	var point := origin + right * lateral - forward * depth
	var world_source: Node3D = _spawn_parent
	if world_source == null and player is Node3D:
		world_source = player as Node3D
	if world_source == null or not world_source.is_inside_tree():
		return point
	var space := world_source.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 8.0, point - Vector3.DOWN * 16.0, 1)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		point = (hit["position"] as Vector3) + Vector3.UP * 0.05
	return point


func _on_ally_extracted(ally: Node) -> void:
	_allies = _allies.filter(func(entry: Node) -> bool: return entry != ally)
	ally_extracted.emit(ally)
	squad_changed.emit(get_allies(), _pet)


func _exit_tree() -> void:
	_allies.clear()
	_pet = null
	player = null
