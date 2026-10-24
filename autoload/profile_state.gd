extends Node
## Persistent meta/progression state. Run state must never leak into this file.
## All IDs are strings in the save payload; hot-path accessors convert to StringName.

signal profile_loaded
signal profile_saved
signal profile_changed
signal level_up(new_level: int)
signal currency_changed(salvage: int, cores: int)

const SAVE_PATH := "user://riftward_profile.json"
const BACKUP_PATH := "user://riftward_profile.json.bak"
const SAVE_VERSION := 3
const MAX_LEVEL := 30
const MechanicUnlocks := preload("res://features/player/mechanic_unlocks.gd")

const DISCIPLINES := [&"vanguard", &"infiltrator", &"engineer", &"pathfinder"]
const STARTING_ABILITIES := {
	"vanguard": ["aegis_wall", "blink_step"],
	"infiltrator": ["phase_cloak", "blink_step"],
	"engineer": ["deploy_turret", "blink_step"],
	"pathfinder": ["pulse_scan", "blink_step"],
}

const BASE_LAYOUT := {
	"command_nexus": Vector2i(3, 3),
	"foundry": Vector2i(1, 1),
	"armory": Vector2i(6, 1),
	"infirmary": Vector2i(1, 4),
	"barracks": Vector2i(6, 4),
	"drift_den": Vector2i(1, 6),
	"reactor": Vector2i(4, 6),
	"signal_array": Vector2i(6, 6),
}

const SET_BONUSES := {
	"vanguard": [
		{"id": "set_vanguard", "stat": "armor", "op": "add", "value": 12.0},
		{"id": "set_vanguard_hp", "stat": "health_max", "op": "add", "value": 15.0},
	],
	"ghost": [
		{"id": "set_ghost", "stat": "move_speed", "op": "add", "value": 0.25},
		{"id": "set_ghost_crit", "stat": "crit_chance", "op": "add", "value": 0.03},
	],
	"engineer": [
		{"id": "set_engineer", "stat": "cooldown_mult", "op": "mult", "value": 0.95},
		{"id": "set_engineer_sd", "stat": "shield_max", "op": "add", "value": 10.0},
	],
	"pathfinder": [
		{"id": "set_pathfinder", "stat": "handling", "op": "add", "value": 0.1},
		{"id": "set_pathfinder_crit", "stat": "crit_chance", "op": "add", "value": 0.04},
	],
}

var data: Dictionary = {}
var save_path := SAVE_PATH
var is_new_profile: bool = false


func _ready() -> void:
	load_or_create()


func _defaults() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"profile_id": "rw-%s" % str(Time.get_unix_time_from_system()).replace(".", ""),
		"callsign": "Warden",
		"created_unix": int(Time.get_unix_time_from_system()),
		"playtime_seconds": 0.0,
		"level": 1,
		"xp": 0,
		"attributes": {"power": 2, "resolve": 3, "agility": 3, "tech": 2},
		"attribute_points": 0,
		"skill_points": 2,
		"discipline": "vanguard",
		"ability_loadout": ["aegis_wall", "blink_step"],
		"skill_ranks": {},
		"salvage": 300,
		"cores": 3,
		"next_uid": 1,
		"inventory": [],
		"equipped": {
			"primary": 0, "primary_2": 0, "sidearm": 0, "helmet": 0, "chest": 0,
			"legs": 0, "cloak": 0, "charm": 0,
		},
		"base_modules": {
			"command_nexus": 1, "foundry": 0, "armory": 0, "infirmary": 0,
			"barracks": 0, "drift_den": 0, "reactor": 0, "signal_array": 0,
		},
		"base_layout": _layout_payload(),
		"active_allies": ["mara_voss", "irie_sol"],
		"ally_ranks": {"mara_voss": 1, "rook": 1, "irie_sol": 1, "toma_nix": 1},
		"active_pet": "mote",
		"pet_ranks": {"mote": 1, "cinder": 1, "pip": 1},
		"unlocked_cosmetics": [],
		"cosmetics": {"suit": "suit_wayfinder", "dye": "dye_mint", "weapon_skin": "skin_lattice", "pet_shell": "shell_default"},
		"records": {"deployments": 0, "extractions": 0, "deaths": 0, "kills": 0, "bosses": 0, "best_extraction": 0, "total_salvage": 0},
		"contracts_completed": 0,
		"daily": {},
		"last_difficulty": "patrol",
		"last_mode": "normal",
		"tutorial_done": false,
		"last_run": {},
	}


func _layout_payload() -> Dictionary:
	var payload: Dictionary = {}
	for id in BASE_LAYOUT.keys():
		var pos: Vector2i = BASE_LAYOUT[id]
		payload[id] = [pos.x, pos.y]
	return payload


func load_or_create() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		if _load_from(SAVE_PATH):
			profile_loaded.emit()
			return
	if FileAccess.file_exists(BACKUP_PATH):
		push_warning("[ProfileState] Primary save unreadable; restoring backup.")
		if _load_from(BACKUP_PATH):
			save_now()
			profile_loaded.emit()
			return
	is_new_profile = true
	data = _defaults()
	_make_starter_kit()
	_ensure_valid()
	save_now()
	profile_loaded.emit()


func _load_from(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	var loaded: Dictionary = parsed
	var loaded_version := int(loaded.get("version", 1))
	var defaults := _defaults()
	_deep_fill(loaded, defaults)
	data = loaded
	_migrate_save(loaded_version)
	_ensure_valid()
	if loaded_version < SAVE_VERSION:
		save_now()
	return true


func _deep_fill(target: Dictionary, defaults: Dictionary) -> void:
	for key in defaults.keys():
		if not target.has(key) or target[key] == null:
			target[key] = defaults[key].duplicate(true) if defaults[key] is Dictionary or defaults[key] is Array else defaults[key]
		elif target[key] is Dictionary and defaults[key] is Dictionary:
			_deep_fill(target[key], defaults[key])


## One-time schema upgrade. Version 3 adds the second primary weapon slot and
## makes the Sable Rail the default primary for profiles that still carry the
## original starter rifle.
func _migrate_save(loaded_version: int) -> void:
	if loaded_version >= SAVE_VERSION:
		return
	var inventory: Array = data.get("inventory", [])
	if not (inventory is Array):
		inventory = []
	var equipped: Dictionary = data.get("equipped", {})
	var level := maxi(1, int(data.get("level", 1)))
	var primary_item := _inventory_item_by_uid(inventory, int(equipped.get("primary", 0)))
	var owns_sniper := false
	for item in inventory:
		if item is Dictionary and String(item.get("base_id", "")) == "sable_rail":
			owns_sniper = true
			break
	if not primary_item.is_empty() and String(primary_item.get("base_id", "")) == "lattice_ar" and not owns_sniper:
		var sniper := _make_migrated_weapon(&"sable_rail", 1, level)
		if not sniper.is_empty():
			inventory.append(sniper)
			equipped["primary"] = int(sniper.get("uid", 0))
	if int(equipped.get("primary_2", 0)) <= 0:
		var second_uid := _best_unequipped_primary_uid(inventory, equipped)
		if second_uid <= 0:
			var rifle := _make_migrated_weapon(&"lattice_ar", 1, level)
			if not rifle.is_empty():
				inventory.append(rifle)
				second_uid = int(rifle.get("uid", 0))
		equipped["primary_2"] = second_uid
	data["inventory"] = inventory
	data["equipped"] = equipped


func _make_migrated_weapon(base_id: StringName, rarity: int, level: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%s:%d" % [String(data.get("profile_id", "")), String(base_id), Time.get_unix_time_from_system()])
	var uid := int(data.get("next_uid", 1))
	var item := ItemFactory.generate_weapon(rng, base_id, rarity, level, uid)
	if item.is_empty():
		return {}
	data["next_uid"] = uid + 1
	return item


func _inventory_item_by_uid(inventory: Array, uid: int) -> Dictionary:
	if uid <= 0:
		return {}
	for item in inventory:
		if item is Dictionary and int(item.get("uid", 0)) == uid:
			return item
	return {}


func _best_unequipped_primary_uid(inventory: Array, equipped: Dictionary) -> int:
	var used: Dictionary = {}
	for slot in [StatKeys.SLOT_PRIMARY, StatKeys.SLOT_PRIMARY_2, StatKeys.SLOT_SIDEARM]:
		var uid := int(equipped.get(String(slot), 0))
		if uid > 0:
			used[uid] = true
	var best_uid := 0
	var best_score := -1.0
	for item in inventory:
		if not (item is Dictionary):
			continue
		if String(item.get("kind", "")) != "weapon" or String(item.get("slot", "")) != "primary":
			continue
		var uid := int(item.get("uid", 0))
		if uid <= 0 or used.has(uid):
			continue
		var score := float(int(item.get("rarity", 0))) * 10.0 + float(int(item.get("level", 1)))
		if score > best_score:
			best_score = score
			best_uid = uid
	return best_uid


func _ensure_valid() -> void:
	data["version"] = SAVE_VERSION
	data["level"] = clampi(int(data.get("level", 1)), 1, MAX_LEVEL)
	data["xp"] = maxi(0, int(data.get("xp", 0)))
	data["salvage"] = maxi(0, int(data.get("salvage", 0)))
	data["cores"] = maxi(0, int(data.get("cores", 0)))
	data["skill_points"] = maxi(0, int(data.get("skill_points", 0)))
	data["attribute_points"] = maxi(0, int(data.get("attribute_points", 0)))
	if not (data.get("discipline", "vanguard") in DISCIPLINES):
		data["discipline"] = "vanguard"
	var difficulty_id := StringName(data.get("last_difficulty", "patrol"))
	if ContentDB.get_difficulty(difficulty_id).is_empty():
		data["last_difficulty"] = "patrol"
	else:
		data["last_difficulty"] = String(difficulty_id)
	if not (String(data.get("last_mode", "normal")) in ["normal", "quick"]):
		data["last_mode"] = "normal"
	var attrs: Dictionary = data.get("attributes", {})
	for attr in ["power", "resolve", "agility", "tech"]:
		attrs[attr] = clampi(int(attrs.get(attr, 2)), 1, 30)
	data["attributes"] = attrs
	var inventory: Array = data.get("inventory", [])
	var seen_uids: Dictionary = {}
	var next_uid: int = int(data.get("next_uid", 1))
	for item in inventory:
		if not (item is Dictionary):
			continue
		if not item.has("uid") or int(item.get("uid", 0)) <= 0:
			item["uid"] = next_uid
			next_uid += 1
		if seen_uids.has(item["uid"]):
			item["uid"] = next_uid
			next_uid += 1
		seen_uids[item["uid"]] = true
	data["inventory"] = inventory
	data["next_uid"] = maxi(next_uid, int(data.get("next_uid", 1)))
	var equipped: Dictionary = data.get("equipped", {})
	for slot in StatKeys.EQUIP_SLOTS:
		if not equipped.has(slot):
			equipped[slot] = 0
		elif int(equipped[slot]) > 0 and not _inventory_has_uid(int(equipped[slot])):
			equipped[slot] = 0
	# A weapon can only occupy one weapon slot. Repair legacy/duplicate saves.
	var equipped_weapons: Dictionary = {}
	for slot in [StatKeys.SLOT_PRIMARY, StatKeys.SLOT_PRIMARY_2, StatKeys.SLOT_SIDEARM]:
		var uid := int(equipped.get(slot, 0))
		if uid <= 0:
			continue
		if equipped_weapons.has(uid):
			equipped[slot] = 0
		else:
			equipped_weapons[uid] = true
	data["equipped"] = equipped
	var modules: Dictionary = data.get("base_modules", {})
	for module in ContentDB.base_modules.keys():
		modules[module] = clampi(int(modules.get(module, 0)), 0, 3)
	data["base_modules"] = modules
	var ranks: Dictionary = data.get("skill_ranks", {})
	for perk_id in ranks.keys():
		if ContentDB.get_perk(StringName(perk_id)) == null:
			ranks.erase(perk_id)
	data["skill_ranks"] = ranks
	var unlocked: Array = data.get("unlocked_cosmetics", [])
	if unlocked.is_empty():
		for cosmetic in ContentDB.cosmetics.values():
			unlocked.append(cosmetic.id)
	else:
		unlocked = Array(unlocked)
	data["unlocked_cosmetics"] = unlocked
	var cosmetic_equipped: Dictionary = data.get("cosmetics", {})
	for key in ["suit", "dye", "weapon_skin", "pet_shell"]:
		if not cosmetic_equipped.has(key):
			cosmetic_equipped[key] = _default_cosmetic_for(key)
	data["cosmetics"] = cosmetic_equipped
	_ensure_ability_loadout()
	if not data.has("ally_ranks"):
		data["ally_ranks"] = {"mara_voss": 1, "rook": 1, "irie_sol": 1, "toma_nix": 1}
	if not data.has("pet_ranks"):
		data["pet_ranks"] = {"mote": 1, "cinder": 1, "pip": 1}
	if not data.has("active_allies") or data["active_allies"].is_empty():
		data["active_allies"] = ["mara_voss"]
	if not data.has("active_pet"):
		data["active_pet"] = "mote"
	if not data.has("records"):
		data["records"] = {"deployments": 0, "extractions": 0, "deaths": 0, "kills": 0, "bosses": 0, "best_extraction": 0, "total_salvage": 0}
	if not data.has("base_layout"):
		data["base_layout"] = _layout_payload()


func _default_cosmetic_for(slot: String) -> String:
	match slot:
		"dye":
			return "dye_mint"
		"weapon_skin":
			return "skin_lattice"
		"pet_shell":
			return "shell_default"
		_:
			return "suit_wayfinder"


func _ensure_ability_loadout() -> void:
	var loadout: Array = data.get("ability_loadout", [])
	var valid: Array[String] = []
	for id in loadout:
		var ability := ContentDB.get_ability(StringName(id))
		if ability != null and not ability.is_ultimate and is_ability_unlocked(StringName(id)):
			valid.append(String(ability.id))
	if valid.is_empty():
		var defaults: Array = STARTING_ABILITIES.get(String(data.get("discipline", "vanguard")), ["aegis_wall", "blink_step"])
		for id in defaults:
			if is_ability_unlocked(StringName(id)):
				valid.append(String(id))
	data["ability_loadout"] = valid.slice(0, 2)


func _make_starter_kit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x51F7A11
	var inventory: Array = []
	var uid := 1
	# Default loadout: sniper primary, rifle secondary primary, sidearm.
	# The close-combat knife is built into the player and needs no item.
	var primary := ItemFactory.generate_weapon(rng, &"sable_rail", 1, 1, uid); uid += 1
	var primary_2 := ItemFactory.generate_weapon(rng, &"lattice_ar", 1, 1, uid); uid += 1
	var sidearm := ItemFactory.generate_weapon(rng, &"sidewinder", 0, 1, uid); uid += 1
	var helmet := ItemFactory.generate_gear(rng, &"vanguard_helm", 1, 1, uid); uid += 1
	var chest := ItemFactory.generate_gear(rng, &"aegis_chest", 1, 1, uid); uid += 1
	var legs := ItemFactory.generate_gear(rng, &"engineer_legs", 0, 1, uid); uid += 1
	var cloak := ItemFactory.generate_gear(rng, &"storm_cloak", 1, 1, uid); uid += 1
	var charm := ItemFactory.generate_gear(rng, &"scavenger_tag", 0, 1, uid); uid += 1
	var starter: Array = [primary, primary_2, sidearm, helmet, chest, legs, cloak, charm]
	for item in starter:
		inventory.append(item)
	inventory.append(ItemFactory.generate_weapon(rng, &"wisp_smg", 1, 1, uid)); uid += 1
	inventory.append(ItemFactory.generate_weapon(rng, &"longview_dmr", 2, 2, uid)); uid += 1
	inventory.append(ItemFactory.generate_gear(rng, &"pathfinder_visor", 1, 2, uid)); uid += 1
	inventory.append(ItemFactory.generate_gear(rng, &"ghost_chest", 2, 2, uid)); uid += 1
	inventory.append(ItemFactory.generate_gear(rng, &"striders", 1, 2, uid)); uid += 1
	data["inventory"] = inventory
	data["equipped"] = {
		"primary": int(primary.get("uid", 0)),
		"primary_2": int(primary_2.get("uid", 0)),
		"sidearm": int(sidearm.get("uid", 0)),
		"helmet": int(helmet.get("uid", 0)),
		"chest": int(chest.get("uid", 0)),
		"legs": int(legs.get("uid", 0)),
		"cloak": int(cloak.get("uid", 0)),
		"charm": int(charm.get("uid", 0)),
	}
	data["next_uid"] = uid
	for cosmetic in ContentDB.cosmetics.values():
		data["unlocked_cosmetics"].append(String(cosmetic.id))


func save_now() -> bool:
	if data.is_empty():
		return false
	data["saved_unix"] = int(Time.get_unix_time_from_system())
	var json_text := JSON.stringify(data, "\t")
	var tmp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("[ProfileState] Cannot write save: %s" % FileAccess.get_open_error())
		return false
	file.store_string(json_text)
	file.close()
	var abs_save := ProjectSettings.globalize_path(SAVE_PATH)
	var abs_backup := ProjectSettings.globalize_path(BACKUP_PATH)
	var abs_tmp := ProjectSettings.globalize_path(tmp_path)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(abs_save, abs_backup)
	var err := DirAccess.rename_absolute(abs_tmp, abs_save)
	if err != OK:
		push_error("[ProfileState] Save rename failed: %s" % err)
		return false
	profile_saved.emit()
	return true


func create_new_profile(callsign: String) -> void:
	data = _defaults()
	var clean := callsign.strip_edges()
	data["callsign"] = clean if not clean.is_empty() else "Warden"
	_make_starter_kit()
	_ensure_valid()
	is_new_profile = true
	save_now()
	profile_changed.emit()
	profile_loaded.emit()


func set_callsign(callsign: String) -> void:
	var clean := callsign.strip_edges().substr(0, 20)
	if clean.is_empty():
		return
	data["callsign"] = clean
	profile_changed.emit()


func get_callsign() -> String:
	return String(data.get("callsign", "Warden"))


func get_profile_id() -> String:
	return String(data.get("profile_id", ""))


func get_level() -> int:
	return int(data.get("level", 1))


func get_xp() -> int:
	return int(data.get("xp", 0))


func get_xp_for_next_level() -> int:
	if get_level() >= MAX_LEVEL:
		return 0
	return 140 + get_level() * 70


func get_xp_ratio() -> float:
	var target := get_xp_for_next_level()
	if target <= 0:
		return 1.0
	return clampf(float(get_xp()) / float(target), 0.0, 1.0)


func get_unspent_points() -> int:
	return get_skill_points() + get_attribute_points()


func get_last_difficulty() -> StringName:
	var difficulty_id := StringName(data.get("last_difficulty", "patrol"))
	if ContentDB.get_difficulty(difficulty_id).is_empty():
		return &"patrol"
	return difficulty_id


func set_last_difficulty(difficulty_id: StringName) -> bool:
	if ContentDB.get_difficulty(difficulty_id).is_empty():
		return false
	data["last_difficulty"] = String(difficulty_id)
	profile_changed.emit()
	return true


func get_last_mode() -> StringName:
	var mode := String(data.get("last_mode", "normal"))
	return StringName(mode if mode in ["normal", "quick"] else "normal")


func set_last_mode(mode_id: StringName) -> bool:
	var mode := String(mode_id)
	if not (mode in ["normal", "quick"]):
		return false
	data["last_mode"] = mode
	profile_changed.emit()
	return true


func is_mechanic_unlocked(mechanic_id: StringName) -> bool:
	return MechanicUnlocks.is_unlocked(mechanic_id, get_level())


func get_mechanic_unlocks() -> Array[Dictionary]:
	return MechanicUnlocks.unlocked_entries(get_level())


func get_next_mechanic_unlock() -> Dictionary:
	var upcoming := MechanicUnlocks.next_entries(get_level(), 1)
	return upcoming[0] if not upcoming.is_empty() else {}


func get_mechanic_level(mechanic_id: StringName) -> int:
	return MechanicUnlocks.level_of(mechanic_id)


func add_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	var gained := 0
	data["xp"] = int(data.get("xp", 0)) + amount
	while get_level() < MAX_LEVEL and get_xp() >= get_xp_for_next_level():
		data["xp"] = get_xp() - get_xp_for_next_level()
		data["level"] = get_level() + 1
		data["attribute_points"] = int(data.get("attribute_points", 0)) + 2
		data["skill_points"] = int(data.get("skill_points", 0)) + 1
		gained += 1
		level_up.emit(get_level())
	if get_level() >= MAX_LEVEL:
		data["xp"] = 0
	_ensure_ability_loadout()
	profile_changed.emit()
	return gained


func get_attributes() -> Dictionary:
	return data.get("attributes", {"power": 2, "resolve": 3, "agility": 3, "tech": 2}).duplicate(true)


func get_attribute_points() -> int:
	return int(data.get("attribute_points", 0))


func spend_attribute_point(attribute: StringName) -> bool:
	if get_attribute_points() <= 0:
		return false
	var key := String(attribute)
	var attrs := get_attributes()
	if not attrs.has(key):
		return false
	attrs[key] = int(attrs[key]) + 1
	data["attributes"] = attrs
	data["attribute_points"] = get_attribute_points() - 1
	profile_changed.emit()
	return true


func get_skill_points() -> int:
	return int(data.get("skill_points", 0))


func get_skill_ranks() -> Dictionary:
	return data.get("skill_ranks", {}).duplicate(true)


func has_perk(perk_id: StringName) -> bool:
	return data.get("skill_ranks", {}).has(String(perk_id))


func can_buy_perk(perk_id: StringName) -> bool:
	if get_skill_points() <= 0 or has_perk(perk_id):
		return false
	var perk := ContentDB.get_perk(perk_id)
	if perk == null:
		return false
	if get_level() < perk.unlock_level:
		return false
	if perk.requires != &"" and not has_perk(perk.requires):
		return false
	return true


func buy_perk(perk_id: StringName) -> bool:
	if not can_buy_perk(perk_id):
		return false
	var ranks: Dictionary = data.get("skill_ranks", {})
	ranks[String(perk_id)] = 1
	data["skill_ranks"] = ranks
	data["skill_points"] = get_skill_points() - 1
	profile_changed.emit()
	return true


func get_discipline() -> StringName:
	return StringName(data.get("discipline", "vanguard"))


func set_discipline(discipline: StringName) -> bool:
	if not (String(discipline) in DISCIPLINES):
		return false
	data["discipline"] = String(discipline)
	_ensure_ability_loadout()
	profile_changed.emit()
	return true


func is_ability_unlocked(ability_id: StringName) -> bool:
	var ability := ContentDB.get_ability(ability_id)
	if ability == null:
		return false
	if ability.is_ultimate:
		return ability.discipline == get_discipline()
	return get_level() >= ability.unlock_level


func get_unlocked_ability_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for ability in ContentDB.abilities.values():
		if ability.is_ultimate:
			if ability.discipline == get_discipline():
				out.append(ability.id)
		elif get_level() >= ability.unlock_level:
			out.append(ability.id)
	return out


func get_ability_loadout() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in data.get("ability_loadout", []):
		out.append(StringName(id))
	return out


func set_ability_loadout(ids: Array) -> bool:
	var valid: Array[String] = []
	for id in ids:
		var sn := StringName(id)
		if is_ability_unlocked(sn):
			var ability := ContentDB.get_ability(sn)
			if ability != null and not ability.is_ultimate and not (String(sn) in valid):
				valid.append(String(sn))
	if valid.is_empty():
		return false
	data["ability_loadout"] = valid.slice(0, 2)
	profile_changed.emit()
	return true


func get_equipped_ultimate() -> AbilityData:
	return ContentDB.get_ultimate_for_discipline(get_discipline())


func get_salvage() -> int:
	return int(data.get("salvage", 0))


func get_cores() -> int:
	return int(data.get("cores", 0))


func add_currency(salvage: int, cores: int = 0) -> void:
	data["salvage"] = maxi(0, get_salvage() + salvage)
	data["cores"] = maxi(0, get_cores() + cores)
	currency_changed.emit(get_salvage(), get_cores())
	profile_changed.emit()


func get_inventory() -> Array:
	return data.get("inventory", []).duplicate(true)


func get_inventory_size() -> int:
	return data.get("inventory", []).size()


func get_item(uid: int) -> Dictionary:
	for item in data.get("inventory", []):
		if int(item.get("uid", 0)) == uid:
			return item
	return {}


func _inventory_has_uid(uid: int) -> bool:
	return not get_item(uid).is_empty()


func add_item(item: Dictionary) -> int:
	if item.is_empty():
		return 0
	var copy := item.duplicate(true)
	if int(copy.get("uid", 0)) <= 0:
		copy["uid"] = int(data.get("next_uid", 1))
		data["next_uid"] = int(data.get("next_uid", 1)) + 1
	data["inventory"].append(copy)
	profile_changed.emit()
	return int(copy["uid"])


func remove_item(uid: int) -> bool:
	var inventory: Array = data.get("inventory", [])
	for i in inventory.size():
		if int(inventory[i].get("uid", 0)) == uid:
			inventory.remove_at(i)
			for slot in data.get("equipped", {}).keys():
				if int(data["equipped"][slot]) == uid:
					data["equipped"][slot] = 0
			profile_changed.emit()
			return true
	return false


func scrap_item(uid: int) -> bool:
	var item := get_item(uid)
	if item.is_empty():
		return false
	for slot in data.get("equipped", {}).keys():
		if int(data["equipped"][slot]) == uid:
			return false
	var value := maxi(1, int(ItemFactory.item_value(item) * 0.25))
	if remove_item(uid):
		add_currency(value, 0)
		return true
	return false


func get_equipped_item(slot: StringName) -> Dictionary:
	var uid := int(data.get("equipped", {}).get(String(slot), 0))
	if uid <= 0:
		return {}
	return get_item(uid)


func get_equipped_uid(slot: StringName) -> int:
	return int(data.get("equipped", {}).get(String(slot), 0))


## Equips an item. `target_slot` is optional; the loadout screen uses it to
## distinguish primary 1 from primary 2 because both accept weapon-slot items.
func equip_item(uid: int, target_slot: StringName = &"") -> bool:
	var item := get_item(uid)
	if item.is_empty():
		return false
	var item_slot := StringName(item.get("slot", ""))
	var slot := target_slot if target_slot != &"" else item_slot
	if not (String(slot) in ["primary", "primary_2", "sidearm", "helmet", "chest", "legs", "cloak", "charm"]):
		return false
	if item_slot == StatKeys.SLOT_PRIMARY or item_slot == StatKeys.SLOT_SIDEARM:
		if String(item.get("kind", "")) != "weapon":
			return false
	elif String(item.get("kind", "")) != "gear":
		return false
	# Verify the item actually fits this slot's type.
	var expected_slot: StringName
	if item.kind == "weapon":
		var weapon := ContentDB.get_weapon(StringName(item.get("base_id", "")))
		if weapon == null:
			return false
		expected_slot = weapon.slot
	else:
		var template := ContentDB.get_item_template(StringName(item.get("base_id", "")))
		if template == null:
			return false
		expected_slot = template.slot
	if not _slot_accepts(slot, expected_slot):
		return false
	var equipped: Dictionary = data.get("equipped", {})
	if int(equipped.get(String(slot), 0)) == uid:
		return true
	var previous_uid := int(equipped.get(String(slot), 0))
	# A weapon may only live in one weapon slot. Moving a primary between the
	# two primary slots swaps the displaced weapon instead of duplicating it.
	for other in [StatKeys.SLOT_PRIMARY, StatKeys.SLOT_PRIMARY_2, StatKeys.SLOT_SIDEARM]:
		if other == slot:
			continue
		if int(equipped.get(String(other), 0)) != uid:
			continue
		if previous_uid > 0 and _is_primary_slot(other) and _is_primary_slot(slot) and _uid_is_primary_weapon(previous_uid):
			equipped[String(other)] = previous_uid
		else:
			equipped[String(other)] = 0
		break
	equipped[String(slot)] = uid
	data["equipped"] = equipped
	profile_changed.emit()
	return true


func _slot_accepts(slot: StringName, expected_slot: StringName) -> bool:
	if expected_slot == StatKeys.SLOT_PRIMARY:
		return slot == StatKeys.SLOT_PRIMARY or slot == StatKeys.SLOT_PRIMARY_2
	return slot == expected_slot


func _is_primary_slot(slot: StringName) -> bool:
	return slot == StatKeys.SLOT_PRIMARY or slot == StatKeys.SLOT_PRIMARY_2


func _uid_is_primary_weapon(uid: int) -> bool:
	var item := get_item(uid)
	if item.is_empty() or String(item.get("kind", "")) != "weapon":
		return false
	var weapon := ContentDB.get_weapon(StringName(item.get("base_id", "")))
	return weapon != null and weapon.slot == StatKeys.SLOT_PRIMARY


func unequip_slot(slot: StringName) -> void:
	data["equipped"][String(slot)] = 0
	profile_changed.emit()


func get_weapon_item(slot: StringName) -> Dictionary:
	return get_equipped_item(slot)


func get_equipment_modifiers() -> Array[Dictionary]:
	var mods: Array[Dictionary] = []
	for slot in [StatKeys.SLOT_HELMET, StatKeys.SLOT_CHEST, StatKeys.SLOT_LEGS, StatKeys.SLOT_CLOAK, StatKeys.SLOT_CHARM]:
		var item := get_equipped_item(slot)
		if item.is_empty():
			continue
		mods.append_array(ItemFactory.equipment_modifiers(item))
	# Set bonuses
	var set_counts: Dictionary = {}
	for slot in [StatKeys.SLOT_HELMET, StatKeys.SLOT_CHEST, StatKeys.SLOT_LEGS, StatKeys.SLOT_CLOAK, StatKeys.SLOT_CHARM]:
		var item := get_equipped_item(slot)
		if item.is_empty():
			continue
		var info := ItemFactory.describe(item)
		var set_id := String(info.get("set_id", ""))
		if set_id != "":
			set_counts[set_id] = int(set_counts.get(set_id, 0)) + 1
	for set_id in set_counts.keys():
		if int(set_counts[set_id]) >= 3 and SET_BONUSES.has(set_id):
			for entry in SET_BONUSES[set_id]:
				mods.append({
					"id": StringName(entry.id),
					"source": "set_bonus",
					"stat": StringName(entry.stat),
					"op": StringName(entry.op),
					"value": float(entry.value),
				})
	return mods


func get_perk_modifiers() -> Array[Dictionary]:
	var mods: Array[Dictionary] = []
	var ranks: Dictionary = data.get("skill_ranks", {})
	for perk_id in ranks.keys():
		var perk := ContentDB.get_perk(StringName(perk_id))
		if perk == null:
			continue
		mods.append({
			"id": &"perk_" + perk.id,
			"source": "perk",
			"stat": perk.stat,
			"op": perk.op,
			"value": perk.value,
		})
	return mods


func get_base_modifiers() -> Array[Dictionary]:
	var mods: Array[Dictionary] = []
	var modules: Dictionary = data.get("base_modules", {})
	var reactor := int(modules.get("reactor", 0))
	if reactor > 0:
		mods.append({"id": &"base_reactor", "source": "base", "stat": &"cooldown_mult", "op": &"mult", "value": 1.0 - 0.03 * reactor})
	var signal_tier := int(modules.get("signal_array", 0))
	if signal_tier > 0:
		mods.append({"id": &"base_signal", "source": "base", "stat": &"luck", "op": &"add", "value": 0.03 * signal_tier})
	var infirmary := int(modules.get("infirmary", 0))
	if infirmary > 0:
		mods.append({"id": &"base_infirmary", "source": "base", "stat": &"health_max", "op": &"add", "value": 8.0 * infirmary})
	return mods


func get_stat_modifiers() -> Array[Dictionary]:
	var mods: Array[Dictionary] = []
	mods.append_array(get_equipment_modifiers())
	mods.append_array(get_perk_modifiers())
	mods.append_array(get_base_modifiers())
	return mods


func get_preview_stats() -> Dictionary:
	return PlayerStats.base_with_profile(self)


func get_base_tier(module_id: StringName) -> int:
	return int(data.get("base_modules", {}).get(String(module_id), 0))


func get_base_modules() -> Dictionary:
	return data.get("base_modules", {}).duplicate(true)


func get_base_power() -> int:
	var total := 0
	var modules: Dictionary = data.get("base_modules", {})
	for id in modules.keys():
		var mod := ContentDB.get_base_module(StringName(id))
		if mod != null:
			total += mod.power * int(modules[id])
	return total


func get_base_layout() -> Dictionary:
	var result: Dictionary = {}
	var payload: Dictionary = data.get("base_layout", {})
	for id in payload.keys():
		var arr: Array = payload[id]
		if arr.size() >= 2:
			result[StringName(id)] = Vector2i(int(arr[0]), int(arr[1]))
	return result


func can_upgrade_base_module(module_id: StringName) -> bool:
	var module := ContentDB.get_base_module(module_id)
	if module == null:
		return false
	var tier := get_base_tier(module_id)
	if tier >= module.max_tier:
		return false
	if module_id != &"command_nexus":
		var nexus := get_base_tier(&"command_nexus")
		if tier + 1 > nexus:
			return false
	if get_salvage() < module.cost_for_tier(tier):
		return false
	if get_cores() < module.core_cost_for_tier(tier):
		return false
	return true


func upgrade_base_module(module_id: StringName) -> bool:
	if not can_upgrade_base_module(module_id):
		return false
	var module := ContentDB.get_base_module(module_id)
	var tier := get_base_tier(module_id)
	var cost := module.cost_for_tier(tier)
	var core_cost := module.core_cost_for_tier(tier)
	data["salvage"] = get_salvage() - cost
	data["cores"] = get_cores() - core_cost
	data["base_modules"][String(module_id)] = tier + 1
	currency_changed.emit(get_salvage(), get_cores())
	profile_changed.emit()
	save_now()
	return true


func get_active_allies() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in data.get("active_allies", []):
		out.append(StringName(id))
	return out


func set_active_allies(ids: Array) -> bool:
	var valid: Array[String] = []
	for id in ids:
		var ally := ContentDB.get_ally(StringName(id))
		if ally != null and not (String(id) in valid):
			valid.append(String(id))
	if valid.size() > 2:
		valid = valid.slice(0, 2)
	data["active_allies"] = valid
	profile_changed.emit()
	return true


func get_ally_rank(ally_id: StringName) -> int:
	return int(data.get("ally_ranks", {}).get(String(ally_id), 1))


func set_ally_rank(ally_id: StringName, rank: int) -> void:
	data["ally_ranks"][String(ally_id)] = clampi(rank, 1, 5)
	profile_changed.emit()


func get_active_pet() -> StringName:
	return StringName(data.get("active_pet", "mote"))


func set_active_pet(pet_id: StringName) -> bool:
	if ContentDB.get_pet(pet_id) == null:
		return false
	data["active_pet"] = String(pet_id)
	profile_changed.emit()
	return true


func get_pet_rank(pet_id: StringName) -> int:
	return int(data.get("pet_ranks", {}).get(String(pet_id), 1))


func upgrade_ally(ally_id: StringName) -> bool:
	var rank := get_ally_rank(ally_id)
	if rank >= 5:
		return false
	var cost := 1 + rank
	if get_cores() < cost:
		return false
	data["cores"] = get_cores() - cost
	data["ally_ranks"][String(ally_id)] = rank + 1
	currency_changed.emit(get_salvage(), get_cores())
	profile_changed.emit()
	save_now()
	return true


func upgrade_pet(pet_id: StringName) -> bool:
	var rank := get_pet_rank(pet_id)
	if rank >= 5:
		return false
	var cost := 1 + rank
	if get_cores() < cost:
		return false
	data["cores"] = get_cores() - cost
	data["pet_ranks"][String(pet_id)] = rank + 1
	currency_changed.emit(get_salvage(), get_cores())
	profile_changed.emit()
	save_now()
	return true


func get_unlocked_cosmetics() -> Array:
	return data.get("unlocked_cosmetics", []).duplicate()


func get_equipped_cosmetic(slot: String) -> String:
	return String(data.get("cosmetics", {}).get(slot, ""))


func equip_cosmetic(slot: String, cosmetic_id: String) -> bool:
	var cosmetic := ContentDB.get_cosmetic(StringName(cosmetic_id))
	if cosmetic == null or String(cosmetic.slot) != slot:
		return false
	if not (cosmetic_id in data.get("unlocked_cosmetics", [])):
		return false
	data["cosmetics"][slot] = cosmetic_id
	profile_changed.emit()
	return true


func get_records() -> Dictionary:
	return data.get("records", {}).duplicate(true)


func record_run(result: Dictionary, items: Array) -> Dictionary:
	var level_before := get_level()
	var xp_before := get_xp()
	var skill_points_before := get_skill_points()
	var attribute_points_before := get_attribute_points()
	var records: Dictionary = data.get("records", {})
	records["deployments"] = int(records.get("deployments", 0)) + 1
	if bool(result.get("extracted", false)):
		records["extractions"] = int(records.get("extractions", 0)) + 1
		records["best_extraction"] = maxi(int(records.get("best_extraction", 0)), int(result.get("value", 0)))
	else:
		records["deaths"] = int(records.get("deaths", 0)) + 1
	records["kills"] = int(records.get("kills", 0)) + int(result.get("kills", 0))
	records["bosses"] = int(records.get("bosses", 0)) + int(result.get("bosses", 0))
	if bool(result.get("extracted", false)):
		records["total_salvage"] = int(records.get("total_salvage", 0)) + int(result.get("salvage", 0))
	data["records"] = records
	data["contracts_completed"] = int(data.get("contracts_completed", 0)) + (1 if bool(result.get("contract_completed", false)) else 0)
	data["last_run"] = result.duplicate(true)
	add_xp(int(result.get("xp", 0)))
	add_currency(int(result.get("salvage", 0)) if bool(result.get("extracted", false)) else 0, int(result.get("cores", 0)) if bool(result.get("extracted", false)) else 0)
	for item in items:
		if item is Dictionary:
			add_item(item)
	save_now()
	profile_changed.emit()
	var level_after := get_level()
	return {
		"level_before": level_before,
		"xp_before": xp_before,
		"level_after": level_after,
		"xp_after": get_xp(),
		"xp_next": get_xp_for_next_level(),
		"levels_gained": maxi(0, level_after - level_before),
		"skill_points_gained": maxi(0, get_skill_points() - skill_points_before),
		"attribute_points_gained": maxi(0, get_attribute_points() - attribute_points_before),
		"skill_points": get_skill_points(),
		"attribute_points": get_attribute_points(),
		"unlocks": _unlock_entries_between(level_before, level_after),
	}


func _unlock_entries_between(level_before: int, level_after: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if level_after <= level_before:
		return out
	for level in range(level_before + 1, level_after + 1):
		for mechanic in MechanicUnlocks.new_at_level(level):
			out.append({
				"kind": "mechanic",
				"id": String(mechanic.id),
				"name": String(mechanic.name),
				"level": level,
			})
		for ability in ContentDB.abilities.values():
			if ability.is_ultimate or ability.unlock_level != level:
				continue
			out.append({
				"kind": "ability",
				"id": String(ability.id),
				"name": ability.display_name,
				"level": level,
			})
	return out


func set_tutorial_done() -> void:
	data["tutorial_done"] = true
	profile_changed.emit()


func get_tutorial_done() -> bool:
	return bool(data.get("tutorial_done", false))


func mark_playtime(delta: float) -> void:
	data["playtime_seconds"] = float(data.get("playtime_seconds", 0.0)) + maxf(0.0, delta)


func get_playtime() -> float:
	return float(data.get("playtime_seconds", 0.0))


func add_salvage(amount: int) -> void:
	add_currency(amount, 0)
