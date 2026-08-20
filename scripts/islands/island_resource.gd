extends Resource
class_name IslandResource

## Display name used in dialogue and UI.
@export var island_name: String = ""
## The customer that lives on this island.
@export var customer: CustomerNPC = null
## Marks this as the boss/home island. Return deliveries target it.
@export var is_home: bool = false