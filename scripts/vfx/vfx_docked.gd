extends Node3D
class_name VFXDocked

var emitting := false:
	set(value):
		emitting = value
		for child in get_children():
			if child is GPUParticles3D:
				child.emitting = value