class_name GameManager
extends Node
## Coordinates game state, wave lifecycle, XP/level progression, and Upgrade Modal queueing.

const BalanceDBRef := preload("res://scripts/game/balance_db.gd")
const UpgradeSystemRef := preload("res://scripts/game/upgrade_system.gd")
const WeaponLoadoutRef := preload("res://scripts/game/weapon_loadout.gd")

enum State { PLAYING, UPGRADE_MODAL, PAUSED, GAME_OVER }

signal state_changed(new_state: int)
signal wave_started(wave_number: int, wave_spec: Dictionary)
signal wave_cleared(wave_number: int)
signal upgrade_modal_opened(choices: Array)
signal upgrade_applied(result: Dictionary)
signal xp_changed(current_xp: int, xp_to_next: int, level: int)
signal score_changed(score: int, kills: int)
signal lifesteal_triggered(heal_amount: float)
signal countdown_updated(seconds_left: float)

var balance_db: BalanceDBRef = BalanceDBRef.new()
var upgrades: UpgradeSystemRef
var loadout: WeaponLoadoutRef

var state: State = State.PLAYING
var current_wave: int = 0
var enemies_remaining_in_wave: int = 0
var level: int = 1
var current_xp: int = 0
var xp_to_next: int = 80
var score: int = 0
var kills: int = 0
var elapsed_time_s: float = 0.0
var total_damage_dealt: float = 0.0
var damage_dealt_by_weapon: Dictionary = {}
var kills_by_type: Dictionary = {}
var pending_upgrade_drafts: int = 0
var current_choices: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _inter_wave_timer_s: float = 0.0
var _waiting_next_wave: bool = false
var _manage_scene_pause: bool = true
var _pending_legendary_drafts: int = 0


func initialize(balance_path: String = "res://data/game_balance.json", rng_seed: int = 0) -> bool:
	if not balance_db.load_from_file(balance_path):
		return false
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	upgrades = UpgradeSystemRef.new(balance_db)
	loadout = WeaponLoadoutRef.new(balance_db, upgrades)
	xp_to_next = balance_db.get_xp_for_next_level(1)
	return true


func start_run(manage_scene_pause: bool = true) -> void:
	_manage_scene_pause = manage_scene_pause
	if not balance_db.is_loaded():
		initialize()
	if upgrades == null:
		upgrades = UpgradeSystemRef.new(balance_db)
	else:
		upgrades.set_balance_db(balance_db)
		upgrades.reset()
	if loadout == null:
		loadout = WeaponLoadoutRef.new(balance_db, upgrades)
	else:
		loadout.setup(balance_db, upgrades)
	current_wave = 0
	enemies_remaining_in_wave = 0
	level = 1
	current_xp = 0
	xp_to_next = balance_db.get_xp_for_next_level(1)
	score = 0
	kills = 0
	elapsed_time_s = 0.0
	total_damage_dealt = 0.0
	damage_dealt_by_weapon.clear()
	kills_by_type.clear()
	pending_upgrade_drafts = 0
	_pending_legendary_drafts = 0
	current_choices.clear()
	_waiting_next_wave = false
	_set_state(State.PLAYING)
	xp_changed.emit(current_xp, xp_to_next, level)
	score_changed.emit(score, kills)
	_begin_next_wave()


func tick(delta: float) -> void:
	if state != State.PLAYING:
		return
	elapsed_time_s += delta
	if _waiting_next_wave:
		_inter_wave_timer_s = maxf(0.0, _inter_wave_timer_s - delta)
		countdown_updated.emit(_inter_wave_timer_s)
		if _inter_wave_timer_s <= 0.0:
			_waiting_next_wave = false
			_begin_next_wave()


func notify_enemy_killed(_enemy_id: String, xp_reward: int, score_reward: int) -> void:
	if state == State.GAME_OVER:
		return
	kills += 1
	var ekey := _enemy_id if not _enemy_id.is_empty() else "droid_small"
	kills_by_type[ekey] = int(kills_by_type.get(ekey, 0)) + 1
	score += score_reward
	score_changed.emit(score, kills)

	var heal_kill := upgrades.get_stat("heal_on_kill")
	if heal_kill > 0.0:
		lifesteal_triggered.emit(heal_kill)

	if enemies_remaining_in_wave > 0:
		enemies_remaining_in_wave -= 1

	var is_wave_done := enemies_remaining_in_wave <= 0 and not _waiting_next_wave
	if is_wave_done:
		var spec := balance_db.get_wave_spec(current_wave)
		var guarantee := bool(balance_db.get_waves_cfg().get("guarantee_upgrade_choice_on_wave_clear", true))
		wave_cleared.emit(current_wave)
		add_xp(xp_reward + int(spec.get("clear_xp_bonus", 25)))
		if guarantee and pending_upgrade_drafts <= 0 and state != State.UPGRADE_MODAL:
			pending_upgrade_drafts += 1
			_open_next_upgrade_modal()
		_waiting_next_wave = true
		_inter_wave_timer_s = float(spec.get("inter_wave_countdown_s", 2.5))
	else:
		add_xp(xp_reward)


func add_xp(amount: int) -> void:
	if amount <= 0 or state == State.GAME_OVER:
		return
	current_xp += amount
	while current_xp >= xp_to_next:
		current_xp -= xp_to_next
		level += 1
		xp_to_next = balance_db.get_xp_for_next_level(level)
		pending_upgrade_drafts += 1
	xp_changed.emit(current_xp, xp_to_next, level)
	if pending_upgrade_drafts > 0 and state != State.UPGRADE_MODAL:
		_open_next_upgrade_modal()


func choose_upgrade(index: int) -> bool:
	if state != State.UPGRADE_MODAL or index < 0 or index >= current_choices.size():
		return false
	var chosen := current_choices[index]
	var res := upgrades.apply_upgrade(chosen)
	if float(res.get("ammo_refill_ratio", 0.0)) > 0.0:
		loadout.refill_ammo_percent(float(res["ammo_refill_ratio"]), 0.5)
	upgrade_applied.emit(res)

	pending_upgrade_drafts = maxi(0, pending_upgrade_drafts - 1)
	if pending_upgrade_drafts > 0:
		_open_next_upgrade_modal()
	else:
		current_choices.clear()
		_set_state(State.PLAYING)
	return true


func toggle_pause() -> void:
	if state == State.PLAYING:
		_set_state(State.PAUSED)
	elif state == State.PAUSED:
		_set_state(State.PLAYING)


func trigger_game_over() -> void:
	_set_state(State.GAME_OVER)


func record_damage(weapon_id: String, amount: float) -> void:
	if amount <= 0.0 or state == State.GAME_OVER:
		return
	total_damage_dealt += amount
	var wid := weapon_id if not weapon_id.is_empty() else "other"
	damage_dealt_by_weapon[wid] = float(damage_dealt_by_weapon.get(wid, 0.0)) + amount


func get_run_summary() -> Dictionary:
	var fav_weapon := "—"
	var best_dmg := -1.0
	for wid in damage_dealt_by_weapon.keys():
		var d := float(damage_dealt_by_weapon[wid])
		if d > best_dmg:
			best_dmg = d
			fav_weapon = str(wid)
	return {
		"wave": current_wave,
		"level": level,
		"elapsed_s": elapsed_time_s,
		"kills": kills,
		"kills_small": int(kills_by_type.get("droid_small", 0)),
		"kills_tall": int(kills_by_type.get("droid_tall", 0)),
		"score": score,
		"total_damage": total_damage_dealt,
		"favorite_weapon": fav_weapon,
		"favorite_weapon_dmg": maxf(0.0, best_dmg),
		"upgrades": upgrades.get_all_stacks() if upgrades != null else {},
	}


func _begin_next_wave() -> void:
	current_wave += 1
	var spec := balance_db.get_wave_spec(current_wave)
	enemies_remaining_in_wave = int(spec["total_enemies"])
	wave_started.emit(current_wave, spec)


func grant_boss_legendary_draft() -> void:
	if state == State.GAME_OVER:
		return
	_pending_legendary_drafts += 1
	pending_upgrade_drafts += 1
	if state != State.UPGRADE_MODAL:
		_open_next_upgrade_modal()


func _open_next_upgrade_modal() -> void:
	var min_rar := ""
	if _pending_legendary_drafts > 0:
		_pending_legendary_drafts -= 1
		min_rar = "legendary"
	current_choices = upgrades.roll_choices(maxi(1, current_wave), _rng, min_rar)
	if current_choices.is_empty():
		pending_upgrade_drafts = 0
		_set_state(State.PLAYING)
		return
	_set_state(State.UPGRADE_MODAL)
	upgrade_modal_opened.emit(current_choices)


func _set_state(next_state: State) -> void:
	state = next_state
	if _manage_scene_pause and is_inside_tree():
		get_tree().paused = state != State.PLAYING
	state_changed.emit(int(state))
