class_name PerkData
extends Resource
## Passive discipline-tree node. One rank per node in v1.

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var discipline: StringName = &"vanguard"
@export var tier: int = 1
## Warden level required before this perk can be bought.
@export var unlock_level: int = 1
@export var stat: StringName = &""
@export var op: StringName = &"add"
@export var value: float = 0.0
@export var color: Color = Color("62e6c3")
@export var icon: StringName = &"diamond"
@export var requires: StringName = &""
