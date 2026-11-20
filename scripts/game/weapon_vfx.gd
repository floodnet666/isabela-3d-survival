class_name WeaponVFX
extends RefCounted
## Spawns muzzle flashes, tracer beams, hit sparks, and melee slash arcs using shared cached Meshes/Materials.

static var _rng := RandomNumberGenerator.new()
static var _seeded := false
static var _cache_ready := false
static var _muzzle_sphere: SphereMesh
static var _spark_normal_box: BoxMesh
static var _spark_crit_box: BoxMesh
static var _beam_cyl: CylinderMesh
static var _arc_fps: ArrayMesh
static var _arc_tps: ArrayMesh
static var _arc_core_fps: ArrayMesh
static var _arc_core_tps: ArrayMesh


static func has_shared_cache() -> bool:
	return _cache_ready and _muzzle_sphere != null and _spark_normal_box != null and _beam_cyl != null


static func warmup(scene_root: Node) -> void:
	_ensure_shared_meshes()
	if scene_root == null or not scene_root.is_inside_tree():
		return
	var p := Vector3(0.0, -50.0, 0.0)
	spawn_muzzle_flash(scene_root, p, Color(1.0, 0.85, 0.35))
	spawn_hit_sparks(scene_root, p, Vector3.UP, false, true)
	spawn_hit_sparks(scene_root, p, Vector3.UP, true, true)
	spawn_beam_fx(scene_root, p, p + Vector3.FORWARD, Color(0.15, 0.9, 1.0), 0.05, 0.05)


static func _ensure_shared_meshes() -> void:
	if _cache_ready:
		return
	_cache_ready = true
	if not _seeded:
		_rng.randomize()
		_seeded = true
	_muzzle_sphere = SphereMesh.new()
	_muzzle_sphere.radius = 0.095
	_muzzle_sphere.height = 0.19
	_muzzle_sphere.radial_segments = 8
	_muzzle_sphere.rings = 4
	_spark_normal_box = BoxMesh.new()
	_spark_normal_box.size = Vector3(0.024, 0.024, 0.11)
	_spark_crit_box = BoxMesh.new()
	_spark_crit_box.size = Vector3(0.024, 0.024, 0.15)
	_beam_cyl = CylinderMesh.new()
	_beam_cyl.top_radius = 1.0
	_beam_cyl.bottom_radius = 1.0
	_beam_cyl.height = 1.0
	_beam_cyl.radial_segments = 8
	_beam_cyl.rings = 1
	_arc_fps = _build_arc_mesh(0.90, 0.26, 12)
	_arc_tps = _build_arc_mesh(0.98, 0.28, 12)
	_arc_core_fps = _build_arc_mesh(0.92, 0.085, 12)
	_arc_core_tps = _build_arc_mesh(1.00, 0.085, 12)


static func _make_unshaded_mat(col: Color, emission_energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	if emission_energy > 0.0:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.emission_enabled = true
		mat.emission = Color(col.r, col.g, col.b, 1.0)
		mat.emission_energy_multiplier = emission_energy
	return mat


static func spawn_muzzle_flash(scene_root: Node, pos: Vector3, col: Color) -> void:
	if scene_root == null or not scene_root.is_inside_tree():
		return
	_ensure_shared_meshes()
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 4.2
	l.omni_range = 4.8
	l.light_volumetric_fog_energy = 0.0
	scene_root.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.08)
	tw.tween_callback(l.queue_free)

	var orb := MeshInstance3D.new()
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.mesh = _muzzle_sphere
	var mat := _make_unshaded_mat(Color(minf(1.0, col.r + 0.25), minf(1.0, col.g + 0.25), minf(1.0, col.b + 0.25), 0.95))
	orb.material_override = mat
	scene_root.add_child(orb)
	orb.global_position = pos
	var otw := orb.create_tween()
	otw.set_parallel(true)
	otw.tween_property(orb, "scale", Vector3(2.2, 2.2, 2.2), 0.07)
	otw.tween_property(mat, "albedo_color:a", 0.0, 0.075)
	otw.chain().tween_callback(orb.queue_free)


static func spawn_hit_sparks(scene_root: Node, hit_pos: Vector3, hit_normal: Vector3, is_crit: bool = false, is_metal: bool = true) -> void:
	if scene_root == null or not scene_root.is_inside_tree():
		return
	_ensure_shared_meshes()
	var nrm := hit_normal.normalized() if hit_normal.length_squared() > 0.01 else Vector3.UP
	var count := 10 if is_crit else (5 if is_metal else 3)
	var base_col := Color(0.28, 0.95, 1.0, 1.0) if is_crit else (Color(1.0, 0.72, 0.22, 1.0) if is_metal else Color(0.85, 0.80, 0.65, 0.9))
	var spark_mesh := _spark_crit_box if is_crit else _spark_normal_box
	var shared_mat := _make_unshaded_mat(base_col)

	for _i in range(count):
		var sp := MeshInstance3D.new()
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sp.mesh = spark_mesh
		sp.material_override = shared_mat
		scene_root.add_child(sp)
		sp.global_position = hit_pos
		var jitter := Vector3(_rng.randf_range(-0.85, 0.85), _rng.randf_range(-0.35, 0.95), _rng.randf_range(-0.85, 0.85))
		var dir := (nrm + jitter).normalized()
		if dir.length_squared() < 0.01:
			dir = Vector3.UP
		sp.look_at(hit_pos + dir, Vector3.UP)
		var dist := _rng.randf_range(0.45, 1.15 if is_crit else 0.75)
		var tw := sp.create_tween()
		tw.set_parallel(true)
		tw.tween_property(sp, "global_position", hit_pos + dir * dist, 0.16)
		tw.tween_property(sp, "scale", Vector3.ZERO, 0.18)
		tw.chain().tween_callback(sp.queue_free)


static func spawn_beam_fx(scene_root: Node, from_p: Vector3, to_p: Vector3, col: Color, radius: float, duration: float) -> void:
	var dist := from_p.distance_to(to_p)
	if dist < 0.05 or scene_root == null or not scene_root.is_inside_tree():
		return
	_ensure_shared_meshes()
	var mi := MeshInstance3D.new()
	mi.mesh = _beam_cyl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := _make_unshaded_mat(Color(col.r, col.g, col.b, 0.92))
	mi.material_override = mat
	scene_root.add_child(mi)
	mi.global_position = (from_p + to_p) * 0.5
	mi.look_at(to_p, Vector3.UP)
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	mi.scale = Vector3(radius, dist, radius)
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.tween_callback(mi.queue_free)


static func spawn_blade_trail(scene_root: Node, origin: Vector3, forward: Vector3, combo_step: int, weapon_id: String, is_fps: bool) -> void:
	if scene_root == null or not scene_root.is_inside_tree():
		return
	_ensure_shared_meshes()
	var col := Color(0.28, 0.92, 1.0, 0.95) if weapon_id == "lightsaber" else Color(1.0, 0.28, 0.14, 0.92)
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.mesh = _arc_fps if is_fps else _arc_tps
	var mat := _make_unshaded_mat(col, 2.6)
	mi.material_override = mat
	scene_root.add_child(mi)

	var flat_fwd := Vector3(forward.x, forward.y * 0.55, forward.z).normalized()
	if flat_fwd.length_squared() < 0.01:
		flat_fwd = Vector3.FORWARD
	mi.global_position = origin + (Vector3(0.0, 0.18, 0.0) if is_fps else Vector3(0.0, 0.24, 0.0)) + flat_fwd * (0.68 if is_fps else 0.58)
	mi.look_at(mi.global_position + flat_fwd, Vector3.UP)
	var roll_deg := 34.0 if combo_step == 2 else (-86.0 if combo_step >= 3 else -34.0)
	mi.rotate_object_local(Vector3.FORWARD, deg_to_rad(roll_deg))
	mi.rotate_object_local(Vector3.RIGHT, deg_to_rad(28.0 if is_fps else 34.0))
	mi.scale = Vector3(0.75, 0.75, 0.75)

	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.24, 1.24, 1.24), 0.17)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.19)
	tw.chain().tween_callback(mi.queue_free)

	var core := MeshInstance3D.new()
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.mesh = _arc_core_fps if is_fps else _arc_core_tps
	var cmat := _make_unshaded_mat(Color(1.0, 1.0, 1.0, 0.92))
	core.material_override = cmat
	mi.add_child(core)
	core.create_tween().tween_property(cmat, "albedo_color:a", 0.0, 0.12)
	spawn_hit_sparks(scene_root, origin + flat_fwd * 0.95, Vector3.UP, weapon_id == "lightsaber", true)


static func _build_arc_mesh(radius: float, width: float, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a0 := deg_to_rad(-65.0)
	var a1 := deg_to_rad(65.0)
	var inner_r := radius - width
	for i in range(segs):
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var th0 := lerpf(a0, a1, t0)
		var th1 := lerpf(a0, a1, t1)
		var r_in0 := lerpf(radius, inner_r, sin(t0 * PI))
		var r_in1 := lerpf(radius, inner_r, sin(t1 * PI))
		var o0 := Vector3(sin(th0) * radius, 0.0, -cos(th0) * radius)
		var i0 := Vector3(sin(th0) * r_in0, 0.0, -cos(th0) * r_in0)
		var o1 := Vector3(sin(th1) * radius, 0.0, -cos(th1) * radius)
		var i1 := Vector3(sin(th1) * r_in1, 0.0, -cos(th1) * r_in1)
		st.add_vertex(o0)
		st.add_vertex(o1)
		st.add_vertex(i1)
		st.add_vertex(o0)
		st.add_vertex(i1)
		st.add_vertex(i0)
	return st.commit()
