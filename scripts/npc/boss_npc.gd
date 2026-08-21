extends NPC
class_name BossNPC

## Fired the first time the player talks to the boss. The level uses it to start the music.
signal first_dialogue_started(player: Node)

@export var snack_options: Array[Snack] = []
## Where a new snack pickup appears for the player to take.
@export var pickup_spawn_point: Node3D = null

var has_met := false

func _ready() -> void:
	super()
	# a timed delivery expired: clear any snack still waiting at the shop so
	# the next order can spawn a fresh pickup
	DeliveryManager.delivery_failed.connect(func(_snack: Snack, _customer: CustomerNPC) -> void:
		if pickup_spawn_point == null:
			return
		for child in pickup_spawn_point.get_children():
			if child is SnackPickup:
				child.queue_free()
	)

func on_interact(player: Node) -> void:
	var backpack := Backpack.from_player(player)
	if DeliveryManager.is_delivering() or (backpack != null and backpack.has_snack()):
		_talk(player, &"already_have_snack")
		return
	if snack_options.is_empty():
		_talk(player, &"not_configured")
		return
	var snack: Snack = snack_options.pick_random()
	var info := DeliveryManager.get_npc_info_from_snack(snack)
	if info.is_empty() or info["customer"] == null:
		_talk(player, &"not_configured")
		return
	DeliveryManager.start_delivery(snack, info["customer"])
	_spawn_pickup(snack)
	var first_meeting := not has_met
	has_met = true
	if first_meeting:
		first_dialogue_started.emit(player)
	_talk(player, &"take_this" if first_meeting else &"welcome_back")

func _spawn_pickup(snack: Snack) -> void:
	if pickup_spawn_point == null:
		return
	for child in pickup_spawn_point.get_children():
		if child is SnackPickup:
			return
	SnackPickup.spawn(snack, pickup_spawn_point, pickup_spawn_point.global_position)

func _default_dialogue_path() -> String:
	return "res://scenes/dialogue/boss.dialogue"
