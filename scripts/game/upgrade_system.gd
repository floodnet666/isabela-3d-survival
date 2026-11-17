class_name UpgradeSystem
extends RefCounted
## Manages stackable player combat upgrades, rarity weighting, and 3-card drafts.

const BalanceDBRef := preload("res://scripts/game/balance_db.gd")

const DEFAULT_STATS: Dictionary = {
	"damage_multiplier": 1.0,
	"max_hp_bonus": 0.0,
	"reload_speed_multiplier": 1.0,
	"fire_rate_multiplier": 1.0,
	"move_speed_multiplier": 1.0,
	"ammo_capacity_multiplier": 1.0,
	"blast_radius_multiplier": 1.0,
	"laser_pierce_bonus": 0.0,
	"melee_range_multiplier": 1.0,
	"crit_chance_bonus": 0.0,
	"heal_on_kill": 0.0,
	"dash_cooldown_reduction": 0.0,
	"dash_extra_charges": 0.0,
}

var _db: BalanceDBRef
var _stacks: Dictionary = {}
var _stats: Dictionary = DEFAULT_STATS.duplicate()


func _init(balance_db: BalanceDBRef = null) -> void:
	_db = balance_db
	reset()


func reset() -> void:
	_stacks.clear()
	_stats = DEFAULT_STATS.duplicate()


func set_balance_db(balance_db: BalanceDBRef) -> void:
	_db = balance_db


func get_stat(key: String) -> float:
	return float(_stats.get(key, 0.0))


func get_stacks(upgrade_id: String) -> int:
	return int(_stacks.get(upgrade_id, 0))


func get_all_stacks() -> Dictionary:
	return _stacks.duplicate()


func get_effective_dash_cooldown(base_cd: float, min_cd: float) -> float:
	var red := clampf(get_stat("dash_cooldown_reduction"), 0.0, 0.85)
	return maxf(min_cd, base_cd * (1.0 - red))


func roll_choices(wave: int, rng: RandomNumberGenerator = null, min_rarity: String = "") -> Array[Dictionary]:
	if _db == null or not _db.is_loaded():
		push_error("UpgradeSystem: BalanceDB not loaded")
		return []
	var generator := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		generator.randomize()

	var prog := _db.get_progression_cfg()
	var desired := int(prog.get("upgrade_choices_per_modal", 3))
	var pool: Array[Dictionary] = []
	for u in prog.get("upgrades", []):
		if u is Dictionary:
			var ud := u as Dictionary
			var uid := str(ud.get("id", ""))
			if get_stacks(uid) < int(ud.get("max_stacks", 99)):
				pool.append(ud)

	# Shuffle pool with Fisher-Yates using provided RNG for deterministic tests
	for i in range(pool.size() - 1, 0, -1):
		var j := generator.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp

	var result: Array[Dictionary] = []
	var count := mini(desired, pool.size())
	for idx in range(count):
		var def := pool[idx]
		var rarity := _find_rarity(min_rarity) if (not min_rarity.is_empty() and idx == 0) else _roll_rarity(wave, generator)
		if min_rarity == "legendary":
			rarity = _find_rarity("legendary")
		result.append(_build_card(def, rarity))
	return result


func _find_rarity(rarity_id: String) -> Dictionary:
	for r in _db.get_progression_cfg().get("rarities", []):
		if r is Dictionary and str((r as Dictionary).get("id", "")) == rarity_id:
			return r as Dictionary
	return {"id": "legendary", "label": "Lendário", "color_hex": "#FBBF24", "multiplier": 3.0}


func apply_upgrade(card: Dictionary) -> Dictionary:
	var uid := str(card.get("id", ""))
	var def := _db.get_upgrade_def(uid)
	if def.is_empty():
		push_error("UpgradeSystem: unknown upgrade id '%s'" % uid)
		return {}

	var cur_stacks := get_stacks(uid)
	if cur_stacks >= int(def.get("max_stacks", 99)):
		return {"applied": false, "heal_amount": 0.0}

	_stacks[uid] = cur_stacks + 1
	var mult := float(card.get("multiplier", 1.0))
	var mode := str(def.get("mode", "add"))
	var stat_key := str(def.get("stat_key", ""))
	var base_val := float(def.get("base_value", 0.0))
	var val := float(card.get("resolved_value", base_val * mult))
	var heal_amount := 0.0

	match mode:
		"add":
			_stats[stat_key] = get_stat(stat_key) + val
		"add_and_heal":
			_stats[stat_key] = get_stat(stat_key) + val
			heal_amount = val
		"blast_and_pierce":
			_stats[stat_key] = get_stat(stat_key) + val
			var sec_key := str(def.get("secondary_stat_key", ""))
			var pierce_gain := int(def.get("base_pierce", 1)) * (2 if str(card.get("rarity", "")) in ["epic", "legendary"] else 1)
			_stats[sec_key] = get_stat(sec_key) + float(pierce_gain)
		"melee_and_crit":
			_stats[stat_key] = get_stat(stat_key) + val
			var crit_key := str(def.get("secondary_stat_key", ""))
			_stats[crit_key] = get_stat(crit_key) + float(def.get("base_crit", 0.08)) * mult
		"dash_upgrade":
			var cur_red := get_stat(stat_key)
			_stats[stat_key] = 1.0 - (1.0 - cur_red) * (1.0 - clampf(val, 0.0, 0.75))
			if str(card.get("rarity", "")) in ["epic", "legendary"]:
				var chg_key := str(def.get("secondary_stat_key", ""))
				_stats[chg_key] = get_stat(chg_key) + 1.0
		_:
			push_error("UpgradeSystem: unsupported upgrade mode '%s'" % mode)

	return {
		"applied": true,
		"id": uid,
		"stacks": _stacks[uid],
		"heal_amount": heal_amount,
		"ammo_refill_ratio": 0.25 if uid == "ammo_capacity" else 0.0,
	}


func _roll_rarity(wave: int, rng: RandomNumberGenerator) -> Dictionary:
	var rarities: Array = _db.get_progression_cfg().get("rarities", [])
	var weighted: Array[Dictionary] = []
	var total_weight := 0.0
	for r in rarities:
		if not (r is Dictionary):
			continue
		var rd := r as Dictionary
		var w := float(rd.get("weight", 1.0))
		var pity := float(rd.get("wave_pity_weight_per_wave_after_3", 0.0))
		if pity > 0.0 and wave > 3:
			w += pity * float(wave - 3)
		total_weight += w
		weighted.append({"def": rd, "weight": w})

	var pick := rng.randf_range(0.0, maxf(0.001, total_weight))
	var accum := 0.0
	for entry in weighted:
		accum += float(entry["weight"])
		if pick <= accum:
			return entry["def"] as Dictionary
	return rarities[0] if not rarities.is_empty() else {"id": "common", "label": "Comum", "color_hex": "#CBD5E1", "multiplier": 1.0}


func _build_card(def: Dictionary, rarity: Dictionary) -> Dictionary:
	var mult := float(rarity.get("multiplier", 1.0))
	var base_val := float(def.get("base_value", 0.0))
	var resolved := base_val * mult
	var rid := str(rarity.get("id", "common"))
	var desc := str(def.get("description", ""))
	desc = desc.replace("{pct}", str(roundi(resolved * 100.0)))
	desc = desc.replace("{val}", str(roundi(resolved)))
	var pierce_gain := int(def.get("base_pierce", 1)) * (2 if rid in ["epic", "legendary"] else 1)
	desc = desc.replace("{pierce}", str(pierce_gain))
	var crit_val := float(def.get("base_crit", 0.08)) * mult
	desc = desc.replace("{crit_pct}", str(roundi(crit_val * 100.0)))

	return {
		"id": str(def.get("id", "")),
		"title": str(def.get("title", "")),
		"description": desc,
		"rarity": rid,
		"rarity_label": str(rarity.get("label", "Comum")),
		"color_hex": str(rarity.get("color_hex", "#CBD5E1")),
		"multiplier": mult,
		"resolved_value": resolved,
		"next_stack": get_stacks(str(def.get("id", ""))) + 1,
		"max_stacks": int(def.get("max_stacks", 99)),
	}
