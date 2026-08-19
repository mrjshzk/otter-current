extends Area3D
class_name InteractionManager

@export var interact_action: GUIDEAction
@onready var player: Player = get_parent()
@onready var root_state_chart: StateChart = %RootStateChart

var _interactables: Array[CollisionObject3D] = []

func _ready() -> void:
	monitorable = false
	self.set_collision_layer_value(1, false)
	self.set_collision_mask_value(1, false)
	self.set_collision_mask_value(Definitions.INTERACTION_PHYSICS_LAYER, true)

	body_entered.connect(_add_interactable)
	area_entered.connect(_add_interactable)
	body_exited.connect(_remove_interactable)
	area_exited.connect(_remove_interactable)

	interact_action.completed.connect(on_interact_pressed)

func _add_interactable(object: CollisionObject3D) -> void:
	if not _interactables.has(object):
		_interactables.append(object)

func _remove_interactable(object: CollisionObject3D) -> void:
	_interactables.erase(object)

func _nearest_interactable() -> CollisionObject3D:
	var stale: Array[CollisionObject3D] = []
	for object in _interactables:
		if not is_instance_valid(object):
			stale.append(object)
	for object in stale:
		_interactables.erase(object)
	var nearest: CollisionObject3D = null
	var best_distance := INF
	for object in _interactables:
		var distance := global_position.distance_squared_to(object.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest = object
	return nearest

func on_interact_pressed() -> void:
	var current_object := _nearest_interactable()
	if current_object == null:
		return
	
	if current_object.has_method("on_interact"):
		current_object.on_interact(player)
		return

	if is_instance_of(current_object, MovementModeContext):
		var ctx = current_object as MovementModeContext
		player.global_position = ctx.get_tp_position(player.in_sea)
		player.in_sea = !player.in_sea
		root_state_chart.send_event("switch_moveset")
