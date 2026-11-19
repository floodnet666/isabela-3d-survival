class_name ArenaElevators
extends Node3D
## Slow-moving vertical sci-fi elevator platforms around the playable arena with anti-crush & anti-trap protection.

const PLATFORM_SIZE := Vector3(4.2, 0.45, 4.2)
const MIN_Y := 0.35
const MAX_Y := 4.2
const CYCLE_SPEED_RAD := 0.35

const PLATFORM_DEFS := [
	{"pos": Vector3(15.5, 0.0, 1.0), "phase": 0.0, "color": Color(0.12, 0.88, 1.0)},
	{"pos": Vector3(-15.5, 0.0, -1.0), "phase": PI * 0.5, "color": Color(1.0, 0.52, 0.14)},
	{"pos": Vector3(0.0, 0.0, 16.0), "phase": PI, "color": Color(0.12, 0.88, 1.0)},
	{"pos": Vector3(0.0, 0.0, -12.2), "phase": PI * 1.5, "color": Color(1.0, 0.52, 0.14)},
]

var _platforms: Array[Dictionary] = []
var _time: float = 0.0
var _built: bool = false


func _init() -> void:
	name = "ArenaElevators"
	add_to_group("arena_elevators")


func _ready() -> void:
	build_elevators()


func build_elevators() -> void:
	if _built:
		return
	_built = true

	var deck_mat := StandardMaterial3D.new()
	deck_mat.albedo_color = Color(0.14, 0.17, 0.22)
	deck_mat.metallic = 0.85
	deck_mat.roughness = 0.30

	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.09, 0.11, 0.15)
	pad_mat.metallic = 0.70
	pad_mat.roughness = 0.45

	for pdef in PLATFORM_DEFS:
		var base_pos: Vector3 = pdef["pos"]
		var phase: float = float(pdef["phase"])
		var rim_col: Color = pdef["color"]

		var rim_mat := StandardMaterial3D.new()
		rim_mat.albedo_color = rim_col
		rim_mat.emission_enabled = true
		rim_mat.emission = rim_col
		rim_mat.emission_energy_multiplier = 2.4

		var body := AnimatableBody3D.new()
		body.sync_to_physics = true
		body.collision_layer = 1
		body.collision_mask = 0
		body.add_to_group("elevator_platforms")
		body.position = Vector3(base_pos.x, _compute_y(phase, 0.0), base_pos.z)
		add_child(body)

		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = PLATFORM_SIZE
		cs.shape = box
		cs.position = Vector3(0.0, -PLATFORM_SIZE.y * 0.5, 0.0)
		body.add_child(cs)

		var deck := MeshInstance3D.new()
		var dmesh := BoxMesh.new()
		dmesh.size = PLATFORM_SIZE
		deck.mesh = dmesh
		deck.position = Vector3(0.0, -PLATFORM_SIZE.y * 0.5, 0.0)
		deck.material_override = deck_mat
		body.add_child(deck)

		var rim := MeshInstance3D.new()
		var rmesh := BoxMesh.new()
		rmesh.size = Vector3(PLATFORM_SIZE.x + 0.14, 0.14, PLATFORM_SIZE.z + 0.14)
		rim.mesh = rmesh
		rim.position = Vector3(0.0, -0.09, 0.0)
		rim.material_override = rim_mat
		body.add_child(rim)

		var pad := MeshInstance3D.new()
		var pmesh := BoxMesh.new()
		pmesh.size = Vector3(PLATFORM_SIZE.x - 0.5, 0.04, PLATFORM_SIZE.z - 0.5)
		pad.mesh = pmesh
		pad.position = Vector3(base_pos.x, 0.02, base_pos.z)
		pad.material_override = pad_mat
		add_child(pad)

		_platforms.append({
			"body": body,
			"base_xz": Vector2(base_pos.x, base_pos.z),
			"phase": phase,
			"half_extent": Vector2(PLATFORM_SIZE.x * 0.5, PLATFORM_SIZE.z * 0.5),
		})


func _physics_process(delta: float) -> void:
	_time += delta
	for p in _platforms:
		var body := p["body"] as AnimatableBody3D
		if is_instance_valid(body):
			var xz: Vector2 = p["base_xz"]
			var prev_y := body.position.y
			var new_y := _compute_y(float(p["phase"]), _time)
			_protect_entities_under_platform(body, p["half_extent"] as Vector2, prev_y, new_y, delta)
			body.position = Vector3(xz.x, new_y, xz.y)


func _protect_entities_under_platform(body: AnimatableBody3D, he: Vector2, prev_y: float, new_y: float, delta: float) -> void:
	if not is_inside_tree():
		return
	var top_pos := body.global_position
	var bottom_y := new_y - PLATFORM_SIZE.y
	var descending := new_y < prev_y
	for grp in ["player", "enemies"]:
		for n in get_tree().get_nodes_in_group(grp):
			var cb := n as CharacterBody3D
			if cb == null or not is_instance_valid(cb) or not cb.is_inside_tree():
				continue
			var ep := cb.global_position
			var dx := ep.x - top_pos.x
			var dz := ep.z - top_pos.z
			if absf(dx) > he.x + 0.38 or absf(dz) > he.y + 0.38:
				continue
			# Only act if entity is underneath the deck surface (not standing on top)
			if ep.y >= new_y - 0.16:
				continue
			var clearance := bottom_y - ep.y
			if clearance <= 1.88:
				# Hard anti-trap rescue: push cleanly outside nearest edge or lift onto deck top
				var exit_pos := _compute_edge_exit(top_pos, he, ep)
				if _is_exit_spot_clear(exit_pos):
					cb.global_position = exit_pos
				else:
					cb.global_position = Vector3(ep.x, new_y + 0.12, ep.z)
					cb.velocity.y = maxf(0.0, cb.velocity.y)
			elif descending and clearance <= 2.35:
				# Proactive lateral nudge out from underneath descending platform before contact
				var out_dir := _compute_outward_dir(dx, dz)
				cb.global_position += out_dir * (9.5 * delta)


func _compute_outward_dir(dx: float, dz: float) -> Vector3:
	if absf(dx) < 0.05 and absf(dz) < 0.05:
		return Vector3(1.0, 0.0, 0.0)
	if absf(dx) >= absf(dz):
		return Vector3(1.0 if dx >= 0.0 else -1.0, 0.0, 0.0)
	return Vector3(0.0, 0.0, 1.0 if dz >= 0.0 else -1.0)


func _compute_edge_exit(top_pos: Vector3, he: Vector2, ep: Vector3) -> Vector3:
	var dx := ep.x - top_pos.x
	var dz := ep.z - top_pos.z
	var rem_x := (he.x + 0.72) - absf(dx)
	var rem_z := (he.y + 0.72) - absf(dz)
	if rem_x <= rem_z:
		var sx := 1.0 if dx >= 0.0 else -1.0
		return Vector3(top_pos.x + sx * (he.x + 0.72), maxf(0.06, ep.y), ep.z)
	var sz := 1.0 if dz >= 0.0 else -1.0
	return Vector3(ep.x, maxf(0.06, ep.y), top_pos.z + sz * (he.y + 0.72))


func _is_exit_spot_clear(pos: Vector3) -> bool:
	var w3d := get_world_3d()
	if w3d == null or w3d.direct_space_state == null:
		return true
	var q := PhysicsShapeQueryParameters3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.42
	cyl.height = 1.5
	q.shape = cyl
	q.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0.0, 0.95, 0.0))
	q.collision_mask = 1
	return w3d.direct_space_state.intersect_shape(q, 1).is_empty()


func get_platform_count() -> int:
	return _platforms.size()


func is_in_platform_footprint(world_pos: Vector3, margin: float = 0.6) -> bool:
	for pdef in PLATFORM_DEFS:
		var c: Vector3 = pdef["pos"]
		if absf(world_pos.x - c.x) <= PLATFORM_SIZE.x * 0.5 + margin and absf(world_pos.z - c.z) <= PLATFORM_SIZE.z * 0.5 + margin:
			return true
	return false


func get_ranged_spawn_position(rng: RandomNumberGenerator) -> Vector3:
	if _platforms.is_empty():
		return Vector3.ZERO
	var idx := rng.randi_range(0, _platforms.size() - 1) if rng != null else 0
	var body := _platforms[idx]["body"] as AnimatableBody3D
	if not is_instance_valid(body):
		return Vector3.ZERO
	var ox := rng.randf_range(-0.9, 0.9) if rng != null else 0.0
	var oz := rng.randf_range(-0.9, 0.9) if rng != null else 0.0
	var top_pos := body.global_position if body.is_inside_tree() else body.position
	return top_pos + Vector3(ox, 0.08, oz)


func is_on_elevator(world_pos: Vector3, margin: float = 0.35) -> bool:
	for p in _platforms:
		var body := p["body"] as AnimatableBody3D
		if not is_instance_valid(body):
			continue
		var top_pos := body.global_position if body.is_inside_tree() else body.position
		var he: Vector2 = p["half_extent"]
		if absf(world_pos.x - top_pos.x) <= he.x + margin and absf(world_pos.z - top_pos.z) <= he.y + margin:
			if world_pos.y >= top_pos.y - 0.5 and world_pos.y <= top_pos.y + 2.5:
				return true
	return false


func _compute_y(phase: float, t: float) -> float:
	var mid := (MIN_Y + MAX_Y) * 0.5
	var amp := (MAX_Y - MIN_Y) * 0.5
	return mid + sin(t * CYCLE_SPEED_RAD + phase) * amp
