extends Area3D
class_name MovementModeContext

@export var in_sea_node: Marker3D
@export var in_land_node: Marker3D

func _ready() -> void:
	monitoring = false
	self.set_collision_layer_value(1, false)
	self.set_collision_mask_value(1, false)
	self.set_collision_layer_value(Definitions.INTERACTION_PHYSICS_LAYER, true)

func get_tp_position(in_sea: bool) -> Vector3:
	if in_sea:
		return in_land_node.global_position
	else:
		return in_sea_node.global_position
