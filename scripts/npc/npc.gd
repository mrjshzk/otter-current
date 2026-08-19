extends Area3D
class_name NPC

signal talked(player: Node, npc: NPC, cue: StringName)
signal snack_received(player: Node, npc: NPC, snack: Snack)

@export var npc_name: String = ""
## The snack this NPC accepts as a delivery.
@export var accepted_snack: Snack = null
## Used by the dialogue system at a later stage.
@export var dialogue: DialogueResource = null

func _ready() -> void:
	monitoring = false
	self.set_collision_layer_value(1, false)
	self.set_collision_mask_value(1, false)
	self.set_collision_layer_value(Definitions.INTERACTION_PHYSICS_LAYER, true)

func on_interact(player: Node) -> void:
	var backpack := Backpack.from_player(player)
	if backpack == null:
		return
	if backpack.has_snack():
		var delivered := backpack.snack
		if delivered == accepted_snack:
			backpack.remove_snack()
			DeliveryManager.complete_delivery()
			snack_received.emit(player, self, delivered)
			_talk(player, &"snack_received")
		else:
			_talk(player, &"wrong_snack")
	else:
		_talk(player, &"greeting")

func _talk(player: Node, cue: StringName) -> void:
	talked.emit(player, self, cue)
	## TODO(dialogue): open the Dialogue Manager balloon with `dialogue` at `cue`.