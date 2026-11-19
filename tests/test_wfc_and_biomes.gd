extends SceneTree

func _assert(cond: bool, label: String) -> bool:
	if not cond:
		push_error("FAIL: " + label)
	return cond


func _init() -> void:
	var ok := true
	var db: RefCounted = (load("res://scripts/game/balance_db.gd") as GDScript).new()
	ok = _assert(db.load_from_file(), "BalanceDB loads") and ok

	var biomes_cfg: Dictionary = db.get_biomes_cfg()
	var types: Dictionary = biomes_cfg.get("types", {})
	ok = _assert(types.size() == 5, "Exactly 5 biomes configured in game_balance.json") and ok
	ok = _assert(int(biomes_cfg.get("wave_interval", 0)) == 5, "Biome wave_interval is 5") and ok

	var wfc := preload("res://scripts/game/wfc_solver.gd")
	var tiles_cfg: Array = biomes_cfg.get("tiles", [])
	var r1: Dictionary = wfc.solve(11, tiles_cfg, 101, 1)
	var r2: Dictionary = wfc.solve(11, tiles_cfg, 101, 1)
	var r3: Dictionary = wfc.solve(11, tiles_cfg, 999, 1)
	ok = _assert(bool(r1.get("ok", false)), "WFC solves 11x11 grid") and ok
	ok = _assert(wfc.validate_adjacency(r1["grid"]), "WFC grid respects all N/E/S/W sockets") and ok
	ok = _assert(str(r1["grid"][5][5]["id"]) == "TILE_Open", "Center spawn cell (5,5) is TILE_Open") and ok
	ok = _assert(str(r1["grid"]) == str(r2["grid"]), "Same seed produces identical WFC layout") and ok
	ok = _assert(str(r1["grid"]) != str(r3["grid"]), "Different seeds produce different WFC layouts") and ok

	# Test random non-repeating biome sequence across 2 runs
	var bm_script := load("res://scripts/game/biome_manager.gd") as GDScript
	var bm: Node = bm_script.new()
	get_root().add_child(bm)
	var seq_a: Array[String] = bm.build_random_sequence(types.keys(), 12345, 6)
	var seq_b: Array[String] = bm.build_random_sequence(types.keys(), 54321, 6)
	ok = _assert(seq_a.size() == 6 and seq_b.size() == 6, "Random biome sequence built") and ok
	ok = _assert(seq_a != seq_b, "Different run seeds produce different random biome orders") and ok
	var no_adj_repeat := true
	for i in range(seq_a.size() - 1):
		if seq_a[i] == seq_a[i + 1]:
			no_adj_repeat = false
	ok = _assert(no_adj_repeat, "No immediate biome repetition on transition") and ok

	# Test BiomeArenaBuilder builds all 5 biomes with clear center spawn
	var builder_script := load("res://scripts/game/biome_arena_builder.gd") as GDScript
	var builder: Node3D = builder_script.new()
	get_root().add_child(builder)
	for bid in types.keys():
		builder.build_biome(str(bid), types[bid] as Dictionary, biomes_cfg, 777)
		ok = _assert(builder.is_position_clear(Vector3.ZERO, 1.5), "Center clear in biome: " + str(bid)) and ok

	# Test tractor_beam SFX exists
	var sfx := preload("res://scripts/game/procedural_sfx.gd")
	var wav: AudioStreamWAV = sfx.make_sfx("tractor_beam")
	ok = _assert(wav != null and wav.data.size() > 1000, "ProceduralSFX generates tractor_beam sound") and ok

	bm.queue_free()
	builder.queue_free()
	print("ALL_TESTS_PASSED: test_wfc_and_biomes" if ok else "TEST_FAILED: test_wfc_and_biomes")
	quit(0 if ok else 1)
