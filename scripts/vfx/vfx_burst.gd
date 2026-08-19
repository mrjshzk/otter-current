extends GPUParticles3D
class_name VFXBurst

func _ready() -> void:
	one_shot = true
	emitting = true
	var life := self.lifetime
	var timer := get_tree().create_timer(life + 1.5)
	timer.timeout.connect(queue_free)
