class_name HUDBossBar
extends Control
## Fixed top HUD boss health bar with cached StyleBoxFlat themes for normal and Enrage phases.

var _title_lbl: Label
var _hp_bar: ProgressBar
var _hp_lbl: Label
var _fill_normal: StyleBoxFlat
var _fill_enraged: StyleBoxFlat
var _bg_style: StyleBoxFlat
var _boss_name: String = ""
var _wave: int = 5
var _built: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_ensure_ui()


func build() -> void:
	_ensure_ui()


func bind_boss(boss: Node, wave: int, display_name: String) -> void:
	_ensure_ui()
	_wave = wave
	_boss_name = display_name.to_upper()
	_title_lbl.text = "BOSS ORBITAL: %s — ONDA %d" % [_boss_name, _wave]
	_hp_bar.add_theme_stylebox_override("fill", _fill_normal)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	visible = true
	if boss != null:
		if "max_hp" in boss and "current_hp" in boss:
			on_hp_updated(float(boss.get("current_hp")), float(boss.get("max_hp")))
		if boss.has_signal("hp_updated") and not boss.is_connected("hp_updated", on_hp_updated):
			boss.connect("hp_updated", on_hp_updated)
		if boss.has_signal("enraged") and not boss.is_connected("enraged", _on_boss_enraged):
			boss.connect("enraged", _on_boss_enraged)
		if boss.has_signal("died") and not boss.is_connected("died", _on_boss_died_signal):
			boss.connect("died", _on_boss_died_signal)


func on_hp_updated(cur: float, mx: float) -> void:
	_ensure_ui()
	_hp_bar.max_value = maxf(1.0, mx)
	_hp_bar.value = clampf(cur, 0.0, mx)
	_hp_lbl.text = "%d / %d HP" % [roundi(cur), roundi(mx)]


func on_enraged() -> void:
	_ensure_ui()
	_title_lbl.text = "BOSS ORBITAL [ENRAGE]: %s — ONDA %d" % [_boss_name, _wave]
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.32, 0.25))
	_hp_bar.add_theme_stylebox_override("fill", _fill_enraged)


func on_boss_died() -> void:
	visible = false


func _on_boss_enraged(_id: String, _salvo: int) -> void:
	on_enraged()


func _on_boss_died_signal(_e: Node3D, _id: String, _xp: int, _sc: int, _dc: float, _pos: Vector3) -> void:
	on_boss_died()


func _ensure_ui() -> void:
	if _built:
		return
	_built = true
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -260.0
	offset_right = 260.0
	offset_top = 86.0
	offset_bottom = 136.0

	_bg_style = StyleBoxFlat.new()
	_bg_style.bg_color = Color(0.06, 0.06, 0.09, 0.85)
	_bg_style.border_color = Color(0.95, 0.72, 0.25, 0.85)
	_bg_style.set_border_width_all(1)
	_bg_style.set_corner_radius_all(4)

	_fill_normal = StyleBoxFlat.new()
	_fill_normal.bg_color = Color(0.92, 0.62, 0.16, 0.95)
	_fill_normal.set_corner_radius_all(3)

	_fill_enraged = StyleBoxFlat.new()
	_fill_enraged.bg_color = Color(0.92, 0.16, 0.22, 0.98)
	_fill_enraged.set_corner_radius_all(3)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 3)
	add_child(vbox)

	var row := HBoxContainer.new()
	vbox.add_child(row)
	_title_lbl = Label.new()
	_title_lbl.text = "BOSS ORBITAL"
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.add_theme_font_size_override("font_size", 14)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	row.add_child(_title_lbl)

	_hp_lbl = Label.new()
	_hp_lbl.text = "950 / 950 HP"
	_hp_lbl.add_theme_font_size_override("font_size", 13)
	_hp_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	row.add_child(_hp_lbl)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(520.0, 14.0)
	_hp_bar.show_percentage = false
	_hp_bar.add_theme_stylebox_override("background", _bg_style)
	_hp_bar.add_theme_stylebox_override("fill", _fill_normal)
	vbox.add_child(_hp_bar)
