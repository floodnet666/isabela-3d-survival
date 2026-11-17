class_name BossSentinel
extends CharacterBody3D
## Rotating Orbital Boss AI (Valkyrie Skull, White Reaper, Anubis Phantom): 2 phases, capsule rain, anti-cheese leaps & signature defenses.

const BalanceDBRef := preload("res://scripts/game/balance_db.gd")
const ProjectileRef := preload("res://scripts/game/projectile_controller.gd")
const BossVisualsRef := preload("res://scripts/game/boss_visuals_helper.gd")

enum BossState { CHASE, GUARD_OR_BLINK, STAGGER, WINDUP, ATTACK, LEAP }

signal hp_updated(current_hp: float, max_hp: float)
signal enraged(boss_id: String, salvo_count: int)
signal capsule_rain_requested(count: int)
signal died(enemy: Node3D, enemy_id: String, xp_reward: int, score_reward: int, drop_chance: float, world_pos: Vector3)
signal took_damage(amount: float, is_crit: bool)

var enemy_id: String = "valkyrie_skull"
var display_name: String = "Valkyrie Skull"
var unlock_skin_id: String = "valkyrie_skull"
var last_weapon_id: String = ""
var max_hp: float = 950.0
var current_hp: float = 950.0
var base_speed_mps: float = 6.4
var move_speed_mps: float = 6.4
var headshot_y_threshold: float = 1.55
var xp_reward: int = 450
var score_reward: int = 2500
var knockback_resistance: float = 0.70
var state: BossState = BossState.CHASE
var is_enraged: bool = false
var is_guarding: bool = false
var is_blinking_telegraph: bool = false

var _cfg: Dictionary = {}
var _bosses_cfg: Dictionary = {}
var _player: Node3D
var _proj_parent: Node3D
var _dead: bool = false
var _state_timer: float = 0.0
var _melee_cd: float = 0.8
var _ranged_cd: float = 1.8
var _special_cd: float = 4.5
var _capsule_cd: float = 11.0
var _aimed_at_time: float = 0.0
var _impact_timer: float = 0.0
var _leap_target: Vector3 = Vector3.ZERO
var _pending_attack: String = ""
var _knockback_vel: Vector3 = Vector3.ZERO
var _vis: Dictionary = {}


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss_sentinel")
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 16
	_ensure_collision()


func configure_from_balance(id: String, db: BalanceDBRef, wave_spec: Dictionary, player: Node3D, proj_parent: Node3D = null) -> void:
	enemy_id = id; _player = player; _proj_parent = proj_parent
	_bosses_cfg = db.get_bosses_cfg()
	_cfg = db.get_boss_cfg(id, maxi(1, int(wave_spec.get("boss_tier", 1))))
	display_name = str(_cfg.get("display_name", id))
	unlock_skin_id = str(_cfg.get("unlock_skin_id", id))
	max_hp = float(_cfg.get("resolved_hp", 950.0)); current_hp = max_hp
	base_speed_mps = float(_cfg.get("base_speed_mps", 6.0)); move_speed_mps = base_speed_mps
	xp_reward = int(_cfg.get("resolved_xp", 450)); score_reward = int(_cfg.get("resolved_score", 2500))
	knockback_resistance = float(_cfg.get("knockback_resistance", 0.70))
	headshot_y_threshold = float(_cfg.get("height_m", 2.15)) * 0.74
	_capsule_cd = float(_bosses_cfg.get("capsule_wave_cooldown_s", 11.0))
	is_enraged = false; is_guarding = false; is_blinking_telegraph = false; _dead = false; _impact_timer = 0.0
	state = BossState.CHASE
	_ensure_collision(float(_cfg.get("capsule_radius_m", 0.5)), float(_cfg.get("capsule_height_m", 2.15)))
	_vis = BossVisualsRef.build_visual(self, enemy_id, _cfg)
	hp_updated.emit(current_hp, max_hp)


func _physics_process(delta: float) -> void:
	if _dead or _player == null or not is_instance_valid(_player):
		return
	_melee_cd = maxf(0.0, _melee_cd - delta); _ranged_cd = maxf(0.0, _ranged_cd - delta)
	_special_cd = maxf(0.0, _special_cd - delta); _impact_timer = maxf(0.0, _impact_timer - delta)
	_capsule_cd -= delta
	if _capsule_cd <= 0.0:
		_capsule_cd = float(_bosses_cfg.get("capsule_wave_cooldown_s", 11.0))
		capsule_rain_requested.emit(int(_bosses_cfg.get("capsules_per_rain", 2)))
	var to_p := _player.global_position - global_position
	var flat_to := Vector3(to_p.x, 0.0, to_p.z)
	var dist := flat_to.length()
	var dir := flat_to.normalized() if dist > 0.01 else Vector3.FORWARD
	var prev_rot_y := rotation.y
	if dist > 0.1 and state != BossState.STAGGER:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)
	var turn_rate := wrapf(rotation.y - prev_rot_y, -PI, PI) / maxf(delta, 0.001)
	_tick_state(delta, dir, dist, to_p.y)
	_knockback_vel = _knockback_vel.move_toward(Vector3.ZERO, 16.0 * delta)
	velocity.x += _knockback_vel.x; velocity.z += _knockback_vel.z
	move_and_slide()
	BossVisualsRef.tick_visual(_vis, delta, self, turn_rate, _pending_attack, _state_timer, _impact_timer)


func _tick_state(delta: float, dir: Vector3, dist: float, dy: float) -> void:
	if state == BossState.CHASE:
		_process_chase(delta, dir, dist, dy)
	elif state == BossState.LEAP:
		var step := Vector3(_leap_target.x - global_position.x, 0.0, _leap_target.z - global_position.z)
		var h_vel := step.normalized() * 14.5 if step.length() > 0.4 else Vector3.ZERO
		velocity = Vector3(h_vel.x, velocity.y - 22.0 * delta, h_vel.z)
		if is_on_floor() and velocity.y <= 0.0:
			_on_leap_land(); state = BossState.CHASE
	else:
		_state_timer -= delta
		velocity = Vector3(0.0, velocity.y - 24.0 * delta, 0.0)
		if _state_timer <= 0.0:
			if state == BossState.GUARD_OR_BLINK: _finish_guard_or_blink()
			elif state == BossState.WINDUP: _execute_attack(dir); state = BossState.CHASE
			else: state = BossState.CHASE


func _process_chase(delta: float, dir: Vector3, dist: float, dy: float) -> void:
	var move_dir := dir
	if enemy_id == "valkyrie_skull":
		move_dir = dir.rotated(Vector3.UP, sin(Time.get_ticks_msec() * 0.005) * 0.35)
		if _is_player_aiming_at_me():
			_aimed_at_time += delta
			if _aimed_at_time >= float(_cfg.get("sidestep_aim_threshold_s", 1.0)) and _special_cd <= 0.0:
				_aimed_at_time = 0.0; _special_cd = 3.2
				_knockback_vel += dir.rotated(Vector3.UP, PI * 0.5 * (1.0 if randf() > 0.5 else -1.0)) * 13.0
		else:
			_aimed_at_time = maxf(0.0, _aimed_at_time - delta)
	elif enemy_id == "anubis_phantom" and _special_cd <= 0.0 and dist > 6.5:
		_special_cd = float(_cfg.get("blink_cooldown_s", 5.5)); is_blinking_telegraph = true
		_state_timer = float(_cfg.get("blink_telegraph_s", 0.6)); state = BossState.GUARD_OR_BLINK; return
	if (enemy_id == "valkyrie_skull" or enemy_id == "anubis_phantom") and dy > 1.2 and _special_cd <= 0.0:
		_special_cd = float(_cfg.get("leap_cooldown_s", 6.5)); _leap_target = _player.global_position
		velocity.y = 11.5; state = BossState.LEAP; return
	if dist <= float(_cfg.get("melee_range_m", 2.5)) and _melee_cd <= 0.0:
		_pending_attack = "slam" if enemy_id == "white_reaper" else "melee"
		_state_timer = 0.42 if enemy_id == "white_reaper" else 0.25
		_melee_cd = float(_cfg.get("melee_cooldown_s", 1.2)); state = BossState.WINDUP; return
	if dist <= float(_cfg.get("ranged_range_m", 24.0)) and dist > 4.0 and _ranged_cd <= 0.0:
		_pending_attack = "ranged"; _state_timer = 0.35
		_ranged_cd = float(_cfg.get("ranged_cooldown_s", 2.1)); state = BossState.WINDUP; return
	velocity = Vector3(move_dir.x * move_speed_mps, velocity.y - 24.0 * delta, move_dir.z * move_speed_mps)


func _finish_guard_or_blink() -> void:
	is_guarding = false
	if is_blinking_telegraph:
		is_blinking_telegraph = false
		if _player != null and is_instance_valid(_player):
			var back := _player.global_transform.basis.z.normalized() * 3.0
			global_position = _player.global_position + Vector3(back.x, 0.2, back.z)
			_pending_attack = "melee"; _execute_attack((_player.global_position - global_position).normalized())
	state = BossState.CHASE


func _execute_attack(dir: Vector3) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_impact_timer = 0.28
	if _pending_attack == "melee":
		if global_position.distance_to(_player.global_position) <= float(_cfg.get("melee_range_m", 2.5)) + 0.9:
			_player.call("take_damage", float(_cfg.get("melee_damage", 20.0)), dir * 8.0)
	elif _pending_attack == "slam":
		var rad := float(_cfg.get("shockwave_radius_m", 6.5))
		BossVisualsRef.spawn_shockwave(get_tree().current_scene if is_inside_tree() else null, global_position, rad, Color(0.95, 0.25, 0.20, 0.8))
		if global_position.distance_to(_player.global_position) <= rad and _player.global_position.y < global_position.y + 1.2:
			_player.call("take_damage", float(_cfg.get("melee_damage", 28.0)), dir * 12.0)
	elif _pending_attack == "ranged":
		for _b in range(2 if is_enraged else 1):
			_fire_ranged_pattern()


func _fire_ranged_pattern() -> void:
	var parent := _proj_parent if _proj_parent != null else (get_tree().current_scene if is_inside_tree() else null)
	if parent == null or _player == null:
		return
	var origin := global_position + Vector3(0.0, 1.45, 0.0)
	var base_dir := ((_player.global_position + Vector3(0.0, 1.0, 0.0)) - origin).normalized()
	for ang in ([-0.24, 0.0, 0.24] if enemy_id == "anubis_phantom" else [0.0]):
		var bolt := ProjectileRef.new()
		bolt.add_to_group("enemy_projectiles")
		parent.add_child(bolt)
		bolt.configure_enemy_plasma(origin, base_dir.rotated(Vector3.UP, ang), float(_cfg.get("ranged_damage", 16.0)), float(_cfg.get("ranged_speed_mps", 22.0)))


func _on_leap_land() -> void:
	_pending_attack = "leap"; _impact_timer = 0.28
	if is_inside_tree():
		BossVisualsRef.spawn_shockwave(get_tree().current_scene, global_position, 3.8, Color(1.0, 0.35, 0.15, 0.8))
	if _player != null and is_instance_valid(_player) and global_position.distance_to(_player.global_position) <= 3.8:
		_player.call("take_damage", float(_cfg.get("melee_damage", 20.0)), (_player.global_position - global_position).normalized() * 10.0)


func take_damage(amount: float, impulse: Vector3 = Vector3.ZERO, is_crit: bool = false, weapon_id: String = "", _tall_armor_pierce: float = 1.0) -> void:
	if _dead or amount <= 0.0:
		return
	last_weapon_id = weapon_id
	var dmg := amount
	var is_explosive := weapon_id == "rocket_launcher" or weapon_id == "explosive_barrel"
	if enemy_id == "white_reaper":
		var from_front := true if _player == null or not is_instance_valid(_player) else (-global_transform.basis.z.normalized()).dot((_player.global_position - global_position).normalized()) > 0.15
		if is_guarding and from_front:
			if is_explosive:
				is_guarding = false; state = BossState.STAGGER; _state_timer = float(_cfg.get("stagger_duration_s", 1.8))
			else: dmg *= float(_cfg.get("guard_frontal_mult", 0.25))
		elif not from_front: dmg *= 1.35
		elif state == BossState.CHASE and _special_cd <= 0.0 and not is_explosive:
			_special_cd = 6.0; is_guarding = true; _state_timer = float(_cfg.get("guard_duration_s", 1.5)); state = BossState.GUARD_OR_BLINK
	if state == BossState.STAGGER: dmg *= 1.5
	current_hp = maxf(0.0, current_hp - dmg)
	_knockback_vel += Vector3(impulse.x, 0.0, impulse.z) * (1.0 - knockback_resistance)
	hp_updated.emit(current_hp, max_hp); took_damage.emit(dmg, is_crit)
	if not is_enraged and current_hp > 0.0 and current_hp <= max_hp * float(_bosses_cfg.get("enrage_hp_ratio", 0.5)):
		is_enraged = true; move_speed_mps = base_speed_mps * float(_bosses_cfg.get("enrage_speed_mult", 1.25))
		enraged.emit(enemy_id, int(_bosses_cfg.get("enrage_salvo_count", 4)))
	if current_hp <= 0.0:
		_dead = true; died.emit(self, enemy_id, xp_reward, score_reward, 0.0, global_position); queue_free()


func _is_player_aiming_at_me() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var cam := _player.get_node_or_null("CameraPivot") as Node3D
	var fwd := -cam.global_transform.basis.z if cam != null else -_player.global_transform.basis.z
	return fwd.normalized().dot((global_position + Vector3(0.0, 1.1, 0.0) - _player.global_position).normalized()) > 0.96


func _ensure_collision(radius: float = 0.5, height: float = 2.15) -> void:
	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs == null:
		cs = CollisionShape3D.new(); cs.name = "CollisionShape3D"; cs.shape = CapsuleShape3D.new(); add_child(cs)
	if cs.shape is CapsuleShape3D:
		(cs.shape as CapsuleShape3D).radius = radius; (cs.shape as CapsuleShape3D).height = height; cs.position = Vector3(0.0, height * 0.5, 0.0)
