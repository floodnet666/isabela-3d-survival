class_name ArenaProps
extends Node3D
## Builds photorealistic Sci-Fi Mirror Coast tactical cover, comms pylons, wet basalt shore rocks, wreckage details, and explosive barrels.

const ExplosiveBarrelRef := preload("res://scripts/game/explosive_barrel.gd")
const MaterialLibRef := preload("res://scripts/game/biome_material_library.gd")

const HELMET_A_PATH := "res://assets/SM_Helmet_A/SM_Helmet_A.glb"
const HELMET_B_PATH := "res://assets/SM_Helmet_B/SM_Helmet_B.glb"
const COAST_BARRIER_PATH := "res://assets/ENV_CoastProps/SM_CoastBarrier.glb"
const COAST_CRATE_PATH := "res://assets/ENV_CoastProps/SM_CoastCrate.glb"
const COAST_PYLON_PATH := "res://assets/ENV_CoastProps/SM_CoastPylon.glb"
const COAST_ROCKS_PATH := "res://assets/ENV_CoastProps/SM_CoastRockCluster.glb"

var _obstacle_footprints: Array[Dictionary] = []
var _barrels: Array[ExplosiveBarrelRef] = []
var _built: bool = false


func _ready() -> void:
	build_arena_props()


func build_arena_props() -> void:
	if _built:
		return
	_built = true
	_build_tactical_covers()
	_build_comms_pylons()
	_build_coast_rocks()
	_build_wreckage_details()
	_spawn_explosive_barrels()


func get_barrels() -> Array[ExplosiveBarrelRef]:
	return _barrels


func is_position_clear(world_pos: Vector3, margin_m: float = 1.5) -> bool:
	var p2 := Vector2(world_pos.x, world_pos.z)
	for fp in _obstacle_footprints:
		var c: Vector2 = fp["center"]
		var r: float = float(fp["radius"]) + margin_m
		if p2.distance_to(c) < r:
			return false
	return true


func set_props_active(active: bool) -> void:
	visible = active
	for node in find_children("*", "CollisionShape3D", true, false):
		(node as CollisionShape3D).disabled = not active
	for co in find_children("*", "CollisionObject3D", true, false):
		var obj := co as CollisionObject3D
		if not obj.has_meta("_orig_col_layer"):
			obj.set_meta("_orig_col_layer", obj.collision_layer)
		obj.collision_layer = int(obj.get_meta("_orig_col_layer")) if active else 0


func _spawn_pbr_glb(parent: Node3D, path: String, scale_v: Vector3 = Vector3.ONE) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var ps := load(path) as PackedScene
	if ps == null:
		return false
	var inst := ps.instantiate() as Node3D
	if inst == null:
		return false
	inst.scale = scale_v
	MaterialLibRef.apply_to_node(inst)
	parent.add_child(inst)
	return true


func _build_tactical_covers() -> void:
	var hull := _make_mat(Color(0.16, 0.19, 0.24), 0.78, 0.36)
	var trim_cyan := _make_emissive_mat(Color(0.12, 0.88, 1.0), 2.2)
	var trim_amber := _make_emissive_mat(Color(1.0, 0.52, 0.14), 1.9)

	var barriers := [
		{"pos": Vector3(-8.2, 0.0, -5.8), "yaw": 28.0, "size": Vector3(3.6, 1.22, 0.65), "trim": trim_cyan},
		{"pos": Vector3(8.5, 0.0, -4.6), "yaw": -32.0, "size": Vector3(3.6, 1.22, 0.65), "trim": trim_cyan},
		{"pos": Vector3(-7.4, 0.0, 7.6), "yaw": -24.0, "size": Vector3(3.4, 1.18, 0.65), "trim": trim_amber},
		{"pos": Vector3(7.9, 0.0, 7.2), "yaw": 34.0, "size": Vector3(3.4, 1.18, 0.65), "trim": trim_amber},
	]
	for b in barriers:
		_add_static_prop(b["pos"], float(b["yaw"]), b["size"], COAST_BARRIER_PATH, Vector3(3.6, 1.22, 0.65), hull, b["trim"])

	var crates := [
		{"pos": Vector3(-14.8, 0.0, -11.5), "yaw": 18.0, "size": Vector3(2.5, 1.75, 2.2), "trim": trim_amber},
		{"pos": Vector3(15.2, 0.0, -12.0), "yaw": -14.0, "size": Vector3(2.6, 1.85, 2.1), "trim": trim_cyan},
		{"pos": Vector3(0.4, 0.0, -16.8), "yaw": 8.0, "size": Vector3(4.8, 1.55, 1.15), "trim": trim_cyan},
		{"pos": Vector3(-13.5, 0.0, 13.0), "yaw": 48.0, "size": Vector3(2.4, 1.65, 2.0), "trim": trim_cyan},
		{"pos": Vector3(14.0, 0.0, 12.6), "yaw": -42.0, "size": Vector3(2.4, 1.65, 2.0), "trim": trim_amber},
	]
	for c in crates:
		_add_static_prop(c["pos"], float(c["yaw"]), c["size"], COAST_CRATE_PATH, Vector3(2.5, 1.75, 2.1), hull, c["trim"])


func _build_comms_pylons() -> void:
	var dark_steel := _make_mat(Color(0.11, 0.13, 0.17), 0.85, 0.30)
	var positions := [
		{"pos": Vector3(-18.5, 0.0, -18.0), "col": Color(0.12, 0.88, 1.0)},
		{"pos": Vector3(18.8, 0.0, -17.5), "col": Color(0.95, 0.25, 0.65)},
		{"pos": Vector3(-18.0, 0.0, 17.5), "col": Color(0.12, 0.88, 1.0)},
		{"pos": Vector3(18.2, 0.0, 17.2), "col": Color(1.0, 0.52, 0.16)},
	]
	for p in positions:
		var pos: Vector3 = p["pos"]
		var col: Color = p["col"]
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = pos
		add_child(body)

		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.52
		cyl.height = 5.8
		cs.shape = cyl
		cs.position = Vector3(0.0, 2.9, 0.0)
		body.add_child(cs)

		if not _spawn_pbr_glb(body, COAST_PYLON_PATH, Vector3.ONE):
			var mast := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.68, 5.8, 0.68)
			mast.mesh = bm
			mast.position = Vector3(0.0, 2.9, 0.0)
			mast.material_override = dark_steel
			body.add_child(mast)

		var light := OmniLight3D.new()
		light.light_color = col
		light.light_energy = 2.8
		light.omni_range = 16.0
		light.position = Vector3(0.0, 4.8, 0.0)
		body.add_child(light)
		_obstacle_footprints.append({"center": Vector2(pos.x, pos.z), "radius": 1.0})


func _build_coast_rocks() -> void:
	var clusters := [
		{"pos": Vector3(-12.5, -0.05, -2.5), "yaw": 20.0, "sc": Vector3(1.4, 1.1, 1.4)},
		{"pos": Vector3(13.2, -0.05, -1.8), "yaw": -45.0, "sc": Vector3(1.5, 1.2, 1.3)},
		{"pos": Vector3(-10.8, -0.05, -15.5), "yaw": 75.0, "sc": Vector3(1.8, 1.4, 1.6)},
		{"pos": Vector3(11.4, -0.05, -16.2), "yaw": 120.0, "sc": Vector3(1.6, 1.3, 1.5)},
		{"pos": Vector3(-16.5, -0.05, 8.5), "yaw": -15.0, "sc": Vector3(1.7, 1.2, 1.5)},
	]
	for cl in clusters:
		var holder := Node3D.new()
		holder.position = cl["pos"]
		holder.rotation_degrees = Vector3(0.0, float(cl["yaw"]), 0.0)
		if _spawn_pbr_glb(holder, COAST_ROCKS_PATH, cl["sc"]):
			add_child(holder)
		else:
			holder.queue_free()


func _build_wreckage_details() -> void:
	var placements := [
		{"path": HELMET_A_PATH, "pos": Vector3(-6.1, 0.02, -4.7), "rot": Vector3(14.0, 38.0, -18.0)},
		{"path": HELMET_B_PATH, "pos": Vector3(2.6, 0.02, -15.3), "rot": Vector3(-12.0, -52.0, 20.0)},
	]
	for item in placements:
		var path: String = str(item["path"])
		if not ResourceLoader.exists(path):
			continue
		var ps := load(path) as PackedScene
		if ps == null:
			continue
		var inst := ps.instantiate() as Node3D
		if inst != null:
			inst.position = item["pos"]
			inst.rotation_degrees = item["rot"]
			for m in inst.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(inst)


func _spawn_explosive_barrels() -> void:
	var spots := [
		Vector3(-5.2, 0.0, -9.2),
		Vector3(-8.4, 0.0, -10.4),
		Vector3(5.6, 0.0, -8.8),
		Vector3(8.8, 0.0, -10.1),
		Vector3(-10.2, 0.0, 4.6),
		Vector3(10.5, 0.0, 4.2),
	]
	for pos in spots:
		var barrel := ExplosiveBarrelRef.new()
		barrel.position = pos
		add_child(barrel)
		_barrels.append(barrel)
		_obstacle_footprints.append({"center": Vector2(pos.x, pos.z), "radius": 0.9})


func _add_static_prop(pos: Vector3, yaw_deg: float, size: Vector3, glb_path: String, ref_sz: Vector3, hull_mat: StandardMaterial3D, trim_mat: StandardMaterial3D) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.position = pos
	sb.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	add_child(sb)

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = Vector3(0.0, size.y * 0.5, 0.0)
	sb.add_child(cs)

	var sc := Vector3(size.x / ref_sz.x, size.y / ref_sz.y, size.z / ref_sz.z)
	if not _spawn_pbr_glb(sb, glb_path, sc):
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		body.mesh = bm
		body.position = Vector3(0.0, size.y * 0.5, 0.0)
		body.material_override = hull_mat
		sb.add_child(body)
		var strip := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(size.x + 0.04, 0.09, size.z + 0.04)
		strip.mesh = sm
		strip.position = Vector3(0.0, size.y * 0.78, 0.0)
		strip.material_override = trim_mat
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sb.add_child(strip)

	var footprint_r := Vector2(size.x * 0.5, size.z * 0.5).length() + 0.35
	_obstacle_footprints.append({"center": Vector2(pos.x, pos.z), "radius": footprint_r})


func _make_mat(col: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metallic
	m.roughness = roughness
	return m


func _make_emissive_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m
