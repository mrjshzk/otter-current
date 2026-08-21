extends Node

var _failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var level: Node3D = (load("res://prototype_level.tscn") as PackedScene).instantiate()
	level.get_node("WaveSpawner").initial_waves = 0
	get_tree().root.add_child(level)
	var spawner: WaveSpawner = level.get_node("WaveSpawner")
	spawner.spawn_interval = 999.0
	var player: Player = level.get_node("Player")
	var im: InteractionManager = player.get_node("InteractionManager")
	await _wait(0.2)

	# --- snack pickup: highlight + prompt on its own nodes ---
	var snack: Snack = load("res://scenes/core_loop_prototype/test_snack.tres")
	var pickup := SnackPickup.new()
	pickup.snack = snack
	level.add_child(pickup)
	pickup.global_position = player.global_position
	var collider := CollisionShape3D.new()
	collider.shape = SphereShape3D.new()
	pickup.add_child(collider)
	await _wait(0.3)
	_check(im._current_target == pickup, "pickup becomes interaction target")
	_check(pickup.prompt_label != null and pickup.prompt_icon != null, "runtime pickup has prompt nodes")
	_check(pickup.prompt_label.visible, "prompt visible near pickup")
	_check(pickup.prompt_label.text == "Pick up Test Snack", "prompt text for pickup")

	# --- taking the pickup frees it: no crash, prompt hidden, target cleared ---
	var backpack := Backpack.from_player(player)
	_check(backpack.add_snack(snack), "snack added to backpack")
	pickup.queue_free()
	await _wait(0.3)
	_check(im._current_target == null, "freed pickup cleared from target")
	_check(backpack.remove_snack() != null, "snack dropped from backpack")

	# --- NPC: talk prompt on its own nodes ---
	var npc: NPC = (load("res://scenes/core_loop_prototype/test_npc.tscn") as PackedScene).instantiate()
	npc.npc_name = "TestNpc"
	level.add_child(npc)
	npc.global_position = player.global_position + Vector3(0.8, 0, 0)
	await _wait(0.3)
	_check(im._current_target == npc, "npc becomes interaction target")
	_check(npc.prompt_label != null and npc.prompt_icon != null, "npc has prompt nodes wired")
	_check(npc.prompt_label.visible, "prompt visible near npc")
	_check(npc.prompt_label.text == "Talk to TestNpc", "talk prompt text")

	# --- carrying the right snack switches to the deliver prompt ---
	var customer := npc.customer
	_check(customer != null, "npc has customer resource")
	_check(backpack.add_snack(customer.snack), "backpack carries customer snack")
	await _wait(0.2)
	_check(npc.prompt_label.text == "Deliver Test Snack to TestNpc", "deliver prompt text")

	# --- dialogue hides the prompt, ending restores it ---
	DialogueManager.dialogue_started.emit(npc.dialogue)
	await _wait(0.1)
	_check(not npc.prompt_label.visible, "prompt hidden during dialogue")
	DialogueManager.dialogue_ended.emit(npc.dialogue)
	await _wait(0.2)
	_check(npc.prompt_label.visible, "prompt restored after dialogue")

	level.queue_free()
	await get_tree().physics_frame
	if _failures.is_empty():
		print("ALL TESTS PASSED")
	else:
		print("FAILURES (%d):" % _failures.size())
		for f in _failures:
			print("  - " + f)
	get_tree().quit(_failures.size())

func _wait(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await get_tree().physics_frame

func _check(condition: bool, label: String) -> void:
	if condition:
		print("ok   " + label)
	else:
		_failures.append(label)
		print("FAIL " + label)