extends SceneTree
## Headless verification suite for Trilha 3: Rotating Bosses, OrbitalDropPods, Skins/Archetypes, HUDRadar & HUDBossBar.

const BalanceDBRef := preload("res://scripts/game/balance_db.gd")
const UpgradeSystemRef := preload("res://scripts/game/upgrade_system.gd")
const WeaponLoadoutRef := preload("res://scripts/game/weapon_loadout.gd")
const SettingsManagerRef := preload("res://scripts/game/settings_manager.gd")
const BossSentinelScene := preload("res://scenes/game/boss_sentinel.tscn")
const OrbitalDropPodRef := preload("res://scripts/game/orbital_drop_pod.gd")
const HUDRadarRef := preload("res://scripts/game/hud_radar.gd")
const HUDBossBarRef := preload("res://scripts/game/hud_boss_bar.gd")
const PlayerSkinHelperRef := preload("res://scripts/game/player_skin_helper.gd")
const PlayerScene := preload("res://scenes/game/player_isabela.tscn")


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	await process_frame
	var ok := true
	ok = _test_boss_rotation_and_enrage() and ok
	ok = _test_orbital_drop_pods() and ok
	ok = _test_legendary_upgrade_and_unlocks() and ok
	ok = await _test_skins_and_archetypes() and ok
	ok = _test_radar_and_boss_bar() and ok
	if ok:
		print("ALL_TESTS_PASSED: test_trilha_3_boss_skins_radar")
		quit(0)
	else:
		push_error("FAILED: test_trilha_3_boss_skins_radar")
		quit(1)


func _assert(cond: bool, msg: String) -> bool:
	if not cond:
		push_error("ASSERT FAILED: %s" % msg)
	return cond


func _test_boss_rotation_and_enrage() -> bool:
	var db := BalanceDBRef.new()
	if not _assert(db.load_from_file("res://data/game_balance.json"), "BalanceDB loaded"):
		return false
	var ok := true
	ok = _assert(db.get_boss_id_for_wave(5) == "white_reaper", "Wave 5 boss is white_reaper") and ok
	ok = _assert(db.get_boss_id_for_wave(10) == "valkyrie_skull", "Wave 10 boss is valkyrie_skull") and ok
	ok = _assert(db.get_boss_id_for_wave(15) == "anubis_phantom", "Wave 15 boss is anubis_phantom") and ok
	ok = _assert(db.get_boss_id_for_wave(20) == "white_reaper", "Wave 20 rotates back to white_reaper") and ok
	ok = _assert(db.get_boss_id_for_wave(4) == "", "Wave 4 has no boss") and ok

	var boss := BossSentinelScene.instantiate()
	root.add_child(boss)
	var player := Node3D.new()
	root.add_child(player)
	var spec := db.get_wave_spec(5)
	boss.call("configure_from_balance", "white_reaper", db, spec, player)
	var bmodel := boss.get_node_or_null("BossModel") as Node3D
	ok = _assert(bmodel != null and bmodel.scale.y > 2.0 and bmodel.position.y > 0.5, "White Reaper .glb loaded, scaled and grounded") and ok
	var b_anim := bmodel.find_child("AnimationPlayer", true, false) as AnimationPlayer if bmodel != null else null
	for req_anim in ["Idle", "Run", "Attack", "Guard_Stance", "Sword_Slam", "Stagger_Core", "Enrage_Roar"]:
		ok = _assert(b_anim != null and b_anim.has_animation(req_anim), "Reaper has animation: " + req_anim) and ok
	var bvis: Dictionary = boss.get("_vis")
	var sh_node := bvis.get("shield") as MeshInstance3D
	ok = _assert(sh_node != null and sh_node.mesh is TorusMesh and not (sh_node.mesh is BoxMesh), "Guard shield uses TorusMesh (not BoxMesh)") and ok

	var enrage_state := {"salvo": 0}
	boss.connect("enraged", func(_id: String, salvo: int) -> void: enrage_state["salvo"] = salvo)
	var base_spd := float(boss.get("base_speed_mps"))
	var max_hp := float(boss.get("max_hp"))
	boss.call("take_damage", max_hp * 0.55)
	ok = _assert(bool(boss.get("is_enraged")), "Boss enraged at <= 50% HP") and ok
	ok = _assert(int(enrage_state["salvo"]) == 4, "Enrage requests 4-capsule salvo") and ok
	ok = _assert(absf(float(boss.get("move_speed_mps")) - base_spd * 1.25) < 0.05, "Enrage grants +25% speed") and ok

	boss.queue_free()
	player.queue_free()
	return ok


func _test_orbital_drop_pods() -> bool:
	var ok := true
	var pod_cfg := {"spawn_y_m": 0.0, "telegraph_s": 0.0, "open_delay_s": 3.0, "pod_hp": 90.0, "impact_radius_m": 2.4, "impact_damage": 24.0, "destroy_xp": 35}

	# Case 1: Destroyed before 3.0s -> no reinforcement
	var pod1 := OrbitalDropPodRef.new()
	root.add_child(pod1)
	var st1 := {"destroyed": false, "opened": false}
	pod1.pod_destroyed.connect(func(by_p: bool, _pos: Vector3, _xp: int) -> void: st1["destroyed"] = by_p)
	pod1.pod_opened.connect(func(_id: String, _pos: Vector3) -> void: st1["opened"] = true)
	pod1.configure(Vector3(5, 0, 5), null, 5, pod_cfg)
	pod1._process(0.05) # lands
	pod1.take_damage(100.0)
	ok = _assert(bool(st1["destroyed"]) and not bool(st1["opened"]), "Destroying pod prevents reinforcement") and ok

	# Case 2: Intact for 3.0s -> opens reinforcement
	var pod2 := OrbitalDropPodRef.new()
	root.add_child(pod2)
	var st2 := {"opened_id": ""}
	pod2.pod_opened.connect(func(eid: String, _pos: Vector3) -> void: st2["opened_id"] = eid)
	pod2.configure(Vector3(-5, 0, 5), null, 10, pod_cfg)
	pod2._process(0.05) # lands
	pod2._process(3.1)  # opens
	ok = _assert(str(st2["opened_id"]) == "mech_leela", "Wave 10 pod opens mech_leela") and ok
	return ok


func _test_legendary_upgrade_and_unlocks() -> bool:
	var db := BalanceDBRef.new()
	db.load_from_file("res://data/game_balance.json")
	var upg := UpgradeSystemRef.new(db)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var cards := upg.roll_choices(5, rng, "legendary")
	var ok := _assert(cards.size() == 3 and str(cards[0].get("rarity", "")) == "legendary", "Boss draft guarantees legendary rarity")

	var test_cfg := "user://test_trilha3_settings.cfg"
	var test_unl := "user://test_trilha3_unlocks.cfg"
	if FileAccess.file_exists(test_unl):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_unl))
	SettingsManagerRef.set_config_path_for_test(test_cfg)
	SettingsManagerRef.set_unlocks_path_for_test(test_unl)
	SettingsManagerRef.reset_to_defaults(true)
	ok = _assert(not SettingsManagerRef.select_skin("valkyrie_skull"), "Locked skin cannot be selected") and ok
	SettingsManagerRef.unlock_skin("valkyrie_skull")
	ok = _assert(SettingsManagerRef.select_skin("valkyrie_skull"), "Unlocked skin can be selected") and ok
	ok = _assert(SettingsManagerRef.get_selected_skin() == "valkyrie_skull", "Selection persisted") and ok
	SettingsManagerRef.set_unlocks_path_for_test("")
	SettingsManagerRef.set_config_path_for_test("")
	return ok


func _test_skins_and_archetypes() -> bool:
	var db := BalanceDBRef.new()
	db.load_from_file("res://data/game_balance.json")
	var upg := UpgradeSystemRef.new(db)
	var loadout := WeaponLoadoutRef.new(db, upg)
	var ok := true

	# Verify White Reaper archetype (+20% dmg, +20% reload)
	var reaper_arch := db.get_archetype_cfg("white_reaper")
	loadout.set_archetype(reaper_arch)
	var pistol_shot := loadout.try_fire(false)
	var base_pistol := float(db.get_weapon_by_id("pistol").get("damage", 22.0))
	ok = _assert(absf(float(pistol_shot.get("base_damage", 0.0)) - base_pistol * 1.20) < 0.05, "White Reaper applies +20% damage") and ok

	# Verify Anubis Phantom archetype (-15% ammo, +15% crit chance)
	loadout.setup(db, upg)
	var anubis_arch := db.get_archetype_cfg("anubis_phantom")
	loadout.set_archetype(anubis_arch)
	var st := loadout.get_slot_hud_state(1)
	ok = _assert(int(st.get("mag_max", 15)) == roundi(15.0 * 0.85), "Anubis applies -15% ammo capacity") and ok

	# Verify PlayerSkinHelper preserves WeaponPoolHelper >= 7
	var player := PlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	player.call("configure", db, upg, loadout)
	for sid in ["leeloo", "isabela_jacket", "isabela_top", "isabela_lingerie", "valkyrie_skull", "anubis_phantom", "white_reaper"]:
		PlayerSkinHelperRef.apply_skin_and_helmet(player, sid, "helmet_a", db, player.get_node_or_null("PlayerAnimator"), player.get_node_or_null("WeaponManager"))
	var pa := player.get_node_or_null("PlayerAnimator")
	var wr_model := player.get_node_or_null("VisualRoot/SK_Isabela") as Node3D
	ok = _assert(pa != null and pa.call("get_weapon_socket") != null, "White Reaper playable skin binds WeaponSocket without errors") and ok
	ok = _assert(wr_model != null and not is_equal_approx(wr_model.scale.y, 1.0), "White Reaper playable skin height normalized to 1.72m") and ok
	var wm := player.get_node_or_null("WeaponManager")
	var pool = wm.get("_tps_pool") if wm != null else null
	ok = _assert(pool != null and int(pool.call("get_count")) >= 7, "WeaponPoolHelper preserves >= 7 pooled weapons after skin swaps") and ok
	player.queue_free()
	return ok


func _test_radar_and_boss_bar() -> bool:
	var ok := true
	# Forward in Godot with yaw=0 is -Z, so entity at (0, 0, -17) should map to (0, -radius * 0.5)
	var off := HUDRadarRef.world_to_radar_offset(Vector3(0.0, 0.0, -17.0), Vector3.ZERO, 0.0, 74.0, 34.0)
	ok = _assert(absf(off.x) < 0.1 and absf(off.y + 37.0) < 0.1, "HUDRadar projects -Z forward to top (-Y) at yaw=0") and ok

	# Yaw = PI/2 rotates forward to -X, so (-17, 0, 0) maps to top (0, -37)
	var off_rot := HUDRadarRef.world_to_radar_offset(Vector3(-17.0, 0.0, 0.0), Vector3.ZERO, PI * 0.5, 74.0, 34.0)
	ok = _assert(absf(off_rot.x) < 0.5 and absf(off_rot.y + 37.0) < 0.5, "HUDRadar rotates world coords by player yaw") and ok

	var bar := HUDBossBarRef.new()
	root.add_child(bar)
	var dummy_boss := Node.new()
	bar.bind_boss(dummy_boss, 5, "Valkyrie Skull")
	ok = _assert(bar.visible, "HUDBossBar visible on bind_boss") and ok
	bar.on_hp_updated(450.0, 950.0)
	bar.on_enraged()
	bar.on_boss_died()
	ok = _assert(not bar.visible, "HUDBossBar hides on boss death") and ok
	bar.queue_free()
	dummy_boss.queue_free()
	return ok
