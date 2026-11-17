class_name EnemyDroid
extends CharacterBody3D
## Shared CharacterBody3D AI for SK_Droid_Small (melee rusher) and SK_Droid_Tall (armored ranged/melee sentinel).

const BalanceDBRef := preload("res://scripts/game/balance_db.gd")
const ProjectileRef := preload("res://scripts/game/projectile_controller.gd")
const DestructionVFXRef := preload("res://scripts/game/droid_destruction_vfx.gd")
const VariantsHelperRef := preload("res://scripts/game/enemy_variants_helper.gd")

signal died(enemy: Node3D, enemy_id: String, xp_reward: int, score_reward: int, drop_chance: float, world_pos: Vector3)
signal took_damage(amount: float, is_crit: bool)

var enemy_id: String = "droid_small"
var last_weapon_id: String = ""
var max_hp: float = 55.0
var current_hp: float = 55.0
var move_speed_mps: float = 4.6
var headshot_y_threshold: float = 0.72
var xp_reward: int = 18
var score_reward: int = 100
var crate_drop_chance: float = 0.10
var knockback_resistance: float = 0.15

var _cfg: Dictionary = {}
var _dmg_mult: float = 1.0
var _player: Node3D
var _projectiles_parent: Node3D
var _cooldown_left: float = 0.4
var _windup_left: float = 0.0
var _pending_attack: String = ""
var _knockback_vel: Vector3 = Vector3.ZERO
var _dead: bool = false
var _stride_phase: float = 0.0
var _idle_phase: float = 0.0
var _arm_windup_blend: float = 0.0
var _flash_left: float = 0.0
var _hp_bar_fill: MeshInstance3D
var _foot_l: Node3D
var _foot_r: Node3D
var _skeleton: Skeleton3D
var _arm_bones: Dictionary = {}
var _arm_rest: Dictionary = {}
var _meshes: Array[MeshInstance3D] = []
var _flash_mat: StandardMaterial3D
var _variants := VariantsHelperRef.new()

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 16
	_ensure_collision_and_bar()
	_foot_l = find_child("Target_Foot_L", true, false) as Node3D
	_foot_r = find_child("Target_Foot_R", true, false) as Node3D
	_setup_arm_bones()
	_collect_body_meshes()
	_variants.bind(self)


func configure_from_balance(id: String, db: BalanceDBRef, wave_spec: Dictionary, player: Node3D, proj_parent: Node3D = null) -> void:
	enemy_id = id
	_cfg = db.get_enemy_cfg(id)
	_player = player
	_projectiles_parent = proj_parent
	var w := int(wave_spec.get("wave", 1))
	var hp_mult := float(wave_spec.get("hp_multiplier", 1.0))
	_dmg_mult = float(wave_spec.get("damage_multiplier", 1.0))

	max_hp = float(_cfg.get("base_hp", 55.0)) * hp_mult
	current_hp = max_hp
	move_speed_mps = minf(
		float(_cfg.get("max_speed_mps", 7.4)),
		float(_cfg.get("base_speed_mps", 4.6)) + float(_cfg.get("speed_per_wave_mps", 0.15)) * float(w - 1)
	)
	knockback_resistance = float(_cfg.get("knockback_resistance", 0.15))
	xp_reward = int(_cfg.get("xp_base", 18)) + int(_cfg.get("xp_per_wave", 2)) * (w - 1)
	score_reward = int(_cfg.get("score_value", 100))
	crate_drop_chance = float(_cfg.get("crate_drop_chance", 0.10))
	headshot_y_threshold = float(_cfg.get("height_m", 1.035)) * 0.72
	_dead = false
	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs != null and cs.shape is CapsuleShape3D:
		var cap := cs.shape as CapsuleShape3D
		cap.radius = float(_cfg.get("capsule_radius_m", 0.30))
		cap.height = float(_cfg.get("capsule_height_m", 1.10))
		cs.position = Vector3(0.0, cap.height * 0.5, 0.0)


func take_damage(amount: float, impulse: Vector3 = Vector3.ZERO, is_crit: bool = false, _weapon_id: String = "", tall_armor_pierce: float = 1.0) -> void:
	if _dead or amount <= 0.0:
		return
	last_weapon_id = _weapon_id
	var final_dmg := amount * (tall_armor_pierce if enemy_id == "droid_tall" else 1.0)
	current_hp = maxf(0.0, current_hp - final_dmg)
	_knockback_vel += Vector3(impulse.x, 0.0, impulse.z) * (1.0 - knockback_resistance)
	_flash_left = 0.11
	_set_hit_flash(true, is_crit)
	_update_hp_bar()
	took_damage.emit(final_dmg, is_crit)
	if current_hp <= 0.0:
		_dead = true
		var fx_parent: Node = get_tree().current_scene if is_inside_tree() else get_parent()
		if fx_parent == null:
			fx_parent = get_parent()
		DestructionVFXRef.spawn_droid_explosion(fx_parent, global_position if is_inside_tree() else position, enemy_id, impulse)
		died.emit(self, enemy_id, xp_reward, score_reward, crate_drop_chance, global_position)
		queue_free()

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _flash_left > 0.0:
		_flash_left = maxf(0.0, _flash_left - delta)
		if _flash_left <= 0.0:
			_set_hit_flash(false, false)
	_knockback_vel = _knockback_vel.move_toward(Vector3.ZERO, 26.0 * delta)

	if not is_on_floor():
		velocity.y -= 24.0 * delta

	if _player != null and is_instance_valid(_player):
		var to_p := _player.global_position - global_position
		var flat_to_p := Vector3(to_p.x, 0.0, to_p.z)
		var dist := flat_to_p.length()
		var dir := flat_to_p / maxf(0.001, dist)
		look_at(global_position - dir, Vector3.UP)

		if _windup_left > 0.0:
			_windup_left -= delta
			velocity.x = _knockback_vel.x
			velocity.z = _knockback_vel.z
			if _windup_left <= 0.0:
				_execute_attack(dist, dir)
		else:
			_choose_move_and_attack(dist, dir, delta)
	else:
		velocity.x = _knockback_vel.x
		velocity.z = _knockback_vel.z

	move_and_slide()
	_animate_ik_targets(delta)


func _choose_move_and_attack(dist: float, dir: Vector3, _delta: float) -> void:
	var has_ranged := enemy_id == "droid_tall" or enemy_id == "mech_leela" or enemy_id == "mech_george"
	var melee_r := float(_cfg.get("melee_range_m", 2.1) if has_ranged else _cfg.get("attack_range_m", 1.55))

	if dist <= melee_r and _cooldown_left <= 0.0:
		_pending_attack = "melee"
		_windup_left = float(_cfg.get("melee_windup_s", 0.50) if has_ranged else _cfg.get("attack_windup_s", 0.35))
		velocity.x = _knockback_vel.x
		velocity.z = _knockback_vel.z
		return

	if has_ranged and dist <= float(_cfg.get("ranged_max_range_m", 26.0)) and dist > melee_r + 1.0 and _cooldown_left <= 0.0:
		_pending_attack = "ranged"
		_windup_left = float(_cfg.get("ranged_windup_s", 0.55))
		velocity.x = _knockback_vel.x
		velocity.z = _knockback_vel.z
		return

	var move_dir := _steer_around_obstacles(dir)
	var desired_speed := move_speed_mps
	if (has_ranged and dist <= float(_cfg.get("preferred_range_min_m", 8.0))) or _variants.should_hold_elevator_ledge(move_dir):
		desired_speed = 0.0
	velocity.x = move_dir.x * desired_speed + _knockback_vel.x
	velocity.z = move_dir.z * desired_speed + _knockback_vel.z


func _execute_attack(dist: float, dir: Vector3) -> void:
	var has_ranged := enemy_id == "droid_tall" or enemy_id == "mech_leela" or enemy_id == "mech_george"
	if _pending_attack == "melee":
		_cooldown_left = float(_cfg.get("melee_cooldown_s", 1.60) if has_ranged else _cfg.get("attack_cooldown_s", 1.15))
		var melee_r := float(_cfg.get("melee_range_m", 2.1) if has_ranged else _cfg.get("attack_range_m", 1.55)) + 0.45
		if dist <= melee_r and _player != null and _player.has_method("take_damage"):
			var dmg := float(_cfg.get("melee_base_damage", 24.0) if has_ranged else _cfg.get("base_damage", 12.0)) * _dmg_mult
			_player.call("take_damage", dmg, dir * 6.0)
	elif _pending_attack == "ranged":
		_cooldown_left = float(_cfg.get("ranged_cooldown_s", 2.10))
		if enemy_id == "mech_leela" or enemy_id == "mech_george":
			_variants.fire_spider_cannon(_player, _cfg, _dmg_mult, _projectiles_parent)
		else:
			_fire_plasma_bolt()
	_pending_attack = ""


func _fire_plasma_bolt() -> void:
	var parent := _projectiles_parent if _projectiles_parent != null else get_tree().current_scene
	if parent == null or _player == null:
		return
	var spawn_p := global_position + Vector3(0.0, 1.45, 0.0)
	var aim_p := _player.global_position + Vector3(0.0, 1.0, 0.0)
	var bolt := ProjectileRef.new()
	bolt.add_to_group("enemy_projectiles")
	parent.add_child(bolt)
	var dmg := float(_cfg.get("ranged_base_damage", 18.0)) * _dmg_mult
	var spd := float(_cfg.get("ranged_projectile_speed_mps", 16.0))
	bolt.configure_enemy_plasma(spawn_p, (aim_p - spawn_p).normalized(), dmg, spd)


func _steer_around_obstacles(dir: Vector3) -> Vector3:
	if not is_inside_tree():
		return dir
	var space := get_world_3d().direct_space_state
	if space == null:
		return dir
	var origin := global_position + Vector3(0.0, 0.55, 0.0)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 2.2, 1)
	if not space.intersect_ray(q).is_empty():
		var left := dir.rotated(Vector3.UP, 0.65)
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + left * 2.2, 1)).is_empty():
			return left
		return dir.rotated(Vector3.UP, -0.65)
	return dir


func _animate_ik_targets(delta: float) -> void:
	var h_spd := Vector2(velocity.x, velocity.z).length()
	_stride_phase += delta * clampf(h_spd * 2.0, 0.0, 14.0)
	_idle_phase += delta * 2.4
	if _foot_l != null and _foot_r != null:
		var s := sin(_stride_phase) * 0.22 * clampf(h_spd / 3.0, 0.0, 1.0)
		_foot_l.position = Vector3(0.14, maxf(0.04, cos(_stride_phase) * 0.14), s)
		_foot_r.position = Vector3(-0.14, maxf(0.04, -cos(_stride_phase) * 0.14), -s)
	_animate_arms(delta, h_spd)
	_variants.tick(delta, enemy_id, _player, _cfg, _dmg_mult, _projectiles_parent, h_spd, _stride_phase, _windup_left > 0.0)


func _setup_arm_bones() -> void:
	var skels := find_children("*", "Skeleton3D", true, false)
	_skeleton = skels[0] as Skeleton3D if not skels.is_empty() else null
	if _skeleton == null:
		return
	var map := {"clav_l": ["shoulder.L", "clavicle.L"], "clav_r": ["shoulder.R", "clavicle.R"], "upper_l": ["upper_arm.L"], "upper_r": ["upper_arm.R"], "fore_l": ["forearm.L"], "fore_r": ["forearm.R"]}
	for k in map:
		for b in map[k]:
			var idx := _skeleton.find_bone(b)
			if idx >= 0:
				_arm_bones[k] = idx
				_arm_rest[k] = _skeleton.get_bone_rest(idx).basis.get_rotation_quaternion()
				break

func _set_arm_rot(key: String, euler_rad: Vector3) -> void:
	if _arm_bones.has(key):
		_skeleton.set_bone_pose_rotation(_arm_bones[key], _arm_rest[key] * Quaternion.from_euler(euler_rad))

func _animate_arms(delta: float, h_spd: float) -> void:
	if _skeleton == null or _arm_bones.is_empty():
		return
	var spd := clampf(h_spd / 3.0, 0.0, 1.0)
	var swing := sin(_stride_phase) * 0.58 * spd
	var breathe := sin(_idle_phase) * 0.05
	_arm_windup_blend = move_toward(_arm_windup_blend, 1.0 if _windup_left > 0.0 else 0.0, delta * 9.0)
	var r := _pending_attack == "ranged"
	var wb := _arm_windup_blend
	var shrug := cos(_stride_phase) * 0.08 * spd
	_set_arm_rot("clav_l", Vector3(0.22 * wb, 0.0, shrug))
	_set_arm_rot("clav_r", Vector3(0.22 * wb, 0.0, shrug))
	_set_arm_rot("upper_l", Vector3(swing - 0.10 + breathe, 0.0, -0.10).lerp(Vector3(-0.45 if r else -1.35, 0.0, -0.18 if r else -0.35), wb))
	_set_arm_rot("upper_r", Vector3(-swing - 0.10 - breathe, 0.0, 0.10).lerp(Vector3(-1.45 if r else -1.35, 0.0, 0.08 if r else 0.35), wb))
	_set_arm_rot("fore_l", Vector3(-0.32 - maxf(0.0, -swing) * 0.65, 0.0, 0.0).lerp(Vector3(-0.85 if r else -0.75, 0.0, 0.0), wb))
	_set_arm_rot("fore_r", Vector3(-0.32 - maxf(0.0, swing) * 0.65, 0.0, 0.0).lerp(Vector3(-0.18 if r else -0.75, 0.0, 0.0), wb))

func _ensure_collision_and_bar() -> void:
	if get_node_or_null("CollisionShape3D") == null:
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = float(_cfg.get("capsule_radius_m", 0.30))
		cap.height = float(_cfg.get("capsule_height_m", 1.10))
		cs.shape = cap
		cs.position = Vector3(0.0, cap.height * 0.5, 0.0)
		add_child(cs)
	_hp_bar_fill = get_node_or_null("HPBar/Fill") as MeshInstance3D

func _update_hp_bar() -> void:
	if _hp_bar_fill != null:
		_hp_bar_fill.scale.x = clampf(current_hp / maxf(1.0, max_hp), 0.0, 1.0)

func _collect_body_meshes() -> void:
	_meshes.clear()
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi != null and mi != _hp_bar_fill:
			_meshes.append(mi)
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.albedo_color = Color(1.0, 0.72, 0.35, 0.65)


func _set_hit_flash(active: bool, is_crit: bool) -> void:
	if _flash_mat != null and active:
		_flash_mat.albedo_color = Color(0.35, 0.98, 1.0, 0.72) if is_crit else Color(1.0, 0.72, 0.32, 0.65)
	for mi in _meshes:
		if is_instance_valid(mi):
			mi.material_overlay = _flash_mat if active else null
