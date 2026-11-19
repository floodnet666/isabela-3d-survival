class_name WaveSpawner
extends Node3D
## Spawns escalating Small/Tall droid and mech waves around clear arena spots (OBB + 3D physics verified) and manages crate drops.

const BalanceDBRef := preload("res://scripts/game/balance_db.gd")
const PickupCrateRef := preload("res://scripts/game/pickup_crate.gd")
const BossSentinelScene := preload("res://scenes/game/boss_sentinel.tscn")
const OrbitalDropPodRef := preload("res://scripts/game/orbital_drop_pod.gd")
const ArenaElevatorsRef := preload("res://scripts/game/arena_elevators.gd")

signal enemy_spawned(enemy: Node3D)
signal boss_spawned(boss: Node3D, wave: int, display_name: String)
signal crate_spawned(crate: Node3D)
signal pod_destroyed_bonus(xp: int)

@export var droid_small_scene: PackedScene
@export var droid_tall_scene: PackedScene
@export var crate_scene: PackedScene

const MECH_SCENES := {
	"mech_leela": preload("res://scenes/game/mech_leela.tscn"),
	"mech_mike": preload("res://scenes/game/mech_mike.tscn"),
	"mech_stan": preload("res://scenes/game/mech_stan.tscn"),
	"mech_george": preload("res://scenes/game/mech_george.tscn"),
}

var _db: BalanceDBRef
var _entities_root: Node3D
var _player: Node3D
var _ship: Node3D
var _arena_props: Node
var _rng := RandomNumberGenerator.new()

var _queue: Array[String] = []
var _spawn_timer: float = 0.0
var _spawn_interval: float = 1.2
var _max_concurrent: int = 10
var _current_wave_spec: Dictionary = {}
var _active_enemies: Array[Node3D] = []
var _active_crates: Array[Node3D] = []


func _ready() -> void:
	_rng.randomize()


func setup(balance_db: BalanceDBRef, entities_root: Node3D, player: Node3D, ship: Node3D = null, arena_props: Node = null) -> void:
	_db = balance_db; _entities_root = entities_root; _player = player; _ship = ship; _arena_props = arena_props


func set_rng_seed(seed_val: int) -> void:
	_rng.seed = seed_val


func get_pending_spawn_count() -> int:
	return _queue.size()


func get_active_enemy_count() -> int:
	_prune_dead(_active_enemies)
	return _active_enemies.size()


func queue_wave(wave_spec: Dictionary) -> void:
	_current_wave_spec = wave_spec
	_queue.clear()
	for _i in range(int(wave_spec.get("small_count", 0))): _queue.append("droid_small")
	for _j in range(int(wave_spec.get("tall_count", 0))): _queue.append("droid_tall")
	var mech_counts: Dictionary = wave_spec.get("mech_counts", {})
	for mech_id in mech_counts.keys():
		for _m in range(int(mech_counts[mech_id])): _queue.append(str(mech_id))
	for idx in range(_queue.size() - 1, 0, -1):
		var swap_idx := _rng.randi_range(0, idx)
		var tmp := _queue[idx]; _queue[idx] = _queue[swap_idx]; _queue[swap_idx] = tmp
	if bool(wave_spec.get("is_boss_wave", false)):
		_queue.push_front("boss:" + str(wave_spec.get("boss_id", "valkyrie_skull")))
	_spawn_interval = float(wave_spec.get("spawn_interval_s", 1.0))
	_max_concurrent = int(wave_spec.get("max_concurrent", 12))
	_spawn_timer = 0.25


func spawn_ambient_wave_crate() -> void:
	if _db == null or _entities_root == null: return
	_prune_dead(_active_crates)
	if _active_crates.size() >= int(_db.get_arena_cfg().get("max_active_crates", 4)): return
	for _attempt in range(20):
		var angle := _rng.randf_range(0.0, TAU)
		var radius := _rng.randf_range(6.0, 16.0)
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		if _is_spot_clear(pos, 1.35):
			_instantiate_crate(choose_crate_type(0.55, 0.55), pos)
			return


func _process(delta: float) -> void:
	if _queue.is_empty() or _entities_root == null: return
	_prune_dead(_active_enemies)
	if _active_enemies.size() >= _max_concurrent: return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_enemy(_queue.pop_front())
		_spawn_timer = _spawn_interval


func pick_ring_spawn_position(player_pos: Vector3) -> Vector3:
	var arena := _db.get_arena_cfg()
	var r_min := float(arena.get("spawn_ring_min_m", 20.0))
	var r_max := float(arena.get("spawn_ring_max_m", 28.0))
	var min_pd := float(arena.get("min_spawn_distance_from_player_m", 10.0))
	var p_flat := Vector3(player_pos.x, 0.0, player_pos.z)

	for attempt in range(56):
		var theta := _rng.randf_range(0.0, TAU)
		var lo := r_min if attempt < 36 else 9.0
		var r := _rng.randf_range(lo, r_max)
		var cand := Vector3(cos(theta) * r, 0.0, sin(theta) * r)
		if cand.distance_to(p_flat) >= min_pd and _is_spot_clear(cand, 1.35):
			return cand

	# Verified fallback 1: open WFC tile centers farthest from player
	if _arena_props != null and _arena_props.has_method("get_open_tile_centers"):
		var opens: Array = _arena_props.call("get_open_tile_centers")
		var best := Vector3.ZERO
		var best_d := -1.0
		for op_v in opens:
			var op := op_v as Vector3
			if _is_spot_clear(op, 1.1):
				var d := op.distance_to(p_flat)
				if d > best_d:
					best_d = d; best = op
		if best_d >= 0.0:
			return best

	# Verified fallback 2: deterministic polar scan
	for r_step in [24.0, 18.0, 12.0, 6.0]:
		for k in range(16):
			var a := (TAU / 16.0) * float(k)
			var c := Vector3(cos(a) * r_step, 0.0, sin(a) * r_step)
			if _is_spot_clear(c, 0.9):
				return c
	return Vector3(0.0, 0.0, 0.0)


func choose_crate_type(hp_ratio: float, avg_ammo_ratio: float) -> String:
	var w_health := float(_db.get_pickup("health_crate").get("drop_weight_base", 0.45))
	var w_ammo := float(_db.get_pickup("ammo_crate").get("drop_weight_base", 0.55))
	var w_hel := float(_db.get_pickup("helmet_a").get("drop_weight_base", 0.05)) * 2.0
	if hp_ratio < 0.40: w_health *= 3.2; w_hel *= 0.2
	elif hp_ratio > 0.90: w_health *= 0.45
	if avg_ammo_ratio < 0.35: w_ammo *= 2.4
	var roll := _rng.randf_range(0.0, maxf(0.001, w_health + w_ammo + w_hel))
	if roll <= w_health: return "health_crate"
	if roll <= w_health + w_ammo: return "ammo_crate"
	return "helmet_a" if _rng.randf() < 0.5 else "helmet_b"


func maybe_drop_crate_at(world_pos: Vector3, drop_chance: float, hp_ratio: float, avg_ammo_ratio: float) -> void:
	if _entities_root == null or _rng.randf() > drop_chance: return
	_prune_dead(_active_crates)
	if _active_crates.size() >= int(_db.get_arena_cfg().get("max_active_crates", 4)): return
	var pos := _find_nearest_clear(Vector3(world_pos.x, 0.0, world_pos.z), 0.9)
	_instantiate_crate(choose_crate_type(hp_ratio, avg_ammo_ratio), pos)


func _spawn_enemy(enemy_id: String) -> void:
	if enemy_id.begins_with("boss:"):
		_spawn_boss(enemy_id.substr(5)); return
	var scene: PackedScene = MECH_SCENES.get(enemy_id, droid_tall_scene if enemy_id == "droid_tall" else droid_small_scene)
	if scene == null:
		push_error("WaveSpawner: missing PackedScene for '%s'" % enemy_id); return
	var p_pos := _player.global_position if _player != null else Vector3.ZERO
	var spawn_pos := _pick_spawn_position(enemy_id, p_pos)
	var enemy := scene.instantiate() as Node3D
	enemy.position = _entities_root.to_local(spawn_pos) if _entities_root.is_inside_tree() else spawn_pos
	_entities_root.add_child(enemy)
	if enemy.is_inside_tree(): enemy.global_position = spawn_pos
	if enemy.has_method("configure_from_balance"):
		enemy.call("configure_from_balance", enemy_id, _db, _current_wave_spec, _player)
	_active_enemies.append(enemy)
	_spawn_drop_beam_fx(spawn_pos)
	enemy_spawned.emit(enemy)


func _instantiate_crate(crate_id: String, world_pos: Vector3) -> void:
	var crate: Node3D = crate_scene.instantiate() as Node3D if crate_scene != null else PickupCrateRef.new()
	crate.position = _entities_root.to_local(world_pos) if _entities_root.is_inside_tree() else world_pos
	_entities_root.add_child(crate)
	if crate.is_inside_tree(): crate.global_position = world_pos
	if crate.has_method("configure"): crate.call("configure", crate_id, _db.get_pickup(crate_id))
	_active_crates.append(crate)
	crate_spawned.emit(crate)


func _spawn_drop_beam_fx(pos: Vector3) -> void:
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25; cyl.bottom_radius = 0.95; cyl.height = 18.0
	beam.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.55, 0.15, 0.42)
	beam.material_override = mat
	_entities_root.add_child(beam)
	beam.global_position = pos + Vector3(0.0, 9.0, 0.0)
	var tw := beam.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.55)
	tw.tween_callback(beam.queue_free)


func _pick_spawn_position(enemy_id: String, player_pos: Vector3) -> Vector3:
	if (enemy_id == "droid_tall" or enemy_id == "mech_leela" or enemy_id == "mech_george") and _rng.randf() < 0.25 and is_inside_tree():
		var elev := get_tree().get_first_node_in_group("arena_elevators")
		if elev != null and elev.has_method("get_ranged_spawn_position"):
			var ep: Vector3 = elev.call("get_ranged_spawn_position", _rng)
			if ep != Vector3.ZERO and ep.distance_to(player_pos) >= 6.0: return ep
	return pick_ring_spawn_position(player_pos)


func _is_spot_clear(pos: Vector3, margin_m: float) -> bool:
	if _arena_props != null and _arena_props.has_method("is_position_clear") and not bool(_arena_props.call("is_position_clear", pos, margin_m)):
		return false
	var hx := ArenaElevatorsRef.PLATFORM_SIZE.x * 0.5 + margin_m
	var hz := ArenaElevatorsRef.PLATFORM_SIZE.z * 0.5 + margin_m
	for pdef in ArenaElevatorsRef.PLATFORM_DEFS:
		var ep: Vector3 = pdef["pos"]
		if absf(pos.x - ep.x) <= hx and absf(pos.z - ep.z) <= hz: return false
	if is_inside_tree() and get_world_3d() != null and get_world_3d().direct_space_state != null:
		var q := PhysicsShapeQueryParameters3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = maxf(0.60, margin_m * 0.65); cyl.height = 1.65
		q.shape = cyl; q.collision_mask = 1
		q.transform = Transform3D(Basis.IDENTITY, Vector3(pos.x, 1.05, pos.z))
		if not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty(): return false
	return true


func _find_nearest_clear(world_pos: Vector3, margin_m: float) -> Vector3:
	var base := Vector3(world_pos.x, 0.0, world_pos.z)
	if _is_spot_clear(base, margin_m): return base
	for rad in [1.8, 3.4, 5.2]:
		for k in range(12):
			var a := (TAU / 12.0) * float(k)
			var c := base + Vector3(cos(a) * rad, 0.0, sin(a) * rad)
			if c.length() <= 29.0 and _is_spot_clear(c, margin_m): return c
	return pick_ring_spawn_position(_player.global_position if _player != null else Vector3.ZERO)


func _spawn_boss(boss_id: String) -> void:
	if _entities_root == null or BossSentinelScene == null: return
	var spawn_pos := pick_ring_spawn_position(_player.global_position if _player != null else Vector3.ZERO)
	var boss := BossSentinelScene.instantiate() as Node3D
	boss.position = _entities_root.to_local(spawn_pos) if _entities_root.is_inside_tree() else spawn_pos
	_entities_root.add_child(boss)
	if boss.is_inside_tree(): boss.global_position = spawn_pos
	if boss.has_method("configure_from_balance"): boss.call("configure_from_balance", boss_id, _db, _current_wave_spec, _player)
	_active_enemies.append(boss); _spawn_drop_beam_fx(spawn_pos); enemy_spawned.emit(boss)
	var dname := str(boss.get("display_name")) if "display_name" in boss else boss_id
	boss_spawned.emit(boss, int(_current_wave_spec.get("wave", 5)), dname)


func spawn_capsule_rain(count: int, wave: int) -> void:
	if _db != null and _entities_root != null:
		OrbitalDropPodRef.spawn_rain(self, _entities_root, _player, wave, count, _db.get_drop_pod_cfg())


func _spawn_reinforcement_at(enemy_id: String, world_pos: Vector3) -> void:
	var scene: PackedScene = MECH_SCENES.get(enemy_id, droid_small_scene)
	if scene == null or _entities_root == null: return
	var safe_pos := _find_nearest_clear(world_pos, 1.0)
	var e := scene.instantiate() as Node3D
	_entities_root.add_child(e)
	if e.is_inside_tree(): e.global_position = safe_pos
	if e.has_method("configure_from_balance"): e.call("configure_from_balance", enemy_id, _db, _current_wave_spec, _player)
	_active_enemies.append(e); enemy_spawned.emit(e)


func spawn_boss_reward_crates(world_pos: Vector3) -> void:
	if _db == null or _entities_root == null: return
	_instantiate_crate("health_crate", _find_nearest_clear(Vector3(world_pos.x - 1.1, 0.0, world_pos.z), 0.8))
	_instantiate_crate("ammo_crate", _find_nearest_clear(Vector3(world_pos.x + 1.1, 0.0, world_pos.z), 0.8))


func _prune_dead(arr: Array[Node3D]) -> void:
	for i in range(arr.size() - 1, -1, -1):
		if not is_instance_valid(arr[i]) or arr[i].is_queued_for_deletion(): arr.remove_at(i)
