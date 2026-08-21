extends Node

var _failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Node = (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(game)
	await _wait(0.5)
	var pause_menu: PauseMenu = game.get_node("PauseMenu")
	_check(pause_menu != null, "pause menu exists in game.tscn")
	_check(pause_menu.pause_action != null, "pause action wired")
	_check(pause_menu.guide_context != null, "guide context wired")
	_check(pause_menu.main_menu_scene == null, "main menu scene lazily loaded (no import cycle)")
	_check(load("res://scenes/ui/main_menu.tscn") != null, "main menu scene loads at runtime")
	_check(not pause_menu.visible, "pause menu hidden initially")
	_check(not get_tree().paused, "game not paused initially")

	# pause via the action
	_tap(pause_menu.pause_action)
	await get_tree().physics_frame
	_check(get_tree().paused, "pause action pauses the tree")
	_check(pause_menu.visible, "pause menu visible while paused")

	# resume via the button
	pause_menu.resume_button.emit_signal("pressed")
	await get_tree().physics_frame
	_check(not get_tree().paused, "resume button unpauses the tree")
	_check(not pause_menu.visible, "pause menu hidden after resume")

	# pause again, then unpause via the action (works while paused)
	_tap(pause_menu.pause_action)
	await get_tree().physics_frame
	_check(get_tree().paused, "pause action pauses again")
	_tap(pause_menu.pause_action)
	await get_tree().physics_frame
	_check(not get_tree().paused, "pause action resumes while paused")

	# settings panel opens and closes
	_tap(pause_menu.pause_action)
	await get_tree().physics_frame
	pause_menu.settings_button.emit_signal("pressed")
	await get_tree().physics_frame
	_check(pause_menu.settings_panel.visible, "settings panel opens while paused")
	pause_menu.settings_panel.back_button.emit_signal("pressed")
	await get_tree().physics_frame
	_check(not pause_menu.settings_panel.visible, "settings panel closes")
	pause_menu.resume_button.emit_signal("pressed")
	await get_tree().physics_frame
	_check(not get_tree().paused, "unpaused after settings round trip")

	game.queue_free()
	await get_tree().physics_frame
	if _failures.is_empty():
		print("ALL TESTS PASSED")
	else:
		print("FAILURES (%d):" % _failures.size())
		for f in _failures:
			print("  - " + f)
	get_tree().quit(_failures.size())

func _tap(action: GUIDEAction) -> void:
	action._triggered(Vector3.ONE, 1.0 / 60.0)
	action._completed(Vector3.ZERO)

func _wait(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await get_tree().physics_frame

func _check(condition: bool, label: String) -> void:
	if condition:
		print("ok   " + label)
	else:
		_failures.append(label)
		print("FAIL " + label)