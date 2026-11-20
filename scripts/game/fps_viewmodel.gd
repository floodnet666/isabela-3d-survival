class_name FPSViewmodel
extends Node3D
## First-person arms + weapon viewmodel attached to Camera3D with sway, bob, ADS alignment, recoil, reload, and melee slashes.

const FPS_ARMS_PATH := "res://assets/SK_Isabela/FPS_Arms.glb"
const FPSOpticHelperRef := preload("res://scripts/game/fps_optic_helper.gd")
const WeaponPoolRef := preload("res://scripts/game/weapon_pool_helper.gd")

const WEAPON_TWEAKS := {
	"pistol": {"pos": Vector3(0.07, -0.06, -0.02), "ads_pos": Vector3(-0.0917, -0.015, 0.03), "rot": Vector3(0.0, 0.025, 0.0), "ads_rot": Vector3.ZERO, "doom_x": -0.0917, "recoil_z": 0.045, "recoil_pitch": 0.08},
	"sniper": {"pos": Vector3(0.08, -0.07, -0.05), "ads_pos": Vector3(-0.0917, -0.032, -0.01), "rot": Vector3(0.0, 0.025, 0.0), "ads_rot": Vector3.ZERO, "doom_x": -0.0917, "recoil_z": 0.095, "recoil_pitch": 0.15},
	"lightsaber": {"pos": Vector3(0.09, -0.09, -0.02), "ads_pos": Vector3(-0.02, -0.07, 0.0), "rot": Vector3(-0.18, 0.14, 0.28), "ads_rot": Vector3(-0.10, 0.05, 0.14), "doom_x": -0.09, "recoil_z": 0.02, "recoil_pitch": 0.04},
	"shotgun": {"pos": Vector3(0.08, -0.07, -0.05), "ads_pos": Vector3(-0.0917, -0.025, -0.01), "rot": Vector3(0.0, 0.025, 0.0), "ads_rot": Vector3.ZERO, "doom_x": -0.0917, "recoil_z": 0.085, "recoil_pitch": 0.14},
	"rocket_launcher": {"pos": Vector3(0.11, -0.08, -0.10), "ads_pos": Vector3(-0.04, -0.05, -0.08), "rot": Vector3(0.0, 0.02, 0.0), "ads_rot": Vector3.ZERO, "doom_x": -0.0917, "recoil_z": 0.10, "recoil_pitch": 0.16},
	"katana": {"pos": Vector3(0.09, -0.10, -0.02), "ads_pos": Vector3(-0.02, -0.08, 0.0), "rot": Vector3(-0.20, 0.16, 0.32), "ads_rot": Vector3(-0.12, 0.06, 0.16), "doom_x": -0.09, "recoil_z": 0.02, "recoil_pitch": 0.04},
	"laser_gun": {"pos": Vector3(0.08, -0.07, -0.04), "ads_pos": Vector3(-0.0917, -0.022, -0.01), "rot": Vector3(0.0, 0.025, 0.0), "ads_rot": Vector3.ZERO, "doom_x": -0.0917, "recoil_z": 0.030, "recoil_pitch": 0.05},
	"smg": {"pos": Vector3(0.08, -0.07, -0.04), "ads_pos": Vector3(-0.0917, -0.025, -0.01), "rot": Vector3(0.0, 0.025, 0.0), "ads_rot": Vector3.ZERO, "doom_x": -0.0917, "recoil_z": 0.036, "recoil_pitch": 0.06},
}

var doom_centered: bool = false

var _rig_root: Node3D
var _arms_instance: Node3D
var _anim_player: AnimationPlayer
var _weapon_socket: Node3D
var _active_weapon: Node3D
var _muzzle_node: Node3D
var _weapon_def: Dictionary = {}

var _has_arms_asset: bool = false
var _built: bool = false
var _bob_phase: float = 0.0
var _breath_phase: float = 0.0
var _sway_offset: Vector2 = Vector2.ZERO
var _recoil_z: float = 0.0
var _recoil_pitch: float = 0.0
var _draw_left: float = 0.0
var _reload_left: float = 0.0
var _reload_total: float = 1.0
var _melee_left: float = 0.0
var _melee_total: float = 0.24
var _melee_combo: int = 1
var _oneshot_left: float = 0.0
var _overheat_active: bool = false
var _overheat_phase: float = 0.0
var _cool_ready_left: float = 0.0
var _optic_helper := FPSOpticHelperRef.new()
var _fps_pool := WeaponPoolRef.new()


func _ready() -> void:
	name = "FPSViewmodel"
	visible = false
	ensure_built()


func ensure_built() -> void:
	if _built:
		return
	_built = true
	_rig_root = Node3D.new()
	_rig_root.name = "RigRoot"
	add_child(_rig_root)

	if ResourceLoader.exists(FPS_ARMS_PATH):
		var ps := load(FPS_ARMS_PATH) as PackedScene
		if ps != null:
			_arms_instance = ps.instantiate() as Node3D
			_rig_root.add_child(_arms_instance)
			_has_arms_asset = true
			_optic_helper.disable_shadows_recursive(_arms_instance)
			_anim_player = _arms_instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if _anim_player != null:
				WeaponPoolRef.sanitize_fps_animations(_anim_player)
				for loop_name in ["FPS_Idle", "FPS_Walk"]:
					if _anim_player.has_animation(loop_name):
						_anim_player.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
			_weapon_socket = _arms_instance.find_child("FPSWeaponSocket", true, false) as Node3D
			if _weapon_socket == null:
				_weapon_socket = _arms_instance.find_child("WeaponSocket", true, false) as Node3D

	if _weapon_socket == null:
		_weapon_socket = Node3D.new()
		_weapon_socket.name = "FPSWeaponSocket"
		_weapon_socket.position = Vector3(0.20, -0.20, -0.42)
		_rig_root.add_child(_weapon_socket)


func set_active(enabled: bool) -> void:
	ensure_built()
	visible = enabled
	if not enabled:
		_optic_helper.set_aiming(false, str(_weapon_def.get("id", "")))
		return
	_sway_offset = Vector2.ZERO
	_recoil_z = 0.0
	_recoil_pitch = 0.0
	_draw_left = 0.22
	_play_clip("FPS_Draw", 0.08, true)


func toggle_doom_centered() -> bool:
	doom_centered = not doom_centered
	return doom_centered


func get_pooled_weapon_count() -> int:
	return _fps_pool.get_count()


func prewarm_weapons(defs: Array) -> void:
	ensure_built()
	_fps_pool.prewarm_all(defs, _weapon_socket, true, _optic_helper)


func set_weapon(def: Dictionary) -> void:
	ensure_built()
	_optic_helper.set_aiming(false, str(_weapon_def.get("id", "")))
	_optic_helper.set_weapon_overlay(_active_weapon, Color(0, 0, 0, 0))
	_weapon_def = def.duplicate(true)
	var entry := _fps_pool.activate(def, _weapon_socket, true, _optic_helper)
	_active_weapon = entry.get("node") as Node3D
	_muzzle_node = entry.get("muzzle") as Node3D
	if _active_weapon == null:
		return
	_optic_helper.bind_weapon(_active_weapon)
	_draw_left = 0.22
	_overheat_active = false
	_cool_ready_left = 0.0
	_reload_left = 0.0
	if visible:
		_play_clip("FPS_Draw", 0.08, true)
	if str(def.get("id", "")) == "lightsaber":
		var blade := entry.get("blade") as Node3D
		if blade != null:
			blade.scale.y = 0.05
			var tw := blade.create_tween()
			tw.tween_property(blade, "scale:y", 1.0, 0.16)


func add_look_sway(rel: Vector2) -> void:
	if not visible:
		return
	_sway_offset.x = clampf(_sway_offset.x - rel.x * 0.00055, -0.045, 0.045)
	_sway_offset.y = clampf(_sway_offset.y + rel.y * 0.00045, -0.035, 0.035)


func trigger_fire(weapon_id: String) -> void:
	var tw: Dictionary = WEAPON_TWEAKS.get(weapon_id, WEAPON_TWEAKS["pistol"])
	_recoil_z = float(tw.get("recoil_z", 0.06))
	_recoil_pitch = float(tw.get("recoil_pitch", 0.12))
	var clip := "FPS_Fire_Heavy" if weapon_id in ["shotgun", "rocket_launcher", "laser_gun", "smg"] else "FPS_Fire_Pistol"
	_play_clip(clip, 0.03, true)


func trigger_reload(duration_s: float) -> void:
	_reload_total = maxf(0.2, duration_s)
	_reload_left = _reload_total
	_play_clip("FPS_Reload", 0.08, true)


func trigger_laser_overheat(_lockout_s: float = 1.8) -> void:
	_overheat_active = true
	_overheat_phase = 0.0
	_cool_ready_left = 0.0
	_set_weapon_overlay(Color(1.0, 0.30, 0.06, 0.42))


func trigger_laser_ready() -> void:
	_overheat_active = false
	_cool_ready_left = 0.40
	_set_weapon_overlay(Color(0.25, 0.92, 1.0, 0.38))


func trigger_melee(combo_step: int, duration_s: float) -> void:
	_melee_combo = clampi(combo_step, 1, 3)
	_melee_total = maxf(0.16, duration_s)
	_melee_left = _melee_total
	_play_clip("FPS_Melee_%d" % _melee_combo, 0.04, true)


func update_viewmodel(delta: float, h_speed: float, max_speed: float, on_floor: bool, is_aiming: bool, is_reloading: bool) -> void:
	if not visible or _rig_root == null:
		return
	_breath_phase = fmod(_breath_phase + delta * 2.1, TAU)
	var move_ratio := clampf(h_speed / maxf(1.0, max_speed), 0.0, 1.4) if on_floor else 0.1
	_bob_phase = fmod(_bob_phase + delta * lerpf(2.0, 10.5, minf(1.0, move_ratio)), TAU)

	_sway_offset = _sway_offset.lerp(Vector2.ZERO, minf(1.0, delta * 11.0))
	_recoil_z = lerpf(_recoil_z, 0.0, minf(1.0, delta * 15.0))
	_recoil_pitch = lerpf(_recoil_pitch, 0.0, minf(1.0, delta * 14.0))
	_draw_left = maxf(0.0, _draw_left - delta)
	_oneshot_left = maxf(0.0, _oneshot_left - delta)
	if is_reloading:
		_reload_left = maxf(0.0, _reload_left - delta)
	else:
		_reload_left = 0.0
	_melee_left = maxf(0.0, _melee_left - delta)
	if _overheat_active:
		_overheat_phase = fmod(_overheat_phase + delta * 22.0, TAU)
		_set_weapon_overlay(Color(1.0, 0.28, 0.06, 0.28 + 0.16 * absf(sin(_overheat_phase * 0.35))))
	elif _cool_ready_left > 0.0:
		_cool_ready_left = maxf(0.0, _cool_ready_left - delta)
		if _cool_ready_left <= 0.0:
			_set_weapon_overlay(Color(0.0, 0.0, 0.0, 0.0))
		else:
			_set_weapon_overlay(Color(0.25, 0.92, 1.0, (_cool_ready_left / 0.40) * 0.40))

	var wid := str(_weapon_def.get("id", "pistol"))
	var tw: Dictionary = WEAPON_TWEAKS.get(wid, WEAPON_TWEAKS["pistol"])
	var base_pos: Vector3 = tw.get("pos", Vector3.ZERO)
	var base_rot: Vector3 = tw.get("rot", Vector3.ZERO)
	if doom_centered:
		base_pos.x += float(tw.get("doom_x", -0.171))
		base_pos.y += 0.015
		base_rot = tw.get("ads_rot", base_rot)
	elif is_aiming and not is_reloading and _melee_left <= 0.0:
		base_pos = tw.get("ads_pos", base_pos)
		base_rot = tw.get("ads_rot", base_rot)
	_optic_helper.set_aiming(is_aiming and not is_reloading and _melee_left <= 0.0 and not doom_centered, wid)

	var aim_scale := 0.35 if is_aiming else 1.0
	var proc_scale := 0.22 if _has_arms_asset else 1.0
	var anim_scale := maxf(0.55, proc_scale)
	var bob_x := cos(_bob_phase * 0.5) * 0.011 * move_ratio * aim_scale
	var bob_y := absf(sin(_bob_phase)) * -0.012 * move_ratio * aim_scale + sin(_breath_phase) * 0.0025
	var draw_drop := (_draw_left / 0.22) * -0.14 * proc_scale if _draw_left > 0.0 else 0.0
	var reload_dip := sin((1.0 - _reload_left / _reload_total) * PI) * -0.11 * anim_scale if _reload_left > 0.0 else 0.0
	var oh_pos := Vector3(0.03 * anim_scale + sin(_overheat_phase) * 0.004, -0.045 * anim_scale, 0.025 * anim_scale) if _overheat_active else Vector3.ZERO
	var cool_z := sin((1.0 - _cool_ready_left / 0.40) * PI) * -0.035 * anim_scale if _cool_ready_left > 0.0 else 0.0
	var oh_rot := Vector3(0.16 * anim_scale, 0.24 * anim_scale, -0.44 * anim_scale) if _overheat_active else Vector3.ZERO
	var cool_pitch := sin((1.0 - _cool_ready_left / 0.40) * PI) * 0.09 * anim_scale if _cool_ready_left > 0.0 else 0.0

	var melee_pos := Vector3.ZERO
	var melee_rot := Vector3.ZERO
	if _melee_left > 0.0:
		var prog := 1.0 - (_melee_left / _melee_total)
		var arc := sin(prog * PI) * proc_scale
		if _melee_combo == 1:
			melee_pos = Vector3(lerpf(0.12, -0.22, prog) * proc_scale, -0.03 * arc, -0.14 * arc)
			melee_rot = Vector3(-0.35 * arc, lerpf(-0.65, 0.95, prog) * proc_scale, 0.72 * arc)
		elif _melee_combo == 2:
			melee_pos = Vector3(lerpf(-0.20, 0.14, prog) * proc_scale, 0.02 * arc, -0.14 * arc)
			melee_rot = Vector3(-0.25 * arc, lerpf(0.85, -0.75, prog) * proc_scale, -0.75 * arc)
		else:
			melee_pos = Vector3(-0.04 * arc, lerpf(0.14, -0.18, prog) * proc_scale, -0.18 * arc)
			melee_rot = Vector3(lerpf(0.55, -1.15, prog) * proc_scale, 0.12 * arc, -0.25 * arc)

	_rig_root.position = base_pos + Vector3(bob_x + _sway_offset.x, bob_y + _sway_offset.y + draw_drop + reload_dip, _recoil_z + cool_z) + melee_pos + oh_pos
	var reload_roll := sin((1.0 - _reload_left / _reload_total) * PI) * 0.42 * anim_scale if _reload_left > 0.0 else 0.0
	_rig_root.rotation = base_rot + Vector3(_recoil_pitch + cool_pitch - _sway_offset.y * 1.4 - (_draw_left / 0.22) * 0.35 * proc_scale, -_sway_offset.x * 1.6, reload_roll) + melee_rot + oh_rot

	if _oneshot_left <= 0.0 and _melee_left <= 0.0 and _reload_left <= 0.0:
		var loco_clip := "FPS_Walk" if move_ratio > 0.22 and on_floor else "FPS_Idle"
		_play_clip(loco_clip, 0.14, false)


func get_muzzle_world_position(def: Dictionary = {}) -> Vector3:
	ensure_built()
	if _muzzle_node != null and _muzzle_node.is_inside_tree():
		return _muzzle_node.global_position
	var d := def if not def.is_empty() else _weapon_def
	var off_arr: Array = d.get("asset_spec", {}).get("muzzle_offset_m", [0.0, 0.06, -0.35])
	var local_off := Vector3(float(off_arr[0]), float(off_arr[1]), float(off_arr[2]))
	if _weapon_socket != null and _weapon_socket.is_inside_tree():
		return _weapon_socket.to_global(local_off)
	return global_position + Vector3(0.15, -0.12, -0.55)


func _play_clip(clip_name: String, blend_s: float, is_oneshot: bool) -> void:
	if _anim_player == null or not _anim_player.has_animation(clip_name):
		return
	if is_oneshot:
		var anim := _anim_player.get_animation(clip_name)
		_oneshot_left = anim.length if anim != null else 0.25
		_anim_player.stop(true)
		_anim_player.play(clip_name, blend_s)
	elif _anim_player.current_animation != clip_name or not _anim_player.is_playing():
		_anim_player.play(clip_name, blend_s)


func _set_weapon_overlay(col: Color) -> void:
	_optic_helper.set_weapon_overlay(_active_weapon, col)
