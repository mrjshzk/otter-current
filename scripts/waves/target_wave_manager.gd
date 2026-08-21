extends Node3D
class_name TargetWaveManager

@export var wave_scene: PackedScene
@export var player: Node3D
@export var spawn_interval: float = 6.0
@export var spawn_distance_min: float = 20.0
@export var spawn_distance_max: float = 40.0
@export var min_speed: float = 7.0
@export var max_speed: float = 13.0
@export var initial_waves: int = 3
## The Y the waves are spawned at. Should match the sea surface.
@export var spawn_height: float = 0.0

## Chance a wave travels toward the player's target island.
@export var toward_target_chance: float = 0.65
## How wide the cone around the target direction is (full spread).
@export var target_cone_degrees: float = 45.0
## Spawn interval while a delivery is active (harder while carrying a snack).
@export var delivery_spawn_interval: float = 4.0
## Speed multiplier for waves while a delivery is active.
@export var delivery_speed_multiplier: float = 1.2

var _timer := 0.0

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
	var wave := wave_scene.instantiate()
	var travel_dir := _pick_travel_direction()
	var distance := randf_range(spawn_distance_min, spawn_distance_max)
	add_child(wave)
	var spawn_pos := player.global_position - travel_dir * distance
	spawn_pos.y = spawn_height
	wave.global_position = spawn_pos
	wave.wave_direction = travel_dir
	wave.speed = randf_range(min_speed, max_speed)
	if DeliveryManager.is_delivering():
		wave.speed *= delivery_speed_multiplier

func _pick_travel_direction() -> Vector3:
	var aim := player.global_position if player != null else Vector3.ZERO
	if DeliveryManager.is_delivering() or DeliveryManager.is_returning():
		var target := DeliveryManager.target_position()
		if not target.is_zero_approx():
			aim = target
	if player == null or aim.is_zero_approx() or player.global_position.distance_to(aim) < 1.0:
		return _random_heading()
	var to_aim := (aim - player.global_position).normalized()
	var heading := atan2(-to_aim.x, -to_aim.z)
	var spread := deg_to_rad(target_cone_degrees * 0.5)
	if randf() < toward_target_chance:
		heading += randf_range(-spread, spread)
	else:
		var side := 1.0 if randf() < 0.5 else -1.0
		heading += side * randf_range(spread, PI)
	return Vector3(-sin(heading), 0.0, -cos(heading))

func _random_heading() -> Vector3:
	var heading := randf_range(-PI, PI)
	return Vector3(-sin(heading), 0.0, -cos(heading))
