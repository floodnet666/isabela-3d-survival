class_name BiomeArenaBuilder
extends Node3D
## Builds WFC procedural multi-biome arenas with MultiMesh batching, exact OBB colliders, elevator clearance, PBR overrides, and ExplosiveBarrels.

const WFCSolverRef := preload("res://scripts/game/wfc_solver.gd")
const ExplosiveBarrelRef := preload("res://scripts/game/explosive_barrel.gd")
const WeatherVFXRef := preload("res://scripts/game/biome_weather_vfx.gd")
const MaterialLibRef := preload("res://scripts/game/biome_material_library.gd")
const ArenaElevatorsRef := preload("res://scripts/game/arena_elevators.gd")

var current_biome_id: String = ""
var _obstacle_obbs: Array[Dictionary] = []
var _open_tile_centers: Array[Vector3] = []
var _barrels: Array[ExplosiveBarrelRef] = []
var _runtime_root: Node3D
var _mesh_cache: Dictionary = {}


func is_position_clear_of_wfc(world_pos: Vector3, margin_m: float = 1.5) -> bool:
	var px := world_pos.x
	var pz := world_pos.z
	for obb in _obstacle_obbs:
		var c: Vector2 = obb["center"]
		var dx := px - c.x
		var dz := pz - c.y
		var ang := -float(obb["rot_y"])
		var ca := cos(ang)
		var sa := sin(ang)
		var lx := dx * ca + dz * sa
		var lz := -dx * sa + dz * ca
		if absf(lx) < float(obb["hx"]) + margin_m and absf(lz) < float(obb["hz"]) + margin_m:
			return false
	return true


func is_position_clear(world_pos: Vector3, margin_m: float = 1.5) -> bool:
	if not is_position_clear_of_wfc(world_pos, margin_m):
		return false
	var he_x := ArenaElevatorsRef.PLATFORM_SIZE.x * 0.5 + margin_m
	var he_z := ArenaElevatorsRef.PLATFORM_SIZE.z * 0.5 + margin_m
	for pdef in ArenaElevatorsRef.PLATFORM_DEFS:
		var ep: Vector3 = pdef["pos"]
		if absf(world_pos.x - ep.x) < he_x and absf(world_pos.z - ep.z) < he_z:
			return false
	return true


func get_open_tile_centers() -> Array[Vector3]:
	return _open_tile_centers


func get_barrels() -> Array[ExplosiveBarrelRef]:
	return _barrels


func clear_biome() -> void:
	_obstacle_obbs.clear()
	_open_tile_centers.clear()
	_barrels.clear()
	if _runtime_root != null and is_instance_valid(_runtime_root):
		_runtime_root.queue_free()
		_runtime_root = null


func _ensure_runtime_root_for_test() -> void:
	if _runtime_root == null or not is_instance_valid(_runtime_root):
		_runtime_root = Node3D.new()
		_runtime_root.name = "BiomeRuntime_Test"
		add_child(_runtime_root)


func build_biome(biome_id: String, biome_cfg: Dictionary, root_cfg: Dictionary, rng_seed: int) -> Dictionary:
	clear_biome()
	current_biome_id = biome_id
	_runtime_root = Node3D.new()
	_runtime_root.name = "BiomeRuntime_" + biome_id
	add_child(_runtime_root)

	var use_wfc := bool(biome_cfg.get("use_wfc", true))
	if not use_wfc:
		return {"ok": true, "biome_id": biome_id, "tiles_placed": 0}

	var grid_n := int(root_cfg.get("grid_size", 11))
	var tile_sz := float(root_cfg.get("tile_size_m", 6.0))
	var half := float(grid_n - 1) * 0.5 * tile_sz
	var forced_open := _compute_elevator_clear_cells(grid_n, tile_sz, half)
	var tiles_cfg: Array = root_cfg.get("tiles", [])
	var res := WFCSolverRef.solve(grid_n, tiles_cfg, rng_seed, 1, 16, forced_open)
	if not bool(res.get("ok", false)):
		return {"ok": false, "biome_id": biome_id, "tiles_placed": 0}

	var grid: Array = res["grid"]
	var asset_dir := str(biome_cfg.get("asset_dir", ""))
	var transforms_by_tile: Dictionary = {}
	var barrel_spots: Array[Vector3] = []

	for z in range(grid_n):
		for x in range(grid_n):
			var cell: Dictionary = grid[z][x]
			var tid := str(cell["id"])
			var rot_y := -float(int(cell["rot"])) * PI * 0.5
			var pos := Vector3(float(x) * tile_sz - half, 0.0, float(z) * tile_sz - half)
			var xf := Transform3D(Basis(Vector3.UP, rot_y), pos)
			if not transforms_by_tile.has(tid):
				transforms_by_tile[tid] = []
			(transforms_by_tile[tid] as Array).append(xf)
			_add_tile_collision(tid, pos, rot_y, tile_sz)
			if tid == "TILE_Open" and pos.length() <= 27.5:
				_open_tile_centers.append(pos)
				if pos.length() >= 7.5 and pos.length() <= 22.0 and not _overlaps_elevator(pos, 3.0):
					barrel_spots.append(pos)

	for tid in transforms_by_tile.keys():
		var xfs: Array = transforms_by_tile[tid]
		var mesh := _load_tile_mesh(asset_dir, str(tid))
		if mesh != null:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = xfs.size()
			for i in range(xfs.size()):
				mm.set_instance_transform(i, xfs[i] as Transform3D)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if tid != "TILE_Open" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_runtime_root.add_child(mmi)

	_spawn_static_glb(asset_dir, "BACKDROP")
	_spawn_static_glb(asset_dir, "FLOOR")
	WeatherVFXRef.build_weather(_runtime_root, str(biome_cfg.get("weather", "")))
	_spawn_biome_lights(biome_id, biome_cfg)
	_spawn_barrels(barrel_spots, rng_seed)
	return {"ok": true, "biome_id": biome_id, "tiles_placed": grid_n * grid_n}


func _compute_elevator_clear_cells(grid_n: int, tile_sz: float, half: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for z in range(grid_n):
		for x in range(grid_n):
			var pos := Vector3(float(x) * tile_sz - half, 0.0, float(z) * tile_sz - half)
			if _overlaps_elevator(pos, 5.2):
				cells.append(Vector2i(x, z))
	return cells


func _overlaps_elevator(pos: Vector3, pad_m: float) -> bool:
	for pdef in ArenaElevatorsRef.PLATFORM_DEFS:
		var ep: Vector3 = pdef["pos"]
		if absf(pos.x - ep.x) <= pad_m and absf(pos.z - ep.z) <= pad_m:
			return true
	return false


func _spawn_static_glb(asset_dir: String, file_stem: String) -> void:
	if asset_dir.is_empty():
		return
	var path := "%s/%s.glb" % [asset_dir, file_stem]
	if not ResourceLoader.exists(path):
		return
	var ps := load(path) as PackedScene
	if ps == null:
		return
	var inst := ps.instantiate() as Node3D
	if inst != null:
		inst.name = file_stem
		MaterialLibRef.apply_to_node(inst)
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			if file_stem == "BACKDROP":
				(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_runtime_root.add_child(inst)


func _load_tile_mesh(asset_dir: String, tile_id: String) -> Mesh:
	if asset_dir.is_empty():
		return null
	var path := "%s/%s.glb" % [asset_dir, tile_id]
	if _mesh_cache.has(path):
		return _mesh_cache[path] as Mesh
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	var mesh: Mesh = null
	if inst != null:
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh != null:
				mesh = mi.mesh.duplicate() as Mesh
				MaterialLibRef.apply_to_mesh(mesh)
				break
		inst.free()
	_mesh_cache[path] = mesh
	return mesh


func _add_tile_collision(tid: String, pos: Vector3, rot_y: float, tile_sz: float) -> void:
	if tid == "TILE_Open":
		return
	var b := Basis(Vector3.UP, rot_y)
	if tid == "TILE_CoverLow":
		_make_box_collider(pos, rot_y, Vector3(3.25, 1.25, 1.0), 0.625)
	elif tid == "TILE_Pillar":
		_make_box_collider(pos, rot_y, Vector3(1.85, 4.8, 1.85), 2.4)
	elif tid == "TILE_WallStraight":
		_make_box_collider(pos, rot_y, Vector3(tile_sz, 2.5, 1.15), 1.25)
	elif tid == "TILE_WallCorner":
		# Exact L-shaped colliders matching East (+X) and North (-Z) visual arms — zero invisible SW box!
		_make_box_collider(pos + b * Vector3(1.25, 0.0, 0.0), rot_y, Vector3(3.5, 2.5, 1.15), 1.25)
		_make_box_collider(pos + b * Vector3(0.0, 0.0, -1.25), rot_y, Vector3(1.15, 2.5, 3.5), 1.25)
	elif tid == "TILE_Arch":
		_make_box_collider(pos + b * Vector3(-2.28, 0.0, 0.0), rot_y, Vector3(1.15, 4.0, 1.25), 2.0)
		_make_box_collider(pos + b * Vector3(2.28, 0.0, 0.0), rot_y, Vector3(1.15, 4.0, 1.25), 2.0)
		_make_box_collider(pos, rot_y, Vector3(5.6, 0.85, 1.30), 4.25, false)


func _make_box_collider(pos: Vector3, rot_y: float, sz: Vector3, cy: float, blocks_ground: bool = true) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = rot_y
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = sz
	cs.shape = box
	cs.position = Vector3(0.0, cy, 0.0)
	body.add_child(cs)
	_runtime_root.add_child(body)
	if blocks_ground:
		_obstacle_obbs.append({"center": Vector2(pos.x, pos.z), "hx": sz.x * 0.5, "hz": sz.z * 0.5, "rot_y": rot_y})


func _add_omni(pos: Vector3, col: Color, energy: float, rng: float, shadows: bool = false) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadows
	l.position = pos
	_runtime_root.add_child(l)


func _spawn_biome_lights(biome_id: String, biome_cfg: Dictionary) -> void:
	var accent := Color.html(str(biome_cfg.get("accent_hex", "#38BDF8")))
	if biome_id == "mothership_interior":
		_add_omni(Vector3(0.0, 15.2, 0.0), Color(0.32, 0.90, 1.0), 22.0, 56.0, true)
		for p in [Vector3(-22, 14.5, -18), Vector3(22, 14.5, -18), Vector3(-22, 14.5, 16), Vector3(22, 14.5, 16)]:
			_add_omni(p, Color(0.45, 0.76, 1.0), 9.5, 36.0)
		_add_omni(Vector3(0.0, 5.2, -16.0), Color(0.24, 0.84, 1.0), 5.0, 26.0)
		_add_omni(Vector3(-22.0, 5.5, -6.0), Color(1.0, 0.50, 0.16), 4.2, 22.0)
		_add_omni(Vector3(22.0, 5.5, -6.0), Color(1.0, 0.50, 0.16), 4.2, 22.0)
		return
	if biome_id == "volcanic_caldera":
		for p in [Vector3(-24, 2.2, -22), Vector3(24, 2.2, -22), Vector3(-24, 2.2, 20), Vector3(24, 2.2, 20), Vector3(0, 3.0, -32)]:
			_add_omni(p, Color(1.0, 0.34, 0.05), 8.5, 34.0)
		return
	var energy := 3.4 if biome_id == "cryo_glacier" else 2.2
	for p in [Vector3(-16, 4.8, -16), Vector3(16, 4.8, -16), Vector3(-16, 4.8, 16), Vector3(16, 4.8, 16)]:
		_add_omni(p, accent, energy, 24.0)


func _spawn_barrels(open_spots: Array[Vector3], rng_seed: int) -> void:
	if open_spots.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed + 4242
	for i in range(open_spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := open_spots[i]
		open_spots[i] = open_spots[j]
		open_spots[j] = tmp
	var count := mini(6, open_spots.size())
	for k in range(count):
		var pos := open_spots[k]
		var barrel := ExplosiveBarrelRef.new()
		barrel.position = pos
		_runtime_root.add_child(barrel)
		_barrels.append(barrel)
		_obstacle_obbs.append({"center": Vector2(pos.x, pos.z), "hx": 0.75, "hz": 0.75, "rot_y": 0.0})
