extends Node

@onready var level_music: AudioStreamPlayer = %LevelMusic
@onready var level_ambience: AudioStreamPlayer = %LevelAmbience

func _ready() -> void:
	level_music.bus = &"Music"
	level_ambience.bus = &"SFX"
