extends SceneTree

func _assert(cond: bool, label: String) -> bool:
	if not cond:
		push_error("FAIL: " + label)
	return cond


func _init() -> void:
	var ok := true
	var db: RefCounted = (load("res://scripts/game/balance_db.gd") as GDScript).new()
	ok = _assert(db.load_from_file(), "BalanceDB loads") and ok

	var upg: RefCounted = (load("res://scripts/game/upgrade_system.gd") as GDScript).new(db)
	var loadout: RefCounted = (load("res://scripts/game/weapon_loadout.gd") as GDScript).new(db, upg)
	ok = _assert(loadout.select_slot(6), "Select laser_gun slot 6") and ok

	var base_shot: Dictionary = loadout.try_fire(false)
	ok = _assert(bool(base_shot.get("fired", false)) and str(base_shot.get("id", "")) == "laser_gun", "Base laser fires") and ok
	var base_dmg := float(base_shot.get("base_damage", 0.0))
	var base_pierce := int(base_shot.get("pierce_count", 0))
	var base_bat_max := float(loadout.get_slot_hud_state(6).get("battery_max", 0.0))

	upg.apply_upgrade({"id": "weapon_damage", "rarity": "rare", "multiplier": 1.5, "resolved_value": 0.225})
	upg.apply_upgrade({"id": "ammo_capacity", "rarity": "common", "multiplier": 1.0, "resolved_value": 0.25})
	upg.apply_upgrade({"id": "blast_pierce", "rarity": "epic", "multiplier": 2.1, "resolved_value": 0.42})
	upg.apply_upgrade({"id": "reload_speed", "rarity": "legendary", "multiplier": 3.0, "resolved_value": 0.54})
	upg.apply_upgrade({"id": "fire_rate", "rarity": "common", "multiplier": 1.0, "resolved_value": 0.12})

	loadout.tick(0.2, false)
	var boosted_shot: Dictionary = loadout.try_fire(false)
	ok = _assert(bool(boosted_shot.get("fired", false)), "Boosted laser fires") and ok
	ok = _assert(float(boosted_shot.get("base_damage", 0.0)) > base_dmg * 1.2, "weapon_damage boosts laser damage") and ok
	ok = _assert(int(boosted_shot.get("pierce_count", 0)) == base_pierce + 2, "blast_pierce epic adds +2 laser pierce") and ok
	ok = _assert(float(loadout.get_slot_hud_state(6).get("battery_max", 0.0)) > base_bat_max * 1.2, "ammo_capacity boosts laser battery_max") and ok

	# Verify reload_speed accelerates regen_delay_left (0.55s -> cleared by 0.38s at 1.54x cool_mult)
	var st_before: float = float(loadout.get_slot_hud_state(6).get("battery", 0.0))
	loadout.tick(0.38, false)
	loadout.tick(0.10, false)
	var st_after: float = float(loadout.get_slot_hud_state(6).get("battery", 0.0))
	ok = _assert(st_after > st_before, "reload_speed accelerates laser regen_delay and cooling") and ok

	print("ALL_TESTS_PASSED: test_laser_boosters" if ok else "TEST_FAILED: test_laser_boosters")
	quit(0 if ok else 1)
