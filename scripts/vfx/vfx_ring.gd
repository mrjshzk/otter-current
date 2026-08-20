extends Node3D
class_name VFXRing

@export var grow_to := 1.8
@export var duration := 0.45
@export var start_scale := 0.25

var _material: StandardMaterial3D

func _ready() -> void:
	var mesh_instance := get_node("MeshInstance3D") as MeshInstance3D
	_material = (mesh_instance.mesh as QuadMesh).material as StandardMaterial3D
	_material.albedo_color.a = 0.9
	scale = Vector3(start_scale, 1.0, start_scale)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(grow_to, 1.0, grow_to), duration)
	tween.parallel().tween_property(_material, "albedo_color:a", 0.0, duration)
	tween.tween_callback(queue_free)