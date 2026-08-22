extends Area3D
class_name OceanCurrent

@export var _peak_position_node: Node3D
@export var wave_direction: Vector3:
	set(value):
		wave_direction = value
		_face_direction()
@export var speed: float = 10.0
@export var lifetime: float = 60.0
@export var sink_depth: float = -3.0
@export var sink_duration: float = 0.6

@onready var _wave_visual: Node3D = $Wave
@onready var collision_checker: Area3D = %CollisionChecker

var _lifetime_left: float
var _sinking := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_checker.body_entered.connect(_on_collision_checker_body_entered)
	_lifetime_left = lifetime

func _face_direction() -> void:
	if _wave_visual == null or wave_direction.is_zero_approx():
		return
	_wave_visual.rotation.y = atan2(-wave_direction.x, -wave_direction.z)

func _physics_process(delta: float) -> void:
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		_die()
		return
	if _sinking:
		return
	global_position += wave_direction.normalized() * speed * delta

func _die() -> void:
	if _sinking:
		return
	_sinking = true
	collision_checker.set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", sink_depth, sink_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func get_velocity() -> Vector3:
	return wave_direction.normalized() * speed

func get_peak_position() -> Vector3:
	return _peak_position_node.global_position

func _on_body_entered(body: Node3D) -> void:
	if _sinking:
		return
	if body.is_in_group(Definitions.PLAYER_GROUP) and body.has_method("on_wave_entered"):
		body.on_wave_entered(self)

func _on_body_exited(body: Node3D) -> void:
	if _sinking:
		return
	if body.is_in_group(Definitions.PLAYER_GROUP) and body.has_method("on_wave_exited"):
		body.on_wave_exited(self)

func _on_collision_checker_body_entered(body: Node3D) -> void:
	if _sinking or body.is_in_group(Definitions.PLAYER_GROUP):
		return
	var player := get_tree().get_first_node_in_group(Definitions.PLAYER_GROUP) as Player
	if player != null:
		player.force_wave_jump_off(self)
	_die()