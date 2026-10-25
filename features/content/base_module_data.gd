class_name BaseModuleData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var max_tier: int = 3
@export var power: int = 1
@export var footprint: Vector2i = Vector2i(2, 2)
@export var costs: PackedInt32Array = PackedInt32Array([100, 250, 600])
@export var core_costs: PackedInt32Array = PackedInt32Array([0, 1, 3])
@export var effects: PackedStringArray = PackedStringArray()
@export var icon: StringName = &"outpost"
@export var color: Color = Color("f4efe5")
@export var accent: Color = Color("62e6c3")


func cost_for_tier(tier: int) -> int:
	return costs[clampi(tier, 0, costs.size() - 1)]


func core_cost_for_tier(tier: int) -> int:
	return core_costs[clampi(tier, 0, core_costs.size() - 1)]
