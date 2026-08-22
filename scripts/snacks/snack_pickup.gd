extends Area3D
class_name SnackPickup

const SPARKLE_VFX := preload("res://scenes/vfx/sparkle.tscn")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")

@export var snack: Snack
@export var prompt_label: Label3D = null
@export var prompt_icon: Sprite3D = null

var _outline_material: ShaderMaterial = null

func _ready() -> void:
	monitoring = false
	self.set_collision_layer_value(1, false)
	self.set_collision_mask_value(1, false)
	self.set_collision_layer_value(Definitions.INTERACTION_PHYSICS_LAYER, true)
	_update_visual()
	_ensure_prompt_nodes()

## Runtime-created pickups (e.g. the boss spawning a snack) have no scene, so
## their prompt nodes are built here with the same defaults as the scene ones.
func _ensure_prompt_nodes() -> void:
	if prompt_label == null:
		prompt_label = Label3D.new()
		prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		prompt_label.position = Vector3(0.5, 1.4, 0.0)
		prompt_label.pixel_size = 0.0045
		prompt_label.font_size = 64
		prompt_label.outline_size = 8
		prompt_label.outline_modulate = Color(0, 0, 0, 1)
		add_child(prompt_label)
		prompt_label.visible = false
	if prompt_icon == null:
		prompt_icon = Sprite3D.new()
		prompt_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		prompt_icon.position = Vector3(0.0, 1.4, 0.0)
		prompt_icon.pixel_size = 0.0045
		add_child(prompt_icon)
		prompt_icon.visible = false

func on_interact(player: Node) -> void:
	var backpack := Backpack.from_player(player)
	if backpack == null:
		return

	if backpack.add_snack(snack):
		VFXManager.spawn(SPARKLE_VFX, global_position)
		AudioManager.play_ui(SfxLibrary.CHIME, -4.0)
		queue_free()

func get_interaction_prompt(_player: Node) -> String:
	return "Pick up %s" % snack.snack_name if snack != null else ""

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

func set_highlighted(enabled: bool) -> void:
	var mesh := _first_mesh_instance(self)
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

func _update_visual() -> void:
	if snack == null:
		return
	var scene := snack.get_visual_scene()
	if scene == null:
		return
	var visual := scene.instantiate()
	if visual is SnackPickup:
		visual.free()
		push_error("Snack visual scene must not be a SnackPickup: %s" % snack.visual_scene_uid)
		return
	visual.name = "SnackVisual"
	add_child(visual)

static func spawn(s: Snack, parent: Node, at: Vector3) -> SnackPickup:
	var pickup := SnackPickup.new()
	pickup.snack = s
	parent.add_child(pickup)
	pickup.global_position = at
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.4
	collider.shape = shape
	pickup.add_child(collider)
	return pickup
