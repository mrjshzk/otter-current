extends Control
class_name MainMenu

const TRANSITION_DURATION := 0.5
## Progress at which the transition overlay is fully transparent. Must be
## larger than the farthest screen point (r/d ~ 1.25 for the shape type),
## otherwise black wedges pop in at the start.
const TRANSITION_START := 1.5

const HOVER_SCALE := 1.08
const HOVER_BRIGHTEN := 1.15
const HOVER_TIME := 0.12

## Scene loaded by Start. Leave unset to use the default game scene.
## Not wired in the scene file: main_menu -> game -> pause_menu -> main_menu
## would form a load-time dependency cycle, so it's loaded lazily instead.
@export var start_scene: PackedScene

@onready var start_button: TextureButton = %StartButton
@onready var settings_button: TextureButton = %SettingsButton
@onready var quit_button: TextureButton = %QuitButton
@onready var menu_buttons: Control = %MenuButtons
@onready var settings_panel: SettingsPanel = %SettingsPanel
@onready var transition_rect: ColorRect = %TransitionRect
@onready var _transition_material: ShaderMaterial = %TransitionRect.material as ShaderMaterial
@onready var title_theme: AudioStreamPlayer = %TitleTheme

var _button_tweens: Dictionary = {}

func _ready() -> void:
	title_theme.volume_linear = 0
	title_theme.bus = &"Music"
	transition_rect.visible = false
	
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_open_settings)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	settings_panel.back_requested.connect(_close_settings)
	for button: TextureButton in [start_button, settings_button, quit_button]:
		button.mouse_entered.connect(_on_button_hover.bind(button, true))
		button.mouse_exited.connect(_on_button_hover.bind(button, false))
		_button_tweens[button] = null
	start_button.grab_focus()
	
	title_theme.play()
	var t = create_tween()
	t.finished.connect(
		func():
			var t2 = create_tween()
			t2.tween_property(title_theme, "volume_linear", 1, 1.0)
	)
	t.tween_property(_transition_material, 'shader_parameter/progress', 3.36, 1.0)
	

func _on_button_hover(button: TextureButton, hovered: bool) -> void:
	var previous: Tween = _button_tweens[button]
	if previous != null and previous.is_valid():
		previous.kill()
	button.pivot_offset = button.size / 2.0
	var tween := create_tween()
	_button_tweens[button] = tween
	tween.tween_property(button, "scale", Vector2.ONE * (HOVER_SCALE if hovered else 1.0), HOVER_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var target_color := Color(HOVER_BRIGHTEN, HOVER_BRIGHTEN, HOVER_BRIGHTEN) if hovered else Color.WHITE
	tween.parallel().tween_property(button, "modulate", target_color, HOVER_TIME)

# --- Menu actions ---

func _on_start_pressed() -> void:
	var scene := start_scene if start_scene != null else load("res://scenes/game/game.tscn") as PackedScene
	if scene == null:
		Log.warn("main menu: no start scene configured")
		return
	start_button.disabled = true
	settings_button.disabled = true
	quit_button.disabled = true
	transition_rect.visible = true
	if _transition_material == null:
		get_tree().change_scene_to_packed(scene)
		return
	_transition_material.set_shader_parameter("progress", TRANSITION_START)
	var tween := create_tween()
	tween.tween_method(_set_transition_progress, TRANSITION_START, 0.0, TRANSITION_DURATION)
	await tween.finished
	get_tree().change_scene_to_packed(scene)

func _set_transition_progress(value: float) -> void:
	_transition_material.set_shader_parameter("progress", value)

func _open_settings() -> void:
	menu_buttons.visible = false
	settings_panel.visible = true
	settings_panel.focus_back()

func _close_settings() -> void:
	settings_panel.visible = false
	menu_buttons.visible = true
	settings_button.grab_focus()
