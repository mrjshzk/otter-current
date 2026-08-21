extends Area3D
class_name NPC

const CONFETTI_VFX := preload("res://scenes/vfx/confetti.tscn")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")

signal talked(player: Node, npc: NPC, cue: StringName)
signal snack_received(player: Node, npc: NPC, snack: Snack)

@export var npc_name: String = ""
## Data resource describing this NPC as a delivery customer (name + snack).
@export var customer: CustomerNPC = null
## Used by the dialogue system at a later stage.
@export var dialogue: DialogueResource = null
## The mesh that gets an outline while the player can interact with this NPC.
@export var highlight_mesh: MeshInstance3D = null
## The label showing the interaction prompt text (hidden while no prompt).
@export var prompt_label: Label3D = null
## The sprite showing the interact key icon (hidden while no prompt).
@export var prompt_icon: Sprite3D = null

var _outline_material: ShaderMaterial = null

func _ready() -> void:
	prompt_label.hide()
	prompt_icon.hide()
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
		if customer != null and delivered == customer.snack:
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
	return DeliveryManager.is_delivering() and DeliveryManager.target_customer == customer

## Text shown on the floating interaction prompt next to this NPC.
## Depends on the player's backpack: delivering the right snack vs just talking.
func get_interaction_prompt(player: Node) -> String:
	var backpack := Backpack.from_player(player)
	if backpack != null and backpack.has_snack() and customer != null and backpack.snack == customer.snack:
		return "Deliver %s to %s" % [backpack.snack.snack_name, npc_name]
	return "Talk to %s" % npc_name

## Shows the interaction prompt with the given text and key icon on this
## NPC's own Label3D/Sprite3D nodes.
func set_prompt(text: String, icon: Texture2D) -> void:
	if prompt_label != null:
		prompt_label.text = text
		prompt_label.visible = true
	if prompt_icon != null:
		prompt_icon.texture = icon
		prompt_icon.visible = icon != null

func set_prompt_visible(visible: bool) -> void:
	if prompt_label != null:
		prompt_label.visible = visible
	if prompt_icon != null:
		prompt_icon.visible = visible

## Adds/removes a next_pass outline on the highlight mesh. next_pass is used
## instead of a duplicated mesh so skinned meshes keep animating.
func set_highlighted(enabled: bool) -> void:
	var mesh := _find_highlight_mesh()
	if mesh == null:
		return
	if enabled:
		if mesh.material_override == null:
			var base := mesh.get_active_material(0)
			if base == null:
				return
			var mat: Material = base.duplicate() as Material
			mat.next_pass = _get_outline_material()
			mesh.material_override = mat
	else:
		mesh.material_override = null

func _find_highlight_mesh() -> MeshInstance3D:
	if highlight_mesh != null:
		return highlight_mesh
	return _first_mesh_instance(self)

func _first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _first_mesh_instance(child)
		if found != null:
			return found
	return null

func _get_outline_material() -> ShaderMaterial:
	if _outline_material == null:
		_outline_material = ShaderMaterial.new()
		_outline_material.shader = OUTLINE_SHADER
	return _outline_material

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
