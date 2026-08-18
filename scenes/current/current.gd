extends Area3D
class_name OceanCurrent

@export var _peak_position_node: Node3D
@export var wave_direction: Vector3
@export var speed: float = 10.0
@export var lifetime: float = 60.0

var _lifetime_left: float

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_lifetime_left = lifetime

func _physics_process(delta: float) -> void:
	global_position += wave_direction.normalized() * speed * delta
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		queue_free()

func get_velocity() -> Vector3:
	return wave_direction.normalized() * speed

func get_peak_position() -> Vector3:
	return _peak_position_node.global_position

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(Definitions.PLAYER_GROUP) and body.has_method("on_wave_entered"):
		body.on_wave_entered(self)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(Definitions.PLAYER_GROUP) and body.has_method("on_wave_exited"):
		body.on_wave_exited(self)