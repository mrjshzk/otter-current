extends Node3D
class_name VFXDocked
## Docked VFX root (wake, bubbles). Exposes an `emitting` property that toggles
## every child GPUParticles3D, so layered scenes keep the simple
## `.emitting = true/false` API used by the player.

var emitting := false:
	set(value):
		emitting = value
		for child in get_children():
			if child is GPUParticles3D:
				child.emitting = value