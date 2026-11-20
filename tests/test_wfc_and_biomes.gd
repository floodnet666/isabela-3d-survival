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

	# Test 100 random WFC seeds for socket adjacency AND guaranteed connectivity / doorway rules
	var all_seeds_ok := true
	for sd in range(1, 101):
		var rr: Dictionary = wfc.solve(11, tiles_cfg, sd * 37 + 11, 1)
		if not bool(rr.get("ok", false)) or not wfc.validate_adjacency(rr["grid"]) or not wfc.validate_connectivity(rr["grid"]):
			all_seeds_ok = false
			push_error("Seed failed WFC connectivity/adjacency: %d" % sd)
			break
	ok = _assert(all_seeds_ok, "All 100 WFC seeds satisfy validate_adjacency() and validate_connectivity()") and ok

	# Test synthetic completely sealed 4-wall room -> ensure_connectivity_and_doors punches TILE_Arch and keeps adjacency
	var sg: Array = []
	for z in range(7):
		var row: Array = []
		for x in range(7):
			row.append({"id": "TILE_Open", "rot": 0, "sockets": PackedStringArray(["open", "open", "open", "open"])})
		sg.append(row)
	sg[2][2] = {"id": "TILE_WallCorner", "rot": 1, "sockets": PackedStringArray(["open", "wall", "wall", "open"])}
	sg[2][3] = {"id": "TILE_WallStraight", "rot": 0, "sockets": PackedStringArray(["open", "wall", "open", "wall"])}
	sg[2][4] = {"id": "TILE_WallCorner", "rot": 2, "sockets": PackedStringArray(["open", "open", "wall", "wall"])}
	sg[3][4] = {"id": "TILE_WallStraight", "rot": 1, "sockets": PackedStringArray(["wall", "open", "wall", "open"])}
	sg[4][4] = {"id": "TILE_WallCorner", "rot": 3, "sockets": PackedStringArray(["wall", "open", "open", "wall"])}
	sg[4][3] = {"id": "TILE_WallStraight", "rot": 0, "sockets": PackedStringArray(["open", "wall", "open", "wall"])}
	sg[4][2] = {"id": "TILE_WallCorner", "rot": 0, "sockets": PackedStringArray(["wall", "wall", "open", "open"])}
	sg[3][2] = {"id": "TILE_WallStraight", "rot": 1, "sockets": PackedStringArray(["wall", "open", "wall", "open"])}
	ok = _assert(wfc.validate_adjacency(sg), "Synthetic sealed room has valid socket adjacency before repair") and ok
	ok = _assert(not wfc.validate_connectivity(sg), "Synthetic sealed room detected as disconnected before repair") and ok
	wfc.ensure_connectivity_and_doors(sg)
	var arch_count := 0
	for z in range(7):
		for x in range(7):
			if str((sg[z][x] as Dictionary)["id"]) == "TILE_Arch":
				arch_count += 1
	ok = _assert(arch_count >= 1, "ensure_connectivity_and_doors converts sealed wall into TILE_Arch") and ok
	ok = _assert(wfc.validate_adjacency(sg), "Repaired sealed room preserves validate_adjacency()") and ok
	ok = _assert(wfc.validate_connectivity(sg), "Repaired sealed room satisfies validate_connectivity()") and ok

	# Test DayNightCycle disables fog and volumetric fog across all 5 biome profiles + BiomeWeatherVFX has no atmospheric shader
	var fx_src := FileAccess.get_file_as_string("res://scripts/game/biome_weather_vfx.gd")
	ok = _assert(not ("biome_atmospheric_particle.gdshader" in fx_src) and not FileAccess.file_exists("res://shaders/biome_atmospheric_particle.gdshader"), "Atmospheric fog/smoke shader removed") and ok
	var env_root := Node3D.new()
	var we := WorldEnvironment.new(); var env := Environment.new(); var sky := Sky.new(); sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky; env.fog_enabled = true; env.volumetric_fog_enabled = true; we.environment = env
	env_root.add_child(we); env_root.add_child(DirectionalLight3D.new())
	var dnc: Node = (load("res://scripts/game/day_night_cycle.gd") as GDScript).new()
	env_root.add_child(dnc); get_root().add_child(env_root)
	await process_frame
	for bid in types.keys():
		dnc.call("set_biome_profile", types[bid] as Dictionary)
		ok = _assert(not we.environment.fog_enabled and not we.environment.volumetric_fog_enabled, "Fog disabled for biome: " + str(bid)) and ok
	env_root.queue_free()

	bm.queue_free()
	builder.queue_free()
	print("ALL_TESTS_PASSED: test_wfc_and_biomes" if ok else "TEST_FAILED: test_wfc_and_biomes")
	quit(0 if ok else 1)
