class_name WeaponManager
extends Node3D
## Mounts active 3D weapon mesh into RightHand WeaponSocket and executes hitscan, pellet, rocket, laser, and melee attacks.

const WeaponLoadoutRef := preload("res://scripts/game/weapon_loadout.gd")
const ProjectileRef := preload("res://scripts/game/projectile_controller.gd")
const WeaponVFXRef := preload("res://scripts/game/weapon_vfx.gd")
const WeaponPoolRef := preload("res://scripts/game/weapon_pool_helper.gd")

signal shot_hit(is_crit: bool, is_kill: bool)
signal shot_executed(weapon_id: String)

@export var projectile_parent_path: NodePath

var _loadout: WeaponLoadoutRef
var _owner_player: Node3D
var _weapon_socket: Node3D
var _active_visual: Node3D
var _muzzle_node: Node3D
var _projectiles_parent: Node3D
var _fps_viewmodel: Node3D
var _is_fps_mode: bool = false
var _rng := RandomNumberGenerator.new()
var _tps_pool := WeaponPoolRef.new()


func _ready() -> void:
	_rng.randomize()
	if not projectile_parent_path.is_empty():
		_projectiles_parent = get_node_or_null(projectile_parent_path) as Node3D


func setup(loadout: WeaponLoadoutRef, owner_player: Node3D, proj_parent: Node3D = null) -> void:
	_loadout = loadout
	_owner_player = owner_player
	if proj_parent != null:
		_projectiles_parent = proj_parent
	_prewarm_pools()
	refresh_equipped_mesh()


func set_weapon_socket(socket: Node3D) -> void:
	_weapon_socket = socket
	_prewarm_pools()
	refresh_equipped_mesh()


func get_pooled_weapon_count() -> int:
	return _tps_pool.get_count()


func set_fps_context(fps_mode: bool, viewmodel: Node3D) -> void:
	_is_fps_mode = fps_mode
	_fps_viewmodel = viewmodel
	_apply_tps_weapon_shadow_mode()
	_prewarm_pools()
	if _fps_viewmodel != null and _loadout != null and _fps_viewmodel.has_method("set_weapon"):
		_fps_viewmodel.call("set_weapon", _loadout.get_selected_def())


func refresh_equipped_mesh() -> void:
	if _loadout == null:
		return
	var def := _loadout.get_selected_def()
	if _fps_viewmodel != null and _fps_viewmodel.has_method("set_weapon"):
		_fps_viewmodel.call("set_weapon", def)
	if _weapon_socket == null:
		return
	var entry := _tps_pool.activate(def, _weapon_socket, false)
	_active_visual = entry.get("node") as Node3D
	_muzzle_node = entry.get("muzzle") as Node3D
	if _active_visual != null:
		_apply_tps_weapon_shadow_mode()


func _prewarm_pools() -> void:
	if _loadout == null:
		return
	var db: Variant = _loadout.get("_db")
	if db == null or not db.has_method("get_all_weapons"):
		return
	var defs: Array = db.call("get_all_weapons")
	if _weapon_socket != null:
		_tps_pool.prewarm_all(defs, _weapon_socket, false)
	if _fps_viewmodel != null and _fps_viewmodel.has_method("prewarm_weapons"):
		_fps_viewmodel.call("prewarm_weapons", defs)


func execute_shot(shot: Dictionary, aim_data: Dictionary) -> void:
	var delivery := str(shot.get("delivery", "hitscan"))
	var muzzle_pos := _get_muzzle_world_position(shot)
	var ray_origin := _get_combat_ray_origin(muzzle_pos, aim_data)
	var target: Vector3 = aim_data.get("target", ray_origin + Vector3.FORWARD * 30.0)
	var base_dir := (target - ray_origin).normalized()
	if base_dir.length_squared() < 0.01:
		base_dir = aim_data.get("forward", Vector3.FORWARD)
	var scene_root := get_tree().current_scene if is_inside_tree() else null
	shot_executed.emit(str(shot.get("id", "pistol")))

	match delivery:
		"hitscan":
			_fire_hitscan_ray(ray_origin, muzzle_pos, apply_spread(base_dir, float(shot.get("spread_deg", 0.0))), shot, Color(1.0, 0.85, 0.35))
			WeaponVFXRef.spawn_muzzle_flash(scene_root, muzzle_pos, Color(1.0, 0.85, 0.35))
		"hitscan_pellets":
			var pellets := int(shot.get("pellets", 8))
			var spread := float(shot.get("spread_deg", 6.8))
			for _i in range(pellets):
				_fire_hitscan_ray(ray_origin, muzzle_pos, apply_spread(base_dir, spread), shot, Color(1.0, 0.65, 0.25))
			WeaponVFXRef.spawn_muzzle_flash(scene_root, muzzle_pos, Color(1.0, 0.65, 0.25))
		"hitscan_pierce":
			_fire_piercing_laser(ray_origin, muzzle_pos, apply_spread(base_dir, float(shot.get("spread_deg", 0.15))), shot)
			var flash_col := Color(1.0, 0.85, 0.45) if str(shot.get("id", "")) == "sniper" else Color(0.20, 0.95, 1.0)
			WeaponVFXRef.spawn_muzzle_flash(scene_root, muzzle_pos, flash_col)
		"projectile_explosive":
			var rocket_origin := ray_origin + base_dir * 0.55
			_spawn_rocket(rocket_origin, apply_spread(base_dir, float(shot.get("spread_deg", 0.4))), shot)
			WeaponVFXRef.spawn_muzzle_flash(scene_root, muzzle_pos, Color(1.0, 0.5, 0.15))
		"melee_cone":
			_execute_melee_cone(shot, aim_data.get("forward", Vector3.FORWARD))


func apply_spread(dir: Vector3, spread_deg: float) -> Vector3:
	if spread_deg <= 0.0001:
		return dir.normalized()
	var rad := deg_to_rad(spread_deg)
	var right := dir.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	var up := right.cross(dir).normalized()
	return (dir + right * tan(_rng.randf_range(-rad, rad)) + up * tan(_rng.randf_range(-rad, rad))).normalized()


func is_point_in_melee_cone(origin: Vector3, forward: Vector3, point: Vector3, range_m: float, arc_deg: float) -> bool:
	var flat_to := Vector3(point.x - origin.x, 0.0, point.z - origin.z)
	if flat_to.length() > range_m:
		return false
	if flat_to.length_squared() < 0.001:
		return true
	var flat_fwd := Vector3(forward.x, 0.0, forward.z).normalized()
	var cos_half := cos(deg_to_rad(arc_deg * 0.5))
	return flat_fwd.dot(flat_to.normalized()) >= cos_half


func deflect_projectiles_in_cone(projectiles: Array, origin: Vector3, forward: Vector3, range_m: float, arc_deg: float, dmg_mult: float) -> int:
	var count := 0
	for p in projectiles:
		if not is_instance_valid(p) or not (p is ProjectileRef):
			continue
		var pr := p as ProjectileRef
		if pr.is_friendly_to_player():
			continue
		var pos := pr.global_position if pr.is_inside_tree() else pr.position
		if is_point_in_melee_cone(origin, forward, pos, range_m + 0.5, arc_deg):
			pr.deflect(forward, dmg_mult)
			count += 1
	return count


func _fire_hitscan_ray(origin: Vector3, beam_start: Vector3, dir: Vector3, shot: Dictionary, beam_color: Color) -> void:
	if not is_inside_tree():
		return
	var max_r := float(shot.get("range_m", 55.0))
	var end_pos := origin + dir * max_r
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, end_pos, 1 | 4)
	if _owner_player != null:
		q.exclude = [_owner_player.get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		end_pos = hit["position"]
		_apply_ray_hit(hit, origin, dir, shot, true)
	WeaponVFXRef.spawn_beam_fx(get_tree().current_scene, beam_start, end_pos, beam_color, 0.025, 0.08)


func _fire_piercing_laser(origin: Vector3, beam_start: Vector3, dir: Vector3, shot: Dictionary) -> void:
	if not is_inside_tree():
		return
	var max_r := float(shot.get("range_m", 60.0))
	var pierce_left := int(shot.get("pierce_count", 3)) + 1
	var excluded: Array[RID] = []
	if _owner_player != null:
		excluded.append(_owner_player.get_rid())
	var space := get_world_3d().direct_space_state
	var end_pos := origin + dir * max_r
	var cur_start := origin
	while pierce_left > 0:
		var q := PhysicsRayQueryParameters3D.create(cur_start, origin + dir * max_r, 1 | 4)
		q.exclude = excluded
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			end_pos = origin + dir * max_r
			break
		end_pos = hit["position"]
		if not _apply_ray_hit(hit, origin, dir, shot, false):
			break
		excluded.append((hit["collider"] as CollisionObject3D).get_rid())
		cur_start = end_pos + dir * 0.05
		pierce_left -= 1
	var is_sniper := str(shot.get("id", "")) == "sniper"
	var beam_col := Color(1.0, 0.88, 0.55) if is_sniper else Color(0.15, 0.90, 1.0)
	WeaponVFXRef.spawn_beam_fx(get_tree().current_scene, beam_start, end_pos, beam_col, 0.028 if is_sniper else 0.06, 0.16 if is_sniper else 0.10)


func _apply_ray_hit(hit: Dictionary, origin: Vector3, dir: Vector3, shot: Dictionary, use_falloff: bool) -> bool:
	var hp: Vector3 = hit["position"]
	var col: Variant = hit.get("collider", null)
	var dmg_target := _is_damageable(col)
	var is_enemy := col is Node and (col as Node).is_in_group("enemies")
	var is_hs := false
	if dmg_target:
		var dmg := _apply_distance_falloff(float(shot["final_damage"]), origin.distance_to(hp), shot) if use_falloff else float(shot["final_damage"])
		if is_enemy and "headshot_y_threshold" in col and (hp.y - (col as Node3D).global_position.y > float(col.get("headshot_y_threshold"))):
			dmg *= float(shot.get("headshot_multiplier", 1.0))
			is_hs = true
		var will_kill: bool = is_enemy and ("current_hp" in col) and float(col.get("current_hp")) <= dmg
		col.call("take_damage", dmg, dir * float(shot.get("knockback_mps", 2.0)), bool(shot.get("is_crit", false)) or is_hs, str(shot.get("id", "")))
		if is_enemy:
			shot_hit.emit(bool(shot.get("is_crit", false)) or is_hs, will_kill)
	WeaponVFXRef.spawn_hit_sparks(get_tree().current_scene, hp, hit.get("normal", Vector3.UP), (bool(shot.get("is_crit", false)) or is_hs) and is_enemy, dmg_target)
	return is_enemy


func _spawn_rocket(origin: Vector3, dir: Vector3, shot: Dictionary) -> void:
	var parent := _projectiles_parent if _projectiles_parent != null else get_tree().current_scene
	if parent == null:
		return
	var rocket := ProjectileRef.new()
	parent.add_child(rocket)
	rocket.configure_rocket(origin, dir, shot)


func _execute_melee_cone(shot: Dictionary, forward: Vector3) -> void:
	if not is_inside_tree() or _owner_player == null:
		return
	var origin := _owner_player.global_position + Vector3(0.0, 1.25 if _is_fps_mode else 0.95, 0.0)
	var range_m := float(shot.get("range_m", 2.5))
	var arc_deg := float(shot.get("melee_arc_deg", 120.0))
	WeaponVFXRef.spawn_blade_trail(get_tree().current_scene, origin, forward, int(shot.get("combo_step", 1)), str(shot.get("id", "katana")), _is_fps_mode)
	if bool(shot.get("deflects_enemy_projectiles", false)):
		deflect_projectiles_in_cone(get_tree().get_nodes_in_group("enemy_projectiles"), origin, forward, range_m, arc_deg, float(shot.get("deflect_damage_multiplier", 1.75)))

	var hits := 0
	var max_hits := int(shot.get("max_targets_per_swing", 4))
	var armor_mult := float(shot.get("tall_armor_pierce_multiplier", 1.0))
	for e in get_tree().get_nodes_in_group("enemies"):
		if hits >= max_hits or not is_instance_valid(e) or not (e is Node3D):
			continue
		var en := e as Node3D
		if is_point_in_melee_cone(_owner_player.global_position, forward, en.global_position, range_m, arc_deg) and en.has_method("take_damage"):
			var push := (en.global_position - _owner_player.global_position).normalized() * float(shot.get("knockback_mps", 5.0))
			var will_kill: bool = ("current_hp" in en) and float(en.get("current_hp")) <= float(shot["final_damage"]) * armor_mult
			en.call("take_damage", float(shot["final_damage"]), push, bool(shot.get("is_crit", false)), str(shot.get("id", "")), armor_mult)
			shot_hit.emit(bool(shot.get("is_crit", false)), will_kill)
			WeaponVFXRef.spawn_hit_sparks(get_tree().current_scene, en.global_position + Vector3(0.0, 0.8, 0.0), -forward, bool(shot.get("is_crit", false)), true)
			hits += 1
	for prop in get_tree().get_nodes_in_group("damageable_props"):
		if prop is Node3D and is_instance_valid(prop) and is_point_in_melee_cone(_owner_player.global_position, forward, (prop as Node3D).global_position, range_m, arc_deg) and prop.has_method("take_damage"):
			prop.call("take_damage", float(shot["final_damage"]), forward * 4.0, false, str(shot.get("id", "")))

func _is_damageable(col: Variant) -> bool:
	return col is Node and col.has_method("take_damage") and ((col as Node).is_in_group("enemies") or (col as Node).is_in_group("damageable_props"))


func _apply_distance_falloff(dmg: float, dist: float, shot: Dictionary) -> float:
	var start := float(shot.get("falloff_start_m", 999.0))
	var max_r := float(shot.get("range_m", 55.0))
	if dist <= start:
		return dmg
	return dmg * lerpf(1.0, float(shot.get("falloff_min_multiplier", 1.0)), clampf((dist - start) / maxf(0.1, max_r - start), 0.0, 1.0))

func _get_combat_ray_origin(muzzle_fallback: Vector3, aim_data: Dictionary = {}) -> Vector3:
	if _is_fps_mode and aim_data.has("origin"):
		return aim_data["origin"]
	if _owner_player != null and _owner_player.is_inside_tree():
		return _owner_player.global_position + Vector3(0.0, 0.94, 0.0)
	return muzzle_fallback

func _get_muzzle_world_position(_shot: Dictionary) -> Vector3:
	var def := _loadout.get_selected_def() if _loadout != null else {}
	if _is_fps_mode and _fps_viewmodel != null and _fps_viewmodel.has_method("get_muzzle_world_position"):
		return _fps_viewmodel.call("get_muzzle_world_position", def)
	if _muzzle_node != null and _muzzle_node.is_inside_tree():
		return _muzzle_node.global_position
	var off_arr: Array = def.get("asset_spec", {}).get("muzzle_offset_m", [0.0, 0.06, -0.35])
	if _weapon_socket != null and _weapon_socket.is_inside_tree():
		return _weapon_socket.to_global(Vector3(float(off_arr[0]), float(off_arr[1]), float(off_arr[2])))
	return _owner_player.global_position + Vector3(0.0, 1.3, 0.0) if _owner_player != null else global_position


func _apply_tps_weapon_shadow_mode() -> void:
	if _active_visual != null:
		_set_shadow_recursive(_active_visual, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if _is_fps_mode else GeometryInstance3D.SHADOW_CASTING_SETTING_ON)

func _set_shadow_recursive(node: Node, mode: GeometryInstance3D.ShadowCastingSetting) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).cast_shadow = mode
	for c in node.get_children():
		_set_shadow_recursive(c, mode)
