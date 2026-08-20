extends Resource
class_name Snack

@export var snack_name: String = ""
@export var icon: Texture2D
## UID of the 3D visual scene shown at the pickup and in the backpack.
## The scene root must be a plain visual (MeshInstance3D/Node3D) — never a SnackPickup.
## Stored as a string to avoid a circular reference with the pickup scene.
@export var visual_scene_uid: String = ""

func get_visual_scene() -> PackedScene:
	if visual_scene_uid.is_empty():
		return null
	return load(visual_scene_uid)
