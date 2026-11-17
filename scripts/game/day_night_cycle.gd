class_name DayNightCycle
extends Node
## Drives a 24h day/night sky and directional light cycle (1 real minute = 2 in-game hours).

const HOURS_PER_REAL_SEC: float = 2.0 / 60.0

var time_of_day_hours: float = 10.0

var _sun: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _clock_lbl: Label
var _hud_accum: float = 0.0


func _ready() -> void:
	_bind_targets()
	_build_clock_hud()
	_apply_lighting()


func set_time_hours(hours: float) -> void:
	time_of_day_hours = fposmod(hours, 24.0)
	_apply_lighting()
	_refresh_clock()


func get_time_string() -> String:
	var total_min := int(floor(time_of_day_hours * 60.0)) % (24 * 60)
	return "%02d:%02d" % [int(total_min / 60), total_min % 60]


func get_phase_name() -> String:
	if time_of_day_hours >= 5.0 and time_of_day_hours < 7.0:
		return "AMANHECER"
	if time_of_day_hours >= 7.0 and time_of_day_hours < 17.0:
		return "DIA"
	if time_of_day_hours >= 17.0 and time_of_day_hours < 19.5:
		return "ENTARDECER"
	return "NOITE"


func _process(delta: float) -> void:
	time_of_day_hours = fposmod(time_of_day_hours + delta * HOURS_PER_REAL_SEC, 24.0)
	_apply_lighting()
	_hud_accum += delta
	if _hud_accum >= 0.25:
		_hud_accum = 0.0
		_refresh_clock()


func _bind_targets() -> void:
	var p := get_parent()
	if p == null:
		return
	var suns := p.find_children("*", "DirectionalLight3D", true, false)
	if not suns.is_empty():
		_sun = suns[0] as DirectionalLight3D
	var wes := p.find_children("*", "WorldEnvironment", true, false)
	var we := wes[0] as WorldEnvironment if not wes.is_empty() else null
	if we != null and we.environment != null:
		_env = we.environment.duplicate() as Environment
		we.environment = _env
		if _env.sky != null and _env.sky.sky_material is ProceduralSkyMaterial:
			var sky_res := _env.sky.duplicate() as Sky
			_sky = sky_res.sky_material.duplicate() as ProceduralSkyMaterial
			sky_res.sky_material = _sky
			_env.sky = sky_res


func _build_clock_hud() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_clock_lbl = Label.new()
	_clock_lbl.anchor_left = 0.5
	_clock_lbl.anchor_right = 0.5
	_clock_lbl.offset_left = -90.0
	_clock_lbl.offset_right = 90.0
	_clock_lbl.offset_top = 10.0
	_clock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_lbl.add_theme_font_size_override("font_size", 15)
	_clock_lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 0.90))
	_clock_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.90))
	_clock_lbl.add_theme_constant_override("outline_size", 4)
	layer.add_child(_clock_lbl)
	_refresh_clock()


func _refresh_clock() -> void:
	if _clock_lbl != null:
		_clock_lbl.text = "%s  •  %s" % [get_time_string(), get_phase_name()]


func _apply_lighting() -> void:
	var s := _sample_atmosphere(time_of_day_hours)
	if _sun != null:
		_sun.rotation_degrees.x = float(s["sun_pitch"])
		_sun.rotation_degrees.y = float(s["sun_yaw"])
		_sun.light_color = s["light_col"] as Color
		_sun.light_energy = float(s["light_energy"])
	if _env != null:
		_env.ambient_light_energy = float(s["ambient"])
		_env.fog_light_color = s["fog_col"] as Color
	if _sky != null:
		_sky.sky_top_color = s["sky_top"] as Color
		_sky.sky_horizon_color = s["sky_hor"] as Color
		_sky.ground_horizon_color = s["sky_hor"] as Color
		_sky.ground_bottom_color = s["ground_bot"] as Color


static func _sample_atmosphere(h: float) -> Dictionary:
	# Keyframes: [hour, sky_top, sky_hor, ground_bot, light_col, light_energy, ambient, sun_pitch]
	var keys := [
		[0.0,  Color(0.02, 0.03, 0.08), Color(0.05, 0.08, 0.18), Color(0.01, 0.02, 0.05), Color(0.45, 0.60, 0.95), 0.24, 0.28, -42.0],
		[5.5,  Color(0.12, 0.14, 0.28), Color(0.85, 0.45, 0.30), Color(0.08, 0.06, 0.10), Color(1.00, 0.65, 0.42), 0.65, 0.48, -12.0],
		[8.0,  Color(0.16, 0.38, 0.72), Color(0.68, 0.80, 0.92), Color(0.18, 0.16, 0.14), Color(1.00, 0.95, 0.88), 1.15, 0.75, -38.0],
		[12.5, Color(0.14, 0.42, 0.82), Color(0.72, 0.86, 0.98), Color(0.22, 0.20, 0.18), Color(1.00, 0.98, 0.95), 1.30, 0.85, -68.0],
		[17.5, Color(0.22, 0.28, 0.46), Color(0.96, 0.56, 0.30), Color(0.14, 0.10, 0.08), Color(1.00, 0.68, 0.40), 0.90, 0.62, -16.0],
		[19.5, Color(0.05, 0.07, 0.16), Color(0.16, 0.14, 0.28), Color(0.02, 0.02, 0.05), Color(0.50, 0.62, 0.95), 0.30, 0.34, -28.0],
		[24.0, Color(0.02, 0.03, 0.08), Color(0.05, 0.08, 0.18), Color(0.01, 0.02, 0.05), Color(0.45, 0.60, 0.95), 0.24, 0.28, -42.0],
	]
	var a: Array = keys[0]
	var b: Array = keys[keys.size() - 1]
	for i in range(keys.size() - 1):
		if h >= float(keys[i][0]) and h <= float(keys[i + 1][0]):
			a = keys[i]
			b = keys[i + 1]
			break
	var span := maxf(0.001, float(b[0]) - float(a[0]))
	var t := clampf((h - float(a[0])) / span, 0.0, 1.0)
	var sky_hor: Color = (a[2] as Color).lerp(b[2] as Color, t)
	return {
		"sky_top": (a[1] as Color).lerp(b[1] as Color, t),
		"sky_hor": sky_hor,
		"ground_bot": (a[3] as Color).lerp(b[3] as Color, t),
		"fog_col": sky_hor.lerp(Color(0.05, 0.08, 0.15), 0.25),
		"light_col": (a[4] as Color).lerp(b[4] as Color, t),
		"light_energy": lerpf(float(a[5]), float(b[5]), t),
		"ambient": lerpf(float(a[6]), float(b[6]), t),
		"sun_pitch": lerpf(float(a[7]), float(b[7]), t),
		"sun_yaw": lerpf(-45.0, 135.0, h / 24.0),
	}
