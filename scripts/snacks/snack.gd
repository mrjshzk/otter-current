extends Resource
class_name Snack

@export var snack_name: String = ""
@export var icon: Texture2D
## Stored as a string to avoid a circular reference with the pickup scene.
@export var visual_scene_uid: String = ""

func get_visual_scene() -> PackedScene:
	if visual_scene_uid.is_empty():
		return null
	return load(visual_scene_uid)
