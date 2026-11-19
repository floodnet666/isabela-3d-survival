class_name BiomeManager
extends Node
## Manages random non-repeating multi-biome progression every X waves with SM_Ship tractor-beam relocation and physics-safe prop toggling.

const BiomeBuilderRef := preload("res://scripts/game/biome_arena_builder.gd")
const TractorCutsceneRef := preload("res://scripts/game/ship_tractor_cutscene.gd")

signal biome_changed(biome_id: String, display_name: String)

var current_biome_id: String = ""
var run_seed: int = 0

var _arena: Node3D
var _gm: Node
var _spawner: Node
var _player: Node3D
var _ship: Node3D
var _ship_home_pos: Vector3 = Vector3(6.0, 22.0, -58.0)
var _audio: Node
var _day_night: Node
var _builder: BiomeBuilderRef
var _cutscene: TractorCutsceneRef
var _sequence: Array[String] = []
var _last_slot_idx: int = -1


func _ready() -> void:
	name = "BiomeManager"
	_builder = BiomeBuilderRef.new()
	_builder.name = "BiomeArenaBuilder"
	add_child(_builder)
	_cutscene = TractorCutsceneRef.new()
	_cutscene.name = "ShipTractorCutscene"
	add_child(_cutscene)
	call_deferred("_auto_bind_parent")


func _auto_bind_parent() -> void:
	var p := get_parent() as Node3D
	if p == null or not ("game_manager" in p):
		return
	bind_arena(
		p,
		p.get("game_manager"),
		p.get("wave_spawner"),
		p.get("player"),
		p.get_node_or_null("SM_Ship") as Node3D,
		p.get("_audio"),
		p.find_child("DayNightCycle", true, false)
	)


func bind_arena(arena: Node3D, gm: Node, spawner: Node, player: Node3D, ship: Node3D, audio: Node, day_night: Node) -> void:
	_arena = arena
	_gm = gm
	_spawner = spawner
	_player = player
	_ship = ship
	if _ship != null:
		_ship_home_pos = _ship.position
	_audio = audio
	_day_night = day_night
	run_seed = int(Time.get_unix_time_from_system()) ^ randi()
	_last_slot_idx = -1
	var bcfg := _get_biomes_cfg()
	var ids: Array = (bcfg.get("types", {}) as Dictionary).keys()
	_sequence = build_random_sequence(ids, run_seed, 24)
	if _gm != null and _gm.has_signal("wave_started") and not _gm.is_connected("wave_started", _on_wave_started):
		_gm.connect("wave_started", _on_wave_started)
	_apply_biome_for_wave(1, false)


func build_random_sequence(biome_ids: Array, seed_val: int, length: int) -> Array[String]:
	var pool: Array[String] = []
	for id in biome_ids:
		pool.append(str(id))
	var out: Array[String] = []
	if pool.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var last_id := ""
	while out.size() < length:
		var bag: Array[String] = pool.duplicate()
		for i in range(bag.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: String = bag[i]
			bag[i] = bag[j]
			bag[j] = tmp
		if bag.size() > 1 and bag[0] == last_id:
			var swap_i := rng.randi_range(1, bag.size() - 1)
			var t: String = bag[0]
			bag[0] = bag[swap_i]
			bag[swap_i] = t
		for item in bag:
			if out.size() >= length:
				break
			out.append(item)
			last_id = item
	return out


func get_biome_id_for_wave(wave: int) -> String:
	var interval := maxi(1, int(_get_biomes_cfg().get("wave_interval", 5)))
	var slot := int(maxi(0, wave - 1) / interval)
	if _sequence.is_empty():
		return "desert_coast"
	return _sequence[slot % _sequence.size()]


func _on_wave_started(wave: int, _spec: Dictionary) -> void:
	_apply_biome_for_wave(wave, wave > 1)


func _apply_biome_for_wave(wave: int, use_cutscene: bool) -> void:
	var bcfg := _get_biomes_cfg()
	if bcfg.is_empty():
		return
	var interval := maxi(1, int(bcfg.get("wave_interval", 5)))
	var slot := int(maxi(0, wave - 1) / interval)
	if slot == _last_slot_idx:
		return
	_last_slot_idx = slot
	var next_id := get_biome_id_for_wave(wave)
	var types: Dictionary = bcfg.get("types", {})
	var cfg: Dictionary = types.get(next_id, {}) as Dictionary
	var title := str(cfg.get("display_name", next_id))
	var swap_fn := func() -> void:
		_swap_biome_now(next_id, cfg, bcfg, run_seed + wave * 313)
	if use_cutscene and _cutscene != null:
		_cutscene.play_relocation(_arena, _ship, _player, _audio, title, swap_fn)
	else:
		swap_fn.call()


func _swap_biome_now(biome_id: String, cfg: Dictionary, root_cfg: Dictionary, layout_seed: int) -> void:
	current_biome_id = biome_id
	var is_desert := not bool(cfg.get("use_wfc", true))
	_set_desert_nodes_visible(is_desert)
	if _ship != null:
		_ship.visible = not bool(cfg.get("hide_outer_ship", false))
		if biome_id == "sand_dunes_pyramid":
			_ship.position = Vector3(-34.0, 27.0, -76.0)
		elif biome_id == "cryo_glacier":
			_ship.position = Vector3(-38.0, 34.0, -84.0)
		elif biome_id == "volcanic_caldera":
			_ship.position = Vector3(-34.0, 42.0, -76.0)
		else:
			_ship.position = _ship_home_pos
	_builder.build_biome(biome_id, cfg, root_cfg, layout_seed)
	if _spawner != null:
		var props_node: Node = _arena.get_node_or_null("ArenaProps") if (is_desert and _arena != null) else _builder
		_spawner.set("_arena_props", props_node)
	_relocate_trapped_entities(is_desert)
	if _day_night != null:
		if _day_night.has_method("set_biome_profile"):
			_day_night.call("set_biome_profile", cfg)
		elif _day_night.has_method("set_biome_palette"):
			var sky_c := Color.html(str(cfg.get("sky_tint_hex", "#FFFFFF")))
			var fog_c := Color.html(str(cfg.get("fog_tint_hex", "#38BDF8")))
			var fog_d := float(cfg.get("fog_density", 0.0065))
			_day_night.call("set_biome_palette", sky_c, fog_c, fog_d)
	biome_changed.emit(biome_id, str(cfg.get("display_name", biome_id)))


func _relocate_trapped_entities(is_desert: bool) -> void:
	if not is_inside_tree() or _spawner == null:
		return
	var checker: Node = _arena.get_node_or_null("ArenaProps") if (is_desert and _arena != null) else _builder
	if checker == null or not checker.has_method("is_position_clear"):
		return
	var p_pos := _player.global_position if (_player != null and is_instance_valid(_player)) else Vector3.ZERO
	if _player != null and is_instance_valid(_player) and not bool(checker.call("is_position_clear", p_pos, 0.7)):
		_player.global_position = Vector3(0.0, 0.12, 0.0)
		p_pos = _player.global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node3D
		if en != null and is_instance_valid(en) and en.is_inside_tree():
			if not bool(checker.call("is_position_clear", en.global_position, 0.9)):
				en.global_position = _spawner.call("pick_ring_spawn_position", p_pos)
	var crates: Array = _spawner.get("_active_crates") if "_active_crates" in _spawner else []
	for c in crates:
		var cr := c as Node3D
		if cr != null and is_instance_valid(cr) and cr.is_inside_tree():
			if not bool(checker.call("is_position_clear", cr.global_position, 0.9)):
				cr.global_position = _spawner.call("_find_nearest_clear", cr.global_position, 0.9)


func _set_desert_nodes_visible(vis: bool) -> void:
	if _arena == null:
		return
	var water := _arena.get_node_or_null("WaterPlane") as Node3D
	if water != null:
		water.visible = vis
	var env_d := _arena.get_node_or_null("ENV_DesertCoast") as Node3D
	if env_d != null:
		for c_name in ["SM_DesertDunes", "SM_ShoreRocks"]:
			var n := env_d.get_node_or_null(c_name) as Node3D
			if n != null:
				n.visible = vis
				for cs in n.find_children("*", "CollisionShape3D", true, false):
					(cs as CollisionShape3D).disabled = not vis
	var props := _arena.get_node_or_null("ArenaProps") as Node3D
	if props != null:
		if props.has_method("set_props_active"):
			props.call("set_props_active", vis)
		else:
			props.visible = vis


func _get_biomes_cfg() -> Dictionary:
	if _gm != null and "balance_db" in _gm and _gm.balance_db != null and _gm.balance_db.has_method("get_biomes_cfg"):
		return _gm.balance_db.call("get_biomes_cfg")
	return {}
