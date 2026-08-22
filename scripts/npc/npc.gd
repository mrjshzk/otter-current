extends Area3D
class_name NPC

const CONFETTI_VFX := preload("res://scenes/vfx/confetti.tscn")

signal talked(player: Node, npc: NPC, cue: StringName)
signal snack_received(player: Node, npc: NPC, snack: Snack)

@onready var look_at_modifier: LookAtModifier3D = %LookAtModifier

@export var player : Node3D
@export var npc_name: String = ""
@export var customer: CustomerNPC = null
@export var dialogue: DialogueResource = null
@export var prompt_label: Label3D = null
@export var prompt_icon: Sprite3D = null

@export var voice_pitch: float = 1.0
@export var voice_speed: float = 1.0
@export var voice_tone: float = 0.5

func get_voice_settings() -> Dictionary:
	return {
		"pitch": voice_pitch,
		"speed": voice_speed,
		"tone": voice_tone,
	}

func _ready() -> void:
	if player:
		look_at_modifier.target_node = player.get_path()
	else:
		Log.err("Make sure to put the player look at position for NPC -> %s %s" % [self.name, self.npc_name])
	prompt_label.hide()
	prompt_icon.hide()
	monitoring = false
	self.set_collision_layer_value(1, false)
	self.set_collision_mask_value(1, false)
	self.set_collision_layer_value(Definitions.INTERACTION_PHYSICS_LAYER, true)
	if dialogue == null:
		dialogue = load(_default_dialogue_path())


func on_interact(p: Node) -> void:
	var backpack := Backpack.from_player(p)
	if backpack == null:
		return
	if backpack.has_snack():
		var delivered := backpack.snack
		if customer != null and delivered == customer.snack:
			backpack.remove_snack()
			DeliveryManager.complete_delivery()
			snack_received.emit(p, self, delivered)
			VFXManager.spawn(CONFETTI_VFX, global_position)
			AudioManager.play_ui(SfxLibrary.JINGLE, -3.0)
			_talk(p, &"snack_received")
		elif _is_delivery_target():
			_talk(p, &"wrong_snack")
		else:
			_talk(p, &"greeting")
	else:
		if _is_delivery_target():
			_talk(p, &"awaiting_snack")
		else:
			_talk(p, &"greeting")

func _is_delivery_target() -> bool:
	return DeliveryManager.is_delivering() and DeliveryManager.target_customer == customer

func get_interaction_prompt(p: Node) -> String:
	var backpack := Backpack.from_player(p)
	if backpack != null and backpack.has_snack() and customer != null and backpack.snack == customer.snack:
		return "Deliver %s to %s" % [backpack.snack.snack_name, npc_name]
	return "Talk to %s" % npc_name

func set_prompt(text: String, icon: Texture2D) -> void:
	if prompt_label != null:
		prompt_label.text = text
		prompt_label.visible = true
	if prompt_icon != null:
		prompt_icon.texture = icon
		prompt_icon.visible = icon != null

func set_prompt_visible(v: bool) -> void:
	if prompt_label != null:
		prompt_label.visible = v
	if prompt_icon != null:
		prompt_icon.visible = v

func _first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _first_mesh_instance(child)
		if found != null:
			return found
	return null

func _talk(p: Node, cue: StringName) -> void:
	if cue == &"wrong_snack":
		AudioManager.play_ui(SfxLibrary.BUZZ, -6.0)
	else:
		AudioManager.play_ui(SfxLibrary.BLIP, -8.0)
	talked.emit(p, self, cue)
	if dialogue != null:
		DialogueManager.show_dialogue_balloon(dialogue, String(cue), [p, self])

func _default_dialogue_path() -> String:
	return "res://scenes/dialogue/npc.dialogue"
