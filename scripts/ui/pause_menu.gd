extends CanvasLayer
class_name PauseMenu

@export var pause_action: GUIDEAction
@export var guide_context: GUIDEMappingContext

@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var menu_buttons: Control = %MenuButtons
@onready var settings_panel: SettingsPanel = %SettingsPanel
@onready var title_label: Label = %TitleLabel

var _dialogue_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	# GUIDE must keep processing while paused, otherwise the pause action
	# never fires again and the game can't be unpaused.
	GUIDE.process_mode = Node.PROCESS_MODE_ALWAYS
	GUIDE.enable_mapping_context(guide_context)
	pause_action.just_triggered.connect(toggle_pause)
	resume_button.pressed.connect(toggle_pause)
	settings_button.pressed.connect(_open_settings)
	quit_button.pressed.connect(_quit)
	settings_panel.back_requested.connect(_close_settings)
	DialogueManager.dialogue_started.connect(func(_resource: DialogueResource) -> void:
		_dialogue_open = true
	)
	DialogueManager.dialogue_ended.connect(func(_resource: DialogueResource) -> void:
		_dialogue_open = false
	)
	visible = false

func toggle_pause() -> void:
	if _dialogue_open or _is_game_over():
		return
	if get_tree().paused:
		_resume()
	else:
		_pause()

func _is_game_over() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var overlay := scene.get_node_or_null("%GameOver")
	return overlay != null and overlay.visible

func _pause() -> void:
	get_tree().paused = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_buttons.visible = true
	settings_panel.visible = false
	resume_button.grab_focus()

func _resume() -> void:
	get_tree().paused = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _open_settings() -> void:
	title_label.visible = false
	menu_buttons.visible = false
	settings_panel.visible = true
	settings_panel.focus_back()

func _close_settings() -> void:
	title_label.visible = true
	settings_panel.visible = false
	menu_buttons.visible = true
	settings_button.grab_focus()

func _quit() -> void:
	get_tree().quit()
