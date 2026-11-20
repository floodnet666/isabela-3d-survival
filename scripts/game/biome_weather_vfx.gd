class_name BiomeWeatherVFX
extends Node3D
## Crisp atmospheric GPUParticles3D (blowing sand grains, alpine snow, magma embers & reactor sparks) without fog or smoke clouds.

static var _soft_flake_tex: Texture2D
static var _soft_streak_tex: Texture2D
static var _fade_curve: CurveTexture


static func _get_fade_curve() -> CurveTexture:
	if _fade_curve != null:
		return _fade_curve
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.25, 1.0))
	c.add_point(Vector2(0.70, 0.85))
	c.add_point(Vector2(1.0, 0.0))
	_fade_curve = CurveTexture.new()
	_fade_curve.curve = c
	return _fade_curve


static func _get_flake_tex() -> Texture2D:
	if _soft_flake_tex != null:
		return _soft_flake_tex
	var grad := Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.add_point(0.40, Color(1.0, 1.0, 1.0, 0.55))
	grad.set_offset(grad.get_point_count() - 1, 1.0)
	grad.set_color(grad.get_point_count() - 1, Color(1.0, 1.0, 1.0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 64
	gt.height = 64
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	_soft_flake_tex = gt
	return _soft_flake_tex


static func _get_streak_tex() -> Texture2D:
	if _soft_streak_tex != null:
		return _soft_streak_tex
	var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		var vy := (float(y) / 63.0) * 2.0 - 1.0
		for x in range(32):
			var vx := (float(x) / 31.0) * 2.0 - 1.0
			var d := sqrt(vx * vx * 2.2 + vy * vy * 0.65)
			var a := clampf(pow(maxf(0.0, 1.0 - d), 1.8), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_soft_streak_tex = ImageTexture.create_from_image(img)
	return _soft_streak_tex


static func _make_process_mat(cfg: Dictionary) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = cfg["extents"] as Vector3
	pm.direction = (cfg["dir"] as Vector3).normalized()
	pm.spread = float(cfg["spread"])
	pm.initial_velocity_min = float(cfg["vmin"])
	pm.initial_velocity_max = float(cfg["vmax"])
	pm.gravity = cfg["gravity"] as Vector3
	pm.scale_min = float(cfg.get("smin", 0.75))
	pm.scale_max = float(cfg.get("smax", 1.35))
	pm.color = cfg["color"] as Color
	pm.alpha_curve = _get_fade_curve()
	if bool(cfg.get("align_vel", false)):
		pm.particle_flag_align_y = true
	if float(cfg.get("turb", 0.0)) > 0.0:
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = float(cfg["turb"])
		pm.turbulence_noise_scale = float(cfg.get("turb_scale", 4.5))
		pm.turbulence_influence_min = 0.25
		pm.turbulence_influence_max = 0.65
	return pm


static func _spawn_accent_layer(root: Node3D, cfg: Dictionary) -> void:
	var quad := QuadMesh.new()
	quad.size = cfg["qsize"] as Vector2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _get_streak_tex() if bool(cfg.get("streak", false)) else _get_flake_tex()
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if bool(cfg.get("align_vel", false)) else BaseMaterial3D.BILLBOARD_ENABLED
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 2.8
	mat.distance_fade_max_distance = 5.5
	if bool(cfg.get("add", false)):
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = mat

	var p := GPUParticles3D.new()
	p.amount = int(cfg["amount"])
	p.lifetime = float(cfg["life"])
	p.fixed_fps = 30
	p.fract_delta = true
	p.preprocess = minf(float(cfg["life"]) * 0.35, 1.4)
	p.position = cfg["pos"] as Vector3
	p.process_material = _make_process_mat(cfg)
	p.draw_pass_1 = quad
	p.visibility_aabb = cfg.get("aabb", AABB(Vector3(-55, -18, -55), Vector3(110, 60, 110))) as AABB
	p.emitting = true
	root.add_child(p)


static func build_weather(parent: Node3D, weather_type: String) -> Node3D:
	if DisplayServer.get_name() == "headless" or parent == null or weather_type.is_empty():
		return null
	var root := Node3D.new()
	root.name = "BiomeWeather_" + weather_type
	parent.add_child(root)

	match weather_type:
		"sandstorm":
			_spawn_accent_layer(root, {
				"amount": 140, "life": 2.4, "pos": Vector3(-16, 2.6, 0),
				"extents": Vector3(18, 3.2, 26), "dir": Vector3(1.0, -0.02, 0.22),
				"spread": 12.0, "vmin": 9.0, "vmax": 16.0, "gravity": Vector3(1.6, -0.2, 0.0),
				"color": Color(0.98, 0.84, 0.56, 0.36), "qsize": Vector2(0.18, 0.08), "turb": 1.2,
			})
		"blizzard":
			_spawn_accent_layer(root, {
				"amount": 260, "life": 4.2, "pos": Vector3(0, 14, 0),
				"extents": Vector3(30, 2.5, 30), "dir": Vector3(0.35, -1.0, 0.18),
				"spread": 16.0, "vmin": 4.5, "vmax": 8.0, "gravity": Vector3(1.2, -1.6, 0.4),
				"color": Color(0.94, 0.98, 1.0, 0.80), "qsize": Vector2(0.13, 0.13), "turb": 1.8,
			})
		"embers":
			_spawn_accent_layer(root, {
				"amount": 180, "life": 4.0, "pos": Vector3(0, 0.4, 0),
				"extents": Vector3(30, 0.8, 30), "dir": Vector3(0.14, 1.0, 0.08),
				"spread": 28.0, "vmin": 2.2, "vmax": 5.6, "gravity": Vector3(0.3, 0.7, 0.2),
				"color": Color(1.0, 0.52, 0.12, 0.92), "qsize": Vector2(0.12, 0.20), "streak": true, "add": true, "turb": 2.2,
			})
			_spawn_accent_layer(root, {
				"amount": 60, "life": 3.2, "pos": Vector3(16, 54, -96),
				"extents": Vector3(6.0, 1.5, 6.0), "dir": Vector3(0.05, 1.0, 0.0),
				"spread": 32.0, "vmin": 5.5, "vmax": 12.0, "gravity": Vector3(0.0, -2.5, 0.0),
				"color": Color(1.0, 0.48, 0.10, 0.90), "qsize": Vector2(0.70, 1.15), "streak": true, "add": true, "turb": 1.6,
				"aabb": AABB(Vector3(-45, -10, -45), Vector3(90, 95, 90)),
			})
		"ship_sparks":
			_spawn_accent_layer(root, {
				"amount": 100, "life": 3.0, "pos": Vector3(0, 12.5, 0),
				"extents": Vector3(18, 3.0, 18), "dir": Vector3(0.0, -1.0, 0.0),
				"spread": 35.0, "vmin": 1.2, "vmax": 3.2, "gravity": Vector3(0.0, -1.2, 0.0),
				"color": Color(0.32, 0.94, 1.0, 0.80), "qsize": Vector2(0.12, 0.26), "streak": true, "add": true, "turb": 1.6,
			})
		_:
			root.queue_free()
			return null

	return root
