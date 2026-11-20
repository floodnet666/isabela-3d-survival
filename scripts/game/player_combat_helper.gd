class_name PlayerCombatHelper
extends RefCounted
## Processes weapon slot switches, reload, firearm/melee triggers, and FPS viewmodel syncing for PlayerController.


static func handle_slot_input(event: InputEvent, loadout: WeaponLoadout, weapon_mgr: WeaponManager) -> bool:
	if loadout == null or weapon_mgr == null:
		return false
	if event.is_action_pressed("weapon_next") and loadout.cycle_slot(1):
		weapon_mgr.refresh_equipped_mesh()
		return true
	if event.is_action_pressed("weapon_prev") and loadout.cycle_slot(-1):
		weapon_mgr.refresh_equipped_mesh()
		return true
	for s in range(1, 8):
		if event.is_action_pressed("weapon_%d" % s) and loadout.select_slot(s):
			weapon_mgr.refresh_equipped_mesh()
			return true
	return false


static func process_combat(player: CharacterBody3D, delta: float, loadout: WeaponLoadout, cam_rig: PlayerCameraRig, weapon_mgr: WeaponManager, animator: PlayerAnimator) -> Dictionary:
	var res := {"fired": false, "is_melee": false, "melee_total": 0.0, "combo_step": 1}
	if loadout == null:
		return res
	var def := loadout.get_selected_def()
	var wid := str(def.get("id", "pistol"))
	var vm = cam_rig.get_fps_viewmodel() if cam_rig != null else null
	var prev_st := loadout.get_slot_hud_state(loadout.get_selected_slot())
	var was_reloading := bool(prev_st.get("is_reloading", false))
	var was_overheated := bool(prev_st.get("is_overheated", false))
	if Input.is_action_just_pressed("reload"):
		loadout.start_reload_or_vent()
	var is_auto := str(def.get("fire_mode", "semi_auto")) in ["auto", "melee_combo"]
	var trigger := Input.is_action_pressed("fire") if is_auto else Input.is_action_just_pressed("fire")
	loadout.tick(delta, Input.is_action_pressed("fire"))
	var shot := loadout.try_fire(bool(player.get("is_aiming"))) if trigger else {"fired": false}
	_sync_weapon_state_anims(player, def, wid, loadout, animator, vm, was_reloading, was_overheated)
	if not shot.get("fired", false) or weapon_mgr == null:
		return res

	res["fired"] = true
	var yaw := cam_rig.yaw if cam_rig != null else 0.0
	var is_melee := str(shot.get("delivery", "")) == "melee_cone"
	if is_melee:
		var m_total := maxf(0.14, float(shot.get("active_swing_window_s", 0.16)) + 0.08)
		var step := int(shot.get("combo_step", 1))
		res["is_melee"] = true
		res["melee_total"] = m_total
		res["combo_step"] = step
		player.velocity += Vector3(-sin(yaw), 0.0, -cos(yaw)) * (float(shot.get("swing_lunge_distance_m", 0.0)) * 6.5)
		if vm != null:
			vm.trigger_melee(step, m_total)
		if animator != null:
			animator.trigger_melee(wid, step)
	else:
		if vm != null:
			vm.trigger_fire(wid)
		if animator != null:
			animator.trigger_shoot(wid)

	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var aim := cam_rig.get_aim_ray(player) if cam_rig != null else {"origin": player.global_position + Vector3(0.0, 1.35, 0.0), "target": player.global_position + fwd * 40.0, "forward": fwd}
	weapon_mgr.execute_shot(shot, aim)
	return res


static func compute_move_speed(cfg: Dictionary, upgrades: UpgradeSystem, loadout: WeaponLoadout, sprinting: bool, aiming: bool, world_y: float, arch_speed_mult: float = 1.0) -> float:
	var base := float(cfg.get("sprint_speed_mps", 8.6) if sprinting and not aiming else cfg.get("walk_speed_mps", 5.8)) * arch_speed_mult
	if aiming:
		base *= float(cfg.get("aim_speed_multiplier", 0.85))
	if upgrades != null:
		base *= upgrades.get_stat("move_speed_multiplier")
	if loadout != null:
		base *= float(loadout.get_selected_def().get("move_speed_multiplier", 1.0))
	if world_y <= float(cfg.get("shallow_water_max_y_m", 0.08)):
		base *= float(cfg.get("shallow_water_drag_multiplier", 0.94))
	return base


static func ensure_capsule(player: CharacterBody3D) -> void:
	if player.get_node_or_null("CollisionShape3D") != null:
		return
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.44
	cap.height = 1.72
	cs.shape = cap
	cs.position = Vector3(0.0, 0.86, 0.0)
	player.add_child(cs)


static func clamp_to_arena(player: CharacterBody3D, db: BalanceDB) -> void:
	var r := float(db.get_arena_cfg().get("playable_radius_m", 32.0)) - 0.5
	var flat := Vector2(player.global_position.x, player.global_position.z)
	if flat.length() > r:
		flat = flat.normalized() * r
		player.global_position = Vector3(flat.x, player.global_position.y, flat.y)


static func _sync_weapon_state_anims(player: CharacterBody3D, def: Dictionary, wid: String, loadout: WeaponLoadout, animator: PlayerAnimator, vm, was_reloading: bool, was_overheated: bool) -> void:
	var cur_st := loadout.get_slot_hud_state(loadout.get_selected_slot())
	var now_reloading := bool(cur_st.get("is_reloading", false))
	var now_overheated := bool(cur_st.get("is_overheated", false))
	if not was_reloading and now_reloading:
		if player.is_inside_tree():
			player.get_tree().call_group("audio_manager", "play_sfx", "reload")
		if animator != null:
			animator.trigger_reload(wid)
		if vm != null:
			vm.trigger_reload(float(def.get("reload_time_s", 1.2)))
	if not was_overheated and now_overheated:
		if player.is_inside_tree():
			player.get_tree().call_group("audio_manager", "play_sfx", "reload")
		if vm != null and vm.has_method("trigger_laser_overheat"):
			vm.trigger_laser_overheat(float(def.get("overheat_lockout_s", 1.8)))
	elif was_overheated and not now_overheated:
		if vm != null and vm.has_method("trigger_laser_ready"):
			vm.trigger_laser_ready()
