class_name PlayerController
extends CharacterBody3D
## Third-person CharacterBody3D controller for SK_Isabela: movement, water drag/ripples, coyote jump, dash+iframes & survival.

const BalanceDBRef := preload("res://scripts/game/balance_db.gd")
const InputSetupRef := preload("res://scripts/game/input_setup.gd")
const UpgradeSystemRef := preload("res://scripts/game/upgrade_system.gd")
const WeaponLoadoutRef := preload("res://scripts/game/weapon_loadout.gd")
const PlayerAnimatorRef := preload("res://scripts/game/player_animator.gd")
const PlayerCameraRigRef := preload("res://scripts/game/player_camera_rig.gd")
const WeaponManagerRef := preload("res://scripts/game/weapon_manager.gd")
const PlayerCombatRef := preload("res://scripts/game/player_combat_helper.gd")

signal hp_changed(current_hp: float, max_hp: float)
signal damaged(amount: float, knockback: Vector3)
signal died()
signal dash_state_changed(charges: int, max_charges: int, cooldown_progress: float)
signal water_ripple_emitted(world_pos: Vector3, strength: float)
signal hit_confirmed(is_crit: bool, is_kill: bool)
signal view_mode_changed(is_fps: bool, doom_centered: bool)

var _db: BalanceDBRef
var _upgrades: UpgradeSystemRef
var _loadout: WeaponLoadoutRef
var _cfg: Dictionary = {}
var _archetype: Dictionary = {}

var max_hp: float = 120.0
var current_hp: float = 120.0
var is_dead: bool = false
var is_aiming: bool = false

var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _iframes_left: float = 0.0
var _dash_left: float = 0.0
var _dash_dir: Vector3 = Vector3.FORWARD
var _dash_charges: int = 1
var _dash_regen_left: float = 0.0
var _water_step_accum: float = 0.0
var _was_on_floor: bool = true
var _recoil_kick: float = 0.0
var _melee_anim_left: float = 0.0
var _melee_anim_total: float = 0.25
var _melee_combo_step: int = 1
var _last_move_input: Vector2 = Vector2.ZERO

@onready var _visual_root: Node3D = get_node_or_null("VisualRoot")
@onready var _cam_rig: PlayerCameraRigRef = get_node_or_null("CameraPivot")
@onready var _animator: PlayerAnimatorRef = get_node_or_null("PlayerAnimator")
@onready var _weapon_mgr: WeaponManagerRef = get_node_or_null("WeaponManager")


func _ready() -> void:
	InputSetupRef.ensure_default_actions()
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4 | 16
	PlayerCombatRef.ensure_capsule(self)
	if _visual_root != null and _animator != null:
		var isabela := _visual_root.get_node_or_null("SK_Isabela") as Node3D
		if isabela != null:
			_animator.bind_isabela(isabela)
			if _weapon_mgr != null:
				_weapon_mgr.set_weapon_socket(_animator.get_weapon_socket())
	if _weapon_mgr != null:
		_weapon_mgr.shot_hit.connect(func(c: bool, k: bool) -> void: hit_confirmed.emit(c, k))


func configure(balance_db: BalanceDBRef, upgrades: UpgradeSystemRef, loadout: WeaponLoadoutRef) -> void:
	InputSetupRef.ensure_default_actions()
	_db = balance_db
	_upgrades = upgrades
	_loadout = loadout
	_cfg = _db.get_player_cfg()
	var sm := preload("res://scripts/game/settings_manager.gd")
	_archetype = preload("res://scripts/game/player_skin_helper.gd").apply_skin_and_helmet(self, sm.get_selected_skin(), str(sm.get_val("selected_helmet")), _db, _animator, _weapon_mgr)
	if _loadout != null and _loadout.has_method("set_archetype"): _loadout.call("set_archetype", _archetype)
	max_hp = float(_cfg.get("base_max_hp", 120.0)) * float(_archetype.get("max_hp_mult", 1.0)) + _upgrades.get_stat("max_hp_bonus")
	current_hp = max_hp
	_dash_charges = get_max_dash_charges()
	is_dead = false
	if _cam_rig != null:
		_cam_rig.configure(_cfg.get("camera", {}))
	if _weapon_mgr != null:
		_weapon_mgr.setup(_loadout, self)
		if _cam_rig != null:
			_weapon_mgr.set_fps_context(_cam_rig.is_fps_mode, _cam_rig.get_fps_viewmodel())
	hp_changed.emit(current_hp, max_hp)


func is_fps_mode() -> bool:
	return _cam_rig != null and _cam_rig.is_fps_mode


func toggle_view_mode() -> bool:
	if _cam_rig == null:
		return false
	_cam_rig.toggle_view_mode()
	var st := _cam_rig.sync_player_view(_visual_root, _animator, _weapon_mgr)
	view_mode_changed.emit(bool(st["is_fps"]), bool(st["doom_centered"]))
	return bool(st["is_fps"])


func toggle_fps_centered() -> bool:
	var vm = _cam_rig.get_fps_viewmodel() if _cam_rig != null else null
	if vm == null:
		return false
	var centered: bool = vm.toggle_doom_centered()
	view_mode_changed.emit(_cam_rig.is_fps_mode, centered)
	return centered


func get_max_dash_charges() -> int:
	return int(_cfg.get("dash_base_charges", 1)) + int(round(_upgrades.get_stat("dash_extra_charges"))) if _upgrades != null else 1


func get_effective_dash_cooldown() -> float:
	var cd := float(_cfg.get("dash_cooldown_s", 1.60)) * float(_archetype.get("dash_cooldown_mult", 1.0))
	return _upgrades.get_effective_dash_cooldown(cd, float(_cfg.get("dash_min_cooldown_s", 0.45))) if _upgrades != null else cd


func compute_move_speed(sprinting: bool, aiming: bool, world_y: float) -> float:
	return PlayerCombatRef.compute_move_speed(_cfg, _upgrades, _loadout, sprinting, aiming, world_y, float(_archetype.get("move_speed_mult", 1.0)))


func _unhandled_input(event: InputEvent) -> void:
	if is_dead or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _cam_rig != null:
		_cam_rig.apply_mouse_delta((event as InputEventMouseMotion).relative)
	elif event.is_action_pressed("toggle_view"):
		toggle_view_mode()
	elif event.is_action_pressed("toggle_fps_centered"):
		toggle_fps_centered()
	else:
		PlayerCombatRef.handle_slot_input(event, _loadout, _weapon_mgr)


func _physics_process(delta: float) -> void:
	if is_dead or _cfg.is_empty():
		return
	step_timers(delta)
	_handle_combat_inputs(delta)
	_handle_movement(delta)
	_update_visuals(delta)


func step_timers(delta: float) -> void:
	_iframes_left = maxf(0.0, _iframes_left - delta)
	_coyote_left = maxf(0.0, _coyote_left - delta)
	_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)
	_recoil_kick = maxf(0.0, _recoil_kick - delta * 6.0)
	_melee_anim_left = maxf(0.0, _melee_anim_left - delta)

	var max_chg := get_max_dash_charges()
	if _dash_charges < max_chg:
		_dash_regen_left -= delta
		if _dash_regen_left <= 0.0:
			_dash_charges += 1
			if _dash_charges < max_chg:
				_dash_regen_left = get_effective_dash_cooldown()
	var prog := 1.0 if _dash_charges >= max_chg else clampf(1.0 - _dash_regen_left / maxf(0.01, get_effective_dash_cooldown()), 0.0, 1.0)
	dash_state_changed.emit(_dash_charges, max_chg, prog)

	var regen := float(_cfg.get("hp_regen_per_sec", 0.0))
	if regen > 0.0 and current_hp > 0.0 and current_hp < max_hp:
		heal(regen * delta)


func try_start_dash(move_dir: Vector3) -> bool:
	if _dash_charges <= 0 or _dash_left > 0.0:
		return false
	_dash_charges -= 1
	if _dash_regen_left <= 0.0:
		_dash_regen_left = get_effective_dash_cooldown()
	_dash_left = float(_cfg.get("dash_duration_s", 0.20))
	_iframes_left = maxf(_iframes_left, float(_cfg.get("dash_iframes_s", 0.24)))
	var flat := Vector3(move_dir.x, 0.0, move_dir.z)
	var yaw := _cam_rig.yaw if _cam_rig != null else 0.0
	_dash_dir = (flat if flat.length_squared() >= 0.01 else Vector3(-sin(yaw), 0.0, -cos(yaw))).normalized()
	water_ripple_emitted.emit(global_position if is_inside_tree() else position, 1.4)
	return true


func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO) -> void:
	if is_dead or _iframes_left > 0.0 or amount <= 0.0:
		return
	current_hp = maxf(0.0, current_hp - amount)
	_iframes_left = float(_cfg.get("post_hit_iframes_s", 0.35))
	if _cam_rig != null:
		_cam_rig.add_trauma(0.45)
	velocity += Vector3(knockback.x, 0.0, knockback.z) * 0.45
	if _animator != null:
		_animator.trigger_wince()
	hp_changed.emit(current_hp, max_hp)
	damaged.emit(amount, knockback)
	if current_hp <= 0.0:
		is_dead = true
		if _animator != null:
			_animator.trigger_death()
		died.emit()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_hp = minf(max_hp, current_hp + amount)
	hp_changed.emit(current_hp, max_hp)


func apply_pickup(pickup_id: String, cfg: Dictionary) -> void:
	if pickup_id == "health_crate":
		heal(float(cfg.get("heal_flat", 35.0)) + max_hp * float(cfg.get("heal_max_hp_percent", 0.10)))
	elif pickup_id == "ammo_crate" and _loadout != null:
		_loadout.refill_ammo_percent(float(cfg.get("reserve_refill_percent", 0.40)), float(cfg.get("laser_battery_restore_percent", 1.0)))


func apply_upgrade_result(res: Dictionary) -> void:
	if _upgrades == null:
		return
	max_hp = float(_cfg.get("base_max_hp", 120.0)) * float(_archetype.get("max_hp_mult", 1.0)) + _upgrades.get_stat("max_hp_bonus")
	var h := float(res.get("heal_amount", 0.0))
	if h > 0.0:
		heal(h)
	else:
		hp_changed.emit(current_hp, max_hp)
	if str(res.get("id", "")) == "dash_recharge":
		_dash_charges = mini(get_max_dash_charges(), _dash_charges + 1)


func _handle_combat_inputs(delta: float) -> void:
	is_aiming = Input.is_action_pressed("aim")
	var res := PlayerCombatRef.process_combat(self, delta, _loadout, _cam_rig, _weapon_mgr, _animator)
	if res["fired"]:
		_recoil_kick = 1.0
		if res["is_melee"]:
			_melee_anim_total = float(res["melee_total"])
			_melee_anim_left = _melee_anim_total
			_melee_combo_step = int(res["combo_step"])


func _handle_movement(delta: float) -> void:
	var in_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_last_move_input = in_vec
	var yaw := _cam_rig.yaw if _cam_rig != null else 0.0
	var wish_dir := (Basis(Vector3.UP, yaw) * Vector3(in_vec.x, 0.0, in_vec.y))
	wish_dir.y = 0.0
	if wish_dir.length_squared() > 0.001:
		wish_dir = wish_dir.normalized()

	if Input.is_action_just_pressed("dash"):
		try_start_dash(wish_dir)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_left = float(_cfg.get("jump_buffer_time_s", 0.12))
	if is_on_floor():
		_coyote_left = float(_cfg.get("coyote_time_s", 0.14))
		if not _was_on_floor and global_position.y <= float(_cfg.get("shallow_water_max_y_m", 0.08)):
			water_ripple_emitted.emit(global_position, 1.2)
	_was_on_floor = is_on_floor()

	if _dash_left > 0.0:
		_dash_left = maxf(0.0, _dash_left - delta)
		velocity = _dash_dir * float(_cfg.get("dash_speed_mps", 18.5))
	else:
		var spd := compute_move_speed(Input.is_action_pressed("sprint") and wish_dir.length_squared() > 0.1, is_aiming or Input.is_action_pressed("fire"), global_position.y)
		var rate := float(_cfg.get("ground_accel_mps2", 42.0) if wish_dir.length_squared() > 0.01 else _cfg.get("ground_decel_mps2", 36.0)) if is_on_floor() else float(_cfg.get("air_accel_mps2", 16.0) if wish_dir.length_squared() > 0.01 else _cfg.get("air_decel_mps2", 4.0))
		var h_vel := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish_dir * spd, rate * delta)
		var vy := velocity.y - float(_cfg.get("gravity_mps2", 24.0)) * (float(_cfg.get("fall_gravity_multiplier", 1.25)) if velocity.y < 0.0 else 1.0) * delta
		if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
			vy = float(_cfg.get("jump_velocity_mps", 8.8))
			_jump_buffer_left = 0.0
			_coyote_left = 0.0
		velocity = Vector3(h_vel.x, vy, h_vel.z)

	move_and_slide()
	PlayerCombatRef.clamp_to_arena(self, _db)
	if is_on_floor() and global_position.y <= float(_cfg.get("shallow_water_max_y_m", 0.08)):
		_water_step_accum += Vector2(velocity.x, velocity.z).length() * delta
		var step_m := float(_cfg.get("water_ripple_step_distance_m", 0.38))
		if _water_step_accum >= step_m:
			_water_step_accum -= step_m
			water_ripple_emitted.emit(global_position, 0.75)


func _update_visuals(delta: float) -> void:
	if _cam_rig != null:
		_cam_rig.update_rig(delta, is_aiming, _dash_left > 0.0)
		_cam_rig.update_fps_viewmodel(delta, velocity, float(_cfg.get("sprint_speed_mps", 8.6)), is_on_floor(), is_aiming, _loadout)
	if _visual_root != null and _cam_rig != null:
		_visual_root.rotation.y = _cam_rig.yaw if _cam_rig.is_fps_mode else lerp_angle(_visual_root.rotation.y, _cam_rig.yaw, 18.0 * delta)
	if _animator != null and _loadout != null:
		var melee_prog := 1.0 - (_melee_anim_left / maxf(0.01, _melee_anim_total)) if _melee_anim_left > 0.0 else 0.0
		_animator.apply_pose(delta, velocity, is_on_floor(), _dash_left > 0.0, _recoil_kick, melee_prog, _melee_combo_step, str(_loadout.get_selected_def().get("id", "pistol")), _cam_rig.pitch if _cam_rig != null else 0.0, _last_move_input)
