extends CharacterBody3D
class_name Player

@export_category("Input")
@export var guide_context: GUIDEMappingContext
@export var walk_action: GUIDEAction
@export var dive_action: GUIDEAction
@export var jump_action: GUIDEAction

@onready var root_state_chart: StateChart = %RootStateChart

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

@onready var camera_rig: CameraRig = %CameraRig

@export_category("Water")
## The Y position of the water surface. The player counts as being "in the water"
## (on the ground) while at or below this height.
@export var water_level_y: float = 0.0
## How far below the water surface the player floats while swimming.
@export var submerge_offset: float = 0.25
## How fast the player bobs up/down toward the swim depth. Higher = more buoyancy snap.
@export var buoyancy_lift_speed: float = 4.0
@export var swim_speed: float = 2.5  # Deliberately slow
@export var acceleration: float = 11.0
@export var deceleration: float = 8.0

@export_category("Air")
@export var gravity: float = 18.0
@export var jump_velocity: float = 7.5
@export var air_control: float = 1.5
## Weak air control target speed (normal jumps).
@export var air_control_max_speed: float = 4.0
## Below this horizontal speed air control stays weak (normal jumps).
@export var air_control_min_speed: float = 8.0
## How fast the flight direction turns toward the move input at high speed.
@export var air_steer: float = 5.0
## Speed at which air steering reaches full strength.
@export var air_steer_speed_threshold: float = 12.0
## Aligned air input accelerates the player toward this speed.
@export var air_boost_max_speed: float = 16.0
## Rate of the high-speed aligned air boost.
@export var air_boost_rate: float = 3.0
## Horizontal speed bleed while airborne. Higher = less floaty.
@export var air_drag: float = 0.05

@export_category("Diving")
## Allow diving from the water surface into a submerged state.
@export var allow_underwater_dive: bool = true
@export var dive_velocity: float = -9.0
@export var underwater_dive_velocity: float = -3.5
## The plunge speed carried into the water when diving off a wave (deeper dive).
@export var wave_dive_velocity: float = -5.5
## Upward acceleration applied while submerged (the water pushing you back up).
@export var underwater_dive_buoyancy: float = 14.0
@export var underwater_dive_max_speed: float = 5.0

@export_category("Waves")
## Speed multiplier applied to the wave's velocity when jumping off it.
@export var jump_off_speed_multiplier: float = 1.5
## Extra speed added along the move input when jumping off a wave.
@export var jump_off_directional_boost: float = 3.0
## Vertical velocity of the wave leap (small = shallow forward dive).
@export var leap_velocity_y: float = 3.0
## Horizontal speed retained per plain (non-dive) hop. Lower = momentum dies fast without the dive-jump combo.
@export var hop_speed_retention: float = 0.6
## Momentum kept when hopping with the dive+jump combo (crouch-jump).
@export var dive_jump_speed_retention: float = 0.99
## Extra speed added along the move input when landing a dive-jump hop (forward launch).
@export var dive_jump_forward_boost: float = 2.5
## Above this horizontal speed, diving in the water doesn't submerge: you keep gliding
## and the next jump becomes a momentum-preserving hop (silent crouch-jump arm).
@export var dive_glide_speed_threshold: float = 5.0
## Hard cap on horizontal speed (leap boosts, glide and steering respect it).
@export var max_speed: float = 20.0

@export_category("Splash")
## Horizontal damping right after splashing into water. Low = keeps momentum (bunnyhop).
@export var splash_damping: float = 1.2
## Horizontal damping while gliding at speed in the water (wave momentum carry).
@export var glide_damping: float = 0.18
## Speed bleed while moving fast in the water (no input-hold infinite gliding).
@export var momentum_damping: float = 0.15
## How far below the surface splash dives dip before bobbing back up.
@export var splash_dip_depth: float = 0.6
@export var jump_buffer_time: float = 0.15
## How long a dive press stays buffered so it can chain with a landing jump (dive-jump combo).
@export var dive_buffer_time: float = 0.15

@export_category("Rotation")
@export var rotation_speed: float = 16.0
## How fast the body pitches for diving/falling.
@export var pitch_speed: float = 8.0

var current_velocity := Vector3.ZERO
var _jump_buffer := 0.0
var _dive_buffer := 0.0
var _dive_jump_primed := false
var _current_wave: OceanCurrent = null
## The wave the player jumped off. It can't grab the player again until they leave its area.
var _jumped_from_wave: OceanCurrent = null
var _launch_velocity: Vector3 = Vector3.ZERO
var _air_boost_active := false
var _submerged_vy := 0.0

func _ready() -> void:
	GUIDE.enable_mapping_context(guide_context)
	add_to_group(Definitions.PLAYER_GROUP)

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
	diving_state.state_entered.connect(func(): _dive_jump_primed = true)
	water_movement.state_entered.connect(func():
		_jumped_from_wave = null
		_dive_jump_primed = false
	)

	jump_action.just_triggered.connect(func(): _jump_buffer = jump_buffer_time)
	dive_action.just_triggered.connect(func(): _dive_buffer = dive_buffer_time)

func _physics_process(delta: float) -> void:
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_dive_buffer = maxf(0.0, _dive_buffer - delta)
	if _jumped_from_wave != null and not is_instance_valid(_jumped_from_wave):
		_jumped_from_wave = null
	_apply_speed_cap()
	velocity = current_velocity
	move_and_slide()
	current_velocity = velocity

func on_wave_entered(wave: OceanCurrent) -> void:
	if _jumped_from_wave != null and wave == _jumped_from_wave:
		return
	_current_wave = wave
	root_state_chart.send_event("wave_entered")

func on_wave_exited(wave: OceanCurrent) -> void:
	if _current_wave == wave:
		_current_wave = null
		root_state_chart.send_event("wave_exited")

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

## Landing hop: jump alone keeps a little momentum; a dive earlier in the flight (or dive+jump here) keeps most of it.
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

## Fast landings glide (keep momentum, bunnyhop), slow movement stops snappily.
func _glide_damping() -> float:
	return glide_damping if _horizontal_speed() > swim_speed * 1.5 else deceleration

func _on_rising_entered() -> void:
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

func _check_splash() -> void:
	if global_position.y <= water_level_y - splash_dip_depth and current_velocity.y < 0.0:
		root_state_chart.send_event("splash")

## Keeps the player bobbing at swim depth while in the water. Also levels the body.
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
		var speed_along := horizontal.dot(dir)
		if speed_along < air_control_max_speed:
			var add := dir * (air_control_max_speed - speed_along) * air_control * delta
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
