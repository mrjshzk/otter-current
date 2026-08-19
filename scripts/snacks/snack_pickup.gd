extends Area3D
class_name SnackPickup

@export var snack: Snack

func _ready() -> void:
	monitoring = false
	self.set_collision_layer_value(1, false)
	self.set_collision_mask_value(1, false)
	self.set_collision_layer_value(Definitions.INTERACTION_PHYSICS_LAYER, true)
	_update_visual()

func on_interact(player: Node) -> void:
	var backpack := Backpack.from_player(player)
	if backpack == null:
		return
	if backpack.add_snack(snack):
		queue_free()

func _update_visual() -> void:
	if snack != null and snack.pickup_scene != null:
		var visual := snack.pickup_scene.instantiate()
		visual.name = "SnackVisual"
		add_child(visual)

## Creates a pickup in the world. Used by the boss to place the snack at the shop.
static func spawn(snack: Snack, parent: Node, at: Vector3) -> SnackPickup:
	var pickup := SnackPickup.new()
	pickup.snack = snack
	parent.add_child(pickup)
	pickup.global_position = at
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.4
	collider.shape = shape
	pickup.add_child(collider)
	return pickup