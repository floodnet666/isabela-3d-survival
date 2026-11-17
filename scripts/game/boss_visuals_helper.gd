class_name BossVisualsHelper
extends RefCounted
## Builds BossSentinel 3D visuals, procedural combat locomotion, and shockwave/telegraph VFX.


static func build_visual(root: Node3D, boss_id: String, cfg: Dictionary) -> Dictionary:
	var model_node: Node3D = null
	var anim: AnimationPlayer = null
	var eye_mat: StandardMaterial3D = null
	var aura_mat: StandardMaterial3D = null
	var asset_path := str(cfg.get("asset_path", ""))
	if not asset_path.is_empty() and ResourceLoader.exists(asset_path):
		var ps := load(asset_path) as PackedScene
		if ps != null:
			var inst := ps.instantiate() as Node3D
			if inst != null:
				inst.name = "BossModel"
				root.add_child(inst)
				_fit_model_to_height(inst, float(cfg.get("height_m", 2.45)))
				anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
				_setup_anim_loops(anim)
				model_node = inst
	if model_node == null:
		var fb := _build_fallback_rig(root, boss_id)
		model_node = fb["model"]
		eye_mat = fb["eye_mat"]
		aura_mat = fb["aura_mat"]
	var fx := _build_combat_fx(root, float(cfg.get("height_m", 2.45)))
	return {
		"model": model_node, "anim": anim, "last_anim": "", "eye_mat": eye_mat, "aura_mat": aura_mat,
		"base_pos": model_node.position, "base_scale": model_node.scale, "base_rot_y": model_node.rotation.y,
		"shield": fx["shield"], "shield_mat": fx["shield_mat"],
		"enrage_light": fx["light"], "enrage_ring": fx["ring"], "enrage_mat": fx["ring_mat"],
		"stride_phase": 0.0, "anim_time": 0.0,
	}


static func tick_visual(vis: Dictionary, delta: float, boss: CharacterBody3D, turn_rate: float, pending_attack: String, state_timer: float, impact_timer: float) -> void:
	var model := vis.get("model") as Node3D
	if model == null or not is_instance_valid(model):
		return
	var anim_t := float(vis.get("anim_time", 0.0)) + delta
	vis["anim_time"] = anim_t
	var base_pos: Vector3 = vis.get("base_pos", Vector3.ZERO)
	var base_scale: Vector3 = vis.get("base_scale", Vector3.ONE)
	var base_rot_y: float = float(vis.get("base_rot_y", PI))
	var local_vel := boss.global_transform.basis.inverse() * Vector3(boss.velocity.x, 0.0, boss.velocity.z)
	var horiz_speed := Vector2(local_vel.x, local_vel.z).length()

	# 1. Banking/tilting into turns and velocity
	var pitch := clampf(-local_vel.z * 0.032, -0.18, 0.22)
	var roll := clampf(turn_rate * 0.055 - local_vel.x * 0.035, -0.28, 0.28)
	var yaw_off := 0.0
	var pos_off := Vector3.ZERO
	var scale_mult := Vector3.ONE
	var st := int(boss.get("state"))
	var anim := vis.get("anim") as AnimationPlayer
	var has_skel_run := anim != null and is_instance_valid(anim) and anim.has_animation("Run")
	_tick_skeletal_anim(vis, anim, boss, st, horiz_speed, impact_timer, pending_attack)

	# 2. Heavy hydraulic stride/hover cadence (subtle when skeletal Run is driving limbs)
	if horiz_speed > 0.35 and st == 0:
		var phase := float(vis.get("stride_phase", 0.0)) + delta * (4.0 + horiz_speed * 0.65)
		vis["stride_phase"] = phase
		var amp := 0.25 if has_skel_run else 1.0
		pos_off += Vector3(cos(phase) * 0.045 * amp, absf(sin(phase)) * 0.09 * amp, 0.0)
		roll += sin(phase) * 0.045 * amp
		pitch += absf(cos(phase)) * 0.03 * amp
	elif not has_skel_run:
		pos_off.y += sin(anim_t * 2.2) * 0.03
		var breathe := 1.0 + sin(anim_t * 2.2) * 0.015
		scale_mult = Vector3(breathe, 1.0 / breathe, breathe)

	# 3. Windup recoil (Sword_Slam & Chest Cannon), 4. Impact lunge/squash, 5. Guard, 6. Stagger
	if st == 3:
		if pending_attack == "slam":
			pitch = -0.34; yaw_off = -0.28; pos_off.y += 0.14; scale_mult = Vector3(1.06, 0.94, 1.06)
		elif pending_attack == "ranged":
			pitch = -0.22 + sin(anim_t * 36.0) * 0.015; pos_off.z += 0.12; scale_mult = Vector3(1.10, 0.95, 1.08)
		else:
			pitch = -0.22; yaw_off = -0.22
	elif impact_timer > 0.0:
		var imp := clampf(impact_timer / 0.28, 0.0, 1.0)
		if pending_attack == "ranged":
			pitch = -0.24 * imp; pos_off.z += 0.24 * imp; scale_mult = Vector3(1.0 + 0.12 * imp, 1.0 - 0.08 * imp, 1.0 - 0.10 * imp)
		else:
			pitch = 0.40 * imp; yaw_off = 0.30 * imp; pos_off.z -= 0.32 * imp; scale_mult = Vector3(1.0 + 0.18 * imp, 1.0 - 0.16 * imp, 1.0 + 0.14 * imp)
	elif bool(boss.get("is_guarding")):
		pitch = 0.16; yaw_off = -0.34; pos_off.y -= 0.10; scale_mult = Vector3(1.05, 0.94, 1.05)
	elif st == 2:
		pitch = -0.26 + sin(anim_t * 16.0) * 0.14; roll = cos(anim_t * 13.0) * 0.18
		yaw_off = sin(anim_t * 11.0) * 0.22; pos_off.y -= 0.12; scale_mult = Vector3(0.95, 1.05, 0.95)
	elif bool(boss.get("is_blinking_telegraph")):
		pitch = 0.28; scale_mult = Vector3(0.88, 1.12, 0.88)

	var blend := clampf(12.0 * delta, 0.0, 1.0)
	model.position = model.position.lerp(base_pos + pos_off, blend)
	model.scale = model.scale.lerp(base_scale * scale_mult, blend)
	model.rotation.x = lerpf(model.rotation.x, pitch, blend)
	model.rotation.y = lerp_angle(model.rotation.y, base_rot_y + yaw_off, blend)
	model.rotation.z = lerpf(model.rotation.z, roll, blend)
	_tick_auras(vis, anim_t, bool(boss.get("is_guarding")), bool(boss.get("is_enraged")), state_timer)


static func _setup_anim_loops(anim: AnimationPlayer) -> void:
	if anim == null or not is_instance_valid(anim): return
	for ln in ["Run", "Idle", "Guard_Stance", "Stagger_Core"]:
		if anim.has_animation(ln): anim.get_animation(ln).loop_mode = Animation.LOOP_LINEAR
	if anim.has_animation("Idle"): anim.play("Idle")


static func trigger_enrage_roar(vis: Dictionary) -> void:
	var anim := vis.get("anim") as AnimationPlayer
	if anim != null and is_instance_valid(anim) and anim.has_animation("Enrage_Roar"):
		vis["roar_left"] = 1.15
		vis["last_anim"] = "Enrage_Roar"
		anim.play("Enrage_Roar", 0.08)


static func _tick_skeletal_anim(vis: Dictionary, anim: AnimationPlayer, boss: CharacterBody3D, st: int, horiz_speed: float, impact_timer: float, pending_attack: String) -> void:
	if anim == null or not is_instance_valid(anim): return
	var roar_left := maxf(0.0, float(vis.get("roar_left", 0.0)) - 0.016)
	vis["roar_left"] = roar_left
	if roar_left > 0.0 and anim.has_animation("Enrage_Roar") and anim.is_playing():
		return
	var target := "Idle"; var spd := 1.0
	if bool(boss.get("is_guarding")) and anim.has_animation("Guard_Stance"):
		target = "Guard_Stance"
	elif st == 2 and anim.has_animation("Stagger_Core"):
		target = "Stagger_Core"
	elif st == 3 or impact_timer > 0.0:
		target = "Sword_Slam" if (pending_attack == "slam" and anim.has_animation("Sword_Slam")) else "Attack"
		spd = 1.05
	elif st == 0 and horiz_speed > 0.35 and anim.has_animation("Run"):
		target = "Run"; spd = clampf(horiz_speed / 5.2, 0.75, 1.85)
	if not anim.has_animation(target): return
	if str(vis.get("last_anim", "")) != target:
		vis["last_anim"] = target; anim.play(target, 0.12)
	anim.speed_scale = spd


static func _tick_auras(vis: Dictionary, anim_t: float, guarding: bool, enraged: bool, _state_timer: float) -> void:
	var shield := vis.get("shield") as MeshInstance3D
	var shield_mat := vis.get("shield_mat") as StandardMaterial3D
	if shield != null:
		shield.visible = guarding
		if guarding and shield_mat != null:
			shield_mat.albedo_color.a = 0.28 + sin(anim_t * 10.0) * 0.08
			shield.scale = Vector3.ONE * (1.0 + sin(anim_t * 8.0) * 0.04)
	var enrage_light := vis.get("enrage_light") as OmniLight3D
	var enrage_ring := vis.get("enrage_ring") as MeshInstance3D
	var enrage_mat := vis.get("enrage_mat") as StandardMaterial3D
	var pulse := 0.5 + 0.5 * sin(anim_t * 8.5)
	if enrage_light != null:
		enrage_light.light_energy = (1.6 + pulse * 1.4) if enraged else 0.0
	if enrage_ring != null:
		enrage_ring.visible = enraged
		if enraged and enrage_mat != null:
			enrage_ring.scale = Vector3.ONE * (0.95 + pulse * 0.22)
			enrage_mat.albedo_color.a = 0.35 + pulse * 0.35
	var eye_mat := vis.get("eye_mat") as StandardMaterial3D
	if eye_mat != null:
		eye_mat.emission_energy_multiplier = (3.2 + pulse * 2.0) if enraged else 2.4


static func _build_combat_fx(root: Node3D, height_m: float) -> Dictionary:
	var shield_torus := TorusMesh.new(); shield_torus.inner_radius = 0.52; shield_torus.outer_radius = 0.68
	var shield := _make_fx_mesh(shield_torus, Color(1.0, 0.38, 0.14, 0.42), Vector3(0.0, height_m * 0.50, -0.45), root)
	shield.rotation_degrees.x = 90.0
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.68; ring_mesh.outer_radius = 0.84
	var ring := _make_fx_mesh(ring_mesh, Color(1.0, 0.14, 0.16, 0.55), Vector3(0.0, 0.14, 0.0), root)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.15, 0.18); light.omni_range = 4.5; light.light_energy = 0.0
	light.position = Vector3(0.0, height_m * 0.55, -0.3)
	root.add_child(light)
	return {"shield": shield, "shield_mat": shield.material_override, "ring": ring, "ring_mat": ring.material_override, "light": light}


static func _make_fx_mesh(mesh: Mesh, col: Color, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.visible = false
	parent.add_child(mi)
	return mi


static func _build_fallback_rig(root: Node3D, boss_id: String) -> Dictionary:
	var model := Node3D.new()
	model.name = "BossFallbackRig"
	root.add_child(model)
	var body_col := Color(0.86, 0.88, 0.92) if boss_id == "white_reaper" else (Color(0.08, 0.08, 0.10) if boss_id == "anubis_phantom" else Color(0.14, 0.14, 0.18))
	var accent_col := Color(1.0, 0.72, 0.12) if boss_id == "anubis_phantom" else Color(0.95, 0.16, 0.20)
	var scale_w := 1.28 if boss_id == "white_reaper" else (0.96 if boss_id == "anubis_phantom" else 1.0)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = body_col; body_mat.metallic = 0.72; body_mat.roughness = 0.28
	var accent_mat := StandardMaterial3D.new()
	accent_mat.albedo_color = accent_col; accent_mat.emission_enabled = true
	accent_mat.emission = accent_col; accent_mat.emission_energy_multiplier = 2.4
	var tm := CapsuleMesh.new(); tm.radius = 0.34 * scale_w; tm.height = 1.45
	var hm := BoxMesh.new(); hm.size = Vector3(0.32 * scale_w, 0.34, 0.34)
	var em := BoxMesh.new(); em.size = Vector3(0.26 * scale_w, 0.08, 0.06)
	for entry in [[tm, body_mat, Vector3(0.0, 1.05, 0.0)], [hm, body_mat, Vector3(0.0, 1.92, 0.0)], [em, accent_mat, Vector3(0.0, 1.94, -0.17)]]:
		var mi := MeshInstance3D.new()
		mi.mesh = entry[0]; mi.material_override = entry[1]; mi.position = entry[2]
		model.add_child(mi)
	return {"model": model, "eye_mat": accent_mat, "aura_mat": body_mat}


static func _fit_model_to_height(inst: Node3D, target_height_m: float) -> void:
	var min_y := INF; var max_y := -INF
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var a := (m as MeshInstance3D).get_aabb()
		min_y = minf(min_y, a.position.y); max_y = maxf(max_y, a.end.y)
	if min_y < INF and max_y > min_y:
		var s := target_height_m / maxf(0.01, max_y - min_y)
		inst.scale = Vector3.ONE * s; inst.position.y = -min_y * s
	inst.rotation.y = PI


static func spawn_shockwave(scene: Node, pos: Vector3, radius: float, color: Color) -> void:
	if scene == null:
		return
	var tm := TorusMesh.new(); tm.inner_radius = 0.65; tm.outer_radius = 1.0
	var ring := _make_fx_mesh(tm, color, Vector3(pos.x, 0.15, pos.z), scene as Node3D)
	ring.visible = true
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(radius, 1.0, radius), 0.35)
	tw.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(ring.queue_free)


static func spawn_blink_vfx(scene: Node, from_pos: Vector3, to_pos: Vector3) -> void:
	if scene == null: return
	for p in [from_pos, to_pos]:
		var cyl := CylinderMesh.new(); cyl.top_radius = 0.15; cyl.bottom_radius = 0.55; cyl.height = 2.2
		var fx := _make_fx_mesh(cyl, Color(1.0, 0.72, 0.15, 0.75), Vector3(p.x, p.y + 1.1, p.z), scene as Node3D)
		fx.visible = true
		var tw := fx.create_tween(); tw.set_parallel(true)
		tw.tween_property(fx, "scale", Vector3(1.6, 1.35, 1.6), 0.32)
		tw.tween_property(fx.material_override, "albedo_color:a", 0.0, 0.32)
		tw.chain().tween_callback(fx.queue_free)
		spawn_shockwave(scene, p, 2.4, Color(1.0, 0.72, 0.15, 0.85))


static func bind_boss_to_arena(boss: Node3D, wave: int, dname: String, spawner: Node, gm: Node, hud: Node) -> void:
	if boss == null:
		return
	if hud != null and hud.has_method("bind_boss"):
		hud.call("bind_boss", boss, wave, dname)
	if spawner != null and boss.has_signal("capsule_rain_requested"):
		boss.connect("capsule_rain_requested", func(cnt: int) -> void: spawner.call("spawn_capsule_rain", cnt, wave))
	if spawner != null and boss.has_signal("enraged"):
		boss.connect("enraged", func(_id: String, salvo: int) -> void: spawner.call("spawn_capsule_rain", salvo, wave))
	if gm != null and boss.has_signal("died"):
		boss.connect("died", func(e: Node3D, _eid: String, _xp: int, _sc: int, _dc: float, pos: Vector3) -> void:
			spawner.call("spawn_boss_reward_crates", pos)
			gm.call("grant_boss_legendary_draft")
			if "unlock_skin_id" in e:
				preload("res://scripts/game/settings_manager.gd").unlock_skin(str(e.get("unlock_skin_id")))
		)
