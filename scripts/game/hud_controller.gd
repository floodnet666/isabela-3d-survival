class_name HUDController
extends CanvasLayer
## Combat HUD: Wave/XP bar, HP & Dash indicator, 1-6 Weapon Hotbar, Crosshair/Hitmarker, and Modal Overlays.

const GameManagerRef := preload("res://scripts/game/game_manager.gd")
const PlayerControllerRef := preload("res://scripts/game/player_controller.gd")
const UpgradeModalRef := preload("res://scripts/game/upgrade_modal_ui.gd")
const HUDWeaponBarRef := preload("res://scripts/game/hud_weapon_bar.gd")
const HUDCrosshairRef := preload("res://scripts/game/hud_crosshair.gd")
const PauseModalRef := preload("res://scripts/game/pause_modal_ui.gd")
const GameOverModalRef := preload("res://scripts/game/game_over_modal_ui.gd")
const SettingsModalRef := preload("res://scripts/game/settings_modal_ui.gd")

signal restart_requested()
signal menu_requested()

var _gm: GameManagerRef
var _player: PlayerControllerRef

var _wave_lbl: Label
var _score_lbl: Label
var _xp_bar: ProgressBar
var _xp_lbl: Label
var _banner_lbl: Label
var _hp_bar: ProgressBar
var _hp_lbl: Label
var _dash_bar: ProgressBar
var _dash_lbl: Label
var _vignette: ColorRect
var _crosshair: HUDCrosshairRef
var _weapon_bar: HUDWeaponBarRef
var _upgrade_modal: UpgradeModalRef
var _pause_modal: PauseModalRef
var _game_over_modal: GameOverModalRef
var _settings_modal: SettingsModalRef
var _radar: Control
var _boss_bar: Control
var _vig_left: float = 0.0
var _banner_left: float = 0.0
var _built: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_ensure_ui()


func bind(gm: GameManagerRef, player: PlayerControllerRef) -> void:
	_ensure_ui()
	_gm = gm
	_player = player
	_connect_once(_gm.wave_started, _on_wave_started)
	_connect_once(_gm.wave_cleared, _on_wave_cleared)
	_connect_once(_gm.xp_changed, _on_xp_changed)
	_connect_once(_gm.score_changed, _on_score_changed)
	_connect_once(_gm.upgrade_modal_opened, _on_upgrade_modal_opened)
	_connect_once(_gm.state_changed, _on_state_changed)
	_connect_once(_gm.countdown_updated, _on_countdown_updated)
	_connect_once(_player.hp_changed, _on_hp_changed)
	_connect_once(_player.damaged, _on_player_damaged)
	_connect_once(_player.dash_state_changed, _on_dash_changed)
	_connect_once(_player.hit_confirmed, _on_hit_confirmed)
	if _player.has_signal("view_mode_changed"):
		_connect_once(_player.view_mode_changed, _on_view_mode_changed)
	if _crosshair != null and _player.has_method("is_fps_mode"):
		_crosshair.set_view_mode(_player.is_fps_mode(), false)
	if _radar != null: _radar.call("bind", _player, _player.get_node_or_null("CameraPivot"))
	_refresh_weapon_bar()

func bind_boss(boss: Node, wave: int, dname: String) -> void:
	if _boss_bar != null: _boss_bar.call("bind_boss", boss, wave, dname)


func _connect_once(sig: Signal, cb: Callable) -> void:
	if not sig.is_connected(cb):
		sig.connect(cb)

func get_weapon_slot_count() -> int: return _weapon_bar.get_slot_count() if _weapon_bar != null else 0
func get_view_mode_text() -> String: return _crosshair.get_view_mode_text() if _crosshair != null else ""
func is_upgrade_modal_visible() -> bool: return _upgrade_modal != null and _upgrade_modal.visible
func is_pause_modal_visible() -> bool: return _pause_modal != null and _pause_modal.visible
func is_game_over_modal_visible() -> bool: return _game_over_modal != null and _game_over_modal.visible
func get_upgrade_card_count() -> int: return _upgrade_modal.get_card_count() if _upgrade_modal != null else 0

func select_upgrade_card(idx: int) -> void:
	if _gm != null:
		_gm.choose_upgrade(idx)


func _process(delta: float) -> void:
	if _vig_left > 0.0:
		_vig_left = maxf(0.0, _vig_left - delta)
		_vignette.color.a = clampf(_vig_left * 1.4, 0.0, 0.38)
	if _banner_left > 0.0:
		_banner_left = maxf(0.0, _banner_left - delta)
		_banner_lbl.visible = _banner_left > 0.0
	if _crosshair != null and _gm != null and _gm.loadout != null:
		var def := _gm.loadout.get_selected_def()
		var aiming := _player != null and _player.is_aiming
		var sp := float(def.get("spread_aim_deg", 0.2) if aiming else def.get("spread_hip_deg", 1.0))
		var mv := clampf(Vector2(_player.velocity.x, _player.velocity.z).length() / 8.6, 0.0, 1.0) if _player != null else 0.0
		_crosshair.update_crosshair(delta, sp, aiming, mv, str(def.get("id", "")))
	if _gm != null and _gm.loadout != null:
		_refresh_weapon_bar()
		_wave_lbl.text = "ONDA %d  •  RESTAM: %d" % [_gm.current_wave, _gm.enemies_remaining_in_wave]


func _unhandled_input(event: InputEvent) -> void:
	if _settings_modal != null and _settings_modal.visible:
		return
	if _gm != null and event.is_action_pressed("pause"):
		if _gm.state == GameManagerRef.State.PLAYING or _gm.state == GameManagerRef.State.PAUSED:
			_gm.toggle_pause()


func _ensure_ui() -> void:
	if _built:
		return
	_built = true
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color(0.85, 0.1, 0.1, 0.0)
	add_child(_vignette)

	# Top wave + XP header
	var top_box := VBoxContainer.new()
	top_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_box.offset_left = 260.0
	top_box.offset_right = -260.0
	top_box.offset_top = 14.0
	top_box.add_theme_constant_override("separation", 4)
	add_child(top_box)

	var top_row := HBoxContainer.new()
	top_box.add_child(top_row)
	_wave_lbl = _make_label("ONDA 1  •  RESTAM: 6", 18, Color(0.98, 0.85, 0.45))
	_wave_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_wave_lbl)
	_score_lbl = _make_label("ABATES: 0  •  PONTOS: 0", 16, Color(0.75, 0.9, 1.0))
	top_row.add_child(_score_lbl)

	_xp_bar = _make_bar(Vector2(0.0, 14.0), 80.0)
	top_box.add_child(_xp_bar)
	_xp_lbl = _make_label("NÍVEL 1  •  0 / 80 XP", 13, Color(0.82, 0.92, 1.0))
	_xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_box.add_child(_xp_lbl)

	_banner_lbl = _make_label("", 28, Color(1.0, 0.82, 0.30))
	_banner_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_lbl.offset_top = 95.0
	_banner_lbl.offset_left = -260.0
	_banner_lbl.offset_right = 260.0
	_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_lbl.visible = false
	add_child(_banner_lbl)

	_crosshair = HUDCrosshairRef.new()
	_crosshair.build()
	add_child(_crosshair)

	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.offset_left = 20.0
	bl.offset_right = 280.0
	bl.offset_top = -115.0
	bl.offset_bottom = -18.0
	add_child(bl)
	_hp_lbl = _make_label("HP 120 / 120", 16, Color(0.35, 1.0, 0.55))
	bl.add_child(_hp_lbl)
	_hp_bar = _make_bar(Vector2(250.0, 18.0), 120.0)
	bl.add_child(_hp_bar)
	_dash_lbl = _make_label("DASH [Q]: 1/1", 13, Color(0.45, 0.85, 1.0))
	bl.add_child(_dash_lbl)
	_dash_bar = _make_bar(Vector2(250.0, 10.0), 1.0)
	bl.add_child(_dash_bar)

	# Bottom-center 1-6 weapon bar + reload/heat prompt
	_weapon_bar = HUDWeaponBarRef.new()
	_weapon_bar.build()
	add_child(_weapon_bar)

	_upgrade_modal = UpgradeModalRef.new()
	_upgrade_modal.card_selected.connect(select_upgrade_card)
	add_child(_upgrade_modal)
	_radar = preload("res://scripts/game/hud_radar.gd").new(); add_child(_radar)
	_boss_bar = preload("res://scripts/game/hud_boss_bar.gd").new(); add_child(_boss_bar)
	_build_modals()


func _build_modals() -> void:
	_pause_modal = PauseModalRef.new()
	_pause_modal.resume_requested.connect(func() -> void:
		if _gm != null and _gm.state == GameManagerRef.State.PAUSED:
			_gm.toggle_pause()
	)
	_pause_modal.settings_requested.connect(func() -> void:
		if _settings_modal != null:
			_settings_modal.open()
	)
	_pause_modal.restart_requested.connect(func() -> void: restart_requested.emit())
	_pause_modal.menu_requested.connect(func() -> void: menu_requested.emit())
	add_child(_pause_modal)

	_game_over_modal = GameOverModalRef.new()
	_game_over_modal.restart_requested.connect(func() -> void: restart_requested.emit())
	_game_over_modal.menu_requested.connect(func() -> void: menu_requested.emit())
	add_child(_game_over_modal)

	_settings_modal = SettingsModalRef.new()
	_settings_modal.closed.connect(func() -> void:
		if _pause_modal != null and _pause_modal.visible:
			_pause_modal.focus_default()
	)
	add_child(_settings_modal)


func _refresh_weapon_bar() -> void:
	if _weapon_bar != null and _gm != null:
		_weapon_bar.refresh(_gm.loadout)


func _on_wave_started(wave: int, _spec: Dictionary) -> void:
	_banner_lbl.text = "ONDA %d INICIADA!" % wave
	_banner_left = 2.2


func _on_wave_cleared(wave: int) -> void:
	_banner_lbl.text = "ONDA %d CONCLUÍDA!" % wave
	_banner_left = 2.0


func _on_countdown_updated(sec: float) -> void:
	if sec > 0.1:
		_banner_lbl.text = "PRÓXIMA ONDA EM %.1fs..." % sec
		_banner_left = 0.25


func _on_xp_changed(xp: int, next_xp: int, lvl: int) -> void:
	_xp_bar.max_value = maxf(1.0, float(next_xp))
	_xp_bar.value = float(xp)
	_xp_lbl.text = "NÍVEL %d  •  %d / %d XP" % [lvl, xp, next_xp]
func _on_score_changed(sc: int, kl: int) -> void:
	_score_lbl.text = "ABATES: %d  •  PONTOS: %d" % [kl, sc]
func _on_hp_changed(cur: float, mx: float) -> void:
	_hp_bar.max_value = maxf(1.0, mx)
	_hp_bar.value = cur
	_hp_lbl.text = "HP %d / %d" % [roundi(cur), roundi(mx)]
func _on_player_damaged(_amt: float, _kb: Vector3) -> void:
	_vig_left = 0.28
func _on_dash_changed(chg: int, mx: int, prog: float) -> void:
	_dash_lbl.text = "DASH [Q]: %d/%d" % [chg, mx]
	_dash_bar.value = prog
func _on_hit_confirmed(is_crit: bool, _is_kill: bool) -> void:
	if _crosshair != null:
		_crosshair.trigger_hitmarker(is_crit)
func _on_view_mode_changed(is_fps: bool, doom_centered: bool) -> void:
	if _crosshair != null:
		_crosshair.set_view_mode(is_fps, doom_centered)
func _on_upgrade_modal_opened(choices: Array) -> void:
	_upgrade_modal.show_choices(choices)

func _on_state_changed(new_state: int) -> void:
	if new_state != GameManagerRef.State.UPGRADE_MODAL:
		_upgrade_modal.hide_modal()
	if new_state == GameManagerRef.State.PAUSED and _gm != null:
		_game_over_modal.hide_modal()
		var upgs: Dictionary = _gm.upgrades.get_all_stacks() if _gm.upgrades != null else {}
		_pause_modal.show_pause(_gm.current_wave, _gm.kills, _gm.score, upgs)
	elif new_state == GameManagerRef.State.GAME_OVER and _gm != null:
		_pause_modal.hide_modal()
		if _settings_modal != null:
			_settings_modal.visible = false
		_game_over_modal.show_summary(_gm.get_run_summary())
	else:
		_pause_modal.hide_modal()
		_game_over_modal.hide_modal()
		if _settings_modal != null:
			_settings_modal.visible = false

func _make_bar(min_sz: Vector2, max_v: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = min_sz
	b.max_value = max_v
	b.show_percentage = false
	return b

func _make_label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.90))
	l.add_theme_constant_override("outline_size", 4)
	return l
