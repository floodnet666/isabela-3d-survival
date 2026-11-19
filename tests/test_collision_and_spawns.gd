extends SceneTree
## Regression tests for: (1) zero invisible walls from hidden ArenaProps or WallCorner OBBs, (2) zero WFC overlap on ArenaElevators, (3) zero enemy spawns inside obstacles, (4) zero player crush/trap under descending elevators.

const ArenaElevatorsRef := preload("res://scripts/game/arena_elevators.gd")
const BiomeBuilderRef := preload("res://scripts/game/biome_arena_builder.gd")
const BalanceDBRef := preload("res://scripts/game/balance_db.gd")
const WaveSpawnerRef := preload("res://scripts/game/wave_spawner.gd")

var _failed := 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error("ASSERTION FAILED: " + msg)
		_failed += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_no_invisible_arena_props()
	await _test_wfc_clear_of_elevators_and_exact_obbs()
	await _test_spawner_never_spawns_inside_obstacles()
	await _test_elevator_anti_crush_never_traps_player()

	if _failed == 0:
		print("ALL_TESTS_PASSED: test_collision_and_spawns")
		quit(0)
	else:
		print("FAILED_TESTS: %d" % _failed)
		quit(1)


func _test_no_invisible_arena_props() -> void:
	var ps := load("res://scenes/game/playable_arena.tscn") as PackedScene
	var arena := ps.instantiate() as Node3D
	get_root().add_child(arena)
	for _i in range(4):
		await physics_frame

	var bm := arena.find_child("BiomeManager", true, false)
	var props := arena.get_node_or_null("ArenaProps") as Node3D
	var gm: Node = arena.get("game_manager")
	var bcfg: Dictionary = gm.get("balance_db").call("get_biomes_cfg")
	var types: Dictionary = bcfg.get("types", {})

	# Switch to WFC biome -> ArenaProps colliders MUST be disabled
	bm.call("_swap_biome_now", "sand_dunes_pyramid", types["sand_dunes_pyramid"] as Dictionary, bcfg, 777)
	await physics_frame
	_check(props != null and not props.visible, "ArenaProps hidden in WFC biome")
	var active_shapes := 0
	for cs in props.find_children("*", "CollisionShape3D", true, false):
		if not (cs as CollisionShape3D).disabled:
			active_shapes += 1
	_check(active_shapes == 0, "Hidden ArenaProps must have 0 active CollisionShape3D (found %d)" % active_shapes)

	# Switch back to desert_coast -> ArenaProps colliders MUST be re-enabled
	bm.call("_swap_biome_now", "desert_coast", types["desert_coast"] as Dictionary, bcfg, 777)
	await physics_frame
	var restored_shapes := 0
	for cs in props.find_children("*", "CollisionShape3D", true, false):
		if not (cs as CollisionShape3D).disabled:
			restored_shapes += 1
	_check(restored_shapes >= 10, "Restored desert_coast ArenaProps must re-enable colliders (found %d)" % restored_shapes)

	arena.queue_free()
	await physics_frame


func _test_wfc_clear_of_elevators_and_exact_obbs() -> void:
	var db := BalanceDBRef.new()
	db.load_from_file()
	var bcfg := db.get_biomes_cfg()
	var types: Dictionary = bcfg.get("types", {})

	var builder := BiomeBuilderRef.new()
	get_root().add_child(builder)

	for sd in [777, 1234, 9999]:
		var res := builder.build_biome("sand_dunes_pyramid", types["sand_dunes_pyramid"] as Dictionary, bcfg, sd)
		_check(bool(res.get("ok", false)), "Biome builds cleanly with elevator clearance (seed %d)" % sd)
		for pdef in ArenaElevatorsRef.PLATFORM_DEFS:
			var ppos: Vector3 = pdef["pos"]
			_check(builder.is_position_clear_of_wfc(ppos, 2.2), "Elevator at %s must be clear of WFC obstacles (seed %d)" % [str(ppos), sd])

	# Verify WallCorner L-shape collider has open SW quadrant and solid E/N arms
	builder.clear_biome()
	builder.call("_ensure_runtime_root_for_test")
	builder.call("_add_tile_collision", "TILE_WallCorner", Vector3.ZERO, 0.0, 6.0)
	_check(not builder.is_position_clear_of_wfc(Vector3(1.8, 0.0, 0.0), 0.3), "WallCorner E arm must be solid")
	_check(not builder.is_position_clear_of_wfc(Vector3(0.0, 0.0, -1.8), 0.3), "WallCorner N arm must be solid")
	_check(builder.is_position_clear_of_wfc(Vector3(-1.5, 0.0, 1.5), 0.3), "WallCorner open SW quadrant must NOT have invisible wall")

	builder.queue_free()
	await physics_frame


func _test_spawner_never_spawns_inside_obstacles() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var db := BalanceDBRef.new()
	db.load_from_file()
	var bcfg := db.get_biomes_cfg()
	var types: Dictionary = bcfg.get("types", {})

	var elev := ArenaElevatorsRef.new()
	root.add_child(elev)
	var builder := BiomeBuilderRef.new()
	root.add_child(builder)
	builder.build_biome("mothership_interior", types["mothership_interior"] as Dictionary, bcfg, 2026)

	var entities := Node3D.new()
	root.add_child(entities)
	var player := Node3D.new()
	root.add_child(player)

	var spawner := WaveSpawnerRef.new()
	root.add_child(spawner)
	spawner.setup(db, entities, player, null, builder)
	spawner.set_rng_seed(555)

	for _f in range(3):
		await physics_frame

	var space := root.get_world_3d().direct_space_state
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.55
	cyl.height = 1.6

	var blocked_hits := 0
	for _i in range(50):
		var pos := spawner.pick_ring_spawn_position(Vector3.ZERO)
		if not builder.is_position_clear(pos, 0.6):
			blocked_hits += 1
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cyl
		q.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0.0, 1.0, 0.0))
		q.collision_mask = 1
		if not space.intersect_shape(q, 1).is_empty():
			blocked_hits += 1
	_check(blocked_hits == 0, "All 50 enemy spawns must be clear of OBBs & physics colliders (hits=%d)" % blocked_hits)

	root.queue_free()
	await physics_frame


func _test_elevator_anti_crush_never_traps_player() -> void:
	var root := Node3D.new()
	get_root().add_child(root)

	# Ground floor
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var fcs := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(80, 1, 80)
	fcs.shape = fbox
	fcs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(fcs)
	root.add_child(floor_body)

	var elev := ArenaElevatorsRef.new()
	root.add_child(elev)

	# Fake player CharacterBody3D standing dead-center under platform 0 while it descends
	var player := CharacterBody3D.new()
	player.add_to_group("player")
	player.collision_layer = 2
	player.collision_mask = 1
	var pcs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	pcs.shape = cap
	pcs.position = Vector3(0, 0.85, 0)
	player.add_child(pcs)
	var p0: Vector3 = ArenaElevatorsRef.PLATFORM_DEFS[0]["pos"]
	player.position = Vector3(p0.x, 0.05, p0.z)
	root.add_child(player)

	# Force platform 0 near top and step physics through descent past MIN_Y
	elev.set("_time", 2.0)
	for _i in range(420):
		await physics_frame

	var bodies := get_nodes_in_group("elevator_platforms")
	var ab0 := bodies[0] as AnimatableBody3D
	var dx := absf(player.global_position.x - ab0.global_position.x)
	var dz := absf(player.global_position.z - ab0.global_position.z)
	var under_footprint := dx < 2.05 and dz < 2.05
	var trapped_under := under_footprint and (player.global_position.y < ab0.global_position.y - 0.15) and (ab0.global_position.y < 2.2)
	_check(not trapped_under, "Player must NEVER be trapped under descending elevator (player=%s, plat=%s)" % [str(player.global_position), str(ab0.global_position)])

	root.queue_free()
	await physics_frame
