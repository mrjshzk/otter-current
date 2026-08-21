extends VBoxContainer
class_name SettingsPanel
## Shared settings UI (resolution, fullscreen, audio volumes), persisted to
## user://settings.cfg. Used by both the main menu and the pause menu.

signal back_requested

const SETTINGS_PATH := "user://settings.cfg"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

const VOLUME_BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"UI"]

@onready var resolution_option: OptionButton = %ResolutionOption
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var volume_sliders: Array[HSlider] = [%MasterSlider, %MusicSlider, %SfxSlider, %UiSlider]
@onready var back_button: Button = %BackButton

var _settings := {
	"display/resolution": Vector2i(1280, 720),
	"display/fullscreen": false,
	"audio/master_volume_db": 0.0,
	"audio/music_volume_db": 0.0,
	"audio/sfx_volume_db": 0.0,
	"audio/ui_volume_db": 0.0,
}

func _ready() -> void:
	_load_settings()
	_apply_settings()
	_sync_settings_widgets()
	back_button.pressed.connect(func() -> void: back_requested.emit())
	resolution_option.item_selected.connect(_on_resolution_selected)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	for i in volume_sliders.size():
		volume_sliders[i].value_changed.connect(func(value: float, index: int = i) -> void:
			_on_volume_changed(VOLUME_BUSES[index], value)
		)

## Moves keyboard focus to the back button (used when the panel is shown).
func focus_back() -> void:
	back_button.grab_focus()

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for key: String in _settings.keys():
		var parts := key.split("/")
		_settings[key] = config.get_value(parts[0], parts[1], _settings[key])

func _apply_settings() -> void:
	_apply_resolution(_settings["display/resolution"])
	_apply_fullscreen(_settings["display/fullscreen"])
	for bus: StringName in VOLUME_BUSES:
		var key := _volume_key(bus)
		_set_volume(bus, _settings[key])

func _sync_settings_widgets() -> void:
	resolution_option.select(_resolution_index(_settings["display/resolution"]))
	fullscreen_check.set_pressed_no_signal(_settings["display/fullscreen"])
	for i in volume_sliders.size():
		volume_sliders[i].set_value_no_signal(_settings[_volume_key(VOLUME_BUSES[i])])

func _on_resolution_selected(index: int) -> void:
	if index < 0 or index >= RESOLUTIONS.size():
		return
	_settings["display/resolution"] = RESOLUTIONS[index]
	_apply_resolution(RESOLUTIONS[index])
	_save_settings()

func _on_fullscreen_toggled(enabled: bool) -> void:
	_settings["display/fullscreen"] = enabled
	_apply_fullscreen(enabled)
	_save_settings()

func _on_volume_changed(bus: StringName, db: float) -> void:
	_settings[_volume_key(bus)] = db
	_set_volume(bus, db)
	_save_settings()

func _apply_resolution(size: Vector2i) -> void:
	if size.x <= 0 or size.y <= 0:
		return
	DisplayServer.window_set_size(size)

func _apply_fullscreen(enabled: bool) -> void:
	get_window().mode = Window.MODE_FULLSCREEN if enabled else Window.MODE_WINDOWED

func _set_volume(bus: StringName, db: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, db)

func _save_settings() -> void:
	var config := ConfigFile.new()
	for key: String in _settings.keys():
		var parts := key.split("/")
		config.set_value(parts[0], parts[1], _settings[key])
	config.save(SETTINGS_PATH)

func _resolution_index(size: Vector2i) -> int:
	for i in RESOLUTIONS.size():
		if RESOLUTIONS[i] == size:
			return i
	return 0

func _volume_key(bus: StringName) -> String:
	return "audio/" + String(bus).to_lower() + "_volume_db"