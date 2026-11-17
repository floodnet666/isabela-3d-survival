class_name ArenaCoordinator
extends Node3D
## Root controller for playable_arena.tscn: wires GameManager, Player, WaveSpawner, HUD, SM_Ship orbit, and water ripples.

const InputSetupRef := preload("res://scripts/game/input_setup.gd")
const GameManagerRef := preload("res://scripts/game/game_manager.gd")
const PlayerControllerRef := preload("res://scripts/game/player_controller.gd")
const WaveSpawnerRef := preload("res://scripts/game/wave_spawner.gd")
const HUDControllerRef := preload("res://scripts/game/hud_controller.gd")
const AudioManagerRef := preload("res://scripts/game/audio_manager.gd")
const ArenaPropsRef := preload("res://scripts/game/arena_props.gd")
const SettingsManagerRef := preload("res://scripts/game/settings_manager.gd")
const WeaponVFXRef := preload("res://scripts/game/weapon_vfx.gd")
const DestructionVFXRef := preload("res://scripts/game/droid_destruction_vfx.gd")

@export var droid_small_scene: PackedScene
@export var droid_tall_scene: PackedScene

var game_manager: GameManagerRef
var player: PlayerControllerRef
var wave_spawner: WaveSpawnerRef
var hud: HUDControllerRef

var _ship: Node3D
var _water_mat: ShaderMaterial
var _audio: AudioManagerRef
var _arena_props: ArenaPropsRef
var _capture_mouse: bool = true
var _bootstrapped: bool = false
var _ripple_accum: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	InputSetupRef.ensure_default_actions()
	if not _bootstrapped and get_node_or_null("GameManager") != null:
		_bootstrapped = true
		_bind_scene_nodes()
		_start_game()


func set_interactive_mouse_capture(enabled: bool) -> void:
	_capture_mouse = enabled


func bootstrap_headless_arena() -> void:
	if _bootstrapped:
		return
	_bootstrapped = true
	InputSetupRef.ensure_default_actions()
	_ensure_minimal_arena_nodes()
	_bind_scene_nodes()
	_start_game(false)


func _process(delta: float) -> void:
	if game_manager != null:
		game_manager.tick(delta)
	if _ship != null and game_manager != null:
		var yaw_deg := float(game_manager.balance_db.get_arena_cfg().get("ship_orbit_yaw_deg_per_sec", 2.5))
		_ship.rotate_y(deg_to_rad(yaw_deg) * delta)
	_update_dynamic_water_ripples(delta)


func _bind_scene_nodes() -> void:
	game_manager = get_node("GameManager") as GameManagerRef
	player = get_node("Player") as PlayerControllerRef
	wave_spawner = get_node("WaveSpawner") as WaveSpawnerRef
	hud = get_node("HUD") as HUDControllerRef
	_ship = get_node_or_null("SM_Ship") as Node3D
	if _ship != null:
		for m in _ship.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	WeaponVFXRef.warmup(self); DestructionVFXRef.warmup(self)
	add_child(preload("res://scripts/game/day_night_cycle.gd").new())

	var water := get_node_or_null("WaterPlane") as MeshInstance3D
	if water != null and water.get_active_material(0) is ShaderMaterial:
		var dup := (water.get_active_material(0) as ShaderMaterial).duplicate() as ShaderMaterial
		water.set_surface_override_material(0, dup)
		_water_mat = dup

	game_manager.initialize("res://data/game_balance.json")
	player.configure(game_manager.balance_db, game_manager.upgrades, game_manager.loadout)
	var entities := get_node_or_null("Entities") as Node3D
	if entities == null:
		entities = Node3D.new()
		entities.name = "Entities"
		add_child(entities)
	if droid_small_scene != null:
		wave_spawner.droid_small_scene = droid_small_scene
	if droid_tall_scene != null:
		wave_spawner.droid_tall_scene = droid_tall_scene
	_setup_audio_and_props()
	wave_spawner.setup(game_manager.balance_db, entities, player, _ship, _arena_props)
	hud.bind(game_manager, player)

	if not game_manager.wave_started.is_connected(_on_wave_started):
		game_manager.wave_started.connect(_on_wave_started)
	if not game_manager.upgrade_modal_opened.is_connected(_on_upgrade_modal_opened):
		game_manager.upgrade_modal_opened.connect(_on_upgrade_modal_opened)
	if not game_manager.upgrade_applied.is_connected(player.apply_upgrade_result):
		game_manager.upgrade_applied.connect(player.apply_upgrade_result)
	if not game_manager.lifesteal_triggered.is_connected(player.heal):
		game_manager.lifesteal_triggered.connect(player.heal)
	if not game_manager.state_changed.is_connected(_on_state_changed):
		game_manager.state_changed.connect(_on_state_changed)
	if not player.died.is_connected(game_manager.trigger_game_over):
		player.died.connect(game_manager.trigger_game_over)
	if not player.damaged.is_connected(_on_player_hurt):
		player.damaged.connect(_on_player_hurt)
	if not player.hit_confirmed.is_connected(_on_player_hit):
		player.hit_confirmed.connect(_on_player_hit)
	if not player.water_ripple_emitted.is_connected(_on_water_ripple):
		player.water_ripple_emitted.connect(_on_water_ripple)
	var wm := player.get_node_or_null("WeaponManager")
	if wm != null and wm.has_signal("shot_executed") and not wm.is_connected("shot_executed", _on_weapon_shot):
		wm.connect("shot_executed", _on_weapon_shot)
	if not wave_spawner.enemy_spawned.is_connected(_on_enemy_spawned):
		wave_spawner.enemy_spawned.connect(_on_enemy_spawned)
	if not wave_spawner.crate_spawned.is_connected(_on_crate_spawned):
		wave_spawner.crate_spawned.connect(_on_crate_spawned)
	if wave_spawner.has_signal("boss_spawned") and not wave_spawner.is_connected("boss_spawned", _on_boss_spawned):
		wave_spawner.connect("boss_spawned", _on_boss_spawned)
	if wave_spawner.has_signal("pod_destroyed_bonus") and not wave_spawner.is_connected("pod_destroyed_bonus", game_manager.add_xp):
		wave_spawner.connect("pod_destroyed_bonus", game_manager.add_xp)
	if not hud.restart_requested.is_connected(_on_restart):
		hud.restart_requested.connect(_on_restart)
	if hud.has_signal("menu_requested") and not hud.is_connected("menu_requested", _on_return_to_menu):
		hud.connect("menu_requested", _on_return_to_menu)


func _start_game(manage_pause: bool = true) -> void:
	game_manager.start_run(manage_pause)
	SettingsManagerRef.apply_all(get_tree() if is_inside_tree() else null)
	if bool(SettingsManagerRef.get_val("default_fps_mode")) and player != null and player.has_method("is_fps_mode") and not player.is_fps_mode():
		if player.has_method("toggle_view_mode"):
			player.call("toggle_view_mode")
	if _audio != null:
		_audio.start_music()
	_update_mouse_mode(game_manager.state)


func _on_wave_started(_wave: int, spec: Dictionary) -> void:
	wave_spawner.queue_wave(spec)
	wave_spawner.spawn_ambient_wave_crate()
	if _audio != null:
		_audio.play_sfx("wave_start")


func _on_enemy_spawned(enemy: Node3D) -> void:
	if enemy.has_signal("died"):
		enemy.connect("died", _on_enemy_died)
	if enemy.has_signal("took_damage"):
		enemy.connect("took_damage", func(dmg: float, _crit: bool) -> void:
			if game_manager != null:
				game_manager.record_damage(str(enemy.get("last_weapon_id")), dmg)
		)


func _on_enemy_died(_e: Node3D, enemy_id: String, xp: int, sc: int, drop_chance: float, pos: Vector3) -> void:
	var hp_ratio := player.current_hp / maxf(1.0, player.max_hp)
	var avg_ammo := _compute_avg_ammo_ratio()
	wave_spawner.maybe_drop_crate_at(pos, drop_chance, hp_ratio, avg_ammo)
	game_manager.notify_enemy_killed(enemy_id, xp, sc)
	if _audio != null:
		_audio.play_sfx("droid_explode")


func _setup_audio_and_props() -> void:
	_audio = get_node_or_null("AudioManager") as AudioManagerRef
	if _audio == null:
		_audio = AudioManagerRef.new()
		_audio.name = "AudioManager"
		add_child(_audio)
	_arena_props = get_node_or_null("ArenaProps") as ArenaPropsRef
	if _arena_props == null:
		_arena_props = ArenaPropsRef.new()
		_arena_props.name = "ArenaProps"
		add_child(_arena_props)
	_arena_props.build_arena_props()
	var perim := preload("res://scripts/game/arena_electric_perimeter.gd").new()
	add_child(perim)
	perim.setup(game_manager, player, _audio)
	add_child(preload("res://scripts/game/arena_elevators.gd").new())
	for barrel in _arena_props.get_barrels():
		if is_instance_valid(barrel) and not barrel.exploded.is_connected(_on_barrel_exploded):
			barrel.exploded.connect(_on_barrel_exploded)


func _on_weapon_shot(weapon_id: String) -> void:
	if _audio != null: _audio.play_weapon_shot(weapon_id)

func _on_player_hit(_c: bool, _k: bool) -> void:
	if _audio != null: _audio.play_sfx("droid_hit", 0.12, -5.0)

func _on_player_hurt(_a: float, _kb: Vector3) -> void:
	if _audio != null: _audio.play_sfx("player_hurt")

func _on_upgrade_modal_opened(_c: Array) -> void:
	if _audio != null: _audio.play_sfx("level_up", 0.02, -2.0)

func _on_barrel_exploded(_p: Vector3, _r: float) -> void:
	if _audio != null: _audio.play_sfx("barrel_explode", 0.08, -1.0)


func _on_boss_spawned(boss: Node3D, wave: int, dname: String) -> void:
	preload("res://scripts/game/boss_visuals_helper.gd").bind_boss_to_arena(boss, wave, dname, wave_spawner, game_manager, hud)


func _on_crate_spawned(crate: Node3D) -> void:
	if crate != null and crate.has_signal("collected"):
		crate.connect("collected", func(_id: String, _c: Node3D) -> void:
			if _audio != null:
				_audio.play_sfx("pickup", 0.05, -2.5)
		)


func _compute_avg_ammo_ratio() -> float:
	if game_manager == null or game_manager.loadout == null:
		return 1.0
	var total := 0.0
	var count := 0
	for slot in [1, 3, 4, 6]:
		var st := game_manager.loadout.get_slot_hud_state(slot)
		var at := str(st.get("ammo_type", ""))
		if at == "magazine":
			total += float(st.get("reserve", 0)) / maxf(1.0, float(st.get("reserve_max", 1)))
			count += 1
		elif at == "battery":
			total += float(st.get("battery", 0.0)) / maxf(1.0, float(st.get("battery_max", 100.0)))
			count += 1
	return total / maxf(1.0, float(count))


func _on_water_ripple(world_pos: Vector3, _strength: float) -> void:
	if _water_mat == null:
		return
	_water_mat.set_shader_parameter("ripple_center_0", Vector2(world_pos.x, world_pos.z))


func _update_dynamic_water_ripples(delta: float) -> void:
	if _water_mat == null or player == null or not is_inside_tree():
		return
	var p := player.global_position
	_water_mat.set_shader_parameter("ripple_center_0", Vector2(p.x, p.z))
	_ripple_accum += delta
	if _ripple_accum < 0.08:
		return
	_ripple_accum = 0.0
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Array[Dictionary] = []
	for e in enemies:
		if e is Node3D and is_instance_valid(e):
			var ep := (e as Node3D).global_position
			nearest.append({"d": p.distance_squared_to(ep), "xz": Vector2(ep.x, ep.z)})
	nearest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["d"]) < float(b["d"]))
	for slot_idx in range(3):
		var uname := "ripple_center_%d" % (slot_idx + 1)
		if slot_idx < nearest.size():
			_water_mat.set_shader_parameter(uname, nearest[slot_idx]["xz"])
		else:
			_water_mat.set_shader_parameter(uname, Vector2(999.0, 999.0))


func _on_state_changed(new_state: int) -> void:
	if _audio != null:
		_audio.set_paused_ducking(new_state != GameManagerRef.State.PLAYING)
	_update_mouse_mode(new_state)


func _update_mouse_mode(st: int) -> void:
	if not _capture_mouse or DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if st == GameManagerRef.State.PLAYING else Input.MOUSE_MODE_VISIBLE


func _on_restart() -> void:
	if is_inside_tree():
		get_tree().paused = false
		get_tree().reload_current_scene()


func _on_return_to_menu() -> void:
	if is_inside_tree():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/game/main_menu.tscn")


func _ensure_minimal_arena_nodes() -> void:
	for spec in [["GameManager", GameManagerRef], ["Player", PlayerControllerRef], ["WaveSpawner", WaveSpawnerRef], ["HUD", HUDControllerRef]]:
		if get_node_or_null(str(spec[0])) == null:
			var n: Node = (spec[1] as GDScript).new()
			n.name = str(spec[0])
			add_child(n)
	if get_node_or_null("Entities") == null:
		var ent := Node3D.new()
		ent.name = "Entities"
		add_child(ent)
