extends Node

var _failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var level: Node = (load("res://scenes/final_level.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(level)
	await _wait(0.5)

	_check(DeliveryManager._islands.size() >= 3, "three islands registered")
	_check(DeliveryManager.home_island != null, "home island registered")

	var sandwich: Snack = load("res://resources/snacks/sardine_sandwich.tres")
	var info := DeliveryManager.get_npc_info_from_snack(sandwich)
	_check(not info.is_empty(), "sardine sandwich has a customer")
	if not info.is_empty():
		_check(info["npc_name"] == "Builder Otter", "customer is Builder Otter (got '%s')" % info["npc_name"])
		_check(info["island_name"] == "Customer Island 1", "customer island is Customer Island 1")

	var builder: CustomerNPC = null
	for island in DeliveryManager._islands:
		var customer := island.customer()
		if customer != null and customer.npc_name == "Builder Otter":
			builder = customer
			break
	_check(builder != null, "builder otter customer found via islands")
	if builder != null:
		DeliveryManager.start_delivery(sandwich, builder)
		_check(DeliveryManager.is_delivering(), "delivery starts")
		_check(DeliveryManager.get_delivery_target_name() == "Builder Otter", "delivery target named")
		_check(DeliveryManager.target_island.display_name() == "Customer Island 1", "delivery targets customer island")

	var plant_food: Snack = load("res://resources/snacks/plant_food.tres")
	_check(DeliveryManager.get_npc_info_from_snack(plant_food).is_empty(), "plant food has no customer yet (expected)")

	level.queue_free()
	await get_tree().physics_frame
	_reset_manager()
	if _failures.is_empty():
		print("ALL TESTS PASSED")
	else:
		print("FAILURES (%d):" % _failures.size())
		for f in _failures:
			print("  - " + f)
	get_tree().quit(_failures.size())

func _reset_manager() -> void:
	DeliveryManager.state = DeliveryManager.DeliveryState.IDLE
	DeliveryManager.current_snack = null
	DeliveryManager.target_customer = null
	DeliveryManager.target_island = null
	DeliveryManager.deliveries_completed = 0
	DeliveryManager.time_limit = 0.0
	DeliveryManager.time_remaining = 0.0
	DeliveryManager.home_island = null
	DeliveryManager._islands.clear()

func _wait(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await get_tree().physics_frame

func _check(condition: bool, label: String) -> void:
	if condition:
		print("ok   " + label)
	else:
		_failures.append(label)
		print("FAIL " + label)