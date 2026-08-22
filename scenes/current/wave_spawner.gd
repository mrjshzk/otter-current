extends Node3D
class_name WaveSpawner

@export var wave_scene: PackedScene
@export var player: Node3D
@export var spawn_interval: float = 6.0
@export var spawn_distance_min: float = 20.0
@export var spawn_distance_max: float = 40.0
@export var min_speed: float = 7.0
@export var max_speed: float = 13.0
@export var bias_strength: float = 0.75
@export var bias_cone_degrees: float = 60.0
@export var initial_waves: int = 3
@export var spawn_height: float = 0.0

var _timer := 0.0

func _ready() -> void:
	if player == null:
		var players := get_tree().get_nodes_in_group(Definitions.PLAYER_GROUP)
		if not players.is_empty():
			player = players[0]
	for i in initial_waves:
		_spawn_wave()

func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= spawn_interval:
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

func _pick_travel_direction() -> Vector3:
	var heading: float
	if randf() < bias_strength:
		var facing := player.global_rotation.y
		var spread := deg_to_rad(bias_cone_degrees * 0.5)
		heading = facing + randf_range(-spread, spread)
	else:
		heading = randf_range(-PI, PI)
	return Vector3(-sin(heading), 0.0, -cos(heading))