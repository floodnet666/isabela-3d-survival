class_name PlayerSkinHelper
extends RefCounted
## Applies playable skin models, submesh variants, Head-bone helmets, and archetype modifiers while preserving O(1) weapon pooling.

const BalanceDBRef := preload("res://scripts/game/balance_db.gd")

const HELMET_PATHS := {
	"helmet_a": "res://assets/SM_Helmet_A/SM_Helmet_A.glb",
	"helmet_b": "res://assets/SM_Helmet_B/SM_Helmet_B.glb",
}

const BOSS_TINTS := {
	"valkyrie_skull": Color(0.85, 0.20, 0.25),
	"white_reaper": Color(0.92, 0.94, 0.98),
	"anubis_phantom": Color(0.14, 0.14, 0.18),
}


static func apply_skin_and_helmet(
	player: Node3D,
	skin_id: String,
	helmet_id: String,
	db: BalanceDBRef,
	animator: Node = null,
	weapon_mgr: Node = null
) -> Dictionary:
	if db == null:
		return {}
	var arch := db.get_archetype_cfg(skin_id)
	var visual_root := player.get_node_or_null("VisualRoot") as Node3D if player != null else null
	if visual_root != null:
		var model := _swap_visual_model(visual_root, skin_id, arch)
		if model != null:
			_apply_submesh_or_tint(model, skin_id, str(arch.get("submesh_mode", "")))
			_attach_helmet(model, helmet_id)
			if animator != null and animator.has_method("bind_isabela"):
				animator.call("bind_isabela", model)
				if weapon_mgr != null and animator.has_method("get_weapon_socket"):
					var sock: Variant = animator.call("get_weapon_socket")
					if sock != null and weapon_mgr.has_method("set_weapon_socket"):
						weapon_mgr.call("set_weapon_socket", sock)
			if weapon_mgr != null and weapon_mgr.has_method("_prewarm_pools"):
				weapon_mgr.call("_prewarm_pools")
	return arch


static func _swap_visual_model(visual_root: Node3D, skin_id: String, arch: Dictionary) -> Node3D:
	var existing := visual_root.get_node_or_null("SK_Isabela") as Node3D
	var asset_path := str(arch.get("asset_path", ""))
	if asset_path.is_empty() or not ResourceLoader.exists(asset_path):
		return existing
	if existing != null and str(existing.get_meta("skin_id", "leeloo")) == skin_id:
		return existing

	var ps := load(asset_path) as PackedScene
	if ps == null:
		return existing
	var inst := ps.instantiate() as Node3D
	if inst == null:
		return existing
	if inst.find_children("*", "Skeleton3D", true, false).is_empty():
		inst.queue_free()
		return existing
	if existing != null:
		inst.transform = existing.transform
		visual_root.remove_child(existing)
		existing.queue_free()
	else:
		inst.rotation.y = PI
	if skin_id in ["valkyrie_skull", "white_reaper", "anubis_phantom"] and inst.get_node_or_null("Armature_Isabela") == null:
		_fit_skin_height(inst, 1.72)
	inst.name = "SK_Isabela"
	inst.set_meta("skin_id", skin_id)
	visual_root.add_child(inst)
	return inst


static func _fit_skin_height(inst: Node3D, target_h: float) -> void:
	var min_y := INF; var max_y := -INF
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var a := (m as MeshInstance3D).get_aabb()
		min_y = minf(min_y, a.position.y); max_y = maxf(max_y, a.end.y)
	if min_y < INF and max_y > min_y:
		var s := target_h / maxf(0.01, max_y - min_y)
		inst.scale = Vector3.ONE * s; inst.position.y = -min_y * s


static func tick_boss_skin_anim(anim: AnimationPlayer, velocity: Vector3, attacking: bool) -> void:
	if anim == null or not is_instance_valid(anim): return
	for ln in ["Idle", "Run"]:
		if anim.has_animation(ln): anim.get_animation(ln).loop_mode = Animation.LOOP_LINEAR
	var h_spd := Vector2(velocity.x, velocity.z).length()
	var target := "Attack" if attacking and anim.has_animation("Attack") else ("Run" if h_spd > 0.35 and anim.has_animation("Run") else "Idle")
	if anim.has_animation(target) and anim.current_animation != target:
		anim.play(target, 0.10)


static func _apply_submesh_or_tint(model: Node3D, skin_id: String, mode: String) -> void:
	if mode in ["jacket", "top", "lingerie"]:
		for m in model.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := m as MeshInstance3D
			var nm := mesh_node.name.to_lower()
			if "jacket" in nm:
				mesh_node.visible = (mode == "jacket")
			elif "top" in nm:
				mesh_node.visible = (mode == "jacket" or mode == "top")
			elif "lingerie" in nm or "bra" in nm or "panty" in nm:
				mesh_node.visible = (mode == "lingerie")
	elif BOSS_TINTS.has(skin_id) and mode == "boss_fallback" and model.get_node_or_null("Armature_Isabela") != null:
		var tint: Color = BOSS_TINTS[skin_id]
		for m in model.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var mat := StandardMaterial3D.new()
			mat.albedo_color = tint
			mat.metallic = 0.55
			mat.roughness = 0.35
			mi.material_override = mat


static func attach_helmet_on_player(player: Node3D, helmet_id: String) -> void:
	if player == null:
		return
	var model := player.get_node_or_null("VisualRoot/SK_Isabela") as Node3D
	if model != null:
		_attach_helmet(model, helmet_id)


static func _set_hair_visible(model: Node3D, vis: bool) -> void:
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if "hair" in mi.name.to_lower():
			mi.visible = vis


static func _attach_helmet(model: Node3D, helmet_id: String) -> void:
	var old_att := model.find_child("EquippedHelmetAttachment", true, false)
	if old_att != null:
		if old_att.get_parent() != null:
			old_att.get_parent().remove_child(old_att)
		old_att.queue_free()
	var has_helmet := HELMET_PATHS.has(helmet_id)
	_set_hair_visible(model, not has_helmet)
	if not has_helmet:
		return
	var hpath: String = HELMET_PATHS[helmet_id]
	if not ResourceLoader.exists(hpath):
		return
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		var all_skels := model.find_children("*", "Skeleton3D", true, false)
		skel = all_skels[0] as Skeleton3D if not all_skels.is_empty() else null
	if skel == null:
		return
	var head_idx := -1
	for candidate in ["Head", "head", "DEF-spine.006", "mixamorig_Head"]:
		head_idx = skel.find_bone(candidate)
		if head_idx >= 0:
			break
	if head_idx < 0:
		return
	var ps := load(hpath) as PackedScene
	if ps == null:
		return
	var helmet := ps.instantiate() as Node3D
	if helmet == null:
		return
	helmet.position = Vector3(0.0, -0.185, 0.015)
	helmet.scale = Vector3(1.0, 1.0, 1.0)
	var att := BoneAttachment3D.new()
	att.name = "EquippedHelmetAttachment"
	att.bone_name = skel.get_bone_name(head_idx)
	att.add_child(helmet)
	skel.add_child(att)
