extends RefCounted
## Level-gated field mechanics. Kept as plain data + static helpers (no global
## class_name) so it can be preloaded anywhere without depending on the editor
## script-class cache. ProfileState wraps these helpers for gameplay/UI.

const ALL: Array[Dictionary] = [
	{
		"id": &"sprint", "name": "Sprint", "level": 1, "icon": &"boot",
		"description": "Hold Shift to move at sprint speed.",
	},
	{
		"id": &"crouch", "name": "Crouch", "level": 1, "icon": &"arrow-down",
		"description": "Toggle crouch with Ctrl or C. Slide from a sprint once unlocked.",
	},
	{
		"id": &"aim_zoom", "name": "Aim Down Sights", "level": 1, "icon": &"crosshair",
		"description": "Hold right mouse to zoom. Precision weapons zoom farther.",
	},
	{
		"id": &"minimap", "name": "Field Minimap", "level": 1, "icon": &"grid",
		"description": "Top-left tactical minimap with objectives, exfils, hostiles and allies.",
	},
	{
		"id": &"slide", "name": "Combat Slide", "level": 2, "icon": &"arrow-right",
		"description": "Crouch while sprinting to slide under fire.",
	},
	{
		"id": &"melee", "name": "Melee Shove", "level": 2, "icon": &"impact",
		"description": "Press V to shove and stagger a close enemy.",
	},
	{
		"id": &"tactical_map", "name": "Tactical Map Overlay", "level": 2, "icon": &"radar",
		"description": "Press M to open the full Reach map without pausing.",
	},
	{
		"id": &"grenade", "name": "Frag Grenade", "level": 3, "icon": &"rocket",
		"description": "Press G to throw a fragmentation charge.",
	},
	{
		"id": &"squad_command", "name": "Squad Commands", "level": 4, "icon": &"users",
		"description": "Press Z to cycle follow, hold and focus orders.",
	},
	{
		"id": &"pet_command", "name": "Driftling Commands", "level": 4, "icon": &"paw",
		"description": "Press B to trigger your Driftling's ability.",
	},
]


static func entry(mechanic_id: StringName) -> Dictionary:
	for mechanic in ALL:
		if StringName(mechanic.id) == mechanic_id:
			return mechanic
	return {}


static func level_of(mechanic_id: StringName) -> int:
	var data := entry(mechanic_id)
	return int(data.get("level", 1)) if not data.is_empty() else 0


static func is_unlocked(mechanic_id: StringName, player_level: int) -> bool:
	var data := entry(mechanic_id)
	if data.is_empty():
		return true
	return player_level >= int(data.get("level", 1))


static func unlocked_entries(player_level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mechanic in ALL:
		if player_level >= int(mechanic.level):
			out.append(mechanic)
	return out


static func new_at_level(player_level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mechanic in ALL:
		if int(mechanic.level) == player_level:
			out.append(mechanic)
	return out


static func next_entries(player_level: int, limit: int = 3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mechanic in ALL:
		if int(mechanic.level) > player_level:
			out.append(mechanic)
			if out.size() >= limit:
				break
	return out
