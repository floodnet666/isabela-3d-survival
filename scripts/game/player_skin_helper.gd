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
	inst.name = "SK_Isabela"
	inst.set_meta("skin_id", skin_id)
	visual_root.add_child(inst)
	return inst


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
	elif BOSS_TINTS.has(skin_id) and mode == "boss_fallback":
		var tint: Color = BOSS_TINTS[skin_id]
		for m in model.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var mat := StandardMaterial3D.new()
			mat.albedo_color = tint
			mat.metallic = 0.55
			mat.roughness = 0.35
			mi.material_override = mat


static func _attach_helmet(model: Node3D, helmet_id: String) -> void:
	var old_att := model.find_child("EquippedHelmetAttachment", true, false)
	if old_att != null:
		old_att.queue_free()
	if not HELMET_PATHS.has(helmet_id):
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
	var att := BoneAttachment3D.new()
	att.name = "EquippedHelmetAttachment"
	att.bone_name = skel.get_bone_name(head_idx)
	att.add_child(helmet)
	skel.add_child(att)
