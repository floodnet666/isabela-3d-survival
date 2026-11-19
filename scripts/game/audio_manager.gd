class_name AudioManager
extends Node
## Hybrid music and combat SFX manager (prefers external .ogg/.wav in assets/audio/, falls back to ProceduralSFX).

const ProceduralSFXRef := preload("res://scripts/game/procedural_sfx.gd")

const MUSIC_CANDIDATES := [
	"res://assets/audio/music/punk_rock_loop.ogg",
	"res://assets/audio/music/punk_rock_loop.wav",
]
const SFX_POOL_SIZE := 16
const MUSIC_LIVE_DB := -7.5
const MUSIC_PAUSED_DB := -17.5

var played_events_count: int = 0

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
var _streams: Dictionary = {}
var _music_stream: AudioStream
var _rng := RandomNumberGenerator.new()
var _user_music_ratio: float = 0.70
var _user_sfx_ratio: float = 0.85
var _is_paused_duck: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("audio_manager")
	_rng.randomize()
	_ensure_buses()
	_build_players()
	_preload_default_streams()


func has_music_stream() -> bool:
	return _music_stream != null


func start_music() -> void:
	if _music_stream == null or _music_player == null:
		return
	if DisplayServer.get_name() == "headless":
		return
	if _music_player.stream != _music_stream:
		_music_player.stream = _music_stream
	if not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()


func set_paused_ducking(paused: bool) -> void:
	_is_paused_duck = paused
	_sync_music_bus_volume()


func apply_user_volumes(music_ratio: float, sfx_ratio: float) -> void:
	_user_music_ratio = clampf(music_ratio, 0.0, 1.0)
	_user_sfx_ratio = clampf(sfx_ratio, 0.0, 1.0)
	_sync_music_bus_volume()
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		if _user_sfx_ratio <= 0.005:
			AudioServer.set_bus_mute(sfx_idx, true)
			AudioServer.set_bus_volume_db(sfx_idx, -80.0)
		else:
			AudioServer.set_bus_mute(sfx_idx, false)
			AudioServer.set_bus_volume_db(sfx_idx, -1.5 + linear_to_db(_user_sfx_ratio))


func _sync_music_bus_volume() -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		return
	var base := MUSIC_PAUSED_DB if _is_paused_duck else MUSIC_LIVE_DB
	if _user_music_ratio <= 0.005:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, base + linear_to_db(_user_music_ratio))


func play_weapon_shot(weapon_id: String) -> void:
	var vol := -3.5
	var jitter := 0.07
	match weapon_id:
		"smg":
			vol = -5.5
			jitter = 0.09
		"shotgun", "rocket_launcher", "sniper":
			vol = -2.0
			jitter = 0.05
		"laser_gun":
			vol = -3.0
			jitter = 0.04
		"lightsaber", "katana":
			vol = -2.5
			jitter = 0.06
	play_sfx(weapon_id, jitter, vol)


func play_sfx(sfx_id: String, pitch_jitter: float = 0.08, volume_db: float = -3.0) -> void:
	played_events_count += 1
	if DisplayServer.get_name() == "headless":
		return
	var stream := _resolve_sfx_stream(sfx_id)
	if stream == null or _sfx_pool.is_empty():
		return
	var player := _sfx_pool[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_pool.size()
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	player.play()


func _ensure_buses() -> void:
	_ensure_bus("Music", MUSIC_LIVE_DB)
	_ensure_bus("SFX", -1.5)


func _ensure_bus(bus_name: String, default_db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, &"Master")
	AudioServer.set_bus_volume_db(idx, default_db)


func _build_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = &"Music"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)

	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SFX_%d" % i
		p.bus = &"SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_pool.append(p)


func _preload_default_streams() -> void:
	for cand in MUSIC_CANDIDATES:
		if ResourceLoader.exists(cand):
			var loaded := load(cand) as AudioStream
			if loaded != null:
				if loaded is AudioStreamOggVorbis:
					(loaded as AudioStreamOggVorbis).loop = true
				elif loaded is AudioStreamWAV:
					(loaded as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
				_music_stream = loaded
				break
	if _music_stream == null:
		_music_stream = ProceduralSFXRef.make_punk_loop()

	for sfx_id in [
		"pistol", "smg", "shotgun", "laser_gun", "laser_overheat",
		"rocket_launcher", "rocket_explode", "katana", "sniper", "lightsaber", "reload",
		"droid_small", "droid_tall", "droid_spider_cannon", "droid_spider_step",
		"droid_sawbox_hum", "droid_sawbox_impact", "enemy_hit", "enemy_death",
		"droid_hit", "droid_explode", "barrel_explode", "electric_shock",
		"pickup", "level_up", "player_hurt", "wave_start",
		"upgrade_appear", "metal_click", "tractor_beam",
	]:
		_resolve_sfx_stream(sfx_id)


func _resolve_sfx_stream(sfx_id: String) -> AudioStream:
	if _streams.has(sfx_id):
		return _streams[sfx_id] as AudioStream
	for ext in [".ogg", ".wav"]:
		var path := "res://assets/audio/sfx/%s%s" % [sfx_id, ext]
		if ResourceLoader.exists(path):
			var s := load(path) as AudioStream
			if s != null:
				_streams[sfx_id] = s
				return s
	var synth := ProceduralSFXRef.make_sfx(sfx_id)
	_streams[sfx_id] = synth
	return synth
