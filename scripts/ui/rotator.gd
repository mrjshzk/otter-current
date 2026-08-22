@tool
extends Node3D

func _physics_process(delta: float) -> void:
	self.rotation_degrees.y += delta * 100
