extends SceneTree

const BalanceDBScript := preload("res://scripts/game/balance_db.gd")
const ProceduralSFXRef := preload("res://scripts/game/procedural_sfx.gd")
const AudioManagerRef := preload("res://scripts/game/audio_manager.gd")
const GameManagerRef := preload("res://scripts/game/game_manager.gd")
const ArenaElectricPerimeterRef := preload("res://scripts/game/arena_electric_perimeter.gd")
const WaveSpawnerRef := preload("res://scripts/game/wave_spawner.gd")
const PlayerScene := preload("res://scenes/game/player_isabela.tscn")
const DroidSmallScene := preload("res://scenes/game/droid_small_enemy.tscn")
const DroidTallScene := preload("res://scenes/game/droid_tall_enemy.tscn")


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	var ok := true
	ok = ok and await _test_electric_perimeter_damage()
	ok = ok and await _test_new_enemies_and_wave_progression()
	ok = ok and _test_procedural_sfx_new_ids()
	ok = ok and await _test_leeloo_player_and_protected_assets()
	if not ok:
		push_error("test_v3_features FAILED")
		quit(1)
		return
	print("ALL_TESTS_PASSED: test_v3_features")
	quit(0)


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		push_error("ASSERTION FAILED: " + msg)
		return false
	return true


func _test_electric_perimeter_damage() -> bool:
	var host := Node3D.new()
	root.add_child(host)

	var db := BalanceDBScript.new()
	if not _check(db.load_from_file("res://data/game_balance.json"), "BalanceDB loads"):
		host.queue_free()
		return false

	var gm := GameManagerRef.new()
	host.add_child(gm)
	if not _check(gm.initialize("res://data/game_balance.json"), "GameManager initializes"):
		host.queue_free()
		return false
	gm.start_run(false)

	var audio := AudioManagerRef.new()
	host.add_child(audio)

	var player := PlayerScene.instantiate()
	host.add_child(player)
	player.configure(db, gm.upgrades, gm.loadout)
	player.global_position = Vector3.ZERO

	var perimeter := ArenaElectricPerimeterRef.new()
	host.add_child(perimeter)
	perimeter.setup(gm, player, audio)
	await process_frame

	var ok := true
	var hp_start: float = player.current_hp

	# Safe inside arena center: no perimeter damage
	perimeter.tick_hazard(0.55)
	ok = ok and _check(is_equal_approx(player.current_hp, hp_start), "No perimeter damage at arena center")

	# Move into perimeter rim (radius 32.0m - width 1.8m = 30.2m): 2 ticks = 1.0s => 10 dmg
	player.global_position = Vector3(31.0, 0.2, 0.0)
	perimeter.tick_hazard(0.55)
	await physics_frame
	for _i in range(8):
		player.set("_iframes_left", 0.0)
	perimeter.tick_hazard(0.55)
	var dmg_dealt: float = hp_start - player.current_hp
	ok = ok and _check(dmg_dealt >= 9.5 and dmg_dealt <= 10.5, "Perimeter deals ~10 dmg/s (got %.2f)" % dmg_dealt)

	host.queue_free()
	await process_frame
	return ok


func _test_new_enemies_and_wave_progression() -> bool:
	var db := BalanceDBScript.new()
	if not _check(db.load_from_file("res://data/game_balance.json"), "BalanceDB loads"):
		return false

	var ok := true
	var small_hp := float(db.get_enemy_cfg("droid_small").get("base_hp", 0.0))
	var tall_hp := float(db.get_enemy_cfg("droid_tall").get("base_hp", 0.0))
	var spider_hp := float(db.get_enemy_cfg("mech_leela").get("base_hp", 0.0))
	var sawbox_hp := float(db.get_enemy_cfg("mech_mike").get("base_hp", 0.0))

	ok = ok and _check(sawbox_hp > spider_hp and spider_hp > tall_hp and tall_hp > small_hp,
		"HP ordering mech_mike(%.1f) > mech_leela(%.1f) > tall(%.1f) > small(%.1f)" % [sawbox_hp, spider_hp, tall_hp, small_hp])

	var w4 := db.get_wave_spec(4)
	var w5 := db.get_wave_spec(5)
	var w10 := db.get_wave_spec(10)
	var m4: Dictionary = w4.get("mech_counts", {})
	var m5: Dictionary = w5.get("mech_counts", {})
	var m10: Dictionary = w10.get("mech_counts", {})
	ok = ok and _check(int(m4.get("mech_leela", 0)) == 0 and int(m4.get("mech_mike", 0)) == 0, "Wave 4 has no mech_leela/mech_mike")
	ok = ok and _check(int(m5.get("mech_leela", 0)) >= 1 and int(m5.get("mech_mike", 0)) == 0, "Wave 5 introduces mech_leela")
	ok = ok and _check(int(m10.get("mech_leela", 0)) >= 1 and int(m10.get("mech_mike", 0)) >= 1, "Wave 10 has both mech_leela and mech_mike")

	var host := Node3D.new()
	root.add_child(host)
	var entities := Node3D.new()
	host.add_child(entities)
	var player_stub := Node3D.new()
	host.add_child(player_stub)

	var spawner := WaveSpawnerRef.new()
	spawner.droid_small_scene = DroidSmallScene
	spawner.droid_tall_scene = DroidTallScene
	host.add_child(spawner)
	spawner.setup(db, entities, player_stub)
	spawner.set_rng_seed(42)
	spawner.queue_wave(w10)
	ok = ok and _check(spawner.get_pending_spawn_count() == int(w10.get("total_enemies", 0)), "WaveSpawner queues all Wave 10 enemies")

	var spider_scene := load("res://scenes/game/mech_leela.tscn") as PackedScene
	var sawbox_scene := load("res://scenes/game/mech_mike.tscn") as PackedScene
	ok = ok and _check(spider_scene != null and sawbox_scene != null, "Mech Leela and Mike scenes load")
	if spider_scene != null and sawbox_scene != null:
		var s_inst := spider_scene.instantiate()
		var b_inst := sawbox_scene.instantiate()
		s_inst.position = Vector3(8.0, 0.0, 0.0)
		b_inst.position = Vector3(-8.0, 0.0, 0.0)
		entities.add_child(s_inst)
		entities.add_child(b_inst)
		s_inst.configure_from_balance("mech_leela", db, w5, player_stub)
		b_inst.configure_from_balance("mech_mike", db, w10, player_stub)
		await process_frame
		ok = ok and _check(s_inst.current_hp > 0.0 and b_inst.current_hp > s_inst.current_hp, "Instantiated mech_mike HP > mech_leela HP")

	host.queue_free()
	await process_frame
	return ok


func _test_procedural_sfx_new_ids() -> bool:
	var ok := true
	var ids := [
		"electric_shock",
		"droid_small", "droid_tall",
		"droid_spider_cannon", "droid_spider_step",
		"droid_sawbox_hum", "droid_sawbox_impact",
		"enemy_hit", "enemy_death",
		"pistol", "shotgun", "smg",
		"rocket_launcher", "rocket_explode",
		"laser_gun", "laser_overheat",
		"lightsaber", "katana", "reload",
	]
	for sfx_id in ids:
		var stream := ProceduralSFXRef.make_sfx(sfx_id)
		ok = ok and _check(stream is AudioStreamWAV, "ProceduralSFX returns AudioStreamWAV for " + sfx_id)
		if stream != null:
			ok = ok and _check(stream.data.size() > 0 and stream.mix_rate > 0, "Valid PCM data for " + sfx_id)
	return ok


func _test_leeloo_player_and_protected_assets() -> bool:
	var ok := true
	var tscn_text := FileAccess.get_file_as_string("res://scenes/game/player_isabela.tscn")
	ok = ok and _check(tscn_text.contains("SK_Isabela_Leeloo.glb"), "player_isabela.tscn references SK_Isabela_Leeloo.glb")
	ok = ok and _check(FileAccess.file_exists("res://assets/SK_Isabela/SK_Isabela.glb"), "Base SK_Isabela.glb still exists")
	ok = ok and _check(FileAccess.file_exists("res://scenes/main_isabela_scene.tscn"), "Protected main_isabela_scene.tscn still exists")

	var host := Node3D.new()
	root.add_child(host)
	var player := PlayerScene.instantiate()
	host.add_child(player)
	await process_frame

	var skel := player.find_children("*", "Skeleton3D", true, false)
	ok = ok and _check(not skel.is_empty() and (skel[0] as Skeleton3D).get_bone_count() == 84,
		"Leeloo player preserves 84-bone Skeleton3D")
	var socket := player.find_child("WeaponSocket", true, false)
	ok = ok and _check(socket != null, "Leeloo player preserves WeaponSocket")

	host.queue_free()
	await process_frame
	return ok
