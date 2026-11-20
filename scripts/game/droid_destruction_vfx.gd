class_name DroidDestructionVFX
extends RefCounted
## Spawns robot explosion bursts, spark showers, scorch marks, and pooled RigidBody3D parts using shared cached resources.

const MAX_DEBRIS_PIECES := 36

static var _rng := RandomNumberGenerator.new()
static var _seeded := false
static var _cache_ready := false
static var _orb_mesh: SphereMesh
static var _spark_mesh: BoxMesh
static var _scorch_mesh: CylinderMesh
static var _scorch_mat: StandardMaterial3D
static var _chunk_meshes: Dictionary = {}
static var _chunk_shapes: Dictionary = {}
static var _mats: Dictionary = {}


static func has_shared_cache() -> bool:
	return _cache_ready and _orb_mesh != null and _spark_mesh != null and not _chunk_meshes.is_empty()


static func warmup(scene_root: Node) -> void:
	_ensure_shared_cache()
	if scene_root == null or not scene_root.is_inside_tree():
		return
	spawn_explosion_burst(scene_root, Vector3(0.0, -50.0, 0.0), 1.5, Color(1.0, 0.55, 0.16), 4)


static func _ensure_shared_cache() -> void:
	if _cache_ready:
		return
	_cache_ready = true
	if not _seeded:
		_rng.randomize()
		_seeded = true
	_orb_mesh = SphereMesh.new()
	_orb_mesh.radius = 0.35
	_orb_mesh.height = 0.70
	_orb_mesh.radial_segments = 12
	_orb_mesh.rings = 6
	_spark_mesh = BoxMesh.new()
	_spark_mesh.size = Vector3(0.035, 0.035, 0.22)
	_scorch_mesh = CylinderMesh.new()
	_scorch_mesh.top_radius = 1.0
	_scorch_mesh.bottom_radius = 1.0
	_scorch_mesh.height = 0.02
	_scorch_mesh.radial_segments = 12
	_scorch_mesh.rings = 1
	_scorch_mat = StandardMaterial3D.new()
	_scorch_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_scorch_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_scorch_mat.albedo_color = Color(0.05, 0.05, 0.07, 0.58)

	for tag in ["small", "tall"]:
		var sc := 1.25 if tag == "tall" else 0.95
		var head := BoxMesh.new()
		head.size = Vector3(0.24, 0.20, 0.26) * sc
		var head_s := BoxShape3D.new()
		head_s.size = head.size
		var limb := CylinderMesh.new()
		limb.top_radius = 0.055 * sc
		limb.bottom_radius = 0.045 * sc
		limb.height = 0.38 * sc
		limb.radial_segments = 8
		limb.rings = 1
		var limb_s := CylinderShape3D.new()
		limb_s.radius = 0.055 * sc
		limb_s.height = limb.height
		var plate := BoxMesh.new()
		plate.size = Vector3(0.28, 0.09, 0.22) * sc
		var plate_s := BoxShape3D.new()
		plate_s.size = plate.size
		_chunk_meshes[tag] = [head, limb, plate]
		_chunk_shapes[tag] = [head_s, limb_s, plate_s]

	_mats["hull_small"] = _make_metal_mat(Color(0.18, 0.20, 0.24), false)
	_mats["core_small"] = _make_metal_mat(Color(0.95, 0.42, 0.12), true)
	_mats["hull_tall"] = _make_metal_mat(Color(0.24, 0.27, 0.32), false)
	_mats["core_tall"] = _make_metal_mat(Color(0.18, 0.82, 0.96), true)


static func spawn_droid_explosion(scene_root: Node, world_pos: Vector3, enemy_id: String, impulse_hint: Vector3 = Vector3.ZERO) -> void:
	if scene_root == null or not scene_root.is_inside_tree():
		return
	_ensure_shared_cache()
	var is_tall := enemy_id == "droid_tall" or enemy_id.begins_with("mech_")
	var center := world_pos + Vector3(0.0, 1.05 if is_tall else 0.58, 0.0)
	var flash_col := Color(0.35, 0.85, 1.0) if is_tall else Color(1.0, 0.55, 0.16)
	spawn_explosion_burst(scene_root, center, 2.8 if is_tall else 2.0, flash_col, 12 if is_tall else 8)
	_spawn_debris_chunks(scene_root, center, is_tall, impulse_hint)


static func spawn_explosion_burst(scene_root: Node, center: Vector3, radius: float, col: Color, spark_count: int = 10) -> void:
	if scene_root == null or not scene_root.is_inside_tree():
		return
	_ensure_shared_cache()

	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 7.5
	light.omni_range = radius * 3.4
	light.light_volumetric_fog_energy = 0.0
	scene_root.add_child(light)
	light.global_position = center
	var ltw := light.create_tween()
	ltw.tween_property(light, "light_energy", 0.0, 0.24)
	ltw.tween_callback(light.queue_free)

	var orb := MeshInstance3D.new()
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.mesh = _orb_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(col.r, col.g, col.b, 0.45)
	orb.material_override = mat
	scene_root.add_child(orb)
	orb.global_position = center
	var tw := orb.create_tween()
	tw.set_parallel(true)
	tw.tween_property(orb, "scale", Vector3.ONE * radius, 0.16)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tw.chain().tween_callback(orb.queue_free)

	_spawn_spark_shower(scene_root, center, col, spark_count, radius)
	_spawn_scorch_ring(scene_root, Vector3(center.x, 0.03, center.z), radius * 0.65)


static func _spawn_debris_chunks(scene_root: Node, center: Vector3, is_tall: bool, impulse_hint: Vector3) -> void:
	var count := 8 if is_tall else 6
	_enforce_debris_cap(scene_root.get_tree(), MAX_DEBRIS_PIECES - count)
	var tag := "tall" if is_tall else "small"
	var meshes: Array = _chunk_meshes[tag]
	var shapes: Array = _chunk_shapes[tag]
	var hull_mat := _mats["hull_" + tag] as StandardMaterial3D
	var core_mat := _mats["core_" + tag] as StandardMaterial3D

	for i in range(count):
		var rb := RigidBody3D.new()
		rb.add_to_group("droid_debris")
		rb.collision_layer = 0
		rb.collision_mask = 1
		rb.mass = 1.4
		var mi := MeshInstance3D.new()
		var cs := CollisionShape3D.new()
		var kind := 0 if i == 0 else (1 if i <= 3 else 2)
		mi.mesh = meshes[kind]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_override = core_mat if (i == 0 or (kind == 2 and i % 2 == 1)) else hull_mat
		cs.shape = shapes[kind]
		rb.add_child(mi)
		rb.add_child(cs)
		scene_root.add_child(rb)
		rb.global_position = center + Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.15, 0.35), _rng.randf_range(-0.25, 0.25))
		var out_dir := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)).normalized()
		if out_dir.length_squared() < 0.01:
			out_dir = Vector3.RIGHT
		rb.linear_velocity = out_dir * _rng.randf_range(3.0, 7.2) + Vector3(0.0, _rng.randf_range(3.8, 7.8), 0.0) + Vector3(impulse_hint.x, 0.0, impulse_hint.z) * 0.35
		rb.angular_velocity = Vector3(_rng.randf_range(-11.0, 11.0), _rng.randf_range(-11.0, 11.0), _rng.randf_range(-11.0, 11.0))

		var dtw := rb.create_tween()
		dtw.tween_interval(_rng.randf_range(2.2, 3.0))
		dtw.tween_property(mi, "scale", Vector3.ZERO, 0.32)
		dtw.tween_callback(rb.queue_free)


static func _enforce_debris_cap(tree: SceneTree, target_max: int) -> void:
	if tree == null:
		return
	var existing := tree.get_nodes_in_group("droid_debris")
	var over := existing.size() - maxi(0, target_max)
	for i in range(mini(over, existing.size())):
		var node := existing[i]
		if is_instance_valid(node):
			node.remove_from_group("droid_debris")
			node.queue_free()


static func _spawn_spark_shower(scene_root: Node, center: Vector3, col: Color, count: int, radius: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(minf(1.0, col.r + 0.3), minf(1.0, col.g + 0.3), minf(1.0, col.b + 0.2), 1.0)
	for _i in range(count):
		var sp := MeshInstance3D.new()
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sp.mesh = _spark_mesh
		sp.material_override = mat
		scene_root.add_child(sp)
		sp.global_position = center
		var dir := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(0.15, 0.95), _rng.randf_range(-1.0, 1.0)).normalized()
		sp.look_at(center + dir, Vector3.UP)
		var stw := sp.create_tween()
		stw.set_parallel(true)
		stw.tween_property(sp, "global_position", center + dir * _rng.randf_range(radius * 0.7, radius * 1.6), 0.24)
		stw.tween_property(sp, "scale", Vector3.ZERO, 0.24)
		stw.chain().tween_callback(sp.queue_free)


static func _spawn_scorch_ring(scene_root: Node, floor_pos: Vector3, radius: float) -> void:
	var disc := MeshInstance3D.new()
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.mesh = _scorch_mesh
	disc.scale = Vector3(radius, 1.0, radius)
	disc.material_override = _scorch_mat
	scene_root.add_child(disc)
	disc.global_position = floor_pos
	var tw := disc.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(disc, "scale", Vector3(0.01, 1.0, 0.01), 0.45)
	tw.tween_callback(disc.queue_free)


static func _make_metal_mat(col: Color, emissive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = 0.82
	m.roughness = 0.34
	if emissive:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 2.0
	return m
