class_name BiomeWeatherVFX
extends Node3D
## Spawns dual-layer photorealistic atmospheric GPUParticles3D with soft radial textures (sandstorm haze, steam + sparks, blizzard mist + snow, volcanic embers + ash).

static var _soft_circle_tex: Texture2D


static func _get_soft_tex() -> Texture2D:
	if _soft_circle_tex != null:
		return _soft_circle_tex
	var grad := Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	grad.add_point(0.45, Color(1.0, 1.0, 1.0, 0.55))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 64
	gt.height = 64
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	_soft_circle_tex = gt
	return _soft_circle_tex


static func _spawn_layer(root: Node3D, cfg: Dictionary) -> void:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = cfg["extents"] as Vector3
	pm.direction = (cfg["dir"] as Vector3).normalized()
	pm.spread = float(cfg["spread"])
	pm.initial_velocity_min = float(cfg["vmin"])
	pm.initial_velocity_max = float(cfg["vmax"])
	pm.gravity = cfg["gravity"] as Vector3
	pm.scale_min = float(cfg.get("smin", 0.7))
	pm.scale_max = float(cfg.get("smax", 1.3))
	pm.color = cfg["color"] as Color

	var quad := QuadMesh.new()
	quad.size = cfg["qsize"] as Vector2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _get_soft_tex()
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if bool(cfg.get("add", false)):
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = mat

	p.amount = int(cfg["amount"])
	p.lifetime = float(cfg["life"])
	p.preprocess = float(cfg["life"]) * 0.8
	p.position = cfg["pos"] as Vector3
	p.process_material = pm
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-50, -15, -50), Vector3(100, 48, 100))
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
			# Layer 1: Low billowing golden sand haze clouds hugging the ruins
			_spawn_layer(root, {
				"amount": 95, "life": 4.5, "pos": Vector3(-16, 1.8, 0),
				"extents": Vector3(24, 2.2, 28), "dir": Vector3(1.0, 0.04, 0.2),
				"spread": 14.0, "vmin": 5.5, "vmax": 9.5, "gravity": Vector3(0.8, 0.05, 0.0),
				"color": Color(0.96, 0.78, 0.48, 0.14), "qsize": Vector2(6.5, 3.2),
			})
			# Layer 2: Fast wind-blown golden sand grains
			_spawn_layer(root, {
				"amount": 260, "life": 2.8, "pos": Vector3(-18, 3.5, 0),
				"extents": Vector3(18, 4.5, 28), "dir": Vector3(1.0, -0.05, 0.22),
				"spread": 10.0, "vmin": 13.0, "vmax": 20.0, "gravity": Vector3(2.0, -0.3, 0.0),
				"color": Color(0.98, 0.84, 0.56, 0.42), "qsize": Vector2(0.45, 0.14),
			})
		"blizzard":
			# Layer 1: Drifting cold arctic ground mist
			_spawn_layer(root, {
				"amount": 75, "life": 5.0, "pos": Vector3(0, 1.5, 0),
				"extents": Vector3(28, 1.8, 28), "dir": Vector3(0.6, 0.02, 0.25),
				"spread": 20.0, "vmin": 2.2, "vmax": 4.5, "gravity": Vector3(0.2, 0.0, 0.0),
				"color": Color(0.76, 0.90, 1.0, 0.12), "qsize": Vector2(7.0, 3.5),
			})
			# Layer 2: Crisp falling blizzard snowflakes
			_spawn_layer(root, {
				"amount": 360, "life": 4.2, "pos": Vector3(0, 14, 0),
				"extents": Vector3(30, 2.5, 30), "dir": Vector3(0.35, -1.0, 0.18),
				"spread": 14.0, "vmin": 4.8, "vmax": 8.2, "gravity": Vector3(1.2, -1.6, 0.4),
				"color": Color(0.92, 0.97, 1.0, 0.78), "qsize": Vector2(0.16, 0.16),
			})
		"embers":
			# Layer 1: Rising volcanic heat smoke & ash wisps
			_spawn_layer(root, {
				"amount": 80, "life": 5.2, "pos": Vector3(0, 1.2, -8),
				"extents": Vector3(30, 1.5, 30), "dir": Vector3(0.12, 1.0, 0.05),
				"spread": 22.0, "vmin": 1.4, "vmax": 3.0, "gravity": Vector3(0.2, 0.35, 0.0),
				"color": Color(0.42, 0.16, 0.08, 0.14), "qsize": Vector2(6.2, 4.8),
			})
			# Layer 2: Bright glowing rising magma embers
			_spawn_layer(root, {
				"amount": 280, "life": 4.0, "pos": Vector3(0, 0.4, 0),
				"extents": Vector3(30, 0.8, 30), "dir": Vector3(0.14, 1.0, 0.08),
				"spread": 26.0, "vmin": 2.2, "vmax": 5.6, "gravity": Vector3(0.3, 0.7, 0.2),
				"color": Color(1.0, 0.52, 0.10, 0.92), "qsize": Vector2(0.18, 0.18), "add": true,
			})
			# Layer 3: Stratovolcano summit eruption ash plume & fire sparks (Ref 5!)
			_spawn_layer(root, {
				"amount": 65, "life": 6.5, "pos": Vector3(16, 56, -96),
				"extents": Vector3(6.5, 2.0, 6.5), "dir": Vector3(0.12, 1.0, 0.05),
				"spread": 24.0, "vmin": 4.5, "vmax": 8.5, "gravity": Vector3(0.6, 1.2, 0.0),
				"color": Color(0.24, 0.12, 0.09, 0.32), "qsize": Vector2(18.0, 16.0),
			})
			_spawn_layer(root, {
				"amount": 90, "life": 3.4, "pos": Vector3(16, 55, -96),
				"extents": Vector3(5.5, 1.5, 5.5), "dir": Vector3(0.05, 1.0, 0.0),
				"spread": 32.0, "vmin": 5.0, "vmax": 12.0, "gravity": Vector3(0.0, -2.5, 0.0),
				"color": Color(1.0, 0.45, 0.08, 0.88), "qsize": Vector2(1.1, 1.1), "add": true,
			})
		"ship_sparks":
			# Layer 1: Moody industrial vapor/steam venting along hangar perimeter
			_spawn_layer(root, {
				"amount": 55, "life": 4.6, "pos": Vector3(0, 3.0, -6),
				"extents": Vector3(24, 2.5, 24), "dir": Vector3(0.0, 1.0, 0.0),
				"spread": 30.0, "vmin": 0.9, "vmax": 2.0, "gravity": Vector3(0.0, 0.2, 0.0),
				"color": Color(0.34, 0.62, 0.78, 0.10), "qsize": Vector2(5.5, 4.0),
			})
			# Layer 2: Falling cyan-blue plasma energy motes from Reactor Core
			_spawn_layer(root, {
				"amount": 160, "life": 3.0, "pos": Vector3(0, 12.5, 0),
				"extents": Vector3(18, 3.0, 18), "dir": Vector3(0.0, -1.0, 0.0),
				"spread": 35.0, "vmin": 1.2, "vmax": 3.2, "gravity": Vector3(0.0, -1.2, 0.0),
				"color": Color(0.32, 0.94, 1.0, 0.78), "qsize": Vector2(0.14, 0.24), "add": true,
			})
		_:
			root.queue_free()
			return null

	return root
