class_name EnemyVariantsHelper
extends RefCounted
## Handles specialized rig animations, dorsal cannon burst fire, and lateral saw contact damage for droid_spider & droid_sawbox.

const ProjectileRef := preload("res://scripts/game/projectile_controller.gd")

var _enemy: CharacterBody3D
var _cannon_pivot: Node3D
var _cannon_muzzle: Marker3D
var _legs: Array[Dictionary] = []
var _saw_l: Node3D
var _saw_r: Node3D
var _saw_tick_left: float = 0.0
var _saw_hum_left: float = 0.8
var _burst_remaining: int = 0
var _burst_timer: float = 0.0
var _step_sfx_cd: float = 0.0
var _mech_anim: AnimationPlayer
var _mech_last_anim: String = ""


func bind(enemy: CharacterBody3D) -> void:
	_enemy = enemy
	_mech_anim = enemy.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _mech_anim != null:
		for loop_name in ["Idle", "Walk", "Run"]:
			if _mech_anim.has_animation(loop_name):
				_mech_anim.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
		if _mech_anim.has_animation("Idle"):
			_mech_anim.play("Idle")
			_mech_last_anim = "Idle"
	_cannon_pivot = enemy.get_node_or_null("VisualRoot/DorsalCannonPivot") as Node3D
	_cannon_muzzle = enemy.get_node_or_null("VisualRoot/DorsalCannonPivot/CannonMuzzle") as Marker3D
	_saw_l = enemy.get_node_or_null("VisualRoot/SawPivotL") as Node3D
	_saw_r = enemy.get_node_or_null("VisualRoot/SawPivotR") as Node3D
	_legs.clear()
	var leg_defs := [
		["Leg_FL", 0.0],
		["Leg_FR", PI],
		["Leg_ML", PI],
		["Leg_MR", 0.0],
		["Leg_BL", 0.0],
		["Leg_BR", PI],
	]
	for ld in leg_defs:
		var hip := enemy.get_node_or_null("VisualRoot/Legs/%s" % ld[0]) as Node3D
		if hip != null:
			var knee := hip.get_node_or_null("KneePivot") as Node3D
			_legs.append({
				"hip": hip,
				"hip_rest": hip.rotation,
				"knee": knee,
				"knee_rest": knee.rotation if knee != null else Vector3.ZERO,
				"phase": float(ld[1]),
			})


func tick(delta: float, enemy_id: String, player: Node3D, cfg: Dictionary, dmg_mult: float, proj_parent: Node3D, h_spd: float, stride_phase: float, is_windup: bool) -> void:
	if enemy_id.begins_with("mech_"):
		_tick_mech(delta, player, cfg, dmg_mult, proj_parent, h_spd, is_windup)
	elif enemy_id == "droid_spider":
		_tick_spider(delta, player, cfg, dmg_mult, proj_parent, h_spd, stride_phase)
	elif enemy_id == "droid_sawbox":
		_tick_sawbox(delta, player, cfg, dmg_mult, h_spd, is_windup)


func _tick_mech(delta: float, player: Node3D, cfg: Dictionary, dmg_mult: float, proj_parent: Node3D, h_spd: float, is_windup: bool) -> void:
	if _burst_remaining > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_remaining -= 1
			_burst_timer = float(cfg.get("burst_interval_s", 0.16))
			_spawn_spider_bolt(player, cfg, dmg_mult, proj_parent)
	if _mech_anim == null or not is_instance_valid(_mech_anim):
		return
	var target := "Idle"
	if is_windup:
		var is_ranged := str(cfg.get("attack_type", "")) == "ranged_cannon"
		target = "Shoot" if is_ranged and _mech_anim.has_animation("Shoot") else ("Punch" if _mech_anim.has_animation("Punch") else "Idle")
	elif h_spd > 0.35 and _mech_anim.has_animation("Run"):
		target = "Run"
	if target != _mech_last_anim and _mech_anim.has_animation(target):
		_mech_anim.play(target, 0.12)
		_mech_last_anim = target


func fire_spider_cannon(player: Node3D, cfg: Dictionary, dmg_mult: float, proj_parent: Node3D) -> void:
	var burst := int(cfg.get("burst_count", 2))
	_burst_remaining = maxi(0, burst - 1)
	_burst_timer = float(cfg.get("burst_interval_s", 0.16))
	_spawn_spider_bolt(player, cfg, dmg_mult, proj_parent)


func _tick_spider(delta: float, player: Node3D, cfg: Dictionary, dmg_mult: float, proj_parent: Node3D, h_spd: float, stride_phase: float) -> void:
	var move_blend := clampf(h_spd / 2.8, 0.0, 1.0)
	for leg in _legs:
		var hip := leg["hip"] as Node3D
		var knee := leg["knee"] as Node3D
		var ph := stride_phase + float(leg["phase"])
		var rest_h: Vector3 = leg["hip_rest"]
		hip.rotation = Vector3(
			rest_h.x + maxf(0.0, cos(ph)) * 0.24 * move_blend,
			rest_h.y + sin(ph) * 0.28 * move_blend,
			rest_h.z
		)
		if knee != null:
			var rest_k: Vector3 = leg["knee_rest"]
			knee.rotation = Vector3(rest_k.x - maxf(0.0, cos(ph)) * 0.35 * move_blend, rest_k.y, rest_k.z)

	if _cannon_pivot != null and player != null and is_instance_valid(player) and _enemy.is_inside_tree():
		var dy := (player.global_position.y + 0.95) - _cannon_pivot.global_position.y
		var flat_d := maxf(1.0, Vector2(player.global_position.x - _enemy.global_position.x, player.global_position.z - _enemy.global_position.z).length())
		_cannon_pivot.rotation.x = clampf(-atan2(dy, flat_d), -0.45, 0.45)

	if move_blend > 0.25:
		_step_sfx_cd -= delta
		if _step_sfx_cd <= 0.0:
			_step_sfx_cd = 0.42
			_play_sfx("droid_spider_step", 0.08, -7.0)

	if _burst_remaining > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_remaining -= 1
			_burst_timer = float(cfg.get("burst_interval_s", 0.16))
			_spawn_spider_bolt(player, cfg, dmg_mult, proj_parent)


func _tick_sawbox(delta: float, player: Node3D, cfg: Dictionary, dmg_mult: float, h_spd: float, is_windup: bool) -> void:
	var spin_spd := 14.0 + (8.0 if is_windup else clampf(h_spd * 1.5, 0.0, 6.0))
	if _saw_l != null:
		_saw_l.rotate_x(spin_spd * delta)
	if _saw_r != null:
		_saw_r.rotate_x(-spin_spd * delta)

	_saw_tick_left = maxf(0.0, _saw_tick_left - delta)
	_saw_hum_left -= delta
	if _saw_hum_left <= 0.0:
		_saw_hum_left = 1.65
		_play_sfx("droid_sawbox_hum", 0.05, -8.0)

	if player == null or not is_instance_valid(player) or _enemy == null:
		return
	var flat_delta := Vector2(player.global_position.x - _enemy.global_position.x, player.global_position.z - _enemy.global_position.z)
	var saw_r := float(cfg.get("saw_contact_range_m", 1.80))
	if flat_delta.length() <= saw_r and _saw_tick_left <= 0.0:
		_saw_tick_left = float(cfg.get("saw_tick_interval_s", 0.38))
		var saw_dmg := float(cfg.get("saw_tick_damage", 12.0)) * dmg_mult
		var push := Vector3(flat_delta.x, 0.0, flat_delta.y).normalized() * 5.0 if flat_delta.length_squared() > 0.001 else Vector3.FORWARD * 5.0
		if player.has_method("take_damage"):
			player.call("take_damage", saw_dmg, push)
		_play_sfx("droid_sawbox_impact", 0.08, -2.0)


func _spawn_spider_bolt(player: Node3D, cfg: Dictionary, dmg_mult: float, proj_parent: Node3D) -> void:
	if _enemy == null or player == null or not is_instance_valid(player):
		return
	var parent: Node = proj_parent
	if parent == null and _enemy.is_inside_tree():
		parent = _enemy.get_tree().current_scene
	if parent == null:
		parent = _enemy.get_parent()
	if parent == null:
		return
	var spawn_p := _cannon_muzzle.global_position if (_cannon_muzzle != null and _cannon_muzzle.is_inside_tree()) else _enemy.global_position + Vector3(0.0, 1.25, 0.0)
	var aim_p := player.global_position + Vector3(0.0, 1.0, 0.0)
	var bolt := ProjectileRef.new()
	bolt.add_to_group("enemy_projectiles")
	parent.add_child(bolt)
	var dmg := float(cfg.get("ranged_base_damage", 16.0)) * dmg_mult
	var spd := float(cfg.get("ranged_projectile_speed_mps", 21.0))
	bolt.configure_enemy_plasma(spawn_p, (aim_p - spawn_p).normalized(), dmg, spd)
	_play_sfx("droid_spider_cannon", 0.06, -1.5)


func should_hold_elevator_ledge(move_dir: Vector3) -> bool:
	if _enemy == null or not _enemy.is_inside_tree() or not _enemy.is_on_floor():
		return false
	var elev := _enemy.get_tree().get_first_node_in_group("arena_elevators")
	if elev == null or not elev.has_method("is_on_elevator"):
		return false
	var pos := _enemy.global_position
	if not bool(elev.call("is_on_elevator", pos, 0.25)):
		return false
	return not bool(elev.call("is_on_elevator", pos + move_dir * 0.9, -0.45))


func _play_sfx(sfx_id: String, pitch_jitter: float, vol_db: float) -> void:
	if _enemy != null and _enemy.is_inside_tree():
		_enemy.get_tree().call_group("audio_manager", "play_sfx", sfx_id, pitch_jitter, vol_db)
