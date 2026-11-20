class_name PlayerCameraRig
extends Node3D
## Manages TPS over-shoulder & FPS eye-level camera yaw/pitch, aim zoom, FOV kick, trauma shake, and center-screen aim raycast.

const FPSViewmodelRef := preload("res://scripts/game/fps_viewmodel.gd")

var yaw: float = 0.0
var pitch: float = -0.08
var is_fps_mode: bool = false

var _cfg: Dictionary = {}
var _trauma: float = 0.0
var _spring_arm: SpringArm3D
var _camera: Camera3D
var _fps_viewmodel: FPSViewmodelRef


func _ready() -> void:
	_spring_arm = get_node_or_null("SpringArm3D") as SpringArm3D
	_camera = get_node_or_null("SpringArm3D/Camera3D") as Camera3D
	_ensure_fps_viewmodel()


func configure(cam_cfg: Dictionary) -> void:
	_cfg = cam_cfg
	if _spring_arm == null:
		_spring_arm = get_node_or_null("SpringArm3D") as SpringArm3D
	if _spring_arm != null:
		var arm_shape := SphereShape3D.new()
		arm_shape.radius = 0.24
		_spring_arm.shape = arm_shape
		_spring_arm.collision_mask = 1
		_spring_arm.margin = 0.12
	if _camera == null:
		_camera = get_node_or_null("SpringArm3D/Camera3D") as Camera3D
	if _camera != null:
		_camera.near = 0.03
		_camera.far = 500.0
	_ensure_fps_viewmodel()
	_apply_rig_targets(true, false, false)


func apply_user_settings(mouse_sens: float, controller_sens: float, fov_deg: float) -> void:
	_cfg["mouse_sensitivity"] = mouse_sens
	_cfg["controller_sensitivity"] = controller_sens
	_cfg["fov_normal_deg"] = fov_deg
	_cfg["fps_fov_normal_deg"] = clampf(fov_deg + 20.0, 68.0, 110.0)
	_apply_rig_targets(true, false, false)


func set_fps_mode(enabled: bool, immediate: bool = true) -> void:
	is_fps_mode = enabled
	pitch = _clamp_pitch(pitch)
	_ensure_fps_viewmodel()
	if _fps_viewmodel != null:
		_fps_viewmodel.set_active(enabled)
	if immediate:
		_apply_rig_targets(true, false, false)


func toggle_view_mode() -> bool:
	set_fps_mode(not is_fps_mode, true)
	return is_fps_mode


func sync_player_view(visual_root: Node3D, animator: Node, weapon_mgr: Node) -> Dictionary:
	if animator != null and animator.has_method("set_first_person_shadow_only"):
		animator.call("set_first_person_shadow_only", is_fps_mode)
	if weapon_mgr != null and weapon_mgr.has_method("set_fps_context"):
		weapon_mgr.call("set_fps_context", is_fps_mode, get_fps_viewmodel())
	if is_fps_mode and visual_root != null:
		visual_root.rotation.y = yaw
	var vm := get_fps_viewmodel()
	return {"is_fps": is_fps_mode, "doom_centered": vm != null and vm.doom_centered}


func get_camera() -> Camera3D:
	return _camera


func get_fps_viewmodel() -> FPSViewmodelRef:
	_ensure_fps_viewmodel()
	return _fps_viewmodel


func apply_mouse_delta(rel: Vector2) -> void:
	var sens := float(_cfg.get("mouse_sensitivity", 0.0022))
	yaw -= rel.x * sens
	pitch = _clamp_pitch(pitch - rel.y * sens)
	if is_fps_mode and _fps_viewmodel != null:
		_fps_viewmodel.add_look_sway(rel)


func apply_controller_look(look_vec: Vector2, delta: float, is_aiming: bool = false) -> void:
	if look_vec.length_squared() < 0.001:
		return
	var sens := float(_cfg.get("controller_sensitivity", 3.4))
	if is_aiming:
		sens *= float(_cfg.get("controller_aim_sensitivity_multiplier", 0.65))
	var curve := pow(look_vec.length(), 1.3)
	var dir := look_vec.normalized() * curve
	yaw -= dir.x * sens * delta
	pitch = _clamp_pitch(pitch - dir.y * sens * delta)
	if is_fps_mode and _fps_viewmodel != null:
		_fps_viewmodel.add_look_sway(dir * sens * delta * 50.0)


func add_trauma(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


func update_rig(delta: float, is_aiming: bool, is_dashing: bool) -> void:
	var look_vec := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	apply_controller_look(look_vec, delta, is_aiming)
	_trauma = maxf(0.0, _trauma - delta * 2.2)
	rotation = Vector3(pitch, yaw, 0.0)
	_apply_rig_targets(false, is_aiming, is_dashing, delta)
	if _camera != null:
		if _trauma > 0.001:
			var shake := _trauma * _trauma * (0.04 if is_fps_mode else 0.07)
			_camera.h_offset = randf_range(-shake, shake)
			_camera.v_offset = randf_range(-shake, shake)
		else:
			_camera.h_offset = 0.0
			_camera.v_offset = 0.0


func update_fps_viewmodel(delta: float, velocity: Vector3, max_speed: float, on_floor: bool, is_aiming: bool, loadout: Variant) -> void:
	if _fps_viewmodel != null and _fps_viewmodel.visible and loadout != null:
		var hud_st: Dictionary = loadout.get_slot_hud_state(loadout.get_selected_slot())
		_fps_viewmodel.update_viewmodel(delta, Vector2(velocity.x, velocity.z).length(), max_speed, on_floor, is_aiming, bool(hud_st.get("is_reloading", false)))


func get_aim_ray(owner_body: CollisionObject3D) -> Dictionary:
	var body_pos := owner_body.global_position if owner_body.is_inside_tree() else owner_body.position
	if _camera == null or not _camera.is_inside_tree():
		var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var h := float(_cfg.get("fps_eye_height_m", 1.58)) if is_fps_mode else 1.30
		return {"origin": body_pos + Vector3(0.0, h, 0.0), "target": body_pos + Vector3(0.0, h, 0.0) + fwd * 40.0, "forward": fwd}
	var origin := _camera.global_position
	var fwd := -_camera.global_transform.basis.z.normalized()
	var target := origin + fwd * float(_cfg.get("aim_raycast_max_m", 120.0))
	var space := owner_body.get_world_3d().direct_space_state
	if space != null:
		var q := PhysicsRayQueryParameters3D.create(origin, target, 1 | 4)
		q.exclude = [owner_body.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var hp: Vector3 = hit["position"]
			var min_dist := 0.35 if is_fps_mode else 1.5
			if (hp.distance_to(origin) if is_fps_mode else hp.distance_to(body_pos)) > min_dist:
				target = hp
	return {"origin": origin, "target": target, "forward": fwd}


func _ensure_fps_viewmodel() -> void:
	if _camera == null:
		return
	if _fps_viewmodel == null:
		_fps_viewmodel = _camera.get_node_or_null("FPSViewmodel") as FPSViewmodelRef
	if _fps_viewmodel == null:
		_fps_viewmodel = FPSViewmodelRef.new()
		_fps_viewmodel.name = "FPSViewmodel"
		_camera.add_child(_fps_viewmodel)
	_fps_viewmodel.ensure_built()


func _clamp_pitch(p: float) -> float:
	var min_deg := float(_cfg.get("fps_pitch_min_deg", -82.0) if is_fps_mode else _cfg.get("pitch_min_deg", -58.0))
	var max_deg := float(_cfg.get("fps_pitch_max_deg", 82.0) if is_fps_mode else _cfg.get("pitch_max_deg", 50.0))
	return clampf(p, deg_to_rad(min_deg), deg_to_rad(max_deg))


func _apply_rig_targets(immediate: bool, is_aiming: bool, is_dashing: bool, delta: float = 0.016) -> void:
	var t := 1.0 if immediate else clampf(14.0 * delta, 0.0, 1.0)
	var target_pivot_y := float(_cfg.get("fps_eye_height_m", 1.58)) if is_fps_mode else float(_cfg.get("pivot_height_m", 1.30))
	position = Vector3(0.0, lerpf(position.y, target_pivot_y, t), 0.0)

	if _spring_arm != null:
		var off_arr: Array = _cfg.get("shoulder_offset_m", [0.40, 0.08, 0.0])
		var target_off := Vector3.ZERO if is_fps_mode else Vector3(float(off_arr[0]), float(off_arr[1]), float(off_arr[2]))
		_spring_arm.position = _spring_arm.position.lerp(target_off, t)
		var target_len := 0.0 if is_fps_mode else float(_cfg.get("spring_length_aim_m", 1.18) if is_aiming else _cfg.get("spring_length_normal_m", 1.80))
		_spring_arm.spring_length = lerpf(_spring_arm.spring_length, target_len, t)

	if _camera != null:
		var fov_norm := float(_cfg.get("fps_fov_normal_deg", 86.0) if is_fps_mode else _cfg.get("fov_normal_deg", 66.0))
		var fov_aim := float(_cfg.get("fps_fov_aim_deg", 66.0) if is_fps_mode else _cfg.get("fov_aim_deg", 50.0))
		var target_fov := fov_aim if is_aiming else fov_norm
		if is_dashing:
			target_fov += float(_cfg.get("fov_dash_kick_deg", 5.0))
		_camera.fov = lerpf(_camera.fov, target_fov, t)
