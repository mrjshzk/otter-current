extends Control

@onready var fader: ColorRect = %Fader
@export var start_fade_time = 1.0

func _ready() -> void:
	var p := get_tree().get_first_node_in_group(Definitions.PLAYER_GROUP) as Player
	p._lock_controls()
	fader.visible = true
	create_tween().tween_property(fader, "self_modulate", Color.TRANSPARENT, start_fade_time).finished.connect(
		func():
			fader.queue_free()
			p._unlock_controls()
	)
