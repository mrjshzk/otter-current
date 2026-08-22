extends CharacterBody3D
class_name Player

@export_category("Input")
@export var guide_context: GUIDEMappingContext
@export var walk_action: GUIDEAction
@export var dive_action: GUIDEAction
@export var jump_action: GUIDEAction
@export var pause_action: GUIDEAction

@onready var root_state_chart: StateChart = %RootStateChart
@onready var animation_player: AnimationPlayer = %AnimationPlayer

@onready var water_movement: CompoundState = %WaterMovement
@onready var idle_state: AtomicState = %IdleState
@onready var moving_state: AtomicState = %MovingState
@onready var submerged_state: AtomicState = %SubmergedState

@onready var air_movement: CompoundState = %AirMovement
@onready var rising_state: AtomicState = %RisingState
@onready var falling_state: AtomicState = %FallingState
@onready var landing_state: AtomicState = %LandingState
@onready var diving_state: AtomicState = %DivingState
@onready var leap_state: AtomicState = %LeapState

@onready var inside_wave_movement: CompoundState = %InsideWaveMovement
@onready var riding_state: AtomicState = %RidingState
@onready var jump_off_state: AtomicState = %JumpOffState

@onready var land: CompoundState = %Land
@onready var idle_land: AtomicState = %IdleLandState
@onready var walk_land: AtomicState = %WalkLandState

@onready var camera_rig: CameraRig = %CameraRig

@export_category("Water")
@export var water_level_y: float = 0.0
@export var submerge_offset: float = 0.25
@export var buoyancy_lift_speed: float = 4.0
@export var swim_speed: float = 2.5
@export var acceleration: float = 11.0
@export var deceleration: float = 8.0

@export_category("Air")
@export var gravity: float = 18.0
@export var jump_velocity: float = 7.5
@export var air_control: float = 1.5
@export var air_control_max_speed: float = 4.0
@export var air_control_min_speed: float = 8.0
@export var air_steer: float = 5.0
@export var air_steer_speed_threshold: float = 12.0
@export var air_boost_max_speed: float = 16.0
@export var air_boost_rate: float = 3.0
@export var air_drag: float = 0.05

@export_category("Diving")
@export var allow_underwater_dive: bool = true
@export var dive_velocity: float = -9.0
@export var underwater_dive_velocity: float = -3.5
@export var wave_dive_velocity: float = -5.5
@export var underwater_dive_buoyancy: float = 14.0
@export var underwater_dive_max_speed: float = 5.0

@export_category("Waves")
@export var jump_off_speed_multiplier: float = 1.5
@export var jump_off_directional_boost: float = 3.0
@export var leap_velocity_y: float = 3.0
@export var hop_speed_retention: float = 0.6
@export var dive_jump_speed_retention: float = 0.99
@export var dive_jump_forward_boost: float = 2.5
@export var dive_glide_speed_threshold: float = 5.0
@export var max_speed: float = 20.0

@export_category("Splash")
@export var splash_damping: float = 1.2
@export var glide_damping: float = 0.18
@export var momentum_damping: float = 0.15
@export var splash_dip_depth: float = 0.6
@export var big_splash_speed_threshold: float = 7.0
@export var jump_buffer_time: float = 0.15
@export var dive_buffer_time: float = 0.15

@export_category("Land")
@export var walk_speed: float = 4.0
@export var walk_acceleration: float = 12.0
@export var footstep_interval: float = 0.35
@export var land_check_distance: float = 1.2
@export var shore_tolerance: float = 0.3
@export var stand_height: float = 0.5
## Grace period after switching to land during which the automatic back-to-sea check is suppressed
## (lets gravity settle the body onto the shore before it rises above the water level).
@export var land_settle_grace: float = 0.5
## Ignore exits of the currently ridden wave within this window after it was entered. The rider is
## glued to the wave's peak, so a real leave can only be a jump-off or the wave dying — a spurious
## body_exited (boundary overlap) must never end a ride.
@export var wave_exit_grace_ms: int = 120

@export_category("Rotation")
@export var rotation_speed: float = 16.0
@export var pitch_speed: float = 8.0

@export_category("Visual")
@export var mesh_offset_y: float = -0.4

const SPLASH_VFX := preload("res://scenes/vfx/splash.tscn")
const BIG_SPLASH_VFX := preload("res://scenes/vfx/big_splash.tscn")
const WAKE_VFX := preload("res://scenes/vfx/wake.tscn")
const BUBBLES_VFX := preload("res://scenes/vfx/bubbles.tscn")
const DUST_VFX := preload("res://scenes/vfx/dust.tscn")

var current_velocity := Vector3.ZERO
var _jump_buffer := 0.0
var _dive_buffer := 0.0
var _dive_jump_primed := false
var _current_wave: OceanCurrent = null
var _jumped_from_wave: OceanCurrent = null
var _launch_velocity: Vector3 = Vector3.ZERO
var _air_boost_active := false
var _submerged_vy := 0.0
var _was_in_sea := true
var _was_below_surface := true
var _was_submerged := false
var _land_step_timer := 0.0
var _land_settle_time := 0.0
var _wave_enter_time_ms := 0
var _wake: VFXDocked
var _bubbles: VFXDocked
var _ground_probe_shape: RID = RID()

var in_sea := true

func _ready() -> void:
	Log.set_log_level(Log.Levels.DEBUG)
	GUIDE.enable_mapping_context(guide_context)
	add_to_group(Definitions.PLAYER_GROUP)

	root_state_chart.event_received.connect(func(event: StringName):
		Log.debug("state chart event: ", event)
	)

	idle_state.state_physics_processing.connect(idle_state_phy_process)
	moving_state.state_physics_processing.connect(moving_state_phy_process)
	submerged_state.state_physics_processing.connect(submerged_state_phy_process)
	rising_state.state_physics_processing.connect(rising_state_phy_process)
	falling_state.state_physics_processing.connect(falling_state_phy_process)
	diving_state.state_physics_processing.connect(diving_state_phy_process)
	leap_state.state_physics_processing.connect(leap_state_phy_process)
	landing_state.state_physics_processing.connect(landing_state_phy_process)
	riding_state.state_physics_processing.connect(riding_state_phy_process)

	rising_state.state_entered.connect(_on_rising_entered)
	leap_state.state_entered.connect(_on_leap_entered)
	submerged_state.state_entered.connect(_on_submerged_entered)
	diving_state.state_entered.connect(func():
		_dive_jump_primed = true
		#AudioManager.play_sfx(SfxLibrary.DIVE, global_position, -2.0, 1.0, 0.1)
		camera_rig.add_shake(0.25)
	)
	water_movement.state_entered.connect(func():
		if current_velocity.length_squared() > 35:
			AudioManager.play_sfx(SfxLibrary.BIG_SPLASH, global_position, -2.0, 1.0, 0.1)
		else:
			AudioManager.play_sfx(SfxLibrary.SMALL_SPLASH, global_position, -2.0, 1.0, 0.1)
		_jumped_from_wave = null
		_dive_jump_primed = false
	)

	jump_action.just_triggered.connect(func(): _jump_buffer = jump_buffer_time)
	dive_action.just_triggered.connect(func(): _dive_buffer = dive_buffer_time)

	DialogueManager.dialogue_started.connect(_lock_controls)
	DialogueManager.dialogue_ended.connect(_unlock_controls)

	DeliveryManager.delivery_failed.connect(func(_snack: Snack, _customer: CustomerNPC) -> void:
		var backpack := get_node_or_null("Backpack") as Backpack
		if backpack != null:
			backpack.remove_snack()
		AudioManager.play_ui(SfxLibrary.BUZZ, -6.0)
	)
	
	for state: AtomicState in [idle_state, moving_state, submerged_state, landing_state]:
		state.state_entered.connect(_play_swim)
	riding_state.state_entered.connect(_play_surf)
	for state: AtomicState in [rising_state, falling_state, leap_state, diving_state]:
		state.state_entered.connect(_play_surfjump)
	
	idle_land.state_entered.connect(idle_land_state_entered)
	walk_land.state_entered.connect(walk_land_state_entered)
	idle_land.state_physics_processing.connect(idle_land_phy_process)
	walk_land.state_physics_processing.connect(walk_land_phy_process)

	for state: AtomicState in [idle_state, moving_state, submerged_state, rising_state, falling_state,
			landing_state, diving_state, leap_state, riding_state, jump_off_state, idle_land, walk_land]:
		state.state_entered.connect(func():
			Log.debug("state entered: ", state.name)
		)

	_wake = VFXManager.dock(WAKE_VFX, self)
	_wake.emitting = false
	_wake.visible = false
	_bubbles = VFXManager.dock(BUBBLES_VFX, self)
	_bubbles.emitting = false
	_bubbles.visible = false

	%OtterSkeleton.position.y = mesh_offset_y

func _play_swim() -> void:
	animation_player.play("otter_swim")

func _lock_controls(_resource: DialogueResource = null) -> void:
	if guide_context != null:
		GUIDE.disable_mapping_context(guide_context)
	_jump_buffer = 0.0
	_dive_buffer = 0.0

func _unlock_controls(_resource: DialogueResource = null) -> void:
	if guide_context != null:
		GUIDE.enable_mapping_context(guide_context)

func _play_surf() -> void:
	animation_player.play("otter_surf")

func _play_surfjump() -> void:
	animation_player.play("otter_surfjump")

func idle_land_state_entered():
	animation_player.play("otter_idle")

func idle_land_phy_process(delta: float):
	_apply_land_gravity(delta)
	current_velocity.x = 0
	current_velocity.z = 0

	if !walk_action.value_axis_2d.is_zero_approx():
		root_state_chart.send_event("moving")

func walk_land_state_entered():
	animation_player.play("otter_walk")

func walk_land_phy_process(delta: float):
	_apply_land_gravity(delta)
	var input := walk_action.value_axis_2d
	if input.is_zero_approx():
		root_state_chart.send_event("stopped")
		return
	var dir := get_move_direction(input)
	var target := dir * walk_speed
	current_velocity.x = lerp(current_velocity.x, target.x, walk_acceleration * delta)
	current_velocity.z = lerp(current_velocity.z, target.z, walk_acceleration * delta)
	_face_direction(dir, delta)
	_land_step_timer -= delta
	if _land_step_timer <= 0.0:
		_land_step_timer = footstep_interval
		VFXManager.spawn(DUST_VFX, global_position + Vector3(0.0, -0.45, 0.0))
		AudioManager.play_sfx(SfxLibrary.STEP, global_position, -6.0, 1.0, 0.25)

func _apply_land_gravity(delta: float) -> void:
	if not is_on_floor():
		current_velocity.y -= gravity * delta
	else:
		current_velocity.y = 0.0
	if _land_settle_time > 0.0:
		_land_settle_time = maxf(0.0, _land_settle_time - delta)
	if _land_settle_time == 0.0 and _should_return_to_sea():
		in_sea = true
		Log.info("switched to sea")
		root_state_chart.send_event("to_in_sea")

func _exit_tree() -> void:
	if _ground_probe_shape.is_valid():
		PhysicsServer3D.free_rid(_ground_probe_shape)
		_ground_probe_shape = RID()

func _physics_process(delta: float) -> void:
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_dive_buffer = maxf(0.0, _dive_buffer - delta)
	if _jumped_from_wave != null and not is_instance_valid(_jumped_from_wave):
		_jumped_from_wave = null
	_apply_speed_cap()
	velocity = current_velocity
	move_and_slide()
	current_velocity = velocity
	RenderingServer.global_shader_parameter_set("player_position", self.global_position)
	_update_water_effects()
	_check_water_impact()
	_check_auto_land_switch()

func on_wave_entered(wave: OceanCurrent) -> void:
	if not in_sea:
		return
	if _current_wave != null:
		return
	if _jumped_from_wave != null and wave == _jumped_from_wave:
		return
	_wave_enter_time_ms = Time.get_ticks_msec()
	_current_wave = wave
	_wake.emitting = true
	_wake.visible = true
	AudioManager.play_sfx(SfxLibrary.WHOOSH, global_position, -4.0, 1.0, 0.15)
	root_state_chart.send_event("wave_entered")

func on_wave_exited(wave: OceanCurrent) -> void:
	if _current_wave == wave:
		if Time.get_ticks_msec() - _wave_enter_time_ms < wave_exit_grace_ms:
			return
		_current_wave = null
		_wake.emitting = false
		_wake.visible = false
		root_state_chart.send_event("wave_exited")

func _update_water_effects() -> void:
	if in_sea and not _was_in_sea:
		%OtterSkeleton.position.y = mesh_offset_y
	elif not in_sea and _was_in_sea:
		%OtterSkeleton.position.y = 0.0
	_was_in_sea = in_sea
	var submerged := in_sea and global_position.y < water_level_y - splash_dip_depth * 0.5
	if submerged and not _was_submerged:
		_bubbles.emitting = true
		_bubbles.visible = true
		AudioManager.play_sfx(SfxLibrary.BUBBLE, global_position, -4.0, 1.0, 0.2)
	elif not submerged and _was_submerged:
		_bubbles.emitting = false
		_bubbles.visible = false
	_was_submerged = submerged

func _is_big_splash() -> bool:
	return current_velocity.length() > big_splash_speed_threshold

func _splash_sfx() -> AudioStream:
	return SfxLibrary.BIG_SPLASH if _is_big_splash() else SfxLibrary.SMALL_SPLASH

func _splash_shake() -> float:
	return 0.3 if _is_big_splash() else 0.1

func _play_splash(at: Vector3, sfx: AudioStream, shake: float) -> void:
	var splash_pos := Vector3(at.x, water_level_y, at.z)
	if current_velocity.length_squared() > 35:
		VFXManager.spawn(BIG_SPLASH_VFX, splash_pos)
	else:
		VFXManager.spawn(SPLASH_VFX, splash_pos)
	AudioManager.play_sfx(sfx, splash_pos, -2.0, 1.0, 0.15)
	camera_rig.add_shake(shake)

# --- Shared helpers ---

func get_move_direction(input: Vector2) -> Vector3:
	var dir := camera_rig.global_transform.basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	return dir.normalized()

func _face_direction(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	global_rotation.y = lerp_angle(global_rotation.y, target_yaw, rotation_speed * delta)

func _face_pitch(target_degrees: float, delta: float) -> void:
	global_rotation.x = lerp_angle(global_rotation.x, deg_to_rad(target_degrees), pitch_speed * delta)

func _apply_speed_cap() -> void:
	var horizontal := Vector2(current_velocity.x, current_velocity.z)
	if horizontal.length() > max_speed:
		horizontal = horizontal.normalized() * max_speed
		current_velocity.x = horizontal.x
		current_velocity.z = horizontal.y

func _try_jump() -> void:
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		root_state_chart.send_event("jump")

func _try_dive_jump() -> void:
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		_dive_jump_primed = _dive_jump_primed or _dive_buffer > 0.0
		_dive_buffer = 0.0
		root_state_chart.send_event("jump")

func _try_catch_wave() -> void:
	if is_instance_valid(_current_wave):
		root_state_chart.send_event("wave_entered")

func _try_dive() -> void:
	if allow_underwater_dive and dive_action.is_triggered():
		if _horizontal_speed() > dive_glide_speed_threshold:
			_dive_jump_primed = true
		else:
			root_state_chart.send_event("dive")

func _horizontal_speed() -> float:
	return Vector2(current_velocity.x, current_velocity.z).length()

func _glide_damping() -> float:
	return glide_damping if _horizontal_speed() > swim_speed * 1.5 else deceleration

func _on_rising_entered() -> void:
	if _was_in_sea:
		_play_splash(global_position, SfxLibrary.WHOOSH, 0.15)
	current_velocity.y = jump_velocity
	_air_boost_active = false
	var primed := _dive_jump_primed
	var retention := dive_jump_speed_retention if primed else hop_speed_retention
	current_velocity.x *= retention
	current_velocity.z *= retention
	if primed:
		var boost_dir := get_move_direction(walk_action.value_axis_2d)
		if boost_dir.is_zero_approx():
			boost_dir = -transform.basis.z
			boost_dir.y = 0.0
			if not boost_dir.is_zero_approx():
				boost_dir = boost_dir.normalized()
		current_velocity += boost_dir * dive_jump_forward_boost
		_apply_speed_cap()
	_dive_jump_primed = false

func _on_leap_entered() -> void:
	_air_boost_active = true
	_wake.emitting = false
	_wake.visible = false
	_play_splash(global_position, SfxLibrary.WHOOSH, 0.2)
	if _launch_velocity != Vector3.ZERO:
		current_velocity = _launch_velocity
		_launch_velocity = Vector3.ZERO
	else:
		current_velocity.y = leap_velocity_y

func _on_submerged_entered() -> void:
	_submerged_vy = clampf(current_velocity.y, wave_dive_velocity, underwater_dive_velocity)
	_dive_jump_primed = false

func _check_landing() -> void:
	if global_position.y <= water_level_y and current_velocity.y < 0.0:
		root_state_chart.send_event("landed")

func _check_auto_land_switch() -> void:
	if in_sea and not is_instance_valid(_current_wave):
		if _ground_below_above_water():
			_switch_to_land()

## Land -> sea. Uses the same ground-height criterion as the land switch so the
## two checks never overlap (no oscillation band): leave land when the player
## falls into the water, or walks onto ground submerged past the shore tolerance.
func _should_return_to_sea() -> bool:
	if not is_on_floor() and global_position.y <= water_level_y:
		return true
	return _ground_y_below() <= water_level_y - shore_tolerance

func _ground_below_above_water() -> bool:
	var ground_y := _ground_y_below()
	return ground_y > water_level_y - shore_tolerance \
		and ground_y + stand_height > water_level_y

## Y of the ground directly below the player, or -INF when the ray hits nothing.
## The ray starts slightly above the body: the player rests with its shape
## bottom sunk into the ground, so a ray from the root can start inside a
## collider and read its far face instead of the surface. From-inside hits
## are rejected for the same reason.
func _ground_y_below() -> float:
	if not _ground_probe_shape.is_valid():
		_ground_probe_shape = PhysicsServer3D.sphere_shape_create()
		PhysicsServer3D.shape_set_data(_ground_probe_shape, 0.3)
	var params := PhysicsShapeQueryParameters3D.new()
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.exclude = [get_rid()]
	params.shape_rid = _ground_probe_shape
	params.transform = Transform3D(Basis(), global_position + Vector3.UP * 0.15)
	var hits := get_world_3d().direct_space_state.collide_shape(params, 16)
	if hits.is_empty():
		return -INF
	# Contact points lie on the probed shape, not the surface: the lowest can
	# be a penetration point well below the ground. The highest contact is
	# the walkable surface.
	var ground := -INF
	for hit in hits:
		ground = maxf(ground, hit.y)
	return ground

func _switch_to_land() -> void:
	in_sea = false
	_land_settle_time = land_settle_grace
	_current_wave = null
	_wake.emitting = false
	_wake.visible = false
	global_rotation.x = 0.0
	%OtterSkeleton.position.y = 0.0
	Log.info("switched to land")
	root_state_chart.send_event("to_in_land")

func _check_water_impact() -> void:
	var below := global_position.y <= water_level_y
	if below and not _was_below_surface and current_velocity.y < -0.1:
		_play_splash(global_position, _splash_sfx(), _splash_shake())
	_was_below_surface = below

func _check_splash() -> void:
	if global_position.y <= water_level_y - splash_dip_depth and current_velocity.y < 0.0:
		root_state_chart.send_event("splash")

func _maintain_swim_depth(delta: float) -> void:
	current_velocity.y = 0.0
	var target_y := water_level_y - submerge_offset
	if not is_equal_approx(global_position.y, target_y):
		global_position.y = lerp(global_position.y, target_y, buoyancy_lift_speed * delta)
	_face_pitch(0.0, delta)

func _apply_air_control(delta: float) -> void:
	var drag_factor := maxf(0.0, 1.0 - air_drag * delta)
	current_velocity.x *= drag_factor
	current_velocity.z *= drag_factor
	var input := walk_action.value_axis_2d
	if input.is_zero_approx():
		return
	var dir := get_move_direction(input)
	var horizontal := Vector3(current_velocity.x, 0.0, current_velocity.z)
	var speed := horizontal.length()
	if speed < air_control_min_speed:
		var speed_alone_copy := horizontal.dot(dir)
		if speed_alone_copy < air_control_max_speed:
			var add := dir * (air_control_max_speed - speed_alone_copy) * air_control * delta
			current_velocity.x += add.x
			current_velocity.z += add.z
			_face_direction(dir, delta)
		return
	var forward := horizontal.normalized()
	var dot := forward.dot(dir)
	var angle := forward.signed_angle_to(dir, Vector3.UP)
	var turn_rate := air_steer * clampf(speed / air_steer_speed_threshold, 0.0, 1.0) * (0.5 + 0.5 * dot)
	var max_turn := turn_rate * delta
	if absf(angle) <= max_turn:
		horizontal = dir * speed
	else:
		horizontal = horizontal.rotated(Vector3.UP, signf(angle) * max_turn)
	var speed_along := horizontal.dot(dir)
	if _air_boost_active and speed_along < air_boost_max_speed:
		var add := dir * (air_boost_max_speed - speed_along) * air_boost_rate * delta
		horizontal.x += add.x
		horizontal.z += add.z
	current_velocity.x = horizontal.x
	current_velocity.z = horizontal.z
	_face_direction(dir, delta)

# --- Water states ---

func idle_state_phy_process(delta: float) -> void:
	_maintain_swim_depth(delta)
	_try_catch_wave()
	var damping := _glide_damping()
	current_velocity.x = lerp(current_velocity.x, 0.0, damping * delta)
	current_velocity.z = lerp(current_velocity.z, 0.0, damping * delta)
	_try_jump()
	_try_dive()
	if !walk_action.value_axis_2d.is_zero_approx():
		root_state_chart.send_event("moving")

func moving_state_phy_process(delta: float) -> void:
	_maintain_swim_depth(delta)
	_try_catch_wave()
	_try_jump()
	_try_dive()
	var input := walk_action.value_axis_2d
	if !input.is_zero_approx():
		var dir := get_move_direction(input)
		var target := dir * maxf(swim_speed, _horizontal_speed() * (1.0 - momentum_damping * delta))
		current_velocity.x = lerp(current_velocity.x, target.x, acceleration * delta)
		current_velocity.z = lerp(current_velocity.z, target.z, acceleration * delta)
		_face_direction(dir, delta)
	if input.is_zero_approx():
		root_state_chart.send_event("stopped")

func submerged_state_phy_process(delta: float) -> void:
	_submerged_vy = minf(_submerged_vy + underwater_dive_buoyancy * delta, 6.0)
	current_velocity.y = _submerged_vy
	_face_pitch(0.0, delta)
	var input := walk_action.value_axis_2d
	if input.is_zero_approx():
		current_velocity.x = lerp(current_velocity.x, 0.0, splash_damping * delta)
		current_velocity.z = lerp(current_velocity.z, 0.0, splash_damping * delta)
	else:
		var dir := get_move_direction(input)
		var target := dir * underwater_dive_max_speed
		current_velocity.x = lerp(current_velocity.x, target.x, acceleration * delta)
		current_velocity.z = lerp(current_velocity.z, target.z, acceleration * delta)
		_face_direction(dir, delta)
	if global_position.y >= water_level_y and _submerged_vy >= 0.0:
		root_state_chart.send_event("surfaced")

# --- Air states ---

func rising_state_phy_process(delta: float) -> void:
	current_velocity.y -= gravity * delta
	_apply_air_control(delta)
	_face_pitch(8.0, delta)
	if current_velocity.y <= 0.0:
		root_state_chart.send_event("falling")
	_check_landing()

func falling_state_phy_process(delta: float) -> void:
	current_velocity.y -= gravity * delta
	_apply_air_control(delta)
	_face_pitch(-12.0, delta)
	if dive_action.is_triggered():
		root_state_chart.send_event("dive")
	_check_landing()

func diving_state_phy_process(delta: float) -> void:
	current_velocity.y = lerp(current_velocity.y, dive_velocity, 10.0 * delta)
	_apply_air_control(delta)
	_face_pitch(-75.0, delta)
	_check_splash()

func leap_state_phy_process(delta: float) -> void:
	current_velocity.y -= gravity * delta
	_apply_air_control(delta)
	_face_pitch(-45.0, delta)
	if dive_action.is_triggered():
		root_state_chart.send_event("dive")
	_check_landing()

func landing_state_phy_process(delta: float) -> void:
	_maintain_swim_depth(delta)
	var damping := _glide_damping()
	current_velocity.x = lerp(current_velocity.x, 0.0, damping * delta)
	current_velocity.z = lerp(current_velocity.z, 0.0, damping * delta)
	_try_dive_jump()

# --- Wave states ---

func riding_state_phy_process(delta: float) -> void:
	if _current_wave == null or not is_instance_valid(_current_wave):
		_current_wave = null
		root_state_chart.send_event("wave_exited")
		return
	global_position = _current_wave.get_peak_position()
	current_velocity = _current_wave.get_velocity()
	_face_pitch(0.0, delta)
	if not current_velocity.is_zero_approx():
		_face_direction(current_velocity.normalized(), delta)
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		var wave_velocity := _current_wave.get_velocity()
		var boost := Vector3.ZERO
		if !walk_action.value_axis_2d.is_zero_approx():
			boost = get_move_direction(walk_action.value_axis_2d) * jump_off_directional_boost
		_launch_velocity = wave_velocity * jump_off_speed_multiplier + boost
		_launch_velocity.y = leap_velocity_y
		_jumped_from_wave = _current_wave
		_current_wave = null
		root_state_chart.send_event("jump_off")

func force_wave_jump_off(wave: OceanCurrent) -> void:
	if not in_sea or _current_wave != wave or not is_instance_valid(wave):
		return
	var wave_velocity := wave.get_velocity()
	var boost := Vector3.ZERO
	if not walk_action.value_axis_2d.is_zero_approx():
		boost = get_move_direction(walk_action.value_axis_2d) * jump_off_directional_boost
	_launch_velocity = wave_velocity * jump_off_speed_multiplier + boost
	_launch_velocity.y = leap_velocity_y
	_jumped_from_wave = wave
	_current_wave = null
	_jump_buffer = 0.0
	_wake.emitting = false
	_wake.visible = false
	root_state_chart.send_event("jump_off")
