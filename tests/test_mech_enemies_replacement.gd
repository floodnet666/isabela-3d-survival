extends SceneTree

func _assert(cond: bool, label: String) -> bool:
	if not cond:
		push_error("FAIL: " + label)
	return cond


func _init() -> void:
	var ok := true
	var db_script := load("res://scripts/game/balance_db.gd") as GDScript
	var db: RefCounted = db_script.new()
	ok = _assert(db.load_from_file(), "BalanceDB loads") and ok

	var w4: Dictionary = db.get_wave_spec(4)
	var w5: Dictionary = db.get_wave_spec(5)
	var w10: Dictionary = db.get_wave_spec(10)
	var w15: Dictionary = db.get_wave_spec(15)
	var w20: Dictionary = db.get_wave_spec(20)
	var m4: Dictionary = w4.get("mech_counts", {})
	var m5: Dictionary = w5.get("mech_counts", {})
	var m10: Dictionary = w10.get("mech_counts", {})
	var m15: Dictionary = w15.get("mech_counts", {})
	var m20: Dictionary = w20.get("mech_counts", {})

	ok = _assert(int(m4.get("mech_leela", 0)) == 0 and int(m4.get("mech_mike", 0)) == 0, "Wave 4 has no mechs") and ok
	ok = _assert(int(m5.get("mech_leela", 0)) >= 1 and int(m5.get("mech_mike", 0)) == 0, "Wave 5 introduces mech_leela only") and ok
	ok = _assert(int(m10.get("mech_mike", 0)) >= 1 and int(m10.get("mech_stan", 0)) == 0, "Wave 10 introduces mech_mike") and ok
	ok = _assert(int(m15.get("mech_stan", 0)) >= 1 and int(m15.get("mech_george", 0)) == 0, "Wave 15 introduces mech_stan") and ok
	ok = _assert(int(m20.get("mech_george", 0)) >= 1, "Wave 20 introduces mech_george") and ok
	ok = _assert(int(w20.get("spider_count", 0)) == 0 and int(w20.get("sawbox_count", 0)) == 0, "Procedural spider/sawbox removed from waves") and ok

	var player_stub := Node3D.new()
	get_root().add_child(player_stub)
	for id in ["mech_leela", "mech_mike", "mech_stan", "mech_george"]:
		var cfg: Dictionary = db.get_enemy_cfg(id)
		ok = _assert(not cfg.is_empty(), id + " exists in BalanceDB") and ok
		var ps := load("res://scenes/game/%s.tscn" % id) as PackedScene
		ok = _assert(ps != null, id + ".tscn loads") and ok
		if ps != null:
			var inst := ps.instantiate() as Node3D
			get_root().add_child(inst)
			var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
			ok = _assert(ap != null and ap.has_animation("Run") and ap.has_animation("Idle"), id + " has AnimationPlayer Run/Idle") and ok
			inst.configure_from_balance(id, db, w20, player_stub)
			ok = _assert(float(inst.max_hp) >= float(cfg.get("base_hp", 0.0)), id + " configured HP") and ok
			inst.queue_free()

	var pod_script := load("res://scripts/game/orbital_drop_pod.gd") as GDScript
	var pod: Node3D = pod_script.new()
	get_root().add_child(pod)
	var st := {"opened_id": ""}
	pod.pod_opened.connect(func(eid: String, _pos: Vector3) -> void: st["opened_id"] = eid)
	pod.configure(Vector3(-5, 0, 5), null, 10, db.get_drop_pod_cfg())
	pod._process(1.5)
	pod._process(1.0)
	pod._process(3.1)
	ok = _assert(str(st.get("opened_id", "")) == "mech_leela", "Wave 10 pod opens mech_leela") and ok
	pod.queue_free()
	player_stub.queue_free()

	print("ALL_TESTS_PASSED: test_mech_enemies_replacement" if ok else "TEST_FAILED: test_mech_enemies_replacement")
	quit(0 if ok else 1)
