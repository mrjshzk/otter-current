extends Node3D
class_name TargetWaveManager

enum WaveRole { RANDOM, INTERCEPT, HELPER, ANTI }

@export var wave_scene: PackedScene
@export var player: Node3D
@export var spawn_interval: float = 0.6
@export var delivery_spawn_interval: float = 0.4
@export var spawn_distance_min: float = 20.0
@export var spawn_distance_max: float = 40.0
@export var min_speed: float = 12.0
@export var max_speed: float = 20.0
@export var initial_waves: int = 20
@export var spawn_height: float = 0.0

@export var spawn_area: MeshInstance3D = null
@export var spawn_edge_bias: float = 0.85
@export var min_lead_time: float = 0.8
@export var max_lead_time: float = 6.0
@export var random_chance: float = 0.4
@export var helper_chance: float = 0.35
@export var anti_chance: float = 0.25
@export var aim_at_player_chance: float = 0.6
@export var delivery_speed_multiplier: float = 1.2
@export var island_margin: float = 2.0
@export var min_scale: float = 0.85
@export var max_scale: float = 1.35

var _timer := 0.0
var _spawn_retries := 8

func _ready() -> void:
	if player == null:
		var players := get_tree().get_nodes_in_group(Definitions.PLAYER_GROUP)
		if not players.is_empty():
			player = players[0]
	for i in initial_waves:
		_spawn_wave()

func _physics_process(delta: float) -> void:
	var interval := delivery_spawn_interval if DeliveryManager.is_delivering() else spawn_interval
	_timer += delta
	if _timer >= interval:
		_timer = 0.0
		_spawn_wave()

func _spawn_wave() -> void:
	if wave_scene == null or player == null:
		return
	var to_target := _target_direction()
	var role := _pick_role(to_target)
	var speed := randf_range(min_speed, max_speed)
	if DeliveryManager.is_delivering():
		speed *= delivery_speed_multiplier
	var predicted := _predict_player_position(to_target, speed)
	var spawn_pos := _pick_spawn_point(predicted, role, to_target)
	var travel_dir := _pick_travel_direction(role, predicted, spawn_pos, to_target)
	var wave := wave_scene.instantiate()
	wave.position = spawn_pos
	add_child(wave)
	wave.wave_direction = travel_dir
	wave.speed = speed
	wave.scale = Vector3.ONE * randf_range(min_scale, max_scale)

func _target_direction() -> Vector3:
	if not (DeliveryManager.is_delivering() or DeliveryManager.is_returning()):
		return Vector3.ZERO
	var target := DeliveryManager.target_position()
	if target.is_zero_approx():
		return Vector3.ZERO
	var dir := target - player.global_position
	dir.y = 0.0
	if dir.length() < 1.0:
		return Vector3.ZERO
	return dir.normalized()

func _pick_role(to_target: Vector3) -> WaveRole:
	if to_target.is_zero_approx():
		return WaveRole.INTERCEPT if randf() < aim_at_player_chance else WaveRole.RANDOM
	var total := random_chance + helper_chance + anti_chance
	var roll := randf() * total
	if roll < random_chance:
		return WaveRole.RANDOM
	if roll < random_chance + helper_chance:
		return WaveRole.HELPER
	return WaveRole.ANTI

func _predict_player_position(to_target: Vector3, speed: float) -> Vector3:
	var pos := player.global_position
	var anchor_dir := to_target if not to_target.is_zero_approx() else _random_heading()
	var t := _intercept_time(pos + anchor_dir * spawn_distance_min, _player_velocity(), speed)
	var predicted := pos + _player_velocity() * t
	predicted.y = spawn_height
	return _clamp_prediction(predicted)

func _intercept_time(from: Vector3, vel: Vector3, speed: float) -> float:
	var d := player.global_position - from
	var a := vel.length_squared() - speed * speed
	if absf(a) < 0.01:
		return clampf(d.length() / maxf(speed, 1.0), min_lead_time, max_lead_time)
	var b := 2.0 * d.dot(vel)
	var c := d.length_squared()
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return clampf(d.length() / maxf(speed, 1.0), min_lead_time, max_lead_time)
	var t1 := (-b - sqrt(disc)) / (2.0 * a)
	var t2 := (-b + sqrt(disc)) / (2.0 * a)
	var t := maxf(t1, t2)
	if t <= 0.0:
		t = d.length() / maxf(speed, 1.0)
	return clampf(t, min_lead_time, max_lead_time)

func _player_velocity() -> Vector3:
	if player == null:
		return Vector3.ZERO
	var current: Variant = player.get(&"current_velocity")
	if current is Vector3:
		return current
	if player is CharacterBody3D:
		return (player as CharacterBody3D).velocity
	return Vector3.ZERO

func _pick_spawn_point(predicted: Vector3, role: WaveRole, to_target: Vector3) -> Vector3:
	var helper := role == WaveRole.HELPER
	var anti := role == WaveRole.ANTI
	var use_box := spawn_area != null and spawn_area.mesh is BoxMesh
	for i in _spawn_retries:
		var pos := _sample_spawn_point(predicted, helper, anti, use_box, to_target)
		if _spawn_point_valid(pos, predicted):
			return pos
	for i in _spawn_retries * 4:
		var pos := _sample_spawn_point(predicted, helper, anti, use_box, to_target)
		if _spawn_point_island_safe(pos):
			return pos
	return _sample_spawn_point(predicted, helper, anti, use_box, to_target)

func _sample_spawn_point(predicted: Vector3, helper: bool, anti: bool, use_box: bool, to_target: Vector3) -> Vector3:
	for i in 8:
		var pos := _base_sample(predicted, helper, anti, use_box, to_target)
		if not use_box or not _wrong_side(pos, predicted, helper, anti, to_target):
			return pos
	return _base_sample(predicted, helper, anti, use_box, to_target)

func _base_sample(predicted: Vector3, helper: bool, anti: bool, use_box: bool, to_target: Vector3) -> Vector3:
	var pos: Vector3
	if use_box:
		pos = _sample_box_point()
	elif helper or anti:
		var dist := randf_range(spawn_distance_min, spawn_distance_max)
		var perp := Vector3(-to_target.z, 0.0, to_target.x)
		var side := -1.0 if helper else 1.0
		pos = predicted + to_target * (side * dist) + perp * randf_range(-6.0, 6.0)
	else:
		var angle := randf_range(0.0, TAU)
		pos = predicted + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(spawn_distance_min, spawn_distance_max)
	pos.y = spawn_height
	return pos

func _wrong_side(pos: Vector3, predicted: Vector3, helper: bool, anti: bool, to_target: Vector3) -> bool:
	if helper and (pos - predicted).dot(to_target) >= 0.0:
		return true
	if anti and (pos - predicted).dot(to_target) <= 0.0:
		return true
	return false

func _pick_travel_direction(role: WaveRole, predicted: Vector3, spawn_pos: Vector3, to_target: Vector3) -> Vector3:
	match role:
		WaveRole.HELPER:
			if not to_target.is_zero_approx():
				return to_target
		WaveRole.ANTI, WaveRole.INTERCEPT:
			var dir := predicted - spawn_pos
			dir.y = 0.0
			if dir.length() > 1.0:
				return dir.normalized()
	return _random_heading()

func _spawn_point_valid(pos: Vector3, predicted: Vector3) -> bool:
	var dist := pos.distance_to(predicted)
	if dist < spawn_distance_min or dist > spawn_distance_max:
		return false
	return _island_safe(pos, predicted)

func _island_safe(pos: Vector3, predicted: Vector3) -> bool:
	for island in get_tree().get_nodes_in_group(Definitions.ISLANDS_GROUP):
		if pos.distance_to(island.global_position) < island.collision_radius + island_margin:
			return false
	return _path_is_clear(pos, predicted)

func _spawn_point_island_safe(pos: Vector3) -> bool:
	for island in get_tree().get_nodes_in_group(Definitions.ISLANDS_GROUP):
		if pos.distance_to(island.global_position) < island.collision_radius + island_margin:
			return false
	return true

func _path_is_clear(from: Vector3, to: Vector3) -> bool:
	for island in get_tree().get_nodes_in_group(Definitions.ISLANDS_GROUP):
		if not _segment_is_clear(from, to, island.global_position, island.collision_radius + island_margin):
			return false
	return true

func _segment_is_clear(a: Vector3, b: Vector3, c: Vector3, r: float) -> bool:
	var ab := b - a
	var t := 0.0
	if ab.length_squared() > 0.0:
		t = clampf((c - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return a.distance_to(c) > r or (a + ab * t).distance_to(c) > r

func _random_heading() -> Vector3:
	var heading := randf_range(-PI, PI)
	return Vector3(-sin(heading), 0.0, -cos(heading))

func _sample_box_point() -> Vector3:
	var box := spawn_area.mesh as BoxMesh
	if box == null:
		return Vector3.ZERO
	var _basis := spawn_area.global_transform.basis
	var _scale := _basis.get_scale()
	var half := Vector2(box.size.x * absf(_scale.x) * 0.5, box.size.z * absf(_scale.z) * 0.5)
	var u: float
	var v: float
	if randf() < spawn_edge_bias:
		var perimeter := 4.0 * (half.x + half.y)
		var t := randf() * perimeter
		if t < 2.0 * half.x:
			u = t / (2.0 * half.x)
			v = 0.0
		elif t < 4.0 * half.x:
			u = 2.0 - t / (2.0 * half.x)
			v = 1.0
		elif t < 4.0 * half.x + 2.0 * half.y:
			u = 0.0
			v = (t - 4.0 * half.x) / (2.0 * half.y)
		else:
			u = 1.0
			v = 2.0 - (t - 4.0 * half.x) / (2.0 * half.y)
	else:
		u = randf()
		v = randf()
	var local := Vector3((u * 2.0 - 1.0) * half.x, 0.0, (v * 2.0 - 1.0) * half.y)
	var world := spawn_area.global_transform * local
	return Vector3(world.x, spawn_height, world.z)

func _box_clamp(pos: Vector3) -> Vector3:
	var box := spawn_area.mesh as BoxMesh if spawn_area != null else null
	if box == null:
		return pos
	var _basis := spawn_area.global_transform.basis
	var _scale := _basis.get_scale()
	var half := Vector2(box.size.x * absf(_scale.x) * 0.5, box.size.z * absf(_scale.z) * 0.5)
	var local := spawn_area.global_transform.affine_inverse() * pos
	local.x = clampf(local.x, -half.x, half.x)
	local.z = clampf(local.z, -half.y, half.y)
	return spawn_area.global_transform * local

func _clamp_prediction(predicted: Vector3) -> Vector3:
	var clamped := _box_clamp(predicted)
	clamped.y = spawn_height
	return clamped
