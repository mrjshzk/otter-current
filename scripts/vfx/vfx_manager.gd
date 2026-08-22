extends Node

var _holder: Node3D

func _ready() -> void:
	_holder = Node3D.new()
	_holder.name = "VFXHolder"
	add_child(_holder)

func spawn(prefab: PackedScene, at: Vector3, parent: Node = null) -> Node3D:
	if prefab == null:
		return null
	var instance := prefab.instantiate()
	(parent if parent != null else _holder).add_child(instance)
	instance.global_position = at
	return instance

func dock(prefab: PackedScene, parent: Node) -> Node3D:
	if prefab == null:
		return null
	var instance := prefab.instantiate()
	parent.add_child(instance)
	return instance