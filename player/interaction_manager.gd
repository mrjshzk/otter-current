extends Area3D
class_name InteractionManager

@export var interact_action: GUIDEAction
@onready var player: Player = get_parent()
@onready var root_state_chart: StateChart = %RootStateChart

var current_object : CollisionObject3D

func _ready() -> void:
	monitorable = false
	self.set_collision_layer_value(1, false)
	self.set_collision_mask_value(1, false)
	self.set_collision_mask_value(Definitions.INTERACTION_PHYSICS_LAYER, true)
	
	body_entered.connect(func(b): current_object = b)
	area_entered.connect(func(b): current_object = b)
	body_exited.connect(func(b): current_object = null)
	area_exited.connect(func(b): current_object = null)
	
	interact_action.completed.connect(on_interact_pressed)

func on_interact_pressed():
	if current_object == null: return
	
	if is_instance_of(current_object, MovementModeContext):
		var ctx = current_object as MovementModeContext
		player.global_position = ctx.get_tp_position(player.in_sea)
		player.in_sea = !player.in_sea
		root_state_chart.send_event("switch_moveset")
	## TODO: implement NPCs and their interaction
