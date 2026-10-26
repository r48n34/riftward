class_name LootItemData
extends Resource
## Authored salvage/consumable cargo. Unlike ItemTemplate (equippable gear) these
## entries are never equipped: they are roll results from LootTables, recovered
## into the satchel and banked into the locker as saleable cargo. The runtime
## footprint is the ordinary item dictionary (kind "loot"), so no save-format
## change is involved.
##
## Field notes for authors:
##   rarity    fixed tier (0 Common .. 4 Prototype); drives colour and value mult.
##   value     base value at Common; ItemFactory multiplies by the rarity curve.
##   icon      id from res://assets/icons (ContentDB validates it is non-empty).
##   effects   optional gameplay payload for consumers (heal, repair, ...); it is
##             authored data only and never persisted outside the item dict.

@export var id: StringName = &""
@export var display_name: String = ""
## Tooltip-worthy field blurb shown by the Codex, locker and inventory rows.
@export var description: String = ""
@export_range(0, 4, 1) var rarity: int = 0
@export var icon: StringName = &"cache"
## Coarse category: consumable, material, intel, relic or trophy.
@export var category: StringName = &"material"
## Base value at Common rarity, before ContentDB.get_rarity_mult() is applied.
@export var value: int = 20
## Upper bound for a single rolled stack (loot tables roll 1..stack_max).
@export var stack_max: int = 1
## Authored gameplay payload (heal amount, repair budget, reveal radius...).
@export var effects: Dictionary = {}
@export var tags: PackedStringArray = PackedStringArray()
@export var color: Color = Color("a7b4b6")


## Loot cargo is intentionally never equippable; ProfileState.equip_item() only
## accepts kind "weapon"/"gear", and this guard keeps callers honest.
func is_equippable() -> bool:
	return false


## Human-readable category used by cards ("Consumable", "Relic"...).
func get_category_label() -> String:
	return String(category).capitalize()


## Rarity multiplier applied to `value` (kept in sync with StatKeys.RARITY_MULT).
func get_rarity_mult() -> float:
	return StatKeys.RARITY_MULT[clampi(rarity, 0, StatKeys.RARITY_MULT.size() - 1)]


## Effective value of a rolled stack before any situational modifiers.
func get_stack_value(amount: int = 1) -> int:
	return int(round(float(value) * get_rarity_mult())) * maxi(1, amount)
