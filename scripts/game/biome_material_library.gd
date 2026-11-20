class_name BiomeMaterialLibrary
extends RefCounted
## Caches photorealistic PBR StandardMaterial3D & custom GLSL ShaderMaterial overrides keyed by Blender material name.

const PBR_ROOT := "res://assets/textures/pbr"
const SHD_ROOT := "res://shaders"

static var _mat_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func apply_to_node(root: Node) -> void:
	if root == null:
		return
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null:
			apply_to_mesh(mi.mesh)


static func apply_to_mesh(mesh: Mesh) -> void:
	if mesh == null:
		return
	var sc := mesh.get_surface_count()
	for s in range(sc):
		var src := mesh.surface_get_material(s)
		if src == null:
			continue
		var mname := src.resource_name
		if mname.is_empty():
			continue
		var rep := get_material(mname)
		if rep != null:
			mesh.surface_set_material(s, rep)


static func get_material(mat_name: String) -> Material:
	if _mat_cache.has(mat_name):
		return _mat_cache[mat_name] as Material
	var mat := _build_material(mat_name)
	if mat != null:
		_mat_cache[mat_name] = mat
	return mat


static func _tex(pack: String, map_kind: String) -> Texture2D:
	var path := "%s/%s/%s_%s.jpg" % [PBR_ROOT, pack, pack, map_kind]
	if _tex_cache.has(path):
		return _tex_cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var t := load(path) as Texture2D
	_tex_cache[path] = t
	return t


static func _pbr(pack: String, tint: Color, met: float, rgh: float, nrm_s: float, uv_s: float, em_col: Color = Color.BLACK, em_e: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.metallic = met
	m.roughness = rgh
	var dif := _tex(pack, "Diffuse")
	if dif != null:
		m.albedo_texture = dif
	var nrm := _tex(pack, "nor_gl")
	if nrm != null:
		m.normal_enabled = true
		m.normal_texture = nrm
		m.normal_scale = nrm_s
	var rgt := _tex(pack, "Rough")
	if rgt != null:
		m.roughness_texture = rgt
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(uv_s, uv_s, uv_s)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if em_e > 0.0:
		m.emission_enabled = true
		m.emission = em_col
		m.emission_energy_multiplier = em_e
	return m


static func _emissive(col: Color, energy: float, rgh: float = 0.14, met: float = 0.1) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rgh
	m.metallic = met
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


static func _shader(shd_name: String, params: Dictionary) -> ShaderMaterial:
	var path := "%s/%s.gdshader" % [SHD_ROOT, shd_name]
	if not ResourceLoader.exists(path):
		return null
	var shd := load(path) as Shader
	if shd == null:
		return null
	var sm := ShaderMaterial.new()
	sm.shader = shd
	for k in params.keys():
		sm.set_shader_parameter(str(k), params[k])
	return sm


static func _build_material(n: String) -> Material:
	match n:
		# --- BIOME 1: MIRROR COAST PROPS ---
		"MAT_CoastArmor":
			return _pbr("blue_metal_plate", Color(0.46, 0.52, 0.60), 0.80, 0.42, 1.25, 0.55)
		"MAT_CoastDarkSteel":
			return _pbr("metal_plate_02", Color(0.28, 0.32, 0.38), 0.86, 0.36, 1.15, 0.55)
		"MAT_CoastBasalt":
			return _pbr("dark_rock_02", Color(0.32, 0.34, 0.38), 0.08, 0.24, 1.45, 0.55)
		"MAT_CoastCyan":
			return _emissive(Color(0.14, 0.90, 1.0), 3.6)
		"MAT_CoastAmber":
			return _emissive(Color(1.0, 0.56, 0.14), 3.2)

		# --- BIOME 2: SAND DUNES PYRAMID ---
		"MAT_SandFloor":
			return _shader("biome_sand_floor", {
				"sand_albedo": _tex("coast_sand_01", "Diffuse"),
				"sand_normal": _tex("coast_sand_01", "nor_gl"),
				"sand_rough": _tex("coast_sand_01", "Rough"),
				"stone_albedo": _tex("large_sandstone_blocks_01", "Diffuse"),
				"stone_normal": _tex("large_sandstone_blocks_01", "nor_gl"),
				"stone_rough": _tex("large_sandstone_blocks_01", "Rough"),
			})
		"MAT_SandDunes":
			return _shader("biome_desert_dunes", {
				"sand_albedo": _tex("coast_sand_01", "Diffuse"),
				"sand_normal": _tex("coast_sand_01", "nor_gl"),
				"sand_rough": _tex("coast_sand_01", "Rough"),
				"cliff_albedo": _tex("sandstone_cracks", "Diffuse"),
				"cliff_normal": _tex("sandstone_cracks", "nor_gl"),
				"cliff_rough": _tex("sandstone_cracks", "Rough"),
			})
		"MAT_SandstoneRuins":
			return _pbr("sandstone_cracks", Color(1.00, 0.82, 0.56), 0.03, 0.88, 1.45, 0.26)
		"MAT_SandstoneBlocks":
			return _pbr("large_sandstone_blocks_01", Color(0.95, 0.78, 0.54), 0.04, 0.84, 1.40, 0.32)
		"MAT_GoldCapstone":
			return _pbr("metal_plate_02", Color(1.00, 0.78, 0.22), 0.96, 0.14, 0.55, 0.35, Color(1.0, 0.74, 0.18), 0.24)
		"MAT_DarkRelicMetal":
			return _pbr("metal_plate_02", Color(0.32, 0.28, 0.24), 0.74, 0.44, 1.20, 0.45)
		"MAT_SciFiCyan":
			return _emissive(Color(0.20, 0.92, 1.0), 2.8)

		# --- BIOME 3: MOTHERSHIP INTERIOR ---
		"MAT_MothershipDeck":
			return _shader("biome_mothership_deck", {
				"metal_albedo": _tex("metal_plate_02", "Diffuse"),
				"metal_normal": _tex("metal_plate_02", "nor_gl"),
				"metal_rough": _tex("metal_plate_02", "Rough"),
				"deck_tint": Color(0.56, 0.64, 0.74),
				"conduit_energy": 2.8,
			})
		"MAT_DeckMetal":
			return _pbr("metal_plate_02", Color(0.52, 0.58, 0.68), 0.80, 0.38, 1.35, 0.24)
		"MAT_HullArmor":
			return _pbr("blue_metal_plate", Color(0.64, 0.72, 0.82), 0.76, 0.40, 1.35, 0.30)
		"MAT_DarkTitanium":
			return _pbr("metal_plate_02", Color(0.38, 0.44, 0.52), 0.84, 0.34, 1.25, 0.34)
		"MAT_ReactorCyan":
			return _emissive(Color(0.14, 0.88, 1.0), 2.4)
		"MAT_ReactorCore":
			return _emissive(Color(0.42, 0.94, 1.0), 3.8)
		"MAT_WarningAmber":
			return _emissive(Color(1.0, 0.48, 0.10), 2.4)
		"MAT_SpaceViewport":
			return _shader("biome_space_viewport", {})

		# --- BIOME 4: CRYO GLACIER ---
		"MAT_IceFloor":
			return _shader("biome_ice_floor", {
				"snow_albedo": _tex("snow_02", "Diffuse"),
				"snow_normal": _tex("snow_02", "nor_gl"),
				"snow_rough": _tex("snow_02", "Rough"),
				"rock_normal": _tex("dark_rock_02", "nor_gl"),
			})
		"MAT_GlacierMountain":
			return _shader("biome_glacier_mountain", {
				"snow_albedo": _tex("snow_02", "Diffuse"),
				"snow_normal": _tex("snow_02", "nor_gl"),
				"snow_rough": _tex("snow_02", "Rough"),
				"rock_albedo": _tex("dark_rock_02", "Diffuse"),
				"rock_normal": _tex("dark_rock_02", "nor_gl"),
				"rock_rough": _tex("dark_rock_02", "Rough"),
			})
		"MAT_SnowRock":
			return _pbr("snow_02", Color(0.92, 0.96, 1.0), 0.02, 0.78, 1.25, 0.32)
		"MAT_DeepGlacierIce":
			return _pbr("snow_02", Color(0.38, 0.78, 0.96), 0.06, 0.24, 1.35, 0.28, Color(0.08, 0.34, 0.52), 0.42)
		"MAT_CryoCrystal":
			return _emissive(Color(0.16, 0.96, 1.0), 4.6, 0.08, 0.12)
		"MAT_Aurora":
			return _shader("biome_aurora", {})
		"MAT_OutpostSteel":
			return _pbr("blue_metal_plate", Color(0.45, 0.52, 0.62), 0.76, 0.46, 1.15, 0.20)

		# --- BIOME 5: VOLCANIC CALDERA ---
		"MAT_ObsidianFloor":
			return _shader("biome_obsidian_floor", {
				"rock_albedo": _tex("dark_rock_02", "Diffuse"),
				"rock_normal": _tex("dark_rock_02", "nor_gl"),
				"rock_rough": _tex("dark_rock_02", "Rough"),
			})
		"MAT_LavaSea":
			return _shader("biome_lava_sea", {
				"crust_normal": _tex("dark_rock_02", "nor_gl"),
				"crust_rough": _tex("dark_rock_02", "Rough"),
			})
		"MAT_VolcanoCone":
			return _shader("biome_volcano_cone", {
				"rock_albedo": _tex("dark_rock_02", "Diffuse"),
				"rock_normal": _tex("dark_rock_02", "nor_gl"),
				"rock_rough": _tex("dark_rock_02", "Rough"),
				"volcano_center": Vector3(16.0, 0.0, -96.0),
				"summit_y": 58.0,
			})
		"MAT_ObsidianRock":
			return _pbr("dark_rock_02", Color(0.28, 0.19, 0.18), 0.16, 0.54, 1.55, 0.38)
		"MAT_BasaltRock":
			return _pbr("dark_rock_02", Color(0.38, 0.25, 0.22), 0.10, 0.68, 1.50, 0.32)
		"MAT_MagmaGlow":
			return _emissive(Color(1.0, 0.46, 0.06), 6.2, 0.18, 0.0)
	return null
