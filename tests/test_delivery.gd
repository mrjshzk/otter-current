extends Node

var _failures: Array[String] = []
var _started := 0
var _completed := 0
var _failed := 0
var _last_time_limit := -1.0

var _home: Island
var _customer_island: Island
var _customer: CustomerNPC
var _snack: Snack

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await _setup()
	DeliveryManager.delivery_started.connect(func(_s: Snack, _c: CustomerNPC, _i: Island, limit: float) -> void:
		_started += 1
		_last_time_limit = limit
	)
	DeliveryManager.delivery_completed.connect(func(_s: Snack) -> void:
		_completed += 1
	)
	DeliveryManager.delivery_failed.connect(func(_s: Snack, _c: CustomerNPC) -> void:
		_failed += 1
	)

	# 1st and 2nd deliveries are untimed
	DeliveryManager.start_delivery(_snack, _customer)
	_check(DeliveryManager.is_delivering(), "delivery started")
	_check(not DeliveryManager.is_timed(), "first delivery is untimed")
	_check(_last_time_limit == 0.0, "first time_limit is 0")
	await _wait(0.2)
	_check(_failed == 0, "untimed delivery never times out")
	DeliveryManager.complete_delivery()
	_check(_completed == 1, "first delivery completed")
	_check(DeliveryManager.is_returning(), "returning home after delivery")
	_check(DeliveryManager.deliveries_completed == 1, "deliveries_completed incremented")

	DeliveryManager.start_delivery(_snack, _customer)
	_check(not DeliveryManager.is_timed(), "second delivery is untimed")
	DeliveryManager.complete_delivery()
	_check(DeliveryManager.deliveries_completed == 2, "two deliveries completed")

	# 3rd delivery onwards is timed, stepping down with each completion
	DeliveryManager.start_delivery(_snack, _customer)
	_check(DeliveryManager.is_timed(), "third delivery is timed")
	_check(is_equal_approx(_last_time_limit, DeliveryManager.first_time_limit), "third limit equals first_time_limit")
	DeliveryManager.complete_delivery()

	DeliveryManager.start_delivery(_snack, _customer)
	_check(is_equal_approx(_last_time_limit, DeliveryManager.first_time_limit - DeliveryManager.time_limit_step_down), "fourth limit steps down")

	# timeout expires the delivery
	DeliveryManager.time_remaining = 0.05
	await _wait(0.3)
	_check(_failed == 1, "timeout emitted delivery_failed")
	_check(not DeliveryManager.is_delivering(), "state reset after timeout")
	_check(DeliveryManager.time_limit == 0.0 and DeliveryManager.time_remaining == 0.0, "timers zeroed after timeout")

	# countdown pauses while a dialogue is open
	DeliveryManager.start_delivery(_snack, _customer)
	DeliveryManager._dialogue_open = true
	DeliveryManager.time_remaining = 0.05
	await _wait(0.3)
	_check(_failed == 1, "no timeout while dialogue is open")
	_check(DeliveryManager.time_remaining > 0.0, "countdown frozen during dialogue")
	DeliveryManager._dialogue_open = false
	DeliveryManager.time_remaining = 0.05
	await _wait(0.3)
	_check(_failed == 2, "timeout resumes after dialogue")

	_teardown()
	if _failures.is_empty():
		print("ALL TESTS PASSED")
	else:
		print("FAILURES (%d):" % _failures.size())
		for f in _failures:
			print("  - " + f)
	get_tree().quit(_failures.size())

func _setup() -> void:
	_snack = Snack.new()
	_snack.snack_name = "Test Snack"
	_customer = CustomerNPC.new()
	_customer.npc_name = "TestNpc"
	_customer.snack = _snack
	var home_res := IslandResource.new()
	home_res.island_name = "Home"
	home_res.is_home = true
	_home = Island.new()
	_home.resource = home_res
	var customer_res := IslandResource.new()
	customer_res.island_name = "Target"
	customer_res.customer = _customer
	_customer_island = Island.new()
	_customer_island.resource = customer_res
	get_tree().root.add_child(_home)
	get_tree().root.add_child(_customer_island)
	await get_tree().physics_frame

func _teardown() -> void:
	DeliveryManager.state = DeliveryManager.DeliveryState.IDLE
	DeliveryManager.current_snack = null
	DeliveryManager.target_customer = null
	DeliveryManager.target_island = null
	DeliveryManager.home_island = null
	DeliveryManager.deliveries_completed = 0
	DeliveryManager.time_limit = 0.0
	DeliveryManager.time_remaining = 0.0
	DeliveryManager._dialogue_open = false
	DeliveryManager._islands.clear()
	_home.queue_free()
	_customer_island.queue_free()

func _wait(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await get_tree().physics_frame

func _check(condition: bool, label: String) -> void:
	if condition:
		print("ok   " + label)
	else:
		_failures.append(label)
		print("FAIL " + label)