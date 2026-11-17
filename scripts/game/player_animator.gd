class_name PlayerAnimator
extends Node
## Drives SK_Isabela retargeted CC0 locomotion, layered upper-body weapon clips, strafe/aim twist, curled finger grips, ARKit expressions, and FPS shadow-only mode.

const AnimLoaderRef := preload("res://scripts/game/anim_library_loader.gd")
const ANIMS_GLB_PATH := "res://assets/SK_Isabela/SK_Isabela_Anims.glb"

var _isabela_root: Node3D
var _skeleton: Skeleton3D
var _body_mesh: MeshInstance3D
var _meshes: Array[MeshInstance3D] = []
var _weapon_socket: Node3D
var _anim_player: AnimationPlayer
var _anim_tree: AnimationTree
var _clips: Dictionary = {}
var _has_anim_tree: bool = false

var _rest_locals: Dictionary = {}
var _rest_globals: Dictionary = {}

var _walk_phase: float = 0.0
var _blink_timer: float = 2.8
var _blink_left: float = 0.0
var _wince_left: float = 0.0
var _focus_left: float = 0.0
var _was_on_floor: bool = true
var _jump_start_left: float = 0.0
var _jump_land_left: float = 0.0
var _is_dead: bool = false
var _last_loco_state: String = ""
var _last_upper_idle: String = ""
var _last_grip_choice: String = ""


func bind_isabela(isabela_root: Node3D) -> void:
	_isabela_root = isabela_root
	_skeleton = isabela_root.get_node_or_null("Armature_Isabela/Skeleton3D") as Skeleton3D
	if _skeleton == null:
		var sks := isabela_root.find_children("*", "Skeleton3D", true, false)
		_skeleton = sks[0] as Skeleton3D if not sks.is_empty() else null
	if _skeleton == null:
		push_error("PlayerAnimator: Skeleton3D not found under SK_Isabela"); return
	_body_mesh = _skeleton.get_node_or_null("SK_Isabela_Body") as MeshInstance3D
	_meshes.clear(); _collect_meshes(isabela_root)
	_rest_locals.clear(); _rest_globals.clear()
	for i in range(_skeleton.get_bone_count()):
		var bname := _skeleton.get_bone_name(i)
		_rest_locals[bname] = _skeleton.get_bone_rest(i).basis
		_rest_globals[bname] = _skeleton.get_bone_global_rest(i).basis
	var attach := _skeleton.get_node_or_null("RightHandAttachment") as BoneAttachment3D
	if attach == null:
		attach = BoneAttachment3D.new(); attach.name = "RightHandAttachment"
		attach.bone_name = "RightHand" if _skeleton.find_bone("RightHand") >= 0 else ("Forearm.R" if _skeleton.find_bone("Forearm.R") >= 0 else _skeleton.get_bone_name(0))
		_skeleton.add_child(attach)
	_weapon_socket = attach.get_node_or_null("WeaponSocket") as Node3D
	if _weapon_socket == null:
		_weapon_socket = Node3D.new(); _weapon_socket.name = "WeaponSocket"
		_weapon_socket.position = Vector3(-0.096, 0.064, 0.100); _weapon_socket.rotation = Vector3(1.35, 0.54, -0.26)
		attach.add_child(_weapon_socket)
	var top_mesh := _skeleton.get_node_or_null("SK_Isabela_Top") as MeshInstance3D
	if top_mesh != null:
		top_mesh.lod_bias = 4.0
		var top_mat := top_mesh.get_active_material(0)
		if top_mat is StandardMaterial3D:
			var smat := (top_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			smat.grow = true
			smat.grow_amount = 0.006
			top_mesh.set_surface_override_material(0, smat)

	_setup_animation_tree()


func _setup_animation_tree() -> void:
	if _skeleton.find_bone("Hips") == -1:
		_has_anim_tree = false; _anim_tree = null
		_anim_player = _isabela_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		return
	var res := AnimLoaderRef.setup_isabela_anim_tree(_isabela_root, ANIMS_GLB_PATH)
	_anim_player = res["player"]; _anim_tree = res["tree"]; _clips = res["clips"]
	_has_anim_tree = _anim_tree != null and not _clips.is_empty()

func has_animation_clip(clip_name: String) -> bool: return _clips.has(clip_name)
func get_skeleton() -> Skeleton3D: return _skeleton
func get_weapon_socket() -> Node3D: return _weapon_socket

func set_first_person_shadow_only(enabled: bool) -> void:
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for m in _meshes:
		if is_instance_valid(m):
			m.cast_shadow = mode

func trigger_wince() -> void:
	_wince_left = 0.28
	_fire_upper_action("hit")


func trigger_fire_expression() -> void:
	_focus_left = 0.35


func trigger_shoot(weapon_id: String) -> void:
	trigger_fire_expression()
	var act := "pistol_shoot"
	if weapon_id in ["shotgun", "laser_gun", "smg", "sniper"]:
		act = "rifle_shoot"
	elif weapon_id == "rocket_launcher":
		act = "rocket_shoot"
	_fire_upper_action(act)


func trigger_reload(weapon_id: String) -> void:
	var act := "pistol_reload"
	if weapon_id in ["shotgun", "laser_gun", "smg", "sniper"]:
		act = "rifle_reload"
	elif weapon_id == "rocket_launcher":
		act = "rocket_reload"
	_fire_upper_action(act)


func trigger_melee(weapon_id: String, combo_step: int) -> void:
	trigger_fire_expression()
	var prefix := "saber" if weapon_id == "lightsaber" else "sword"
	_fire_upper_action("%s_%d" % [prefix, clampi(combo_step, 1, 3)])


func trigger_death() -> void:
	_is_dead = true


func apply_pose(delta: float, velocity: Vector3, on_floor: bool, is_dashing: bool, recoil: float, melee_prog: float, combo_step: int, weapon_id: String, aim_pitch: float = 0.0, local_move: Vector2 = Vector2.ZERO) -> void:
	if _skeleton == null:
		return
	_jump_start_left = maxf(0.0, _jump_start_left - delta)
	_jump_land_left = maxf(0.0, _jump_land_left - delta)
	if _was_on_floor and not on_floor and velocity.y > 0.8:
		_jump_start_left = 0.22
	elif not _was_on_floor and on_floor:
		_jump_land_left = 0.18
	_was_on_floor = on_floor

	if _has_anim_tree and _anim_tree != null:
		_apply_anim_tree_pose(delta, velocity, on_floor, is_dashing, weapon_id, aim_pitch, local_move)
	else:
		_apply_procedural_fallback(delta, velocity, on_floor, is_dashing, recoil, melee_prog, combo_step, weapon_id)
	_update_blendshapes(delta)


func _apply_anim_tree_pose(delta: float, velocity: Vector3, on_floor: bool, is_dashing: bool, weapon_id: String, aim_pitch: float, local_move: Vector2) -> void:
	var h_speed := Vector2(velocity.x, velocity.z).length()
	var loco := "idle"
	var upper_blend := 1.0
	if _is_dead:
		loco = "death"
		upper_blend = 0.0
	elif is_dashing:
		loco = "roll"
		upper_blend = 0.0
	elif not on_floor:
		loco = "jump_start" if _jump_start_left > 0.0 else "jump_loop"
	elif _jump_land_left > 0.0 and h_speed < 3.5:
		loco = "jump_land"
	elif h_speed >= 7.0:
		loco = "sprint"
	elif h_speed >= 4.2:
		loco = "jog"
	elif h_speed >= 0.25:
		loco = "walk"

	if loco != _last_loco_state:
		_anim_tree.set("parameters/Loco/transition_request", loco)
		_last_loco_state = loco

	var uidle := "pistol"
	var grip := "right"
	if weapon_id in ["shotgun", "laser_gun", "smg", "sniper"]:
		uidle = "rifle"
		grip = "both"
	elif weapon_id == "rocket_launcher":
		uidle = "rocket"
		grip = "both"
	elif weapon_id in ["katana", "lightsaber"]:
		uidle = "sword"
	if uidle != _last_upper_idle:
		_anim_tree.set("parameters/UpperIdle/transition_request", uidle)
		_last_upper_idle = uidle
	if grip != _last_grip_choice:
		_anim_tree.set("parameters/GripChoice/transition_request", grip)
		_last_grip_choice = grip

	_anim_tree.set("parameters/UpperBlend/blend_amount", upper_blend)
	_anim_tree.set("parameters/GripBlend/blend_amount", 0.85 if upper_blend > 0.5 else 0.0)
	_anim_tree.advance(delta)
	if uidle == "sword" and upper_blend > 0.5:
		_set_char_rot("LeftShoulder", Vector3.ZERO)
		_set_char_rot("LeftUpperArm", Vector3(-0.18, 0.12, -0.58))
		_set_char_rot("LeftLowerArm", Vector3(-0.38, -0.15, 0.0))

	if not _is_dead and not is_dashing:
		var move_fac := clampf(h_speed / 5.8, 0.0, 1.0)
		var strafe_yaw := clampf(-local_move.x, -1.0, 1.0) * 0.28 * move_fac
		var pitch_add := clampf(aim_pitch * 0.42, -0.34, 0.34)
		if absf(strafe_yaw) > 0.01:
			_add_char_delta("Hips", Vector3(0.0, strafe_yaw, 0.0))
			_add_char_delta("Spine", Vector3(0.0, -strafe_yaw * 0.55, 0.0))
			_add_char_delta("UpperChest", Vector3(pitch_add, -strafe_yaw * 0.45, 0.0))
		elif absf(pitch_add) > 0.01:
			_add_char_delta("UpperChest", Vector3(pitch_add * 0.65, 0.0, 0.0))
		if absf(pitch_add) > 0.01:
			_add_char_delta("Head", Vector3(pitch_add * 0.35, 0.0, 0.0))


func _fire_upper_action(action_name: String) -> void:
	if not _has_anim_tree or _anim_tree == null:
		return
	_anim_tree.set("parameters/UpperAction/transition_request", action_name)
	_anim_tree.set("parameters/UpperOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _apply_procedural_fallback(delta: float, velocity: Vector3, on_floor: bool, is_dashing: bool, recoil: float, melee_prog: float, combo_step: int, weapon_id: String) -> void:
	if _anim_player != null and _skeleton.find_bone("Hips") == -1:
		preload("res://scripts/game/player_skin_helper.gd").tick_boss_skin_anim(_anim_player, velocity, melee_prog > 0.01 or recoil > 0.25)
		return
	var h_speed := Vector2(velocity.x, velocity.z).length()
	_walk_phase = fmod(_walk_phase + delta * (clampf(h_speed * 1.45, 3.0, 12.0) if h_speed > 0.25 and on_floor else 1.6), TAU)
	var mb := clampf(h_speed / 5.8, 0.0, 1.35) if on_floor else 0.35
	var stride := sin(_walk_phase) * 0.48 * mb
	var dash_lean := 0.38 if is_dashing else 0.06 * mb
	_set_char_rot("Hips", Vector3(dash_lean, cos(_walk_phase) * 0.05 * mb, 0.0))
	_set_char_rot("Spine", Vector3(dash_lean * 0.4, -cos(_walk_phase) * 0.04 * mb, 0.0))
	_set_char_rot("UpperChest", Vector3(0.04 - recoil * 0.06, 0.0, 0.0))
	_set_char_rot("LeftUpperLeg", Vector3(-stride, 0.0, 0.0))
	_set_char_rot("LeftLowerLeg", Vector3(maxf(0.0, sin(_walk_phase + 0.6)) * 0.65 * mb, 0.0, 0.0))
	_set_char_rot("RightUpperLeg", Vector3(stride, 0.0, 0.0))
	_set_char_rot("RightLowerLeg", Vector3(maxf(0.0, -sin(_walk_phase + 0.6)) * 0.65 * mb, 0.0, 0.0))
	_set_char_rot("LeftUpperArm", Vector3(stride * 0.35 - 0.08, 0.0, -0.62))
	_set_char_rot("LeftLowerArm", Vector3(-0.24, -0.10, 0.0))
	if melee_prog > 0.001 and weapon_id in ["lightsaber", "katana"]:
		var sw := sin(melee_prog * PI)
		var ds := -1.0 if combo_step % 2 == 1 else 1.0
		_set_char_rot("RightUpperArm", Vector3(-0.48 + 0.25 * sw, ds * 0.70 * sw, 0.28))
		_set_char_rot("RightLowerArm", Vector3(-0.45, 0.0, 0.0))
	else:
		_set_char_rot("RightUpperArm", Vector3(-0.48 - recoil * 0.12, -0.06, 0.24))
		_set_char_rot("RightLowerArm", Vector3(-0.48 + recoil * 0.10, 0.0, 0.0))


func _apply_char_rot(bone_name: String, euler_xyz: Vector3, additive: bool = false) -> void:
	var idx := _skeleton.find_bone(bone_name)
	if idx == -1:
		return
	var base: Basis = Basis(_skeleton.get_bone_pose_rotation(idx)) if additive else _rest_locals.get(bone_name, Basis.IDENTITY)
	var rg: Basis = _rest_globals.get(bone_name, Basis.IDENTITY)
	var cr := Basis.from_euler(euler_xyz, EULER_ORDER_YXZ)
	_skeleton.set_bone_pose_rotation(idx, (base * (rg.inverse() * cr * rg)).get_rotation_quaternion())


func _set_char_rot(bone_name: String, euler_xyz: Vector3) -> void: _apply_char_rot(bone_name, euler_xyz, false)
func _add_char_delta(bone_name: String, euler_xyz: Vector3) -> void: _apply_char_rot(bone_name, euler_xyz, true)


func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_meshes.append(node as MeshInstance3D)
	for c in node.get_children():
		_collect_meshes(c)


func _update_blendshapes(delta: float) -> void:
	if _body_mesh == null:
		return
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_left = 0.14
		_blink_timer = randf_range(2.6, 5.2)
	_blink_left = maxf(0.0, _blink_left - delta)
	_wince_left = maxf(0.0, _wince_left - delta)
	_focus_left = maxf(0.0, _focus_left - delta)
	var bw := sin((_blink_left / 0.14) * PI) if _blink_left > 0.0 else 0.0
	var ww := clampf(_wince_left / 0.28, 0.0, 1.0)
	var fw := clampf(_focus_left / 0.35, 0.0, 1.0) * 0.45
	_set_bs("eyeBlinkLeft", maxf(bw, ww * 0.7))
	_set_bs("eyeBlinkRight", maxf(bw, ww * 0.7))
	_set_bs("browDownLeft", maxf(fw, ww))
	_set_bs("browDownRight", maxf(fw, ww))


func _set_bs(bs_name: String, value: float) -> void:
	var idx := _body_mesh.find_blend_shape_by_name(bs_name)
	if idx != -1:
		_body_mesh.set_blend_shape_value(idx, value)
