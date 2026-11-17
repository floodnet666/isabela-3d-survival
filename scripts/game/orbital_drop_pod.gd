class_name OrbitalDropPod
extends StaticBody3D
## Destructible orbital drop pod launched by SM_Ship: telegraphs ground impact, deals AoE damage, and opens after 3s unless destroyed.

const WeaponVFXRef := preload("res://scripts/game/weapon_vfx.gd")
const BossVisualsRef := preload("res://scripts/game/boss_visuals_helper.gd")

signal pod_destroyed(by_player: bool, world_pos: Vector3, bonus_xp: int)
signal pod_opened(reinforcement_id: String, world_pos: Vector3)

var max_hp: float = 90.0
var current_hp: float = 90.0
var _wave: int = 5
var _player: Node3D
var _target_pos: Vector3 = Vector3.ZERO
var _telegraph_left: float = 1.35
var _open_delay_left: float = 3.0
var _fall_speed: float = 32.0
var _impact_radius: float = 2.4
var _impact_damage: float = 24.0
var _destroy_xp: int = 35
var _landed: bool = false
var _resolved: bool = false

var _pod_mesh: MeshInstance3D
var _ring_mesh: MeshInstance3D

static var _shared_pod_mesh: CylinderMesh
static var _shared_pod_mat: StandardMaterial3D
static var _shared_ring_mesh: TorusMesh
static var _shared_ring_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("orbital_drop_pods")
	add_to_group("damageable_props")
	collision_layer = 4
	collision_mask = 1
	_ensure_meshes_and_collision()


func configure(target_pos: Vector3, player: Node3D, wave: int, cfg: Dictionary) -> void:
	_target_pos = Vector3(target_pos.x, 0.0, target_pos.z)
	_player = player
	_wave = wave
	max_hp = float(cfg.get("pod_hp", 90.0))
	current_hp = max_hp
	_telegraph_left = float(cfg.get("telegraph_s", 1.35))
	_open_delay_left = float(cfg.get("open_delay_s", 3.0))
	_fall_speed = float(cfg.get("fall_speed_mps", 32.0))
	_impact_radius = float(cfg.get("impact_radius_m", 2.4))
	_impact_damage = float(cfg.get("impact_damage", 24.0))
	_destroy_xp = int(cfg.get("destroy_xp", 35))
	var spawn_y := float(cfg.get("spawn_y_m", 26.0))
	var start_pos := Vector3(_target_pos.x, spawn_y, _target_pos.z)
	if is_inside_tree():
		global_position = start_pos
	else:
		position = start_pos
	_ensure_meshes_and_collision()
	if _ring_mesh != null:
		if _ring_mesh.is_inside_tree():
			_ring_mesh.global_position = Vector3(_target_pos.x, 0.08, _target_pos.z)
		else:
			_ring_mesh.position = Vector3(0.0, 0.08 - spawn_y, 0.0)


func _process(delta: float) -> void:
	if _resolved:
		return
	if not _landed:
		if _telegraph_left > 0.0:
			_telegraph_left = maxf(0.0, _telegraph_left - delta)
			if _ring_mesh != null:
				var pulse := 0.88 + 0.16 * sin(Time.get_ticks_msec() * 0.015)
				_ring_mesh.scale = Vector3(pulse, 1.0, pulse)
			return
		position.y = maxf(0.0, position.y - _fall_speed * delta)
		if _ring_mesh != null and _ring_mesh.is_inside_tree():
			_ring_mesh.global_position = Vector3(_target_pos.x, 0.08, _target_pos.z)
		if position.y <= 0.01:
			_on_landed()
	else:
		_open_delay_left = maxf(0.0, _open_delay_left - delta)
		if _pod_mesh != null:
			var warn := 1.0 + 0.05 * sin(Time.get_ticks_msec() * 0.025)
			_pod_mesh.scale = Vector3(warn, 1.0, warn)
		if _open_delay_left <= 0.0:
			_open_pod()


func take_damage(amount: float, _impulse: Vector3 = Vector3.ZERO, _is_crit: bool = false, _weapon_id: String = "") -> void:
	if _resolved or amount <= 0.0:
		return
	current_hp = maxf(0.0, current_hp - amount)
	if current_hp <= 0.0:
		_resolved = true
		if is_inside_tree():
			BossVisualsRef.spawn_shockwave(get_tree().current_scene, global_position, 2.2, Color(1.0, 0.45, 0.15, 0.85))
			WeaponVFXRef.spawn_hit_sparks(get_tree().current_scene, global_position + Vector3(0.0, 0.8, 0.0), Vector3.UP, true, true)
		pod_destroyed.emit(true, global_position, _destroy_xp)
		queue_free()


func _on_landed() -> void:
	_landed = true
	global_position = _target_pos
	if _ring_mesh != null:
		_ring_mesh.visible = false
	if is_inside_tree():
		BossVisualsRef.spawn_shockwave(get_tree().current_scene, _target_pos, _impact_radius, Color(1.0, 0.25, 0.18, 0.85))
	if _player != null and is_instance_valid(_player) and _player.has_method("take_damage"):
		var dist := Vector2(_player.global_position.x - _target_pos.x, _player.global_position.z - _target_pos.z).length()
		if dist <= _impact_radius:
			var push := (_player.global_position - _target_pos).normalized() * 10.0
			_player.call("take_damage", _impact_damage, push)


func _open_pod() -> void:
	if _resolved:
		return
	_resolved = true
	var reinforcement := "mech_leela" if _wave >= 10 else "droid_small"
	pod_opened.emit(reinforcement, _target_pos)
	queue_free()


func _ensure_meshes_and_collision() -> void:
	if _pod_mesh != null:
		return
	_ensure_shared_assets()
	var cs := CollisionShape3D.new()
	var cap := CylinderShape3D.new()
	cap.radius = 0.65
	cap.height = 1.9
	cs.shape = cap
	cs.position = Vector3(0.0, 0.95, 0.0)
	add_child(cs)

	_pod_mesh = MeshInstance3D.new()
	_pod_mesh.mesh = _shared_pod_mesh
	_pod_mesh.material_override = _shared_pod_mat
	_pod_mesh.position = Vector3(0.0, 0.95, 0.0)
	add_child(_pod_mesh)

	_ring_mesh = MeshInstance3D.new()
	_ring_mesh.mesh = _shared_ring_mesh
	_ring_mesh.material_override = _shared_ring_mat
	_ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring_mesh)


static func spawn_rain(spawner: Node, entities_root: Node3D, player: Node3D, wave: int, count: int, pod_cfg: Dictionary) -> void:
	if spawner == null or entities_root == null:
		return
	var p_pos := player.global_position if player != null else Vector3.ZERO
	for _i in range(count):
		var spot: Vector3 = spawner.call("pick_ring_spawn_position", p_pos)
		var pod := OrbitalDropPod.new()
		entities_root.add_child(pod)
		pod.configure(spot, player, wave, pod_cfg)
		pod.pod_destroyed.connect(func(by_player: bool, _pos: Vector3, xp: int) -> void:
			if by_player:
				spawner.emit_signal("pod_destroyed_bonus", xp)
		)
		pod.pod_opened.connect(func(reinforcement_id: String, pos: Vector3) -> void:
			spawner.call("_spawn_reinforcement_at", reinforcement_id, pos)
		)


static func _ensure_shared_assets() -> void:
	if _shared_pod_mesh == null:
		_shared_pod_mesh = CylinderMesh.new()
		_shared_pod_mesh.top_radius = 0.45
		_shared_pod_mesh.bottom_radius = 0.68
		_shared_pod_mesh.height = 1.85
		_shared_pod_mat = StandardMaterial3D.new()
		_shared_pod_mat.albedo_color = Color(0.18, 0.20, 0.24)
		_shared_pod_mat.metallic = 0.78
		_shared_pod_mat.roughness = 0.32
		_shared_pod_mat.emission_enabled = true
		_shared_pod_mat.emission = Color(0.95, 0.22, 0.18)
		_shared_pod_mat.emission_energy_multiplier = 1.6
	if _shared_ring_mesh == null:
		_shared_ring_mesh = TorusMesh.new()
		_shared_ring_mesh.inner_radius = 1.85
		_shared_ring_mesh.outer_radius = 2.35
		_shared_ring_mat = StandardMaterial3D.new()
		_shared_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shared_ring_mat.albedo_color = Color(1.0, 0.22, 0.18, 0.75)
