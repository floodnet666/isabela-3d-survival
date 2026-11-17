class_name MainMenuController
extends Control
## Dune-inspired epic sci-fi Main Menu: atmospheric desert backdrop, particles, Navigation, Settings & How-To-Play.

const InputSetupRef := preload("res://scripts/game/input_setup.gd")
const SettingsManagerRef := preload("res://scripts/game/settings_manager.gd")
const SettingsModalRef := preload("res://scripts/game/settings_modal_ui.gd")
const AudioManagerRef := preload("res://scripts/game/audio_manager.gd")
const DuneBackdropRef := preload("res://scripts/game/dune_backdrop.gd")

const ARENA_SCENE_PATH := "res://scenes/game/playable_arena.tscn"

var _play_btn: Button
var _skin_btn: Button
var _settings_btn: Button
var _howto_btn: Button
var _quit_btn: Button
var _fullscreen_btn: Button
var _settings_modal: SettingsModalRef
var _skin_modal: ColorRect
var _howto_panel: ColorRect
var _howto_close_btn: Button
var _audio: AudioManagerRef
var _built: bool = false


func _ready() -> void:
	InputSetupRef.ensure_default_actions()
	SettingsManagerRef.ensure_loaded()
	SettingsManagerRef.apply_all(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ensure_ui()
	_setup_audio()
	if _play_btn != null and is_inside_tree():
		_play_btn.grab_focus()


func ensure_built() -> void:
	_ensure_ui()


func get_menu_buttons() -> Array[Button]:
	var arr: Array[Button] = []
	for b in [_play_btn, _settings_btn, _howto_btn, _quit_btn]:
		if b != null:
			arr.append(b)
	return arr


func is_settings_open() -> bool:
	return _settings_modal != null and _settings_modal.visible


func is_howto_open() -> bool:
	return _howto_panel != null and _howto_panel.visible


func _ensure_ui() -> void:
	if _built:
		return
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	DuneBackdropRef.build_into(self)
	_build_title_and_menu()
	_build_fullscreen_toggle()
	_build_howto_overlay()

	_settings_modal = SettingsModalRef.new()
	_settings_modal.name = "SettingsModal"
	_settings_modal.closed.connect(_on_submodal_closed)
	add_child(_settings_modal)
	_skin_modal = preload("res://scripts/game/skin_selector_modal_ui.gd").new()
	_skin_modal.closed.connect(_on_submodal_closed)
	add_child(_skin_modal)


func _build_title_and_menu() -> void:
	var left_margin := MarginContainer.new()
	left_margin.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left_margin.offset_right = 620.0
	left_margin.add_theme_constant_override("margin_left", 72)
	left_margin.add_theme_constant_override("margin_top", 84)
	left_margin.add_theme_constant_override("margin_bottom", 48)
	add_child(left_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	left_margin.add_child(vbox)

	var overline := Label.new()
	overline.text = "A R E N A   D E   S O B R E V I V Ê N C I A   3 D"
	overline.add_theme_font_size_override("font_size", 13)
	overline.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36, 0.90))
	vbox.add_child(overline)

	var title := Label.new()
	title.text = "I S A B E L A"
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color(0.98, 0.94, 0.86))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.04, 0.90))
	title.add_theme_constant_override("outline_size", 6)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "COSTA DO DESERTO  •  CERCO ORBITAL"
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color(0.86, 0.64, 0.36))
	vbox.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 26)
	vbox.add_child(spacer)

	_play_btn = _make_menu_button("INICIAR MISSÃO", true)
	_play_btn.pressed.connect(_on_play_pressed)
	vbox.add_child(_play_btn)

	_skin_btn = _make_menu_button("VISUAL & ARQUÉTIPOS", false)
	_skin_btn.pressed.connect(func() -> void:
		if _skin_modal != null: _skin_modal.call("open")
	)
	vbox.add_child(_skin_btn)

	_settings_btn = _make_menu_button("CONFIGURAÇÕES", false)
	_settings_btn.pressed.connect(_on_settings_pressed)
	vbox.add_child(_settings_btn)

	_howto_btn = _make_menu_button("COMO JOGAR & CONTROLES", false)
	_howto_btn.pressed.connect(_on_howto_pressed)
	vbox.add_child(_howto_btn)

	_quit_btn = _make_menu_button("SAIR", false)
	_quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(_quit_btn)

	var hint := Label.new()
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 72.0
	hint.offset_top = -42.0
	hint.offset_right = 760.0
	hint.offset_bottom = -16.0
	hint.text = "[W/S] ou [D-Pad] Navegar   •   [Enter / A] Confirmar   •   [F11] Tela Cheia   •   [V / Y] 3ª/1ª Pessoa"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.84, 0.74, 0.58, 0.85))
	add_child(hint)


func _build_fullscreen_toggle() -> void:
	_fullscreen_btn = _make_menu_button("", false)
	_fullscreen_btn.name = "FullscreenToggleBtn"
	_fullscreen_btn.custom_minimum_size = Vector2(180, 38)
	_fullscreen_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fullscreen_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fullscreen_btn.offset_left = -212.0
	_fullscreen_btn.offset_top = 24.0
	_fullscreen_btn.offset_right = -24.0
	_fullscreen_btn.offset_bottom = 62.0
	_fullscreen_btn.add_theme_font_size_override("font_size", 13)
	_fullscreen_btn.pressed.connect(toggle_fullscreen)
	add_child(_fullscreen_btn)
	_sync_fullscreen_label()


func _sync_fullscreen_label() -> void:
	if _fullscreen_btn == null:
		return
	var is_fs := bool(SettingsManagerRef.get_val("fullscreen"))
	_fullscreen_btn.text = "JANELA [F11]" if is_fs else "TELA CHEIA [F11]"


func toggle_fullscreen() -> void:
	var next_fs := not bool(SettingsManagerRef.get_val("fullscreen"))
	SettingsManagerRef.set_val("fullscreen", next_fs, true)
	SettingsManagerRef.apply_video()
	_sync_fullscreen_label()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()


func _make_menu_button(txt: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(340, 48)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 18 if primary else 16)

	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0.18, 0.11, 0.08, 0.78) if primary else Color(0.08, 0.07, 0.10, 0.72)
	norm.border_color = Color(0.95, 0.70, 0.30, 0.85) if primary else Color(0.55, 0.45, 0.34, 0.55)
	norm.border_width_left = 4
	norm.set_corner_radius_all(4)
	norm.content_margin_left = 18

	var foc := norm.duplicate() as StyleBoxFlat
	foc.bg_color = Color(0.32, 0.19, 0.10, 0.94)
	foc.border_color = Color(1.0, 0.86, 0.45, 1.0)
	foc.set_border_width_all(2)
	foc.border_width_left = 6

	b.add_theme_stylebox_override("normal", norm)
	b.add_theme_stylebox_override("hover", foc)
	b.add_theme_stylebox_override("focus", foc)
	return b


func _build_howto_overlay() -> void:
	_howto_panel = ColorRect.new()
	_howto_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_howto_panel.color = Color(0.02, 0.02, 0.04, 0.86)
	_howto_panel.visible = false
	add_child(_howto_panel)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_howto_panel.add_child(center)

	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(660.0, 400.0)
	center.add_child(p)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 20)
	m.add_theme_constant_override("margin_bottom", 20)
	p.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)

	var t := Label.new()
	t.text = "GUIA TÁTICO DE COMBATE"
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42))
	v.add_child(t)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = (
		"• MOVIMENTO: [WASD / Analógico Esq]  •  CORRER: [Shift / L3]  •  DASH (Iframes): [Q / B]\n"
		+ "• COMBATE: [LMB / RT] Atirar  •  [RMB / LT] Mira Precisa  •  [R / X] Recarregar / Ventilar Laser\n"
		+ "• ARSENAL (1–7 / RB-LB): Pistola, Sabre (deflete plasma!), Escopeta, Lança-Foguetes, Katana, Laser e SMG.\n"
		+ "• CÂMERA: [V / Y] Alterna 3ª Pessoa ↔ 1ª Pessoa  •  [H / R3] Modo Doom Centralizado.\n"
		+ "• DICA: Use barris de plasma para explosões em cadeia e colete caixas para sobreviver às ondas!"
	)
	v.add_child(body)

	_howto_close_btn = Button.new()
	_howto_close_btn.text = "VOLTAR [ESC / B]"
	_howto_close_btn.pressed.connect(_on_submodal_closed)
	v.add_child(_howto_close_btn)


func _setup_audio() -> void:
	_audio = AudioManagerRef.new()
	_audio.name = "AudioManager"
	add_child(_audio)
	SettingsManagerRef.apply_audio(get_tree())
	_audio.start_music()


func _on_play_pressed() -> void:
	if is_inside_tree():
		get_tree().paused = false
		get_tree().change_scene_to_file(ARENA_SCENE_PATH)
func _on_settings_pressed() -> void:
	if _settings_modal != null: _settings_modal.open()
func _on_howto_pressed() -> void:
	if _howto_panel != null:
		_howto_panel.visible = true
		if _howto_close_btn != null and is_inside_tree(): _howto_close_btn.grab_focus()
func _on_submodal_closed() -> void:
	if _howto_panel != null: _howto_panel.visible = false
	_sync_fullscreen_label()
	if _play_btn != null and is_inside_tree(): _play_btn.grab_focus()
func _on_quit_pressed() -> void:
	if is_inside_tree(): get_tree().quit()
