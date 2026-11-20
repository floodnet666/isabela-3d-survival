class_name WeaponPoolHelper
extends RefCounted
## Pre-instantiates and pools weapon Node3D visuals on a WeaponSocket for O(1) zero-stutter switching.

var _entries: Dictionary = {}
var _active_id: String = ""


func get_count() -> int:
	var n := 0
	for k in _entries.keys():
		var e: Dictionary = _entries[k]
		if is_instance_valid(e.get("node")):
			n += 1
	return n


func prewarm_all(defs: Array, socket: Node3D, is_fps: bool, optic_helper: RefCounted = null) -> void:
	if socket == null:
		return
	for d in defs:
		if d is Dictionary:
			ensure_weapon(d as Dictionary, socket, is_fps, optic_helper)


func ensure_weapon(def: Dictionary, socket: Node3D, is_fps: bool, optic_helper: RefCounted = null) -> Dictionary:
	var wid := str(def.get("id", ""))
	if wid.is_empty() or socket == null:
		return {}
	if _entries.has(wid):
		var existing: Dictionary = _entries[wid]
		var node := existing.get("node") as Node3D
		if is_instance_valid(node) and node.get_parent() == socket:
			return existing

	var asset_path := str(def.get("asset_path", ""))
	if asset_path.is_empty() or not ResourceLoader.exists(asset_path):
		return {}
	var ps := load(asset_path) as PackedScene
	if ps == null:
		return {}
	var inst := ps.instantiate() as Node3D
	if inst == null:
		return {}
	inst.visible = false
	socket.add_child(inst)
	var pos_key := "fps_grip_pos" if is_fps else "tps_grip_pos"
	var rot_key := "fps_grip_rot_deg" if is_fps else "tps_grip_rot_deg"
	var gpos: Array = def.get(pos_key, [0.0, 0.0, 0.0])
	var grot: Array = def.get(rot_key, [0.0, 0.0, 0.0])
	if gpos.size() >= 3:
		inst.position = Vector3(float(gpos[0]), float(gpos[1]), float(gpos[2]))
	if grot.size() >= 3:
		inst.rotation_degrees = Vector3(float(grot[0]), float(grot[1]), float(grot[2]))
	if optic_helper != null and optic_helper.has_method("disable_shadows_recursive"):
		optic_helper.call("disable_shadows_recursive", inst)

	var entry := {
		"id": wid,
		"node": inst,
		"muzzle": inst.get_node_or_null("Muzzle") as Node3D,
		"blade": inst.find_child("SM_Weapon_Lightsaber_Blade", true, false) as Node3D,
	}
	_entries[wid] = entry
	return entry


func activate(def: Dictionary, socket: Node3D, is_fps: bool, optic_helper: RefCounted = null) -> Dictionary:
	if not _active_id.is_empty() and _entries.has(_active_id):
		var prev := (_entries[_active_id] as Dictionary).get("node") as Node3D
		if is_instance_valid(prev):
			prev.visible = false
	var entry := ensure_weapon(def, socket, is_fps, optic_helper)
	if entry.is_empty():
		_active_id = ""
		return {}
	var node := entry["node"] as Node3D
	if is_instance_valid(node):
		node.visible = true
	_active_id = str(entry["id"])
	return entry


static func sanitize_fps_animations(anim_player: AnimationPlayer) -> void:
	if anim_player == null:
		return
	var arms_root := anim_player.get_parent()
	if arms_root != null:
		var skels: Array[Node] = arms_root.find_children("*", "Skeleton3D", true, false)
		if arms_root is Skeleton3D:
			skels.append(arms_root)
		for node in skels:
			var skel := node as Skeleton3D
			if skel == null:
				continue
			for i in range(skel.get_bone_count()):
				var rest := skel.get_bone_rest(i)
				var b := rest.basis
				if b.x.length_squared() < 0.0001 or b.y.length_squared() < 0.0001 or b.z.length_squared() < 0.0001 or absf(b.determinant()) < 0.0001:
					rest.basis = Basis.IDENTITY
					skel.set_bone_rest(i, rest)
					skel.set_bone_pose_scale(i, Vector3.ONE)
		for ch in arms_root.find_children("*", "Node3D", true, false):
			var n3 := ch as Node3D
			if n3 != null and (absf(n3.scale.x) < 0.001 or absf(n3.scale.y) < 0.001 or absf(n3.scale.z) < 0.001):
				n3.scale = Vector3.ONE
	for anim_name in anim_player.get_animation_list():
		var anim := anim_player.get_animation(anim_name)
		if anim == null:
			continue
		for t in range(anim.get_track_count() - 1, -1, -1):
			if anim.track_get_type(t) != Animation.TYPE_SCALE_3D:
				continue
			var path_str := str(anim.track_get_path(t))
			var remove := "ThumbDistal" in path_str
			if not remove:
				for k in range(anim.track_get_key_count(t)):
					var v: Vector3 = anim.track_get_key_value(t, k)
					if absf(v.x) < 0.001 or absf(v.y) < 0.001 or absf(v.z) < 0.001:
						remove = true
						break
			if remove:
				anim.remove_track(t)
