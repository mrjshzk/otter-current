extends Node3D

@onready var boss: BossNPC = $TestBossIsland/TestNpc

func _ready() -> void:
	boss.first_dialogue_started.connect(func(_player: Node) -> void:
		AudioManager.play_music()
	)
