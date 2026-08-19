extends Node3D
class_name CameraRig

@export var sensitivity: float = 0.003
@export var invert_y: bool = false
@export var min_pitch_degrees: float = -60.0
@export var max_pitch_degrees: float = 60.0

@onready var pivot: Node3D = %Pivot

var _yaw := 0.0
var _pitch := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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

func _physics_process(_delta: float) -> void:
	global_rotation = Vector3(0.0, _yaw, 0.0)
	pivot.rotation = Vector3(_pitch, 0.0, 0.0)
