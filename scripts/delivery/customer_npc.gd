extends Resource
class_name CustomerNPC

## Display name used in dialogue and UI.
@export var npc_name: String = ""
## The snack this customer wants delivered.
@export var snack: Snack = null