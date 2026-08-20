extends Area3D
class_name NPC

const CONFETTI_VFX := preload("res://scenes/vfx/confetti.tscn")

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
	if dialogue == null:
		dialogue = load(_default_dialogue_path())

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
			VFXManager.spawn(CONFETTI_VFX, global_position)
			AudioManager.play_ui(SfxLibrary.JINGLE, -3.0)
			_talk(player, &"snack_received")
		else:
			_talk(player, &"wrong_snack")
	else:
		if _is_delivery_target():
			_talk(player, &"awaiting_snack")
		else:
			_talk(player, &"greeting")

func _is_delivery_target() -> bool:
	return DeliveryManager.is_delivering() and DeliveryManager.target_customer == self

func _talk(player: Node, cue: StringName) -> void:
	if cue == &"wrong_snack":
		AudioManager.play_ui(SfxLibrary.BUZZ, -6.0)
	else:
		AudioManager.play_ui(SfxLibrary.BLIP, -8.0)
	talked.emit(player, self, cue)
	if dialogue != null:
		DialogueManager.show_dialogue_balloon(dialogue, String(cue), [player, self])

func _default_dialogue_path() -> String:
	return "res://scenes/dialogue/npc.dialogue"
