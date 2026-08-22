extends Node

var _failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var level: Node3D = (load("res://prototype_level.tscn") as PackedScene).instantiate()
	level.get_node("WaveSpawner").initial_waves = 0
	get_tree().root.add_child(level)
	var spawner: TargetWaveManager = level.get_node("WaveSpawner")
	spawner.spawn_interval = 999.0
	var player: Player = level.get_node("Player")
	await get_tree().physics_frame
	await get_tree().physics_frame

	_check(player != null, "player ready")
	_check(player.get_node("%IdleState") != null, "state nodes resolved")

	await _wait(1.5)
	_check(player.water_movement._active_state == player.idle_state, "settled in idle")
	_check(absf(player.global_position.y + 0.25) < 0.05, "idle bobs at swim depth")
	_check(player.animation_player.current_animation == "otter_swim", "swim animation while in water")

	_tap(player.jump_action)
	await get_tree().physics_frame
	_check(player.air_movement._active_state == player.rising_state, "jump -> rising")
	_check(player.animation_player.current_animation == "otter_surfjump", "surfjump animation while jumping")
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
	await _wait(0.5)
	await _hold(player.dive_action, 0.15)
	_check(player.air_movement._active_state == player.diving_state, "air dive -> diving")
	player.dive_action._completed(Vector3.ZERO)
	await _wait(1.0)
	_check(player.water_movement._active_state == player.idle_state, "splash dive returns to water")
	_check(player.global_position.y > -0.9, "splash dive stays shallow (y=%.2f)" % player.global_position.y)

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
	_check(player.animation_player.current_animation == "otter_surf", "surf animation while riding")
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

	# dive-jump chain: the combo on landing keeps momentum (crouch-jump)
	player.walk_action._completed(Vector3.ZERO)
	player.current_velocity = Vector3.ZERO
	await _wait(0.2)
	var chain_wave: OceanCurrent = wave_scene.instantiate()
	level.add_child(chain_wave)
	await get_tree().physics_frame
	chain_wave.global_position = player.global_position
	chain_wave.wave_direction = Vector3(0, 0, -1)
	chain_wave.speed = 8.0
	await _wait(0.3)
	_check(player.inside_wave_movement._active_state == player.riding_state, "riding for chain test")
	_tap(player.jump_action)
	await _wait_until_landing(player)
	_tap(player.dive_action)
	_tap(player.jump_action)
	await get_tree().physics_frame
	_check(player.air_movement._active_state == player.rising_state, "combo chains from landing")
	_check(player._horizontal_speed() > 8.0, "combo chain keeps speed %.1f m/s" % player._horizontal_speed())

	# glide-arm the next combo: tap Ctrl while gliding, then jump
	await _wait_until_landing(player)
	await _wait(0.3)
	_check(player.water_movement._active_state == player.idle_state, "back in water for glide arm")
	await _hold(player.dive_action, 0.1)
	player.dive_action._completed(Vector3.ZERO)
	_tap(player.jump_action)
	await get_tree().physics_frame
	_check(player.air_movement._active_state == player.rising_state, "second combo chains")
	var combo_speed := player._horizontal_speed()
	_check(combo_speed > 6.5, "second combo keeps speed %.1f m/s" % combo_speed)

	# plain hop on landing: weak retention, momentum bleeds and needs a new wave
	await _wait_until_landing(player)
	_tap(player.jump_action)
	await get_tree().physics_frame
	_check(player.air_movement._active_state == player.rising_state, "plain hop after combos")
	var chained_speed := player._horizontal_speed()
	_check(chained_speed < combo_speed * 0.65, "plain hop decays speed (%.1f m/s)" % chained_speed)
	_check(chained_speed > 2.5, "plain hop keeps a little speed (%.1f m/s)" % chained_speed)
	await _hold_walk(player, 1.2)
	player.walk_action._completed(Vector3.ZERO)
	chain_wave.queue_free()
	ride_wave.queue_free()
	await _wait(0.5)
	_check(player.water_movement._active_state == player.idle_state, "settled after momentum test")

	# fast dive in water: stays gliding (no bob, no submerge) and arms the next jump
	var glide_wave: OceanCurrent = wave_scene.instantiate()
	level.add_child(glide_wave)
	await get_tree().physics_frame
	glide_wave.global_position = player.global_position
	glide_wave.wave_direction = Vector3(0, 0, -1)
	glide_wave.speed = 8.0
	await _wait(0.3)
	_check(player.inside_wave_movement._active_state == player.riding_state, "riding for glide-dive test")
	player.walk_action._triggered(Vector3(0, -1, 0), 1.0 / 60.0)
	_tap(player.jump_action)
	await _wait(0.9)
	_check(player.water_movement._active_state == player.idle_state
		or player.water_movement._active_state == player.moving_state, "landed fast for glide-dive test")
	_check(player._horizontal_speed() > 7.0, "gliding fast (%.1f m/s)" % player._horizontal_speed())
	await _hold(player.dive_action, 0.3)
	_check(player.water_movement._active_state == player.idle_state
		or player.water_movement._active_state == player.moving_state, "fast dive keeps gliding (no bob)")
	_check(player.water_movement._active_state != player.submerged_state, "fast dive does not submerge")
	_check(player._horizontal_speed() > 5.0, "fast dive keeps momentum (%.1f m/s)" % player._horizontal_speed())
	player.dive_action._completed(Vector3.ZERO)
	_tap(player.jump_action)
	await get_tree().physics_frame
	_check(player.air_movement._active_state == player.rising_state, "armed glide dive -> strong hop")
	_check(player._horizontal_speed() > 5.0, "armed hop keeps momentum (%.1f m/s)" % player._horizontal_speed())

	# dive is suppressed until the hop peaks, then a held dive takes over
	await _hold(player.dive_action, 0.25)
	_check(player.air_movement._active_state == player.rising_state, "dive suppressed until peak (still rising)")
	await _hold(player.dive_action, 0.25)
	_check(player.air_movement._active_state == player.diving_state, "held dive fires after the peak")
	player.dive_action._completed(Vector3.ZERO)
	await _wait(1.0)
	_check(player.water_movement._active_state == player.idle_state
		or player.water_movement._active_state == player.moving_state, "peak dive splashed back to water")
	await _hold_walk(player, 1.2)
	player.walk_action._completed(Vector3.ZERO)
	glide_wave.queue_free()
	await _wait(0.5)

	# slow dive in water still submerges (the original gentle dive)
	player.current_velocity = Vector3.ZERO
	await _wait(0.2)
	await _hold(player.dive_action, 0.2)
	_check(player.water_movement._active_state == player.submerged_state, "slow dive submerges")
	_check(player.global_position.y < -0.4, "slow dive dips below water (y=%.2f)" % player.global_position.y)
	player.dive_action._completed(Vector3.ZERO)
	await _wait(2.5)
	_check(player.water_movement._active_state == player.idle_state, "slow dive surfaced")

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

	# ride stability: a ride persists on its own without flickering out
	var stable_wave: OceanCurrent = wave_scene.instantiate()
	level.add_child(stable_wave)
	await get_tree().physics_frame
	stable_wave.global_position = player.global_position
	stable_wave.wave_direction = Vector3(0, 0, -1)
	stable_wave.speed = 8.0
	await _wait(0.3)
	_check(player.inside_wave_movement._active_state == player.riding_state, "riding for stability test")
	await _wait(1.7)
	_check(player.inside_wave_movement._active_state == player.riding_state, "ride persists without flicker (2s)")

	# transfer: a faster wave catching up must hand the ride over, not drop it
	var chaser: OceanCurrent = wave_scene.instantiate()
	level.add_child(chaser)
	await get_tree().physics_frame
	chaser.global_position = stable_wave.global_position + Vector3(0, 0, 4)
	chaser.wave_direction = Vector3(0, 0, -1)
	chaser.speed = 12.0
	await _wait(2.0)
	_check(player.inside_wave_movement._active_state == player.riding_state, "faster wave transfer keeps riding")
	stable_wave.queue_free()
	chaser.queue_free()
	await _wait(0.9)
	_check(player.water_movement._active_state == player.idle_state, "back to water after stability waves")
	player.current_velocity = Vector3.ZERO
	await _wait(0.2)

	# any dive in the air is a committed splash dive (no windup threshold)
	_tap(player.jump_action)
	await _wait(0.5)
	_check(player.air_movement._active_state == player.falling_state, "airborne for splash test")
	await _hold(player.dive_action, 0.05)
	_check(player.air_movement._active_state == player.diving_state, "brief dive dives immediately")
	player.dive_action._completed(Vector3.ZERO)
	await _wait(1.0)
	_check(player.water_movement._active_state == player.idle_state, "splash dive landed in water")
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

	# --- land moveset (automatic) ---
	# landing on solid ground above the water auto-switches to the land moveset
	player.global_position = Vector3(2.0, -0.25, 1.0)
	player.current_velocity = Vector3.ZERO
	await _wait(0.5)
	_tap(player.jump_action)
	await get_tree().physics_frame
	_check(player.air_movement._active_state == player.rising_state, "jump from water for land switch")
	player.global_position = Vector3(2.0, 1.5, 2.2)
	await _wait(1.5)
	_check(player.land._active_state == player.idle_land, "auto-switched to land on platform")
	_check(player.in_sea == false, "in_sea flag flips to land")
	_check(player.is_on_floor(), "landed on the platform")
	_check(player.animation_player.current_animation == "otter_idle", "land idle animation")

	# walk forward (+X) on the platform
	await _hold_walk(player, 0.6, Vector3(1, 0, 0))
	_check(player.land._active_state == player.walk_land, "walk state entered")
	_check(player.animation_player.current_animation == "otter_walk", "walk animation")
	_check(player._horizontal_speed() > 2.0, "walking moves (%.1f m/s)" % player._horizontal_speed())
	player.walk_action._completed(Vector3.ZERO)
	await _wait(0.3)
	_check(player.land._active_state == player.idle_land, "input released -> idle")
	_check(player.animation_player.current_animation == "otter_idle", "land idle animation after stop")
	_check(player._horizontal_speed() < 0.1, "stopped on land")

	# walk off the platform edge -> falls into the sea -> auto-switch back to water
	await _hold_walk(player, 0.6)
	_check(player.global_position.z < 1.7, "walked off the platform edge (z=%.2f)" % player.global_position.z)
	await _wait(1.8)
	_check(player.in_sea == true, "auto-switched back to sea after falling in")
	_check(player.water_movement._active_state == player.idle_state
		or player.water_movement._active_state == player.moving_state, "swimming in the water again")
	_check(absf(player.global_position.y + 0.25) < 0.2, "bobbing at swim depth after fall (y=%.2f)" % player.global_position.y)
	_check(player.animation_player.current_animation == "otter_swim", "swim animation after falling in")
	player.walk_action._completed(Vector3.ZERO)
	player.current_velocity = Vector3.ZERO

	# shallow shore: swimming over ground just under the surface switches to land and STAYS
	player.shore_tolerance = 0.5
	var beach := StaticBody3D.new()
	beach.name = "Beach"
	level.add_child(beach)
	var beach_collider := CollisionShape3D.new()
	var beach_box := BoxShape3D.new()
	beach_box.size = Vector3(4.0, 0.2, 4.0)
	beach_collider.shape = beach_box
	beach.add_child(beach_collider)
	beach.global_position = Vector3(2.0, -0.45, 12.0)
	player.global_position = Vector3(2.0, -0.25, 12.0)
	player.current_velocity = Vector3.ZERO
	await _wait(1.5)
	_check(player.land._active_state == player.idle_land, "shallow shore switches to land")
	_check(player.in_sea == false, "shallow shore stays on land (no flicker)")
	_check(player.is_on_floor(), "standing on the shallow shore")
	await _wait(0.5)
	_check(player.land._active_state == player.idle_land, "shallow shore switch is stable")
	_check(player.animation_player.current_animation == "otter_idle", "shore land idle animation")

	# walk off the shore -> falls back into the sea
	await _hold_walk(player, 0.8)
	player.walk_action._completed(Vector3.ZERO)
	await _wait(1.5)
	_check(player.in_sea == true, "walked off shore back to sea")
	_check(player.water_movement._active_state == player.idle_state, "swimming after leaving shore")
	player.shore_tolerance = 0.3
	beach.queue_free()

	# wave collision checker: a wave driving into the platform dies and force-jumps the rider
	player.global_position = Vector3(4.83, -0.25, 18.0)
	player.current_velocity = Vector3.ZERO
	await _wait(0.5)
	var collision_wave: OceanCurrent = wave_scene.instantiate()
	level.add_child(collision_wave)
	await get_tree().physics_frame
	collision_wave.global_position = player.global_position
	collision_wave.wave_direction = Vector3(0, 0, -1)
	collision_wave.speed = 8.0
	await _wait(0.3)
	_check(player.inside_wave_movement._active_state == player.riding_state, "riding wave toward platform")
	var freed := false
	var force_jumped := false
	for i in int(2.0 * 60.0):
		if not is_instance_valid(collision_wave):
			freed = true
		if player.air_movement._active_state == player.leap_state:
			force_jumped = true
		if freed and force_jumped:
			break
		await get_tree().physics_frame
	_check(freed, "wave destroyed by platform collision")
	_check(force_jumped, "rider force-jumped into leap")
	await get_tree().physics_frame
	_check(player.inside_wave_movement._active_state != player.riding_state, "rider not riding after collision")

	# marginal ground (top between -0.3 and -0.2) used to ping-pong land/sea
	var osc_box := StaticBody3D.new()
	osc_box.name = "OscBox"
	level.add_child(osc_box)
	var osc_collider := CollisionShape3D.new()
	var osc_shape := BoxShape3D.new()
	osc_shape.size = Vector3(4.0, 0.5, 4.0)
	osc_collider.shape = osc_shape
	osc_box.add_child(osc_collider)
	osc_box.global_position = Vector3(8.0, -0.5, 14.0)
	player.global_position = Vector3(8.0, -0.05, 14.0)
	player.current_velocity = Vector3.ZERO
	player.root_state_chart.send_event(&"to_in_land")
	player.in_sea = false
	await _wait(1.5)
	_check(player.land._active_state == player.idle_land, "marginal ground settles on land")
	var sea_events := 0
	player.root_state_chart.event_received.connect(func(event: StringName) -> void:
		if event == &"to_in_sea":
			sea_events += 1
	)
	await _wait(2.0)
	_check(sea_events == 0, "no land/sea oscillation on marginal ground (%d to_in_sea)" % sea_events)
	_check(player.in_sea == false, "still on land after oscillation window")
	osc_box.queue_free()

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

func _hold_walk(player: Player, seconds: float, input: Vector3 = Vector3(0, -1, 0)) -> void:
	for i in int(seconds * 60.0):
		player.walk_action._triggered(input, 1.0 / 60.0)
		await get_tree().physics_frame

func _wait(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await get_tree().physics_frame

func _wait_until_landing(player: Player) -> void:
	for i in int(1.5 * 60.0):
		if player.air_movement._active_state == player.landing_state:
			return
		await get_tree().physics_frame

func _check(condition: bool, label: String) -> void:
	if condition:
		print("ok   " + label)
	else:
		_failures.append(label)
		print("FAIL " + label)