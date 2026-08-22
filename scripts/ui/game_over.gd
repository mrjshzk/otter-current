extends CanvasLayer
class_name GameOverScreen

@onready var message: RichTextLabel = %Message
@onready var panel_container: PanelContainer = %PanelContainer
@onready var character_icon: TextureRect = %CharacterIcon
@onready var restart_button: Button = %RestartButton
@onready var dim: ColorRect = %Dim

@export_multiline() var builder_otter_text := ""
@export_multiline()var gardener_otter_text := ""
@export_multiline() var mysterious_otter_text := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	DeliveryManager.game_over.connect(_on_game_over)
	DeliveryManager.delivery_failed.connect(delivery_failed)
	restart_button.pressed.connect(_restart)

func _on_game_over() -> void:
	get_tree().paused = true
	visible = true
	var t = create_tween()
	await t.tween_property(dim, "self_modulate", Color.WHITE, 2.0).finished
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	t = create_tween()
	t.tween_property(panel_container, "global_position", Vector2.ZERO, 1.5)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN_OUT)

func delivery_failed(_snack: Snack, customer: CustomerNPC):
	match customer.npc_name:
		"Mysterious Otter":
			message.text = mysterious_otter_text
			
		"Gardener Otter":
			message.text = gardener_otter_text
			character_icon.texture = customer.avatar
		"Builder Otter":
			message.text = builder_otter_text
	character_icon.texture = customer.avatar

func _restart() -> void:
	DeliveryManager.reset()
	get_tree().paused = false
	get_tree().reload_current_scene()
