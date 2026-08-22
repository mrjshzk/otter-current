extends Node3D
class_name VFXLayered

func _ready() -> void:
	var max_life := 0.0
	for child in get_children():
		if child is GPUParticles3D:
			child.one_shot = true
			child.restart()
			max_life = maxf(max_life, child.lifetime)
	get_tree().create_timer(max_life + 1.5).timeout.connect(queue_free)
