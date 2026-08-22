extends CanvasLayer

@onready var rotator: Node3D = %Rotator
@onready var progress: TextureProgressBar = %Progress
var active := false

func _ready() -> void:
	self.hide()
	
	DeliveryManager.delivery_started.connect(
		func(snack: Snack, customer: CustomerNPC, island: Island, time_limit: float):
			if time_limit <= 0: return
			var scene_to_instance := snack.get_visual_scene().instantiate()
			reset_rotator()
			rotator.add_child.call_deferred(scene_to_instance)
			progress.max_value = time_limit
			progress.value = time_limit
			self.show()
			active = true
	)
	DeliveryManager.delivery_completed.connect(stop)
	DeliveryManager.delivery_failed.connect(stop)

func reset_rotator():
	if !rotator.get_children().is_empty():
		for child in rotator.get_children():
			child.queue_free()

func stop(_s, _c):
	self.hide()
	active = false

func _process(delta: float) -> void:
	if not active: return
	progress.value = int(DeliveryManager.time_remaining)
