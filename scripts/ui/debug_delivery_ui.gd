extends CanvasLayer
class_name DebugDeliveryUI
## Debug overlay for the DeliveryManager: shows the live delivery state
## (target island, customer, snack, countdown). Instance it into any level
## scene while debugging; it reads DeliveryManager.get_delivery_info().

@onready var state_label: Label = %StateLabel
@onready var target_island_label: Label = %TargetIslandLabel
@onready var target_customer_label: Label = %TargetCustomerLabel
@onready var snack_label: Label = %SnackLabel
@onready var timer_label: Label = %TimerLabel
@onready var completed_label: Label = %CompletedLabel
@onready var home_island_label: Label = %HomeIslandLabel

func _process(_delta: float) -> void:
	var info := DeliveryManager.get_delivery_info()
	state_label.text = "State: %s" % _state_name(info.state)
	target_island_label.text = "Target island: %s" % info.target_island_name
	target_customer_label.text = "Target customer: %s" % info.target_npc_name
	snack_label.text = "Snack: %s" % _snack_name(info.snack)
	timer_label.text = "Timer: %s" % _timer_text(info)
	completed_label.text = "Deliveries completed: %d" % info.deliveries_completed
	home_island_label.text = "Home island: %s" % info.home_island_name

func _state_name(state: int) -> String:
	match state:
		DeliveryManager.DeliveryState.DELIVERING:
			return "DELIVERING"
		DeliveryManager.DeliveryState.RETURNING:
			return "RETURNING"
		_:
			return "IDLE"

func _snack_name(snack: Snack) -> String:
	return snack.snack_name if snack != null else "-"

func _timer_text(info: Dictionary) -> String:
	if not info.timed:
		return "untimed"
	return "%.1fs left (limit %.1fs)" % [info.time_remaining, info.time_limit]