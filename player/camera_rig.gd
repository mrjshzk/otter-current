extends Node3D
class_name CameraRig

@export var sensitivity: float = 0.003
@export var invert_y: bool = false
@export var min_pitch_degrees: float = -60.0
@export var max_pitch_degrees: float = 60.0

@export_group("Spring Arm")
@export var camera_distance_sea: float = 3.0
@export var camera_distance_land: float = 2.0
@export var spring_speed: float = 8.0

@export_group("FOV Kick")
@export var base_fov: float = 60.0
@export var max_fov: float = 80.0
## Horizontal speed at which the FOV kick reaches its maximum.
@export var fov_speed_full: float = 12.0
@export var fov_lerp_speed: float = 6.0

@onready var pivot: Node3D = %Pivot
@onready var spring: SpringArm3D = %SpringArm
@onready var camera: Camera3D = %Camera3D
@onready var player: Player = get_parent()

var _yaw := 0.0
var _pitch := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.fov = base_fov

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * sensitivity
		var pitch_direction := -1.0 if invert_y else 1.0
		_pitch -= event.relative.y * sensitivity * pitch_direction
		_pitch = clampf(_pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	global_rotation = Vector3(0.0, _yaw, 0.0)
	pivot.rotation = Vector3(_pitch, 0.0, 0.0)
	_update_camera(delta)

func _update_camera(delta: float) -> void:
	var target_distance := camera_distance_land if not player.in_sea else camera_distance_sea
	spring.spring_length = lerpf(spring.spring_length, target_distance, minf(1.0, spring_speed * delta))
	var horizontal_speed := Vector2(player.current_velocity.x, player.current_velocity.z).length()
	var kick := clampf(horizontal_speed / fov_speed_full, 0.0, 1.0)
	var target_fov := lerpf(base_fov, max_fov, kick)
	camera.fov = lerpf(camera.fov, target_fov, minf(1.0, fov_lerp_speed * delta))