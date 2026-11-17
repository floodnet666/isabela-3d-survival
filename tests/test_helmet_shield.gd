extends SceneTree

func _assert(cond: bool, label: String) -> bool:
	if not cond:
		push_error("FAIL: " + label)
	return cond


func _init() -> void:
	var ok := true
	var db_script := load("res://scripts/game/balance_db.gd") as GDScript
	var db: RefCounted = db_script.new()
	ok = _assert(db.load_from_file(), "BalanceDB loads") and ok

	var ha: Dictionary = db.get_pickup("helmet_a")
	var hb: Dictionary = db.get_pickup("helmet_b")
	ok = _assert(absf(float(ha.get("shield_max_hp_percent", 0.0)) - 0.30) < 0.001, "helmet_a has 30% shield") and ok
	ok = _assert(absf(float(hb.get("shield_max_hp_percent", 0.0)) - 0.30) < 0.001, "helmet_b has 30% shield") and ok

	var player_script := load("res://scripts/game/player_controller.gd") as GDScript
	var player := CharacterBody3D.new()
	player.set_script(player_script)
	var vr := Node3D.new()
	vr.name = "VisualRoot"
	player.add_child(vr)
	get_root().add_child(player)
	await process_frame

	var upg: RefCounted = (load("res://scripts/game/upgrade_system.gd") as GDScript).new(db)
	var loadout: RefCounted = (load("res://scripts/game/weapon_loadout.gd") as GDScript).new(db, upg)
	player.configure(db, upg, loadout)
	player.shield_hp = 0.0
	player.max_shield_hp = 0.0

	player.apply_pickup("helmet_a", ha)
	var expected_shield: float = float(player.max_hp) * 0.30
	ok = _assert(absf(float(player.shield_hp) - expected_shield) < 0.05, "helmet_a grants 30% max_hp shield") and ok
	ok = _assert(player.find_child("EquippedHelmetAttachment", true, false) != null, "helmet_a attached visually") and ok

	var hp_before: float = float(player.current_hp)
	player.take_damage(20.0)
	ok = _assert(absf(float(player.current_hp) - hp_before) < 0.01, "Shield absorbs 20 dmg without hurting HP") and ok
	ok = _assert(absf(float(player.shield_hp) - (expected_shield - 20.0)) < 0.05, "Shield reduced by 20") and ok

	player.set("_iframes_left", 0.0)
	var overflow := (expected_shield - 20.0) + 10.0
	player.take_damage(overflow)
	ok = _assert(absf(float(player.shield_hp)) < 0.01, "Shield breaks to 0") and ok
	ok = _assert(absf(float(player.current_hp) - (hp_before - 10.0)) < 0.05, "Leftover 10 dmg hits HP") and ok
	await process_frame
	ok = _assert(player.find_child("EquippedHelmetAttachment", true, false) == null, "Broken helmet removed visually") and ok

	player.apply_pickup("helmet_b", hb)
	ok = _assert(absf(float(player.shield_hp) - expected_shield) < 0.05, "Picking up helmet_b restores 30% shield") and ok
	ok = _assert(player.find_child("EquippedHelmetAttachment", true, false) != null, "helmet_b attached visually") and ok

	player.queue_free()
	print("ALL_TESTS_PASSED: test_helmet_shield" if ok else "TEST_FAILED: test_helmet_shield")
	quit(0 if ok else 1)
