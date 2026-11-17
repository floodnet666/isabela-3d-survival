class_name WeaponLoadout
extends RefCounted
## Manages runtime state for all 6 weapon slots: ammo, reloads, battery overheat, cooldowns, combos.

const BalanceDBRef := preload("res://scripts/game/balance_db.gd")
const UpgradeSystemRef := preload("res://scripts/game/upgrade_system.gd")

var _db: BalanceDBRef
var _upgrades: UpgradeSystemRef
var _slots: Dictionary = {}
var _selected_slot: int = 1
var _rng := RandomNumberGenerator.new()
var _archetype: Dictionary = {}


func _init(balance_db: BalanceDBRef = null, upgrade_sys: UpgradeSystemRef = null) -> void:
	_rng.randomize()
	if balance_db != null:
		setup(balance_db, upgrade_sys)


func setup(balance_db: BalanceDBRef, upgrade_sys: UpgradeSystemRef) -> void:
	_db = balance_db
	_upgrades = upgrade_sys
	_slots.clear()
	for w in _db.get_all_weapons():
		if not (w is Dictionary):
			continue
		var wd := w as Dictionary
		var slot := int(wd.get("slot", 0))
		_slots[slot] = {
			"def": wd,
			"mag": int(wd.get("mag_size", 0)),
			"reserve": int(wd.get("reserve_start", 0)),
			"battery": float(wd.get("battery_max", 100.0)),
			"cooldown_left": 0.0,
			"reload_left": 0.0,
			"reload_total": 0.0,
			"is_reloading": false,
			"is_overheated": false,
			"overheat_left": 0.0,
			"is_manual_venting": false,
			"regen_delay_left": 0.0,
			"combo_step": 0,
			"combo_reset_left": 0.0,
		}


func set_archetype(arch: Dictionary) -> void:
	_archetype = arch
	for s in _slots.keys():
		var st: Dictionary = _slots[s]; var def: Dictionary = st["def"]
		st["mag"] = _effective_mag_size(def)
		st["reserve"] = mini(_effective_reserve_max(def), roundi(float(def.get("reserve_start", 0)) * _arch_f("ammo_capacity_mult", 1.0)))
		st["battery"] = _effective_battery_max(def)
func _arch_f(key: String, def_v: float) -> float: return float(_archetype.get(key, def_v))
func get_selected_slot() -> int: return _selected_slot
func get_selected_def() -> Dictionary: return (_slots.get(_selected_slot, {}) as Dictionary).get("def", {})


func select_slot(slot: int) -> bool:
	if not _slots.has(slot) or slot == _selected_slot:
		return false
	var prev: Dictionary = _slots[_selected_slot]
	prev["is_reloading"] = false
	prev["reload_left"] = 0.0
	prev["is_manual_venting"] = false
	_selected_slot = slot
	return true


func cycle_slot(delta_step: int) -> bool:
	var next := wrapi(_selected_slot - 1 + delta_step, 0, maxi(1, _slots.size())) + 1
	return select_slot(next)


func tick(delta: float, is_trigger_held: bool) -> void:
	for s in _slots.keys():
		var st: Dictionary = _slots[s]
		st["cooldown_left"] = maxf(0.0, float(st["cooldown_left"]) - delta)
		if float(st["combo_reset_left"]) > 0.0:
			st["combo_reset_left"] = maxf(0.0, float(st["combo_reset_left"]) - delta)
			if float(st["combo_reset_left"]) <= 0.0:
				st["combo_step"] = 0

		var def: Dictionary = st["def"]
		var ammo_type := str(def.get("ammo_type", "unlimited"))
		if ammo_type == "magazine" and bool(st["is_reloading"]):
			st["reload_left"] = maxf(0.0, float(st["reload_left"]) - delta)
			if float(st["reload_left"]) <= 0.0:
				_finish_reload(st)
		elif ammo_type == "battery":
			_tick_battery(st, delta, is_trigger_held and int(s) == _selected_slot)


func try_fire(is_aiming: bool = false) -> Dictionary:
	if not _slots.has(_selected_slot):
		return {"fired": false}
	var st: Dictionary = _slots[_selected_slot]
	var def: Dictionary = st["def"]
	if float(st["cooldown_left"]) > 0.0:
		return {"fired": false, "reason": "cooldown"}

	var ammo_type := str(def.get("ammo_type", "unlimited"))
	if ammo_type == "magazine":
		if bool(st["is_reloading"]):
			return {"fired": false, "reason": "reloading"}
		if int(st["mag"]) <= 0:
			start_reload_or_vent()
			return {"fired": false, "reason": "empty_mag"}
		st["mag"] = int(st["mag"]) - 1
	elif ammo_type == "battery":
		if bool(st["is_overheated"]):
			return {"fired": false, "reason": "overheated"}
		var cost := float(def.get("energy_cost_per_shot", 4.5))
		var cur := float(st["battery"])
		if cur < cost:
			st["battery"] = 0.0
			st["is_overheated"] = true
			st["overheat_left"] = float(def.get("overheat_lockout_s", 1.80))
			return {"fired": false, "reason": "overheated"}
		st["battery"] = cur - cost
		st["is_manual_venting"] = false
		st["regen_delay_left"] = float(def.get("regen_delay_s", 0.55))
		if float(st["battery"]) <= 0.001:
			st["battery"] = 0.0
			st["is_overheated"] = true
			st["overheat_left"] = float(def.get("overheat_lockout_s", 1.80))

	var rate_mult := _stat("fire_rate_multiplier", 1.0)
	st["cooldown_left"] = 1.0 / maxf(0.1, float(def.get("fire_rate_hz", 1.0)) * rate_mult)

	var combo_step := 1
	var combo_mult := 1.0
	var combo_arr: Array = def.get("combo_step_multipliers", [])
	if not combo_arr.is_empty():
		var idx := int(st["combo_step"]) % combo_arr.size()
		combo_mult = float(combo_arr[idx])
		combo_step = idx + 1
		st["combo_step"] = (idx + 1) % combo_arr.size()
		st["combo_reset_left"] = 1.15

	var dmg_mult := _stat("damage_multiplier", 1.0) * _arch_f("damage_mult", 1.0)
	var base_dmg := float(def.get("damage", 10.0)) * combo_mult * dmg_mult
	var crit_chance := clampf(float(def.get("crit_chance", 0.05)) + _stat("crit_chance_bonus", 0.0) + _arch_f("crit_chance_bonus", 0.0), 0.0, 0.95)
	var is_crit := _rng.randf() < crit_chance
	var crit_mult := float(def.get("crit_multiplier", 1.5)) * _arch_f("crit_damage_mult", 1.0)
	var melee_mult := _stat("melee_range_multiplier", 1.0) if str(def.get("category", "")) == "melee" else 1.0
	var blast_mult := _stat("blast_radius_multiplier", 1.0)
	var pierce_bonus := int(round(_stat("laser_pierce_bonus", 0.0)))

	if ammo_type == "magazine" and int(st["mag"]) == 0 and int(st["reserve"]) > 0:
		start_reload_or_vent()

	return {
		"fired": true,
		"slot": _selected_slot,
		"id": str(def.get("id", "")),
		"delivery": str(def.get("delivery", "hitscan")),
		"base_damage": base_dmg,
		"final_damage": base_dmg * (crit_mult if is_crit else 1.0),
		"is_crit": is_crit,
		"crit_multiplier": crit_mult,
		"headshot_multiplier": float(def.get("headshot_multiplier", 1.0)),
		"tall_armor_pierce_multiplier": float(def.get("tall_droid_armor_pierce_multiplier", 1.0)),
		"combo_step": combo_step,
		"pellets": int(def.get("pellets", 1)),
		"pierce_count": int(def.get("pierce_count", 0)) + (pierce_bonus if str(def.get("delivery", "")) == "hitscan_pierce" else 0),
		"spread_deg": float(def.get("spread_aim_deg", 0.0) if is_aiming else def.get("spread_hip_deg", 0.0)),
		"range_m": float(def.get("range_m", 30.0)) * melee_mult,
		"melee_arc_deg": float(def.get("melee_arc_deg", 90.0)),
		"max_targets_per_swing": int(def.get("max_targets_per_swing", 4)),
		"swing_lunge_distance_m": float(def.get("swing_lunge_distance_m", 0.0)),
		"active_swing_window_s": float(def.get("active_swing_window_s", 0.15)),
		"deflects_enemy_projectiles": bool(def.get("deflects_enemy_projectiles", false)),
		"deflect_damage_multiplier": float(def.get("deflect_damage_multiplier", 1.5)),
		"knockback_mps": float(def.get("knockback_mps", 2.0)),
		"splash_damage": float(def.get("splash_damage", 0.0)) * dmg_mult,
		"splash_radius_m": float(def.get("splash_radius_m", 0.0)) * blast_mult,
		"splash_edge_falloff_multiplier": float(def.get("splash_edge_falloff_multiplier", 0.4)),
		"self_damage_multiplier": float(def.get("self_damage_multiplier", 0.15)),
		"projectile_speed_mps": float(def.get("projectile_speed_mps", 25.0)),
		"falloff_start_m": float(def.get("falloff_start_m", 999.0)),
		"falloff_min_multiplier": float(def.get("falloff_min_multiplier", 1.0)),
	}


func start_reload_or_vent() -> bool:
	if not _slots.has(_selected_slot):
		return false
	var st: Dictionary = _slots[_selected_slot]
	var def: Dictionary = st["def"]
	var ammo_type := str(def.get("ammo_type", "unlimited"))
	if ammo_type == "magazine":
		var max_mag := _effective_mag_size(def)
		if bool(st["is_reloading"]) or int(st["mag"]) >= max_mag or int(st["reserve"]) <= 0:
			return false
		var reload_s := (float(def.get("reload_time_s", 1.2)) * _arch_f("reload_time_mult", 1.0)) / maxf(0.25, _stat("reload_speed_multiplier", 1.0))
		st["is_reloading"] = true
		st["reload_total"] = reload_s
		st["reload_left"] = reload_s
		return true
	elif ammo_type == "battery":
		if float(st["battery"]) < _effective_battery_max(def):
			st["is_manual_venting"] = true
			st["regen_delay_left"] = 0.0
			return true
	return false


func refill_ammo_percent(reserve_pct: float, laser_restore_pct: float) -> void:
	for s in _slots.keys():
		var st: Dictionary = _slots[s]
		var def: Dictionary = st["def"]
		var ammo_type := str(def.get("ammo_type", "unlimited"))
		if ammo_type == "magazine":
			var max_res := _effective_reserve_max(def)
			var gain := maxi(1, roundi(float(max_res) * reserve_pct))
			st["reserve"] = mini(max_res, int(st["reserve"]) + gain)
		elif ammo_type == "battery":
			var max_bat := _effective_battery_max(def)
			st["battery"] = minf(max_bat, float(st["battery"]) + max_bat * laser_restore_pct)
			st["is_overheated"] = false
			st["overheat_left"] = 0.0


func get_slot_hud_state(slot: int) -> Dictionary:
	var st: Dictionary = _slots.get(slot, {})
	if st.is_empty():
		return {}
	var def: Dictionary = st["def"]
	var reload_total := maxf(0.001, float(st["reload_total"]))
	return {
		"slot": slot,
		"id": str(def.get("id", "")),
		"display_name": str(def.get("display_name", "")),
		"ammo_type": str(def.get("ammo_type", "unlimited")),
		"mag": int(st["mag"]),
		"mag_max": _effective_mag_size(def),
		"reserve": int(st["reserve"]),
		"reserve_max": _effective_reserve_max(def),
		"battery": float(st["battery"]),
		"battery_max": _effective_battery_max(def),
		"is_reloading": bool(st["is_reloading"]),
		"reload_progress": 1.0 - clampf(float(st["reload_left"]) / reload_total, 0.0, 1.0),
		"is_overheated": bool(st["is_overheated"]),
		"is_selected": slot == _selected_slot,
	}


func _tick_battery(st: Dictionary, delta: float, is_actively_firing: bool) -> void:
	var def: Dictionary = st["def"]
	var max_bat := _effective_battery_max(def)
	var cool_mult := _stat("reload_speed_multiplier", 1.0)
	if bool(st["is_overheated"]):
		st["overheat_left"] = maxf(0.0, float(st["overheat_left"]) - delta * cool_mult)
		var lock_t := maxf(0.01, float(def.get("overheat_lockout_s", 1.8)))
		st["battery"] = max_bat * (1.0 - float(st["overheat_left"]) / lock_t)
		if float(st["overheat_left"]) <= 0.0:
			st["is_overheated"] = false
			st["battery"] = max_bat
		return
	if is_actively_firing:
		return
	if float(st["regen_delay_left"]) > 0.0 and not bool(st["is_manual_venting"]):
		st["regen_delay_left"] = maxf(0.0, float(st["regen_delay_left"]) - delta)
		return
	var rate := float(def.get("manual_vent_regen_per_sec", 45.0) if bool(st["is_manual_venting"]) else def.get("energy_regen_per_sec", 22.0))
	st["battery"] = minf(max_bat, float(st["battery"]) + rate * cool_mult * delta)
	if float(st["battery"]) >= max_bat:
		st["is_manual_venting"] = false


func _finish_reload(st: Dictionary) -> void:
	var def: Dictionary = st["def"]
	var max_mag := _effective_mag_size(def)
	var needed := maxi(0, max_mag - int(st["mag"]))
	var take := mini(needed, int(st["reserve"]))
	st["mag"] = int(st["mag"]) + take
	st["reserve"] = int(st["reserve"]) - take
	st["is_reloading"] = false
	st["reload_left"] = 0.0


func _effective_mag_size(def: Dictionary) -> int:
	return maxi(1, roundi(float(def.get("mag_size", 1)) * _stat("ammo_capacity_multiplier", 1.0) * _arch_f("ammo_capacity_mult", 1.0)))
func _effective_reserve_max(def: Dictionary) -> int:
	return maxi(0, roundi(float(def.get("reserve_max", 0)) * _stat("ammo_capacity_multiplier", 1.0) * _arch_f("ammo_capacity_mult", 1.0)))
func _effective_battery_max(def: Dictionary) -> float:
	return float(def.get("battery_max", 100.0)) * _stat("ammo_capacity_multiplier", 1.0) * _arch_f("ammo_capacity_mult", 1.0)
func _stat(key: String, fallback: float) -> float:
	return _upgrades.get_stat(key) if _upgrades != null else fallback
