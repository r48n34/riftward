class_name ItemFactory
extends RefCounted
## Builds and resolves runtime gear/weapon item dictionaries. Item dicts are the
## save format and are also what UI and gameplay read; no Node state lives here.

const AFFIX_COUNTS := [0, 1, 2, 2, 3]


static func roll_rarity(rng: RandomNumberGenerator, luck: float = 0.0, minimum: int = 0) -> int:
	var roll := rng.randf() - clampf(luck, 0.0, 0.5) * 0.5
	var rarity := 0
	if roll > 0.92:
		rarity = 4
	elif roll > 0.80:
		rarity = 3
	elif roll > 0.62:
		rarity = 2
	elif roll > 0.30:
		rarity = 1
	return clampi(rarity, minimum, 4)


static func generate_weapon(
	rng: RandomNumberGenerator,
	weapon_id: StringName,
	rarity: int = -1,
	level: int = 1,
	uid: int = 0
) -> Dictionary:
	var weapon := ContentDB.get_weapon(weapon_id)
	if weapon == null:
		return {}
	if rarity < 0:
		rarity = roll_rarity(rng)
	return _finish_item({
		"uid": uid,
		"kind": "weapon",
		"base_id": String(weapon_id),
		"slot": String(weapon.slot),
		"rarity": clampi(rarity, 0, 4),
		"level": maxi(1, level),
	}, rng)


static func generate_gear(
	rng: RandomNumberGenerator,
	template_id: StringName,
	rarity: int = -1,
	level: int = 1,
	uid: int = 0
) -> Dictionary:
	var template := ContentDB.get_item_template(template_id)
	if template == null:
		return {}
	if rarity < 0:
		rarity = roll_rarity(rng)
	return _finish_item({
		"uid": uid,
		"kind": "gear",
		"base_id": String(template_id),
		"slot": String(template.slot),
		"rarity": clampi(rarity, 0, 4),
		"level": maxi(1, level),
	}, rng)


## Builds one authored loot-cargo stack (kind "loot"). Authoritative rarity comes
## from the content entry, so the result is stable for a given table entry — no
## affixes and no equipment slot. Loot items still travel in the ordinary item
## dictionary, so save format v5 is untouched.
static func generate_loot_item(item_id: StringName, uid: int = 0, amount: int = 1) -> Dictionary:
	var loot := ContentDB.get_item(item_id)
	if loot == null:
		return {}
	return {
		"uid": uid,
		"kind": "loot",
		"base_id": String(item_id),
		"slot": "",
		"rarity": clampi(loot.rarity, 0, 4),
		"level": 1,
		"amount": maxi(1, amount),
		"affixes": [],
	}


## Rolls one weighted entry from an authored loot table id (poi_common,
## poi_rare, vehicle_stash). Thin facade so gameplay code never needs LootTables.
static func generate_from_loot_table(
	rng: RandomNumberGenerator,
	table_id: StringName,
	luck: float = 0.0,
	level: int = 1,
	uid: int = 0
) -> Dictionary:
	if ContentDB == null:
		return {}
	return ContentDB.roll_loot_table(rng, table_id, luck, level, uid)


static func generate_random_for_slot(
	rng: RandomNumberGenerator,
	slot: StringName,
	rarity: int = -1,
	level: int = 1,
	uid: int = 0
) -> Dictionary:
	var lookup_slot := StatKeys.SLOT_PRIMARY if slot == StatKeys.SLOT_PRIMARY_2 else slot
	if lookup_slot == StatKeys.SLOT_PRIMARY or lookup_slot == StatKeys.SLOT_SIDEARM:
		var weapons: Array[WeaponData] = ContentDB.get_weapons_for_slot(lookup_slot)
		if weapons.is_empty():
			return {}
		return generate_weapon(rng, weapons[rng.randi_range(0, weapons.size() - 1)].id, rarity, level, uid)
	var candidates: Array[ItemTemplate] = []
	for template in ContentDB.item_templates.values():
		if template.slot == slot:
			candidates.append(template)
	if candidates.is_empty():
		return {}
	return generate_gear(rng, candidates[rng.randi_range(0, candidates.size() - 1)].id, rarity, level, uid)


static func _finish_item(item: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var rarity: int = clampi(int(item.rarity), 0, 4)
	var affix_count: int = AFFIX_COUNTS[rarity]
	var pool := ContentDB.get_affixes_for_slot(StringName(item.slot))
	var chosen: Array[String] = []
	var affixes: Array[Dictionary] = []
	for i in affix_count:
		if pool.is_empty():
			break
		var candidates: Array[Dictionary] = []
		for entry in pool:
			var id := String(entry.get("id", ""))
			if id not in chosen:
				candidates.append(entry)
		if candidates.is_empty():
			break
		var affix: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
		var id := String(affix.get("id", ""))
		chosen.append(id)
		var values: PackedFloat32Array = affix.get("values", PackedFloat32Array([0.0]))
		var base_val: float = values[clampi(rarity, 0, values.size() - 1)]
		var variance := rng.randf_range(0.92, 1.08) if rarity > 0 else 1.0
		affixes.append({"id": id, "value": base_val * variance})
	item["affixes"] = affixes
	return item


static func describe(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}
	var base_id := StringName(item.get("base_id", ""))
	var rarity := clampi(int(item.get("rarity", 0)), 0, 4)
	var kind := String(item.get("kind", "gear"))
	var info := {
		"uid": int(item.get("uid", 0)),
		"kind": kind,
		"base_id": String(base_id),
		"slot": String(item.get("slot", "")),
		"rarity": rarity,
		"rarity_name": ContentDB.get_rarity_name(rarity),
		"rarity_color": ContentDB.get_rarity_color(rarity),
		"level": int(item.get("level", 1)),
		"affixes": [],
		"stats": {},
		"armor": 0.0,
		"set_id": "",
		"value": 0,
		"description": "",
		"display_name": "",
		"weapon": null,
		"amount": int(item.get("amount", 1)),
	}
	var multiplier := ContentDB.get_rarity_mult(rarity)
	if kind == "loot":
		var loot := ContentDB.get_item(base_id)
		if loot != null:
			return _describe_loot(info, loot, item)
	if kind == "weapon":
		var weapon := ContentDB.get_weapon(base_id)
		if weapon == null:
			return info
		var level_scale := 1.0 + float(maxi(0, int(item.get("level", 1)) - 1)) * 0.035
		info.display_name = weapon.display_name
		info.description = weapon.description
		info.set_id = ""
		info.value = int(weapon.value * multiplier * level_scale)
		info.weapon = weapon
		info.stats = {
			"damage": weapon.damage * multiplier * level_scale,
			"dps": weapon.damage * multiplier * level_scale * weapon.pellets * weapon.fire_rate / 60.0,
			"magazine": weapon.mag_size,
			"reserve": weapon.reserve_ammo,
			"reload": weapon.reload_time / maxf(1.0, _item_reload_bonus(item, rarity)),
			"rpm": weapon.fire_rate,
			"crit_mult": weapon.crit_mult,
		}
	else:
		var template := ContentDB.get_item_template(base_id)
		if template == null:
			return info
		info.display_name = template.display_name
		info.description = template.description
		info.set_id = String(template.set_id)
		info.armor = template.armor * multiplier
		info.stats = template.base_stats.duplicate(true)
		info.value = int(template.value * multiplier)
		for affix in item.get("affixes", []):
			var affix_data := ContentDB.get_affix(StringName(affix.get("id", "")))
			if affix_data.is_empty():
				continue
			var stat := String(affix_data.get("stat", ""))
			var op := String(affix_data.get("op", "add"))
			var value := float(affix.get("value", 0.0))
			info.affixes.append({
				"id": String(affix.get("id", "")),
				"display_name": String(affix_data.get("display_name", "")),
				"stat": stat,
				"op": op,
				"value": value,
				"value_text": _format_affix(stat, op, value),
			})
			if stat == "armor" and op == "add":
				info.armor += value
			elif op == "mult":
				info.stats[stat] = float(info.stats.get(stat, 1.0)) * value
			else:
				info.stats[stat] = float(info.stats.get(stat, 0.0)) + value
		info.value += int((info.armor + _stat_total(info.stats)) * 2.0) * (rarity + 1)
	return info


## Fills a describe() payload for authored loot cargo (kind "loot"). Loot is never
## equipped and carries no affixes; the authored rarity is authoritative and the
## authored Common-tier value is scaled by the shared rarity curve and stack count.
static func _describe_loot(info: Dictionary, loot: LootItemData, item: Dictionary) -> Dictionary:
	var amount := maxi(1, int(item.get("amount", 1)))
	var tier := clampi(loot.rarity, 0, 4)
	info.kind = "loot"
	info.display_name = loot.display_name
	info.description = loot.description
	info.set_id = ""
	info.rarity = tier
	info.rarity_name = ContentDB.get_rarity_name(tier)
	info.rarity_color = ContentDB.get_rarity_color(tier)
	info.amount = amount
	info.icon = String(loot.icon)
	info.category = String(loot.category)
	info.tags = Array(loot.tags)
	info.effects = loot.effects.duplicate(true)
	info.stats = loot.effects.duplicate(true)
	info.armor = 0.0
	info.affixes = []
	info.value = int(round(float(loot.value) * ContentDB.get_rarity_mult(tier))) * amount
	return info


static func _item_reload_bonus(item: Dictionary, rarity: int) -> float:
	var mult := 1.0
	for affix in item.get("affixes", []):
		var data := ContentDB.get_affix(StringName(affix.get("id", "")))
		if String(data.get("stat", "")) == "reload_speed":
			mult *= float(affix.get("value", 1.0))
	return mult


static func _stat_total(stats: Dictionary) -> float:
	var total := 0.0
	for value in stats.values():
		if value is float or value is int:
			total += float(value)
	return total


static func _format_affix(stat: String, op: String, value: float) -> String:
	var label := stat.replace("_", " ").capitalize()
	if op == "mult":
		return "+%d%% %s" % [int(round((value - 1.0) * 100.0)), label]
	if value < 1.0 and value > 0.0:
		return "+%.1f%% %s" % [value * 100.0, label]
	return "+%s %s" % [str(value), label]


static func equipment_modifiers(item: Dictionary) -> Array[Dictionary]:
	var mods: Array[Dictionary] = []
	var info := describe(item)
	if info.is_empty() or info.kind != "gear":
		return mods
	var source := "equipment"
	if float(info.armor) > 0.0:
		mods.append({"id": "gear_armor", "source": source, "stat": StatKeys.ARMOR, "op": "add", "value": float(info.armor)})
	for affix in info.affixes:
		var stat_name := StringName(affix.stat)
		if stat_name == StatKeys.ARMOR:
			continue
		mods.append({
			"id": StringName("gear_" + String(affix.id)),
			"source": source,
			"stat": stat_name,
			"op": StringName(affix.op),
			"value": float(affix.value),
		})
	for stat in info.stats.keys():
		mods.append({
			"id": StringName("gear_" + String(stat)),
			"source": source,
			"stat": StringName(stat),
			"op": "add",
			"value": float(info.stats[stat]),
		})
	return mods


static func weapon_runtime_stats(item: Dictionary) -> Dictionary:
	var info := describe(item)
	if info.is_empty() or info.kind != "weapon":
		return {}
	var weapon: WeaponData = info.weapon
	var condition := float(info.stats.damage) / maxf(0.001, weapon.damage)
	var runtime := {
		"id": String(weapon.id),
		"display_name": weapon.display_name,
		"archetype": String(weapon.archetype),
		"slot": String(weapon.slot),
		"damage": float(info.stats.damage),
		"pellets": weapon.pellets,
		"fire_rate": weapon.fire_rate,
		"fire_mode": String(weapon.fire_mode),
		"burst_count": weapon.burst_count,
		"mag_size": weapon.mag_size,
		"reserve_ammo": weapon.reserve_ammo,
		"reload_time": float(info.stats.reload),
		"spread_hip": weapon.spread_hip,
		"spread_ads": weapon.spread_ads,
		"ads_zoom": weapon.ads_zoom,
		"recoil_pattern": weapon.recoil_pattern,
		"recoil_kick": weapon.recoil_kick,
		"effective_range": weapon.effective_range,
		"falloff_start": weapon.falloff_start,
		"range_mult": weapon.range_mult,
		"crit_mult": weapon.crit_mult,
		"projectile_speed": weapon.projectile_speed,
		"status_type": String(weapon.status_type),
		"status_chance": weapon.status_chance,
		"status_power": weapon.status_power * (1.0 + (condition - 1.0) * 0.2),
		"style": String(weapon.style),
		"color": weapon.color,
		"accent": weapon.accent,
		"unique_perk": weapon.unique_perk,
		"rarity": int(info.rarity),
		"rarity_color": info.rarity_color,
		"uid": int(info.uid),
	}
	return runtime


static func make_item(
	kind: String,
	base_id: StringName,
	slot: String,
	rarity: int,
	level: int,
	uid: int,
	affixes: Array = []
) -> Dictionary:
	return {
		"uid": uid,
		"kind": kind,
		"base_id": String(base_id),
		"slot": slot,
		"rarity": clampi(rarity, 0, 4),
		"level": maxi(1, level),
		"affixes": affixes.duplicate(true),
	}


static func item_value(item: Dictionary) -> int:
	return int(describe(item).get("value", 0))
