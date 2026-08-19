extends NPC
class_name BossNPC

@export var snack_options: Array[Snack] = []
## Where a new snack pickup appears for the player to take.
@export var pickup_spawn_point: Node3D = null
## The customer the player has to deliver the assigned snack to.
@export var target_customer: NPC = null

func _ready() -> void:
	super()
	if DeliveryManager.home_island == null and get_parent() is Island:
		DeliveryManager.home_island = get_parent() as Island

func on_interact(player: Node) -> void:
	var backpack := Backpack.from_player(player)
	if DeliveryManager.is_delivering() or (backpack != null and backpack.has_snack()):
		_talk(player, &"already_have_snack")
		return
	if target_customer == null or snack_options.is_empty():
		_talk(player, &"not_configured")
		return
	var snack: Snack = snack_options.pick_random()
	DeliveryManager.start_delivery(snack, target_customer)
	_spawn_pickup(snack)
	_talk(player, &"take_this")

func _spawn_pickup(snack: Snack) -> void:
	if pickup_spawn_point == null:
		return
	for child in pickup_spawn_point.get_children():
		if child is SnackPickup:
			return
	SnackPickup.spawn(snack, pickup_spawn_point, pickup_spawn_point.global_position)
