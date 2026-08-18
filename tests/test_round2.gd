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
	level.get_node("Current").queue_free()
	var player: Player = level.get_node("Player")
	await get_tree().physics_frame
	await get_tree().physics_frame

	_check(player != null, "player ready")
	_check(player.get_node("%IdleState") != null, "state nodes resolved")

	await _wait(1.5)
	_check(player.water_movement._active_state == player.idle_state, "settled in idle")
	_check(absf(player.global_position.y + 0.25) < 0.05, "idle bobs at swim depth")

	_tap(player.jump_action)
	await get_tree().physics_frame
	_check(player.air_movement._active_state == player.rising_state, "jump -> rising")
	await _wait(2.0)
	_check(player.water_movement._active_state == player.idle_state, "jump landed back to idle")
	_tap(player.jump_action)
	await get_tree().physics_frame
	_check(player.air_movement._active_state == player.rising_state, "RE-JUMP WORKS (bug fixed)")
	await _wait(2.0)
	_check(player.water_movement._active_state == player.idle_state, "re-jump landed")

	await _hold(player.dive_action, 0.2)
	_check(player.water_movement._active_state == player.submerged_state, "dive -> submerged")
	_check(player.global_position.y < -0.4, "submerged dips below water")
	player.dive_action._completed(Vector3.ZERO)
	await _wait(2.0)
	_check(player.water_movement._active_state == player.idle_state, "buoyancy surfaced to idle")
	_check(absf(player.global_position.y + 0.25) < 0.1, "idle y restored")

	_tap(player.jump_action)
	await get_tree().physics_frame
	await _wait(0.4)
	await _hold(player.dive_action, 0.05)
	_check(player.air_movement._active_state == player.diving_state, "air dive -> diving")
	await _hold(player.dive_action, 0.4)
	_check(player.water_movement._active_state == player.submerged_state, "splash -> submerged")
	_check(player.global_position.y < -0.9, "splash dive goes deeper than water dive")
	player.dive_action._completed(Vector3.ZERO)
	await _wait(2.5)
	_check(player.water_movement._active_state == player.idle_state, "resurfaced after splash")

	var wave_scene: PackedScene = load("res://scenes/current/current.tscn")

	# mid-air catch: a wave passing under a jumping player grabs them
	_tap(player.jump_action)
	await get_tree().physics_frame
	await _wait(0.3)
	_check(player.air_movement._active_state != null, "player is airborne")
	var air_wave: OceanCurrent = wave_scene.instantiate()
	level.add_child(air_wave)
	await get_tree().physics_frame
	air_wave.global_position = Vector3(player.global_position.x, 0.0, player.global_position.z)
	air_wave.wave_direction = Vector3(0, 0, -1)
	air_wave.speed = 8.0
	await _wait(0.3)
	_check(player.inside_wave_movement._active_state == player.riding_state, "caught wave mid-air")
	air_wave.queue_free()
	await _wait(0.9)
	_check(player.water_movement._active_state == player.idle_state, "back to water after air catch")
	player.current_velocity = Vector3.ZERO
	await _wait(0.2)

	# a wave traveling toward the player is caught on arrival (no phasing)
	var approach_wave: OceanCurrent = wave_scene.instantiate()
	level.add_child(approach_wave)
	await get_tree().physics_frame
	approach_wave.global_position = player.global_position + Vector3(0, 0, 12)
	approach_wave.wave_direction = Vector3(0, 0, -1)
	approach_wave.speed = 10.0
	await _wait(2.0)
	_check(player.inside_wave_movement._active_state == player.riding_state, "moving wave caught on arrival")
	approach_wave.queue_free()
	await _wait(0.9)
	_check(player.water_movement._active_state == player.idle_state, "back to water after approach wave")
	player.current_velocity = Vector3.ZERO
	await _wait(0.2)

	# wave jump-off: forward dive leap with momentum
	var ride_wave: OceanCurrent = wave_scene.instantiate()
	level.add_child(ride_wave)
	await get_tree().physics_frame
	ride_wave.global_position = player.global_position
	ride_wave.wave_direction = Vector3(0, 0, -1)
	ride_wave.speed = 8.0
	await _wait(0.3)
	_check(player.inside_wave_movement._active_state == player.riding_state, "riding for leap test")
	player.walk_action._triggered(Vector3(0, -1, 0), 1.0 / 60.0)
	_tap(player.jump_action)
	await get_tree().physics_frame
	_check(player.air_movement._active_state == player.leap_state, "jump-off -> leap state")
	_check(player._horizontal_speed() > 12.0, "leap launch speed %.1f m/s" % player._horizontal_speed())
	var apex_y := player.global_position.y
	for i in int(0.3 * 60.0):
		player.walk_action._triggered(Vector3(0, -1, 0), 1.0 / 60.0)
		await get_tree().physics_frame
		apex_y = maxf(apex_y, player.global_position.y)
	_check(rad_to_deg(player.global_rotation.x) < -15.0, "leap dives forward (pitch %.0f)" % rad_to_deg(player.global_rotation.x))
	for i in int(0.15 * 60.0):
		player.walk_action._triggered(Vector3(0, -1, 0), 1.0 / 60.0)
		await get_tree().physics_frame
		apex_y = maxf(apex_y, player.global_position.y)
	_check(player._horizontal_speed() > 14.8, "aligned input boosts in air (%.1f m/s)" % player._horizontal_speed())
	for i in int(0.3 * 60.0):
		player.walk_action._triggered(Vector3(0, -1, 0), 1.0 / 60.0)
		await get_tree().physics_frame
		apex_y = maxf(apex_y, player.global_position.y)
	_check(apex_y > 1.9, "leap rises higher (apex %.2f)" % apex_y)
	await _hold_walk(player, 0.9)
	_check(player.water_movement._active_state == player.idle_state
		or player.water_movement._active_state == player.moving_state, "jump-off landed")
	_check(player._horizontal_speed() > 8.0, "momentum kept after landing (%.1f m/s)" % player._horizontal_speed())
	await _hold_walk(player, 0.5)
	_check(player._horizontal_speed() > 8.0, "momentum kept while steering (%.1f m/s)" % player._horizontal_speed())

	# bunnyhop chain: jump right after landing keeps momentum
	_tap(player.jump_action)
	await get_tree().physics_frame
	_check(player.air_movement._active_state == player.rising_state, "re-jump chains from landing")
	_check(player._horizontal_speed() > 8.0, "chain keeps speed %.1f m/s" % player._horizontal_speed())
	await _hold_walk(player, 1.2)
	_check(player.water_movement._active_state == player.idle_state
		or player.water_movement._active_state == player.moving_state, "chain landed")
	_check(player._horizontal_speed() > 6.5, "chain speed after second hop (%.1f m/s)" % player._horizontal_speed())

	# bunnyhop chains bleed speed gradually: another wave is needed eventually
	_tap(player.jump_action)
	await get_tree().physics_frame
	_check(player.air_movement._active_state == player.rising_state, "third hop chains")
	await _hold_walk(player, 1.2)
	_check(player.water_movement._active_state == player.idle_state
		or player.water_movement._active_state == player.moving_state, "third hop landed")
	var chained_speed := player._horizontal_speed()
	_check(chained_speed > 3.0 and chained_speed < 9.5, "chain decays gradually (%.1f m/s)" % chained_speed)
	player.walk_action._completed(Vector3.ZERO)
	ride_wave.queue_free()
	await _wait(0.5)
	_check(player.water_movement._active_state == player.idle_state, "settled after momentum test")

	# air steering: holding input turns the flight at speed
	player.current_velocity = Vector3.ZERO
	await _wait(0.2)
	var steer_wave: OceanCurrent = wave_scene.instantiate()
	level.add_child(steer_wave)
	await get_tree().physics_frame
	steer_wave.global_position = player.global_position
	steer_wave.wave_direction = Vector3(0, 0, -1)
	steer_wave.speed = 8.0
	await _wait(0.3)
	_check(player.inside_wave_movement._active_state == player.riding_state, "riding for steer test")
	var before_dir: Vector3 = Vector3(player.current_velocity.x, 0, player.current_velocity.z).normalized()
	player.walk_action._triggered(Vector3(-1, 0, 0), 1.0 / 60.0)
	_tap(player.jump_action)
	for i in int(0.4 * 60.0):
		player.walk_action._triggered(Vector3(-1, 0, 0), 1.0 / 60.0)
		await get_tree().physics_frame
	var after_dir: Vector3 = Vector3(player.current_velocity.x, 0, player.current_velocity.z).normalized()
	var turn_deg := rad_to_deg(before_dir.signed_angle_to(after_dir, Vector3.UP))
	_check(absf(turn_deg) > 30.0, "air steer turns flight (%.0f deg)" % turn_deg)
	player.walk_action._completed(Vector3.ZERO)
	steer_wave.queue_free()
	await _wait(0.9)
	_check(player.water_movement._active_state == player.idle_state, "back to water after steer test")
	player.current_velocity = Vector3.ZERO
	await _wait(0.2)

	# fast wave: the leap boost is big but capped at max_speed
	var fast_wave: OceanCurrent = wave_scene.instantiate()
	level.add_child(fast_wave)
	await get_tree().physics_frame
	fast_wave.global_position = player.global_position
	fast_wave.wave_direction = Vector3(0, 0, -1)
	fast_wave.speed = 13.0
	await _wait(0.3)
	_check(player.inside_wave_movement._active_state == player.riding_state, "riding fast wave")
	player.walk_action._triggered(Vector3(0, -1, 0), 1.0 / 60.0)
	_tap(player.jump_action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(player.air_movement._active_state == player.leap_state, "fast wave jump-off")
	_check(player._horizontal_speed() <= 20.01, "launch capped at max_speed (%.1f m/s)" % player._horizontal_speed())
	_check(player._horizontal_speed() > 18.0, "fast wave gets big boost (%.1f m/s)" % player._horizontal_speed())
	player.walk_action._completed(Vector3.ZERO)
	fast_wave.queue_free()
	await _wait(1.0)

	# normal hop from swimming keeps weak air control (no fast-path steering/boost)
	player.current_velocity = Vector3.ZERO
	await _wait(0.2)
	_tap(player.jump_action)
	await get_tree().physics_frame
	for i in int(0.5 * 60.0):
		player.walk_action._triggered(Vector3(-1, 0, 0), 1.0 / 60.0)
		await get_tree().physics_frame
	_check(player._horizontal_speed() < 7.0, "normal hop keeps weak control (%.1f m/s)" % player._horizontal_speed())
	player.walk_action._completed(Vector3.ZERO)
	await _wait(0.9)
	player.current_velocity = Vector3.ZERO
	await _wait(0.2)

	# spawner: counts, distances, and always at sea level even while the player is airborne
	player.global_position = Vector3(0, 2, 0)
	spawner.spawn_interval = 0.1
	await _wait(0.4)
	_check(spawner.get_child_count() >= 2, "spawner creates waves")
	for spawned_wave: OceanCurrent in spawner.get_children():
		var dist: float = spawned_wave.global_position.distance_to(player.global_position)
		_check(dist >= 14.0 and dist <= 41.0, "wave spawn distance %d" % dist)
		_check(absf(spawned_wave.global_position.y) < 0.001, "wave spawned at sea level (y=0)")

	spawner.queue_free()
	level.queue_free()
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

func _hold(action: GUIDEAction, seconds: float) -> void:
	for i in int(seconds * 60.0):
		action._triggered(Vector3.ONE, 1.0 / 60.0)
		await get_tree().physics_frame

func _hold_walk(player: Player, seconds: float) -> void:
	for i in int(seconds * 60.0):
		player.walk_action._triggered(Vector3(0, -1, 0), 1.0 / 60.0)
		await get_tree().physics_frame

func _wait(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await get_tree().physics_frame

func _check(condition: bool, label: String) -> void:
	if condition:
		print("ok   " + label)
	else:
		_failures.append(label)
		print("FAIL " + label)