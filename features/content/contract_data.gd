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


func objective_count() -> int:
	return maxi(1, objective_types.size())
