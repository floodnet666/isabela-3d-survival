extends SceneTree

const PlayableArenaScene := preload("res://scenes/game/playable_arena.tscn")
const DroidSmallScene := preload("res://scenes/game/droid_small_enemy.tscn")
const DroidTallScene := preload("res://scenes/game/droid_tall_enemy.tscn")
const BalanceDBScript := preload("res://scripts/game/balance_db.gd")
const WeaponVFXRef := preload("res://scripts/game/weapon_vfx.gd")


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	var ok := true
	ok = ok and await _test_audio_manager_hybrid_and_buses()
	ok = ok and await _test_droid_destruction_and_pool_cap()
	ok = ok and await _test_explosive_barrel_aoe_and_chain()
	ok = ok and await _test_arena_props_and_scifi_mood()
	if not ok:
		push_error("test_trilha_a_audio_and_destruction FAILED")
		quit(1)
		return
	print("ALL_TESTS_PASSED: test_trilha_a_audio_and_destruction")
	quit(0)


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		push_error("ASSERTION FAILED: " + msg)
		return false
	return true


func _test_audio_manager_hybrid_and_buses() -> bool:
	var AudioMgr := load("res://scripts/game/audio_manager.gd")
	if not _check(AudioMgr != null, "audio_manager.gd must load"):
		return false
	var host := Node.new()
	root.add_child(host)
	var am = AudioMgr.new()
	host.add_child(am)
	await process_frame

	var ok := true
	ok = ok and _check(AudioServer.get_bus_index("Music") >= 0, "Music bus created")
	ok = ok and _check(AudioServer.get_bus_index("SFX") >= 0, "SFX bus created")
	ok = ok and _check(am.has_music_stream(), "AudioManager resolves Punk-Rock music stream (file or fallback)")
	am.start_music()

	var before_cnt: int = am.played_events_count
	for wid in ["pistol", "smg", "shotgun", "laser_gun", "rocket_launcher", "katana", "sniper"]:
		am.play_weapon_shot(wid)
	for sfx_id in ["droid_hit", "droid_explode", "barrel_explode", "pickup", "level_up", "player_hurt", "wave_start"]:
		am.play_sfx(sfx_id)
	ok = ok and _check(am.played_events_count == before_cnt + 14, "All 14 audio events dispatched cleanly")

	am.set_paused_ducking(true)
	var music_db_paused: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	am.set_paused_ducking(false)
	var music_db_live: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	ok = ok and _check(music_db_paused < music_db_live, "Music bus ducks volume when paused")

	host.queue_free()
	await process_frame
	return ok


func _test_droid_destruction_and_pool_cap() -> bool:
	var host := Node3D.new()
	root.add_child(host)
	var db := BalanceDBScript.new()
	db.load_from_file("res://data/game_balance.json")

	var ok := true
	var d_small := DroidSmallScene.instantiate()
	host.add_child(d_small)
	d_small.configure_from_balance("droid_small", db, {"wave": 1, "hp_multiplier": 1.0, "damage_multiplier": 1.0}, null)
	d_small.global_position = Vector3(2.0, 0.0, -3.0)
	await process_frame

	d_small.take_damage(8.0, Vector3.ZERO, true)
	ok = ok and _check(float(d_small.get("_flash_left")) > 0.05, "Hit flash timer activates on damage")

	WeaponVFXRef.spawn_hit_sparks(host, Vector3(2.0, 0.8, -3.0), Vector3.UP, true, true)
	WeaponVFXRef.spawn_muzzle_flash(host, Vector3(0.0, 1.3, 0.0), Color(1.0, 0.8, 0.3))
	WeaponVFXRef.spawn_blade_trail(host, Vector3(0.0, 1.2, 0.0), Vector3.FORWARD, 1, "lightsaber", false)

	d_small.take_damage(999.0, Vector3(0.0, 0.0, -8.0), true)
	await process_frame

	var debris := get_nodes_in_group("droid_debris")
	ok = ok and _check(debris.size() >= 5, "Killing droid spawns >= 5 physical debris pieces (got %d)" % debris.size())
	var has_rigid := false
	for p in debris:
		if p is RigidBody3D:
			has_rigid = true
			break
	ok = ok and _check(has_rigid, "Spawned droid debris includes RigidBody3D physics chunks")

	for i in range(9):
		var scene := DroidTallScene if i % 2 == 1 else DroidSmallScene
		var eid := "droid_tall" if i % 2 == 1 else "droid_small"
		var d := scene.instantiate()
		host.add_child(d)
		d.configure_from_balance(eid, db, {"wave": 1, "hp_multiplier": 1.0, "damage_multiplier": 1.0}, null)
		d.global_position = Vector3(float(i) * 1.5, 0.0, -5.0)
		d.take_damage(9999.0, Vector3.BACK * 6.0)
	await process_frame

	var capped := get_nodes_in_group("droid_debris")
	ok = ok and _check(capped.size() <= 36, "Debris pool stays capped <= 36 pieces (got %d)" % capped.size())

	host.queue_free()
	await process_frame
	return ok


func _test_explosive_barrel_aoe_and_chain() -> bool:
	var BarrelScript := load("res://scripts/game/explosive_barrel.gd")
	if not _check(BarrelScript != null, "explosive_barrel.gd must load"):
		return false
	var host := Node3D.new()
	root.add_child(host)
	var db := BalanceDBScript.new()
	db.load_from_file("res://data/game_balance.json")

	var b1 = BarrelScript.new()
	var b2 = BarrelScript.new()
	host.add_child(b1)
	host.add_child(b2)
	b1.global_position = Vector3(0.0, 0.0, 0.0)
	b2.global_position = Vector3(3.2, 0.0, 0.0)

	var enemy := DroidSmallScene.instantiate()
	host.add_child(enemy)
	enemy.configure_from_balance("droid_small", db, {"wave": 1, "hp_multiplier": 5.0, "damage_multiplier": 1.0}, null)
	enemy.global_position = Vector3(2.0, 0.0, 0.0)
	var hp_before: float = enemy.current_hp
	await physics_frame

	b1.take_damage(100.0, Vector3.ZERO)
	var ok := true
	ok = ok and _check(b1.is_exploded(), "Barrel 1 explodes on weapon damage")
	ok = ok and _check(enemy.current_hp < hp_before, "Explosive barrel deals AoE damage to nearby droid")

	for _f in range(18):
		await physics_frame
	ok = ok and _check(b2.is_exploded(), "Nearby Barrel 2 detonates via chain reaction")

	host.queue_free()
	await process_frame
	return ok


func _test_arena_props_and_scifi_mood() -> bool:
	var arena := PlayableArenaScene.instantiate()
	arena.set_interactive_mouse_capture(false)
	root.add_child(arena)
	await process_frame
	await process_frame

	var bm := arena.find_child("BiomeManager", true, false)
	var gm: Node = arena.get("game_manager")
	if bm != null and gm != null:
		var bcfg: Dictionary = gm.get("balance_db").call("get_biomes_cfg")
		var types: Dictionary = bcfg.get("types", {})
		if types.has("desert_coast"):
			bm.call("_swap_biome_now", "desert_coast", types["desert_coast"] as Dictionary, bcfg, 101)
			await process_frame

	var ok := true
	var props_node := arena.get_node_or_null("ArenaProps") as Node3D
	ok = ok and _check(props_node != null, "ArenaProps node is mounted in PlayableArena")

	var colliders := 0
	var spawn_clear := true
	if props_node != null:
		for c in props_node.find_children("*", "StaticBody3D", true, false):
			var sb := c as StaticBody3D
			if sb.collision_layer == 1:
				colliders += 1
				var d := Vector2(sb.global_position.x, sb.global_position.z).length()
				if d < 4.0:
					spawn_clear = false
	ok = ok and _check(colliders >= 6, "ArenaProps provides >= 6 StaticBody3D tactical cover colliders (got %d)" % colliders)
	ok = ok and _check(spawn_clear, "Player spawn (0,0,0) has >= 4m clearance from ArenaProps colliders")

	var barrels := get_nodes_in_group("explosive_barrels")
	ok = ok and _check(barrels.size() >= 4, "PlayableArena spawns >= 4 ExplosiveBarrels (got %d)" % barrels.size())

	var we := arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	ok = ok and _check(we != null and we.environment != null, "WorldEnvironment configured")
	if we != null and we.environment != null and we.environment.sky != null:
		var sm := we.environment.sky.sky_material as ProceduralSkyMaterial
		ok = ok and _check(sm != null and sm.sky_top_color.b > sm.sky_top_color.r, "Sci-Fi Crepusculo sky uses cool deep indigo top tint")

	arena.queue_free()
	await process_frame
	return ok
