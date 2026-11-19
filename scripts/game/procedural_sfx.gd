class_name ProceduralSFX
extends RefCounted
## Pure GDScript AudioStreamWAV synthesizer used as zero-asset fallback for music and combat SFX.

const SR_SFX := 22050
const SR_MUSIC := 16000


static func make_punk_loop() -> AudioStreamWAV:
	# 2-bar high-energy 176 BPM punk progression (E5 -> C5 -> G5 -> D5) in ~2.727s seamless loop.
	var bpm := 176.0
	var beat_s := 60.0 / bpm
	var total_s := beat_s * 8.0
	var n := int(total_s * float(SR_MUSIC))
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var chords := [82.41, 82.41, 130.81, 130.81, 98.00, 98.00, 146.83, 146.83]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4077
	for i in range(n):
		var t := float(i) / float(SR_MUSIC)
		var beat_pos := t / beat_s
		var eighth := int(floor(beat_pos * 2.0))
		var beat_frac := fmod(beat_pos, 1.0)
		var eighth_frac := fmod(beat_pos * 2.0, 1.0)
		var chord_idx := mini(chords.size() - 1, int(floor(beat_pos)))
		var f_root: float = chords[chord_idx]
		# Palm-muted / driving power chord (root + 5th + octave saw waves clipped)
		var g_env := exp(-eighth_frac * (2.2 if eighth % 2 == 0 else 4.5))
		var g1 := 2.0 * fmod(t * f_root, 1.0) - 1.0
		var g2 := 2.0 * fmod(t * f_root * 1.498, 1.0) - 1.0
		var g3 := 2.0 * fmod(t * f_root * 2.0, 1.0) - 1.0
		var guitar := clampf((g1 + g2 * 0.8 + g3 * 0.5) * 1.6, -1.0, 1.0) * 0.28 * g_env
		var bass := sin(TAU * f_root * 0.5 * t) * 0.24
		# Kick on beats 0,2,4,6; snappy punk snare on 1,3,5,7; hihat on eighths
		var kick := 0.0
		if int(floor(beat_pos)) % 2 == 0 and beat_frac < 0.22:
			var kf := lerpf(135.0, 42.0, clampf(beat_frac * 5.0, 0.0, 1.0))
			kick = sin(TAU * kf * beat_frac * beat_s) * exp(-beat_frac * 18.0) * 0.55
		var snare := 0.0
		if int(floor(beat_pos)) % 2 == 1 and beat_frac < 0.24:
			snare = (rng.randf_range(-1.0, 1.0) * 0.65 + sin(TAU * 195.0 * t) * 0.35) * exp(-beat_frac * 20.0) * 0.45
		var hihat := rng.randf_range(-1.0, 1.0) * exp(-eighth_frac * 38.0) * 0.14
		var sample := clampf(guitar + bass + kick + snare + hihat, -0.95, 0.95)
		pcm.encode_s16(i * 2, int(sample * 32760.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR_MUSIC
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	wav.data = pcm
	return wav


static func make_sfx(sfx_id: String) -> AudioStreamWAV:
	var dur := 0.18
	match sfx_id:
		"shotgun", "rocket_launcher", "sniper":
			dur = 0.34
		"rocket_explode":
			dur = 0.58
		"droid_explode", "barrel_explode", "enemy_death":
			dur = 0.55
		"level_up", "wave_start":
			dur = 0.42
		"laser_gun", "lightsaber", "droid_tall":
			dur = 0.24
		"laser_overheat":
			dur = 0.48
		"electric_shock":
			dur = 0.32
		"droid_sawbox_hum":
			dur = 0.36
		"droid_sawbox_impact":
			dur = 0.26
		"droid_spider_cannon":
			dur = 0.22
		"droid_small":
			dur = 0.16
		"droid_hit", "enemy_hit", "smg":
			dur = 0.10
		"droid_spider_step":
			dur = 0.09
		"reload":
			dur = 0.22
		"upgrade_appear":
			dur = 0.45
		"tractor_beam":
			dur = 1.25
		"metal_click":
			dur = 0.08
	var n := maxi(64, int(dur * float(SR_SFX)))
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = sfx_id.hash()
	for i in range(n):
		var t := float(i) / float(SR_SFX)
		var u := t / dur
		var s := _sample_sfx(sfx_id, t, u, rng)
		pcm.encode_s16(i * 2, int(clampf(s, -0.95, 0.95) * 32760.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR_SFX
	wav.stereo = false
	wav.data = pcm
	return wav


static func _sample_sfx(id: String, t: float, u: float, rng: RandomNumberGenerator) -> float:
	match id:
		"pistol":
			return (rng.randf_range(-1.0, 1.0) * 0.65 + sin(TAU * lerpf(520.0, 95.0, u) * t) * 0.45) * exp(-u * 11.0)
		"smg":
			return (rng.randf_range(-1.0, 1.0) * 0.72 + sin(TAU * lerpf(680.0, 140.0, u) * t) * 0.35) * exp(-u * 13.0)
		"shotgun":
			return (rng.randf_range(-1.0, 1.0) * 0.75 + sin(TAU * lerpf(240.0, 48.0, u) * t) * 0.65) * exp(-u * 6.5)
		"sniper":
			var crack := rng.randf_range(-1.0, 1.0) * 0.85 * exp(-u * 14.0)
			var boom := sin(TAU * lerpf(320.0, 42.0, pow(u, 0.35)) * t) * 0.72 * exp(-u * 5.2)
			return crack + boom
		"laser_gun":
			var f := lerpf(1650.0, 290.0, pow(u, 0.55))
			return (sin(TAU * f * t) * 0.55 + (2.0 * fmod(t * f, 1.0) - 1.0) * 0.35) * exp(-u * 5.0)
		"rocket_launcher":
			return (rng.randf_range(-1.0, 1.0) * 0.60 + sin(TAU * lerpf(190.0, 52.0, u) * t) * 0.65) * exp(-u * 4.2)
		"katana":
			var sw := lerpf(1900.0, 460.0, u)
			return (rng.randf_range(-1.0, 1.0) * 0.55 * sin(u * PI) + sin(TAU * sw * t) * 0.35) * exp(-u * 6.0)
		"lightsaber":
			var hum := sin(TAU * 138.0 * t) * 0.4 + sin(TAU * 276.0 * t) * 0.25 + sin(TAU * lerpf(980.0, 320.0, u) * t) * 0.35
			return hum * exp(-u * 4.2)
		"droid_hit":
			return (sin(TAU * lerpf(1450.0, 620.0, u) * t) * 0.5 + rng.randf_range(-1.0, 1.0) * 0.45) * exp(-u * 14.0)
		"droid_explode":
			var boom := sin(TAU * lerpf(140.0, 32.0, pow(u, 0.4)) * t) * 0.75
			var crunch := rng.randf_range(-1.0, 1.0) * 0.65 + sin(TAU * 920.0 * t) * 0.15 * exp(-u * 9.0)
			return (boom + crunch) * exp(-u * 3.8)
		"barrel_explode":
			var sub := sin(TAU * lerpf(165.0, 28.0, pow(u, 0.35)) * t) * 0.85
			var blast := rng.randf_range(-1.0, 1.0) * 0.7
			return (sub + blast) * exp(-u * 3.2)
		"pickup":
			var pf := 587.33 if u < 0.48 else 880.0
			return sin(TAU * pf * t) * 0.55 * exp(-fmod(u, 0.5) * 6.0)
		"level_up":
			var notes := [523.25, 659.25, 783.99, 1046.5]
			var idx := mini(3, int(u * 4.0))
			return (sin(TAU * notes[idx] * t) * 0.5 + sin(TAU * notes[idx] * 2.0 * t) * 0.2) * (1.0 - u * 0.35)
		"player_hurt":
			return (sin(TAU * lerpf(220.0, 72.0, u) * t) * 0.65 + rng.randf_range(-1.0, 1.0) * 0.35) * exp(-u * 6.5)
		"wave_start":
			var siren := lerpf(320.0, 660.0, absf(sin(u * PI * 2.0)))
			return (2.0 * fmod(t * siren, 1.0) - 1.0) * 0.35 * sin(u * PI)
		"reload":
			var click := 1.0 if (u < 0.18 or (u > 0.55 and u < 0.75)) else 0.1
			return rng.randf_range(-1.0, 1.0) * click * 0.55
		"upgrade_appear":
			var arp := [523.25, 659.25, 783.99, 1046.5]
			var step := mini(3, int(u * 4.0))
			var freq: float = arp[step]
			var env := sin(minf(u * 6.0, 1.0) * PI * 0.5) * exp(-maxf(0.0, u - 0.15) * 2.8)
			return (sin(TAU * freq * t) * 0.42 + sin(TAU * freq * 1.5 * t) * 0.14) * env
		"metal_click":
			var ring := sin(TAU * 2450.0 * t) * 0.45 + sin(TAU * 3880.0 * t) * 0.30 + sin(TAU * 5240.0 * t) * 0.18
			var snap := rng.randf_range(-1.0, 1.0) * 0.35 * exp(-u * 42.0)
			return (ring * exp(-u * 26.0) + snap) * 0.75
		"rocket_explode":
			var r_sub := sin(TAU * lerpf(115.0, 24.0, pow(u, 0.32)) * t) * 0.85
			var r_punch := sin(TAU * lerpf(220.0, 55.0, u) * t) * 0.45 * exp(-u * 9.0)
			var r_shrap := rng.randf_range(-1.0, 1.0) * 0.70 * exp(-u * 3.6)
			return r_sub * exp(-u * 3.0) + r_punch + r_shrap
		"laser_overheat":
			var whine := sin(TAU * lerpf(1400.0, 260.0, pow(u, 0.65)) * t) * 0.45 * exp(-u * 4.5)
			var vent := rng.randf_range(-1.0, 1.0) * 0.65 * sin(u * PI) * exp(-maxf(0.0, u - 0.3) * 3.5)
			return whine + vent
		"electric_shock":
			var buzz := (2.0 * fmod(t * 120.0, 1.0) - 1.0) * 0.42 + (2.0 * fmod(t * 240.0, 1.0) - 1.0) * 0.28
			var arc := rng.randf_range(-1.0, 1.0) * (0.75 if absf(sin(TAU * 47.0 * t)) > 0.65 else 0.18)
			var zap := sin(TAU * lerpf(2800.0, 420.0, minf(1.0, u * 4.0)) * t) * 0.45 * exp(-u * 14.0)
			return (buzz * sin(u * PI) + arc * exp(-u * 2.5) + zap) * 0.85
		"droid_small":
			var chirp := sin(TAU * lerpf(920.0, 1380.0, u) * t) * 0.48
			var mod_s := 0.55 + 0.45 * sin(TAU * 42.0 * t)
			return (chirp * mod_s + rng.randf_range(-1.0, 1.0) * 0.15 * exp(-u * 18.0)) * exp(-u * 7.5)
		"droid_tall":
			var growl := (2.0 * fmod(t * lerpf(185.0, 110.0, u), 1.0) - 1.0) * 0.45
			var res := sin(TAU * 540.0 * t) * 0.25 * exp(-u * 8.0)
			return (growl + res) * sin(u * PI) * 0.85
		"droid_spider_cannon":
			var thump := sin(TAU * lerpf(320.0, 85.0, pow(u, 0.45)) * t) * 0.60 * exp(-u * 8.0)
			var p_f := lerpf(1350.0, 380.0, u)
			var plasma := (2.0 * fmod(t * p_f, 1.0) - 1.0) * 0.42 * exp(-u * 5.5)
			return thump + plasma
		"droid_spider_step":
			var clack := (sin(TAU * 1850.0 * t) * 0.45 + sin(TAU * 3100.0 * t) * 0.30) * exp(-u * 24.0)
			var tap := rng.randf_range(-1.0, 1.0) * 0.40 * exp(-u * 28.0)
			return clack + tap
		"droid_sawbox_hum":
			var saw_f := 145.0
			var teeth := 0.65 + 0.35 * sin(TAU * 28.0 * t)
			var blade := ((2.0 * fmod(t * saw_f, 1.0) - 1.0) * 0.45 + (2.0 * fmod(t * saw_f * 2.0, 1.0) - 1.0) * 0.28) * teeth
			var air := rng.randf_range(-1.0, 1.0) * 0.18
			return (blade + air) * sin(u * PI) * 0.85
		"droid_sawbox_impact":
			var grind := (sin(TAU * 780.0 * t) * 0.35 + sin(TAU * 1210.0 * t) * 0.30 + sin(TAU * 2150.0 * t) * 0.22) * exp(-u * 6.5)
			var sparks := rng.randf_range(-1.0, 1.0) * 0.65 * exp(-u * 7.5)
			return grind + sparks
		"enemy_hit":
			return (sin(TAU * lerpf(1280.0, 520.0, u) * t) * 0.55 + rng.randf_range(-1.0, 1.0) * 0.45) * exp(-u * 15.0)
		"enemy_death":
			var pdown := sin(TAU * lerpf(620.0, 55.0, pow(u, 0.6)) * t) * 0.45 * exp(-u * 3.5)
			var e_boom := sin(TAU * lerpf(150.0, 30.0, pow(u, 0.4)) * t) * 0.70 * exp(-u * 3.8)
			var debris := rng.randf_range(-1.0, 1.0) * 0.55 * exp(-u * 4.5)
			return pdown + e_boom + debris
		"tractor_beam":
			var env := sin(u * PI)
			var shimmer := 0.5 + 0.5 * sin(TAU * 14.0 * t)
			var f1 := lerpf(320.0, 980.0, pow(u, 0.75))
			var bell := sin(TAU * f1 * t) * 0.34 + sin(TAU * f1 * 1.5 * t) * 0.24 + sin(TAU * f1 * 2.02 * t) * 0.16 * shimmer
			var air := rng.randf_range(-1.0, 1.0) * 0.12 * shimmer
			return (bell + air) * env * 0.90
	return sin(TAU * 440.0 * t) * exp(-u * 8.0) * 0.4
