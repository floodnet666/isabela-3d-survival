extends SceneTree

func _assert(cond: bool, label: String) -> bool:
	if not cond:
		push_error("FAIL: " + label)
	return cond


func _init() -> void:
	var ok := true
	var root_n := Node3D.new()
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	we.environment = env
	var sun := DirectionalLight3D.new()
	root_n.add_child(we)
	root_n.add_child(sun)

	var dnc_script := load("res://scripts/game/day_night_cycle.gd") as GDScript
	var dnc: Node = dnc_script.new()
	root_n.add_child(dnc)
	get_root().add_child(root_n)
	await process_frame

	dnc.set_time_hours(10.0)
	dnc._process(60.0)
	ok = _assert(absf(float(dnc.time_of_day_hours) - 12.0) < 0.01, "60s real-time advances 2.0 game hours (10:00 -> 12:00)") and ok
	ok = _assert(dnc.get_phase_name() == "DIA", "12:00 is DIA") and ok
	ok = _assert(dnc.get_time_string() == "12:00", "Time string formats 12:00") and ok
	var day_energy := sun.light_energy

	dnc.set_time_hours(18.0)
	dnc._process(0.01)
	ok = _assert(dnc.get_phase_name() == "ENTARDECER", "18:00 is ENTARDECER") and ok

	dnc.set_time_hours(0.0)
	dnc._process(0.01)
	ok = _assert(dnc.get_phase_name() == "NOITE", "00:00 is NOITE") and ok
	ok = _assert(sun.light_energy < day_energy * 0.5, "Night light energy lower than day") and ok

	dnc.set_time_hours(23.0)
	dnc._process(60.0)
	ok = _assert(absf(float(dnc.time_of_day_hours) - 1.0) < 0.01, "23:00 + 60s wraps to 01:00") and ok

	root_n.queue_free()
	print("ALL_TESTS_PASSED: test_day_night_cycle" if ok else "TEST_FAILED: test_day_night_cycle")
	quit(0 if ok else 1)
