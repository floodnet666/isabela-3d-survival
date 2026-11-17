class_name BalanceDB
extends RefCounted
## Single-source-of-truth balance configuration loader and wave/XP math evaluator.

var _data: Dictionary = {}
var _weapons_by_slot: Dictionary = {}
var _weapons_by_id: Dictionary = {}
var _pickups_by_id: Dictionary = {}
var _upgrades_by_id: Dictionary = {}
var _is_loaded: bool = false


func load_from_file(path: String = "res://data/game_balance.json") -> bool:
	if not FileAccess.file_exists(path):
		push_error("BalanceDB: balance file not found at '%s'" % path)
		return false
	var raw_text := FileAccess.get_file_as_string(path)
	if raw_text.is_empty():
		push_error("BalanceDB: balance file is empty at '%s'" % path)
		return false
	var parsed: Variant = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		push_error("BalanceDB: invalid JSON root in '%s'" % path)
		return false

	_data = parsed as Dictionary
	_weapons_by_slot.clear()
	_weapons_by_id.clear()
	_pickups_by_id.clear()
	_upgrades_by_id.clear()

	for w in _data.get("weapons", []):
		if w is Dictionary:
			var wd := w as Dictionary
			_weapons_by_slot[int(wd.get("slot", 0))] = wd
			_weapons_by_id[str(wd.get("id", ""))] = wd

	for p in _data.get("pickups", []):
		if p is Dictionary:
			var pd := p as Dictionary
			_pickups_by_id[str(pd.get("id", ""))] = pd

	var prog: Dictionary = _data.get("progression", {})
	for u in prog.get("upgrades", []):
		if u is Dictionary:
			var ud := u as Dictionary
			_upgrades_by_id[str(ud.get("id", ""))] = ud

	_is_loaded = _weapons_by_slot.size() >= 6 and _pickups_by_id.size() >= 2
	if not _is_loaded:
		push_error("BalanceDB: incomplete balance config (weapons=%d, pickups=%d)" % [_weapons_by_slot.size(), _pickups_by_id.size()])
	return _is_loaded


func is_loaded() -> bool:
	return _is_loaded


func get_arena_cfg() -> Dictionary:
	return _data.get("arena", {})


func get_waves_cfg() -> Dictionary:
	return _data.get("waves", {})


func get_player_cfg() -> Dictionary:
	return _data.get("player", {})


func get_all_weapons() -> Array:
	return _data.get("weapons", [])


func get_weapon_by_slot(slot: int) -> Dictionary:
	return _weapons_by_slot.get(slot, {})


func get_weapon_by_id(id: String) -> Dictionary:
	return _weapons_by_id.get(id, {})


func get_pickup(id: String) -> Dictionary:
	return _pickups_by_id.get(id, {})


func get_enemy_cfg(id: String) -> Dictionary:
	var enemies: Dictionary = _data.get("enemies", {})
	return enemies.get(id, {})


func get_bosses_cfg() -> Dictionary:
	return _data.get("bosses", {})


func get_drop_pod_cfg() -> Dictionary:
	return get_bosses_cfg().get("drop_pod", {})


func get_boss_id_for_wave(wave: int) -> String:
	var bosses := get_bosses_cfg()
	var interval := maxi(1, int(bosses.get("wave_interval", 5)))
	if wave <= 0 or wave % interval != 0:
		return ""
	var order: Array = bosses.get("rotation_order", ["valkyrie_skull", "white_reaper", "anubis_phantom"])
	if order.is_empty():
		return ""
	var tier := maxi(1, int(wave / interval))
	return str(order[(tier - 1) % order.size()])


func get_boss_cfg(boss_id: String, tier: int = 1) -> Dictionary:
	var types: Dictionary = get_bosses_cfg().get("types", {})
	var base: Dictionary = (types.get(boss_id, {}) as Dictionary).duplicate(true)
	if base.is_empty():
		return {}
	var t := maxi(1, tier)
	base["tier"] = t
	base["resolved_hp"] = float(base.get("base_hp", 950.0)) + float(base.get("hp_per_tier", 450.0)) * float(t - 1)
	base["resolved_xp"] = int(base.get("xp_base", 450)) + (t - 1) * 150
	base["resolved_score"] = int(base.get("score_value", 2500)) + (t - 1) * 1000
	return base


func get_character_archetypes() -> Dictionary:
	return _data.get("character_archetypes", {})


func get_archetype_cfg(skin_id: String) -> Dictionary:
	var all_arch := get_character_archetypes()
	if all_arch.has(skin_id):
		return all_arch[skin_id] as Dictionary
	return all_arch.get("leeloo", {}) as Dictionary


func get_progression_cfg() -> Dictionary:
	return _data.get("progression", {})


func get_upgrade_def(id: String) -> Dictionary:
	return _upgrades_by_id.get(id, {})


func get_xp_for_next_level(level: int) -> int:
	var prog := get_progression_cfg()
	var base_xp := float(prog.get("xp_level_1_to_2", 80.0))
	var growth := float(prog.get("xp_growth_exponent", 1.28))
	return maxi(10, roundi(base_xp * pow(growth, maxf(0.0, float(level - 1)))))


func get_wave_spec(wave: int) -> Dictionary:
	var w := maxi(1, wave)
	var cfg: Dictionary = _data.get("waves", {})
	var base_n := int(cfg.get("base_enemy_count", 6))
	var per_wave := float(cfg.get("enemy_count_per_wave", 3.5))
	var total := base_n + int(floor(per_wave * float(w - 1)))

	var tall_intro := int(cfg.get("tall_intro_wave", 2))
	var tall_count := 0
	if w >= tall_intro:
		var ratio := minf(
			float(cfg.get("tall_ratio_cap", 0.45)),
			float(cfg.get("tall_ratio_wave_2", 0.18)) + float(cfg.get("tall_ratio_increment_per_wave", 0.04)) * float(w - tall_intro)
		)
		tall_count = maxi(1, roundi(float(total) * ratio))

	var mech_counts := {}
	var mech_total := 0
	for tier_var in cfg.get("mech_tiers", []):
		var t: Dictionary = tier_var as Dictionary
		var mid := str(t.get("id", ""))
		var intro := int(t.get("intro_wave", 999))
		if mid.is_empty() or w < intro:
			continue
		var m_ratio := minf(float(t.get("cap", 0.2)), float(t.get("base_ratio", 0.12)) + float(t.get("increment_per_wave", 0.02)) * float(w - intro))
		var cnt := maxi(1, roundi(float(total) * m_ratio))
		mech_counts[mid] = cnt
		mech_total += cnt

	var small_count := maxi(0, total - tall_count - mech_total)
	var quad_after := int(cfg.get("hp_quadratic_after_wave", 5))
	var quad_coeff := float(cfg.get("hp_quadratic_coeff", 0.02))
	var hp_mult := 1.0 + float(cfg.get("hp_scale_per_wave", 0.18)) * float(w - 1) + quad_coeff * pow(maxf(0.0, float(w - quad_after)), 2.0)
	var dmg_mult := 1.0 + float(cfg.get("damage_scale_per_wave", 0.10)) * float(w - 1)
	var spawn_interval := maxf(
		float(cfg.get("spawn_interval_min_s", 0.35)),
		float(cfg.get("spawn_interval_base_s", 1.35)) - float(cfg.get("spawn_interval_decay_per_wave_s", 0.10)) * float(w - 1)
	)
	var max_concurrent := mini(int(get_arena_cfg().get("max_concurrent_enemies_cap", 20)), 8 + w * 2)
	var clear_xp := int(cfg.get("wave_clear_xp_bonus_base", 25)) + int(cfg.get("wave_clear_xp_bonus_per_wave", 10)) * (w - 1)
	var boss_id := get_boss_id_for_wave(w)
	var is_boss := not boss_id.is_empty()
	if is_boss and small_count > 0:
		small_count -= 1

	return {
		"wave": w,
		"is_boss_wave": is_boss,
		"boss_id": boss_id,
		"boss_tier": maxi(1, int(w / maxi(1, int(get_bosses_cfg().get("wave_interval", 5))))) if is_boss else 0,
		"total_enemies": total,
		"small_count": small_count,
		"tall_count": tall_count,
		"mech_counts": mech_counts,
		"spider_count": 0,
		"sawbox_count": 0,
		"hp_multiplier": hp_mult,
		"damage_multiplier": dmg_mult,
		"spawn_interval_s": spawn_interval,
		"max_concurrent": max_concurrent,
		"clear_xp_bonus": clear_xp,
		"inter_wave_countdown_s": float(cfg.get("inter_wave_countdown_s", 2.5)),
	}
