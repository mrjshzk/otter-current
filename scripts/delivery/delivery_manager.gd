extends Node

signal delivery_started(snack: Snack, customer: CustomerNPC, island: Island, time_limit: float)
signal delivery_completed(snack: Snack)
signal returning_home()
signal delivery_failed(snack: Snack, customer: CustomerNPC)
signal game_over()

enum DeliveryState { IDLE, DELIVERING, RETURNING }

@export var timed_after_deliveries: int = 2
@export var first_time_limit: float = 45.0
@export var time_limit_step_down: float = 5.0
@export var min_time_limit: float = 20.0

var state: DeliveryState = DeliveryState.IDLE
var current_snack: Snack = null
var target_customer: CustomerNPC = null
var target_island: Island = null
var home_island: Island = null

var deliveries_completed: int = 0
var time_limit: float = 0.0
var time_remaining: float = 0.0

var _islands: Array[Island] = []
var _dialogue_open := false

func _ready() -> void:
	# the timer pauses while dialogue is on screen: the player's controls are
	# locked anyway, so ticking would be unfair
	DialogueManager.dialogue_started.connect(func(_resource: DialogueResource) -> void:
		_dialogue_open = true
	)
	DialogueManager.dialogue_ended.connect(func(_resource: DialogueResource) -> void:
		_dialogue_open = false
	)

func _process(delta: float) -> void:
	if state != DeliveryState.DELIVERING or time_limit <= 0.0 or _dialogue_open:
		return
	time_remaining = maxf(0.0, time_remaining - delta)
	if time_remaining <= 0.0:
		_fail_delivery()
		game_over.emit()

func is_delivering() -> bool:
	return state == DeliveryState.DELIVERING

func is_returning() -> bool:
	return state == DeliveryState.RETURNING

func is_timed() -> bool:
	return time_limit > 0.0

func reset() -> void:
	state = DeliveryState.IDLE
	current_snack = null
	target_customer = null
	target_island = null
	time_limit = 0.0
	time_remaining = 0.0
	deliveries_completed = 0
	_dialogue_open = false
	_islands.clear()
	home_island = null

func register_island(island: Island) -> void:
	if island == null or _islands.has(island):
		return
	_islands.append(island)
	if home_island == null and island.is_home():
		home_island = island

func start_delivery(snack: Snack, customer: CustomerNPC) -> void:
	if snack == null or customer == null:
		return
	var island := _island_of_customer(customer)
	if island == null:
		Log.warn("start_delivery: no island registered for customer '%s' (snack '%s')" % [
			customer.npc_name, snack.snack_name])
		return
	current_snack = snack
	target_customer = customer
	target_island = island
	time_limit = _next_time_limit()
	time_remaining = time_limit
	state = DeliveryState.DELIVERING
	delivery_started.emit(snack, customer, island, time_limit)

func complete_delivery() -> void:
	if not is_delivering():
		return
	var snack := current_snack
	current_snack = null
	target_customer = null
	target_island = null
	time_limit = 0.0
	time_remaining = 0.0
	deliveries_completed += 1
	state = DeliveryState.RETURNING
	delivery_completed.emit(snack)
	returning_home.emit()

func _fail_delivery() -> void:
	var snack := current_snack
	var customer := target_customer
	current_snack = null
	target_customer = null
	target_island = null
	time_limit = 0.0
	time_remaining = 0.0
	state = DeliveryState.IDLE
	delivery_failed.emit(snack, customer)

func _next_time_limit() -> float:
	if deliveries_completed < timed_after_deliveries: # FIXME
		return 0.0
	var elapsed := float(deliveries_completed - timed_after_deliveries)
	return maxf(min_time_limit, first_time_limit - elapsed * time_limit_step_down)

func get_npc_info_from_snack(snack: Snack) -> Dictionary:
	if snack == null:
		return {}
	_islands = _islands.filter(func(i): return i != null)

	for island in _islands:
		var customer := island.customer()
		Log.debug("%s -> %s" % [island, customer])
		if customer != null and customer.snack == snack:
			return {
				"npc_name": customer.npc_name,
				"island_name": island.display_name(),
				"island": island,
				"customer": customer,
			}
	Log.warn("get_npc_info_from_snack: no island wants snack '%s'" % (
		snack.snack_name if not snack.snack_name.is_empty() else snack.resource_path))
	return {}

func get_delivery_target_name() -> String:
	return target_customer.npc_name if target_customer != null else ""

func get_delivery_info() -> Dictionary:
	return {
		"state": state,
		"active": is_delivering() or is_returning(),
		"snack": current_snack,
		"target_npc_name": get_delivery_target_name(),
		"target_island_name": target_island.display_name() if target_island != null else "",
		"target_island": target_island,
		"returning_home": is_returning(),
		"home_island_name": home_island.display_name() if home_island != null else "",
		"time_limit": time_limit,
		"time_remaining": time_remaining,
		"timed": is_timed(),
		"deliveries_completed": deliveries_completed,
	}

func target_position() -> Vector3:
	if is_delivering() and is_instance_valid(target_island):
		return target_island.global_position
	if is_instance_valid(home_island):
		return home_island.global_position
	return Vector3.ZERO

func _island_of_customer(customer: CustomerNPC) -> Island:
	for island in _islands:
		if island.customer() == customer:
			return island
	return null
