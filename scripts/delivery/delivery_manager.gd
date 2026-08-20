extends Node

signal delivery_started(snack: Snack, customer: CustomerNPC, island: Island)
signal delivery_completed(snack: Snack)
## Emitted right after delivery_completed, while the player still has to
## return to the home island. The wave manager / UI can react to it.
signal returning_home()

enum DeliveryState { IDLE, DELIVERING, RETURNING }

var state: DeliveryState = DeliveryState.IDLE
var current_snack: Snack = null
var target_customer: CustomerNPC = null
var target_island: Island = null
var home_island: Island = null

var _islands: Array[Island] = []

func is_delivering() -> bool:
	return state == DeliveryState.DELIVERING

func is_returning() -> bool:
	return state == DeliveryState.RETURNING

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
		return
	current_snack = snack
	target_customer = customer
	target_island = island
	state = DeliveryState.DELIVERING
	delivery_started.emit(snack, customer, island)

func complete_delivery() -> void:
	if not is_delivering():
		return
	var snack := current_snack
	current_snack = null
	target_customer = null
	target_island = null
	state = DeliveryState.RETURNING
	delivery_completed.emit(snack)
	returning_home.emit()

## Look up which customer (and island) wants the given snack.
## Returns an empty Dictionary when no customer wants it.
func get_npc_info_from_snack(snack: Snack) -> Dictionary:
	if snack == null:
		return {}
	for island in _islands:
		var customer := island.customer()
		if customer != null and customer.snack == snack:
			return {
				"npc_name": customer.npc_name,
				"island_name": island.display_name(),
				"island": island,
				"customer": customer,
			}
	return {}

## Name of the NPC the player must deliver to right now ("" when idle).
func get_delivery_target_name() -> String:
	return target_customer.npc_name if target_customer != null else ""

## Data for the delivery-info UI: who/where to deliver, or whether to return home.
func get_delivery_info() -> Dictionary:
	return {
		"state": state,
		"active": is_delivering() or is_returning(),
		"snack": current_snack,
		"target_npc_name": get_delivery_target_name(),
		"target_island_name": target_island.display_name() if target_island != null else "",
		"target_island": target_island,
		"returning_home": is_returning(),
	}

## Where waves should lead the player: the customer's island while delivering,
## the home island after the delivery is done.
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