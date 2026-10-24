class_name GrenadeData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var effect_id: StringName = &"frag"
@export var damage: float = 90.0
@export var radius: float = 5.0
@export var duration: float = 0.0
@export var cooldown: float = 18.0
@export var color: Color = Color("ffb866")
@export var charges: int = 2


func _init(p_id: StringName = &"", p_name: String = "") -> void:
	if p_id != &"":
		id = p_id
		display_name = p_name
