extends Marker3D
class_name Island

## Data resource describing this island (name, customer, home flag).
@export var resource: IslandResource = null
## Radius used by the wave manager to keep waves from passing through this island.
@export var collision_radius: float = 4.5

func _ready() -> void:
	DeliveryManager.register_island(self)
	add_to_group(Definitions.ISLANDS_GROUP)

func display_name() -> String:
	return resource.island_name if resource != null else name

func customer() -> CustomerNPC:
	return resource.customer if resource != null else null

func is_home() -> bool:
	return resource != null and resource.is_home