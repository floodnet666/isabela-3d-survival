class_name ShipTractorCutscene
extends Node
## Star Trek-inspired SM_Ship tractor beam relocation cutscene between procedural biomes.

signal relocation_finished()

var is_playing: bool = false

var _layer: CanvasLayer
var _flash_rect: ColorRect
var _title_lbl: Label
var _sub_lbl: Label
var _beam_root: Node3D
var _rings: Array[MeshInstance3D] = []
var _active_time: float = 0.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_layer = CanvasLayer.new()
	_layer.layer = 18
	add_child(_layer)

	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(0.65, 0.94, 1.0, 0.0)
	_layer.add_child(_flash_rect)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -360.0
	vbox.offset_right = 360.0
	vbox.offset_top = -55.0
	vbox.offset_bottom = 55.0
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(vbox)

	_title_lbl = _make_lbl(30, Color(0.78, 0.96, 1.0, 0.0))
	_sub_lbl = _make_lbl(16, Color(1.0, 0.84, 0.48, 0.0))
	vbox.add_child(_title_lbl)
	vbox.add_child(_sub_lbl)


func _process(delta: float) -> void:
	if not is_playing or _beam_root == null or not is_instance_valid(_beam_root):
		return
	_active_time += delta
	for i in range(_rings.size()):
		var r := _rings[i]
		if is_instance_valid(r):
			var phase := fmod(_active_time * 1.45 + float(i) * 0.25, 1.0)
			r.position.y = lerpf(0.2, 13.0, phase)
			r.scale = Vector3.ONE * lerpf(1.25, 0.65, phase)


func play_relocation(arena: Node3D, ship: Node3D, player: Node3D, audio: Node, biome_title: String, on_swap_biome: Callable) -> void:
	if DisplayServer.get_name() == "headless" or arena == null or player == null:
		if on_swap_biome.is_valid():
			on_swap_biome.call()
		relocation_finished.emit()
		return
	if is_playing:
		return
	is_playing = true
	_active_time = 0.0
	var ship_home := ship.global_position if ship != null else Vector3(6, 22, -58)
	var p_pos := player.global_position
	var ship_target := Vector3(p_pos.x, p_pos.y + 13.5, p_pos.z)

	if _title_lbl != null:
		_title_lbl.text = "RELOCAÇÃO ORBITAL"
		_sub_lbl.text = "DESTINO: %s" % biome_title.to_upper()

	# 1. SM_Ship swoops directly over the player (0.65s)
	var tw := create_tween()
	if ship != null:
		tw.tween_property(ship, "global_position", ship_target, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_interval(0.25)

	# 2. Activate Star Trek tractor beam + SFX + gentle player levitation (0.95s)
	tw.tween_callback(func() -> void:
		_spawn_tractor_beam(arena, p_pos, 13.5)
		if audio != null and audio.has_method("play_sfx"):
			audio.call("play_sfx", "tractor_beam", 0.0, 1.5)
	)
	tw.tween_property(player, "global_position:y", p_pos.y + 1.55, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _flash_rect != null:
		tw.parallel().tween_property(_flash_rect, "color:a", 0.96, 0.85).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(_title_lbl, "modulate:a", 1.0, 0.45)
		tw.parallel().tween_property(_sub_lbl, "modulate:a", 1.0, 0.45)

	# 3. Peak flash: dematerialize, swap procedural biome, rematerialize at center (0, 0.1, 0)
	tw.tween_callback(func() -> void:
		_clear_tractor_beam()
		if on_swap_biome.is_valid():
			on_swap_biome.call()
		player.global_position = Vector3(0.0, 0.12, 0.0)
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
		if ship != null:
			ship.global_position = Vector3(0.0, 14.5, 0.0)
		_spawn_tractor_beam(arena, Vector3.ZERO, 14.5)
	)
	tw.tween_interval(0.22)

	# 4. Fade-in revealing new biome + SM_Ship ascends back to orbit
	if _flash_rect != null:
		tw.tween_property(_flash_rect, "color:a", 0.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if ship != null:
		tw.parallel().tween_property(ship, "global_position", ship_home, 0.95).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_clear_tractor_beam)
	if _title_lbl != null:
		tw.tween_property(_title_lbl, "modulate:a", 0.0, 0.55)
		tw.parallel().tween_property(_sub_lbl, "modulate:a", 0.0, 0.55)
	tw.tween_callback(func() -> void:
		is_playing = false
		relocation_finished.emit()
	)


func _spawn_tractor_beam(parent: Node3D, base_pos: Vector3, height: float) -> void:
	_clear_tractor_beam()
	_beam_root = Node3D.new()
	_beam_root.name = "TractorBeamFX"
	_beam_root.position = Vector3(base_pos.x, base_pos.y, base_pos.z)
	parent.add_child(_beam_root)

	# Outer volumetric cyan cone
	var outer := _make_fx_cyl(0.55, 1.55, height, Color(0.18, 0.88, 1.0, 0.34))
	outer.position.y = height * 0.5
	_beam_root.add_child(outer)
	# Inner bright golden-white core
	var core := _make_fx_cyl(0.18, 0.48, height, Color(0.92, 0.98, 1.0, 0.62))
	core.position.y = height * 0.5
	_beam_root.add_child(core)

	# 4 ascending transporter rings
	for i in range(4):
		var tm := TorusMesh.new(); tm.inner_radius = 0.85; tm.outer_radius = 1.05
		var ring := MeshInstance3D.new(); ring.mesh = tm
		ring.material_override = _make_unshaded(Color(0.55, 0.95, 1.0, 0.72))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position.y = float(i) * 3.0
		_beam_root.add_child(ring)
		_rings.append(ring)

	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 0.92, 1.0)
	light.light_energy = 5.5
	light.omni_range = 16.0
	light.position.y = 2.0
	_beam_root.add_child(light)


func _clear_tractor_beam() -> void:
	_rings.clear()
	if _beam_root != null and is_instance_valid(_beam_root):
		_beam_root.queue_free()
		_beam_root = null


func _make_fx_cyl(top_r: float, bot_r: float, h: float, col: Color) -> MeshInstance3D:
	var c := CylinderMesh.new(); c.top_radius = top_r; c.bottom_radius = bot_r; c.height = h
	var mi := MeshInstance3D.new(); mi.mesh = c
	mi.material_override = _make_unshaded(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _make_unshaded(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = col
	return m


func _make_lbl(sz: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.92))
	l.add_theme_constant_override("outline_size", 5)
	l.modulate.a = col.a
	return l
