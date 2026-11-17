class_name HUDRadar
extends Control
## Tactical HUD Mini-Radar rendered via _draw() with 0.06s throttle and yaw-relative projection.

const RADAR_RANGE_M: float = 34.0
const RADAR_SIZE_PX: float = 152.0
const THROTTLE_S: float = 0.06

var _player: Node3D
var _cam_rig: Node3D
var _accum: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -(RADAR_SIZE_PX + 18.0)
	offset_top = 18.0
	offset_right = -18.0
	offset_bottom = 18.0 + RADAR_SIZE_PX
	custom_minimum_size = Vector2(RADAR_SIZE_PX, RADAR_SIZE_PX)


func bind(player: Node3D, cam_rig: Node3D = null) -> void:
	_player = player
	_cam_rig = cam_rig
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta * 6.0
	_accum += delta
	if _accum >= THROTTLE_S:
		_accum = 0.0
		queue_redraw()


static func world_to_radar_offset(entity_pos: Vector3, player_pos: Vector3, player_yaw: float, radar_radius_px: float, max_range_m: float = RADAR_RANGE_M) -> Vector2:
	var dx := entity_pos.x - player_pos.x
	var dz := entity_pos.z - player_pos.z
	# Camera forward in Godot with yaw is (-sin(yaw), 0, -cos(yaw)); right is (cos(yaw), 0, -sin(yaw)).
	var sin_y := sin(player_yaw)
	var cos_y := cos(player_yaw)
	var fwd_proj := dx * (-sin_y) + dz * (-cos_y)
	var right_proj := dx * cos_y + dz * (-sin_y)
	var scale := radar_radius_px / maxf(1.0, max_range_m)
	var offset := Vector2(right_proj * scale, -fwd_proj * scale)
	var max_px := maxf(2.0, radar_radius_px - 5.0)
	if offset.length() > max_px:
		offset = offset.normalized() * max_px
	return offset


func _draw() -> void:
	var center := size * 0.5
	var rad := minf(size.x, size.y) * 0.5 - 2.0
	if rad <= 4.0:
		rad = RADAR_SIZE_PX * 0.5 - 2.0
		center = Vector2(RADAR_SIZE_PX * 0.5, RADAR_SIZE_PX * 0.5)

	draw_circle(center, rad, Color(0.03, 0.05, 0.09, 0.72))
	draw_arc(center, rad, 0.0, TAU, 48, Color(0.35, 0.72, 0.92, 0.55), 1.6)
	draw_arc(center, rad * 0.5, 0.0, TAU, 36, Color(0.30, 0.55, 0.75, 0.25), 1.0)
	# Subtle FOV cone
	var fov_len := rad * 0.85
	draw_line(center, center + Vector2(-sin(0.55), -cos(0.55)) * fov_len, Color(0.45, 0.85, 1.0, 0.22), 1.2)
	draw_line(center, center + Vector2(sin(0.55), -cos(0.55)) * fov_len, Color(0.45, 0.85, 1.0, 0.22), 1.2)

	if _player != null and is_instance_valid(_player) and is_inside_tree():
		var p_pos := _player.global_position
		var yaw := float(_cam_rig.get("yaw")) if (_cam_rig != null and "yaw" in _cam_rig) else 0.0
		var tree := get_tree()
		for b in tree.get_nodes_in_group("explosive_barrels"):
			if b is Node3D and is_instance_valid(b):
				var off := world_to_radar_offset((b as Node3D).global_position, p_pos, yaw, rad)
				draw_circle(center + off, 2.2, Color(0.95, 0.68, 0.15, 0.75))
		for pod in tree.get_nodes_in_group("orbital_drop_pods"):
			if pod is Node3D and is_instance_valid(pod):
				var off := world_to_radar_offset((pod as Node3D).global_position, p_pos, yaw, rad)
				var blink := 0.45 + 0.55 * absf(sin(_pulse * 1.8))
				draw_arc(center + off, 4.0, 0.0, TAU, 12, Color(1.0, 0.18, 0.22, blink), 1.8)
		for e in tree.get_nodes_in_group("enemies"):
			if e is Node3D and is_instance_valid(e):
				_draw_enemy_blip(center, rad, p_pos, yaw, e as Node3D)

	# Player forward triangle
	var tri := PackedVector2Array([center + Vector2(0, -5), center + Vector2(4, 4), center + Vector2(-4, 4)])
	draw_colored_polygon(tri, Color(0.35, 1.0, 0.65, 0.95))


func _draw_enemy_blip(center: Vector2, rad: float, p_pos: Vector3, yaw: float, e: Node3D) -> void:
	var off := world_to_radar_offset(e.global_position, p_pos, yaw, rad)
	var pos := center + off
	if e.is_in_group("boss_sentinel"):
		var blinking := ("is_blinking_telegraph" in e) and bool(e.get("is_blinking_telegraph"))
		var pulse_r := 6.0 + (1.8 * sin(_pulse * 2.5) if blinking else 0.9 * sin(_pulse))
		var col := Color(1.0, 0.95, 0.55, 1.0) if (blinking and sin(_pulse * 5.0) > 0.0) else Color(1.0, 0.80, 0.18, 0.98)
		var dia := PackedVector2Array([
			pos + Vector2(0, -pulse_r),
			pos + Vector2(pulse_r, 0),
			pos + Vector2(0, pulse_r),
			pos + Vector2(-pulse_r, 0),
		])
		draw_colored_polygon(dia, col)
		return
	var eid := str(e.get("enemy_id")) if "enemy_id" in e else "droid_small"
	match eid:
		"droid_tall":
			draw_circle(pos, 4.0, Color(0.20, 0.90, 1.0, 0.92))
		"mech_leela":
			draw_circle(pos, 4.0, Color(0.85, 0.30, 0.95, 0.92))
		"mech_mike":
			draw_circle(pos, 4.2, Color(1.0, 0.42, 0.22, 0.95))
		"mech_stan":
			draw_circle(pos, 4.5, Color(1.0, 0.22, 0.22, 0.95))
		"mech_george":
			draw_circle(pos, 4.8, Color(0.95, 0.15, 0.55, 0.95))
		_:
			draw_circle(pos, 3.0, Color(1.0, 0.58, 0.18, 0.90))
