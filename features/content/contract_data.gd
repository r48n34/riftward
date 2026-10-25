class_name ContractData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var objective_types: PackedStringArray = PackedStringArray()
@export var required_threat: int = 1
@export var base_reward: int = 150
@export var core_reward: int = 1
@export var xp_reward: int = 120
@export var gear_rolls: int = 1
@export var flavor: String = ""
@export var objective_label: String = ""
@export var icon: StringName = &"target"
@export var color: Color = Color("62e6c3")
## Optional multi-stage operation. Each entry is a plain Dictionary:
## {title: String, type: StringName, count: int, label: String}. Empty means the
## classic single-stage contract built from objective_types.
@export var stages: Array = []


func objective_count() -> int:
	if not stages.is_empty():
		return maxi(1, stages.size())
	return maxi(1, objective_types.size())


func stage_count() -> int:
	return maxi(1, stages.size()) if not stages.is_empty() else 1


func is_staged() -> bool:
	return not stages.is_empty()
