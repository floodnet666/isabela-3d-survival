class_name SkinSelectorModalUI
extends ColorRect
## Main Menu Skin & Helmet Customization Modal displaying unlock status, Buffs/Debuffs, and QA unlock toggle.

const BalanceDBRef := preload("res://scripts/game/balance_db.gd")
const SettingsManagerRef := preload("res://scripts/game/settings_manager.gd")

signal closed()

var _db: BalanceDBRef
var _skin_list: VBoxContainer
var _info_title: Label
var _buff_lbl: Label
var _debuff_lbl: Label
var _status_lbl: Label
var _helmet_opt: OptionButton
var _qa_check: CheckBox
var _close_btn: Button
var _built: bool = false


func _ready() -> void:
	visible = false
	_ensure_ui()


func open() -> void:
	_ensure_ui()
	_refresh_ui()
	visible = true
	if _close_btn != null and is_inside_tree():
		_close_btn.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		visible = false
		closed.emit()
		get_viewport().set_input_as_handled()


func _ensure_ui() -> void:
	if _built:
		return
	_built = true
	_db = BalanceDBRef.new()
	_db.load_from_file("res://data/game_balance.json")

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.02, 0.02, 0.05, 0.88)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760.0, 480.0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 12)
	margin.add_child(root_v)

	var hdr := Label.new()
	hdr.text = "VISUAL, CAPACETES & ARQUÉTIPOS"
	hdr.add_theme_font_size_override("font_size", 22)
	hdr.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42))
	root_v.add_child(hdr)

	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 20)
	root_v.add_child(hbox)

	_skin_list = VBoxContainer.new()
	_skin_list.custom_minimum_size = Vector2(310.0, 0.0)
	_skin_list.add_theme_constant_override("separation", 6)
	hbox.add_child(_skin_list)

	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 10)
	hbox.add_child(detail)

	_info_title = Label.new()
	_info_title.add_theme_font_size_override("font_size", 20)
	_info_title.add_theme_color_override("font_color", Color(0.98, 0.94, 0.86))
	detail.add_child(_info_title)

	_status_lbl = Label.new()
	_status_lbl.add_theme_font_size_override("font_size", 14)
	detail.add_child(_status_lbl)

	_buff_lbl = Label.new()
	_buff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buff_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
	detail.add_child(_buff_lbl)

	_debuff_lbl = Label.new()
	_debuff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_debuff_lbl.add_theme_color_override("font_color", Color(1.0, 0.48, 0.38))
	detail.add_child(_debuff_lbl)

	var h_row := HBoxContainer.new()
	detail.add_child(h_row)
	var h_lbl := Label.new()
	h_lbl.text = "Capacete Tático:  "
	h_row.add_child(h_lbl)
	_helmet_opt = OptionButton.new()
	_helmet_opt.add_item("Sem Capacete", 0)
	_helmet_opt.add_item("Capacete A (SM_Helmet_A)", 1)
	_helmet_opt.add_item("Capacete B (SM_Helmet_B)", 2)
	_helmet_opt.item_selected.connect(_on_helmet_selected)
	h_row.add_child(_helmet_opt)

	_qa_check = CheckBox.new()
	_qa_check.text = "Modo QA: Liberar Todas as Skins para Teste"
	_qa_check.toggled.connect(func(on: bool) -> void:
		SettingsManagerRef.set_val("unlock_all_for_test", on, true)
		_refresh_ui()
	)
	detail.add_child(_qa_check)

	_close_btn = Button.new()
	_close_btn.text = "CONCLUÍDO [ESC]"
	_close_btn.pressed.connect(func() -> void:
		visible = false
		closed.emit()
	)
	root_v.add_child(_close_btn)


func _refresh_ui() -> void:
	for c in _skin_list.get_children():
		c.queue_free()
	var selected := SettingsManagerRef.get_selected_skin()
	var archetypes := _db.get_character_archetypes()
	for sid in archetypes.keys():
		var arch: Dictionary = archetypes[sid]
		var unlocked := SettingsManagerRef.is_skin_unlocked(str(sid))
		var btn := Button.new()
		var prefix := "✓ " if str(sid) == selected else ("" if unlocked else "🔒 ")
		btn.text = prefix + str(arch.get("display_name", sid))
		btn.disabled = not unlocked
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func() -> void:
			if SettingsManagerRef.select_skin(str(sid)):
				_refresh_ui()
		)
		_skin_list.add_child(btn)

	var sel_arch := _db.get_archetype_cfg(selected)
	_info_title.text = str(sel_arch.get("display_name", selected))
	_status_lbl.text = "STATUS: DESBLOQUEADA E EQUIPADA"
	_status_lbl.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
	_buff_lbl.text = "BUFFS: " + str(sel_arch.get("buffs_text", "Nenhum"))
	_debuff_lbl.text = "DEBUFFS: " + str(sel_arch.get("debuffs_text", "Nenhum"))

	var hid := str(SettingsManagerRef.get_val("selected_helmet"))
	_helmet_opt.selected = 1 if hid == "helmet_a" else (2 if hid == "helmet_b" else 0)
	_qa_check.button_pressed = bool(SettingsManagerRef.get_val("unlock_all_for_test"))


func _on_helmet_selected(idx: int) -> void:
	var hid := "helmet_a" if idx == 1 else ("helmet_b" if idx == 2 else "none")
	SettingsManagerRef.set_val("selected_helmet", hid, true)
