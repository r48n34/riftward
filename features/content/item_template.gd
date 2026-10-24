class_name ItemTemplate
extends Resource
## Base gear template. LootGenerator combines one of these with rarity, level and affixes.

@export var id: StringName = &""
@export var display_name: String = ""
@export var slot: StringName = StatKeys.SLOT_HELMET
@export var set_id: StringName = &""
@export var armor: float = 0.0
@export var base_stats: Dictionary = {}
@export var description: String = ""
@export var value: int = 60
@export var color: Color = Color("f4efe5")
@export var style: StringName = &"armor"


func is_weapon_slot() -> bool:
	return slot == StatKeys.SLOT_PRIMARY or slot == StatKeys.SLOT_SIDEARM
