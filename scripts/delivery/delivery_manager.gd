extends Node

signal delivery_started(snack: Snack, customer: NPC)
signal delivery_completed(snack: Snack)

var current_snack: Snack = null
var target_customer: NPC = null
var target_island: Island = null
var home_island: Island = null
var delivery_active: bool = false

func is_delivering() -> bool:
	return delivery_active

func start_delivery(snack: Snack, customer: NPC) -> void:
	if delivery_active or snack == null or customer == null:
		return
	current_snack = snack
	target_customer = customer
	target_island = _island_of(customer)
	delivery_active = true
	delivery_started.emit(snack, customer)

func complete_delivery() -> void:
	if not delivery_active:
		return
	var snack := current_snack
	current_snack = null
	target_customer = null
	target_island = null
	delivery_active = false
	delivery_completed.emit(snack)

## Where waves should lead the player: the customer's island while delivering,
## the home island after the delivery is done.
func target_position() -> Vector3:
	if delivery_active and is_instance_valid(target_island):
		return target_island.global_position
	if is_instance_valid(home_island):
		return home_island.global_position
	return Vector3.ZERO

func _island_of(customer: NPC) -> Island:
	var node: Node = customer
	while node != null:
		if node is Island:
			return node as Island
		node = node.get_parent()
	return null