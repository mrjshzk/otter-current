extends Node3D
## Root script of the core loop prototype level.

@onready var boss: BossNPC = $TestBossIsland/TestNpc

func _ready() -> void:
	boss.first_dialogue_started.connect(func(_player: Node) -> void:
		AudioManager.play_music()
	)
