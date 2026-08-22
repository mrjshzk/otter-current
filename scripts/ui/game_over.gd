extends CanvasLayer
class_name GameOverScreen

@export var restart_delay: float = 3.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	DeliveryManager.game_over.connect(_on_game_over)

func _on_game_over() -> void:
	get_tree().paused = true
	visible = true
	var timer := get_tree().create_timer(restart_delay, true)
	timer.timeout.connect(_restart)

func _restart() -> void:
	DeliveryManager.reset()
	get_tree().paused = false
	get_tree().reload_current_scene()
