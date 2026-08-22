extends Node

const SFX_POOL_SIZE := 16

var _sfx_pool: Array[AudioStreamPlayer3D] = []
var _ui_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer

func _ready() -> void:
	_setup_buses()
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.bus = &"SFX"
		player.max_distance = 40.0
		add_child(player)
		_sfx_pool.append(player)
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = &"UI"
	add_child(_ui_player)
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = &"SFX"
	add_child(_ambience_player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	add_child(_music_player)
	#_loop_stream(_ambience_player, SfxLibrary.AMBIENCE, -14.0)

func play_music() -> void:
	if _music_player.playing:
		return
	_loop_stream(_music_player, SfxLibrary.MUSIC, 0.0)

func play_sfx(stream: AudioStream, at: Vector3, volume_db := 0.0, pitch := 1.0, pitch_rand := 0.0) -> void:
	if stream == null:
		return
	for player in _sfx_pool:
		if not player.playing:
			player.stream = stream
			player.global_position = at
			player.volume_db = volume_db
			player.pitch_scale = pitch * randf_range(1.0 - pitch_rand, 1.0 + pitch_rand)
			player.play()
			return

func play_ui(stream: AudioStream, volume_db := 0.0) -> void:
	if stream == null:
		return
	_ui_player.stream = stream
	_ui_player.volume_db = volume_db
	_ui_player.play()

func _setup_buses() -> void:
	_ensure_bus(&"Master")
	_ensure_bus(&"Music", &"Master")
	_ensure_bus(&"SFX", &"Master")
	_ensure_bus(&"UI", &"Master")

func _ensure_bus(bus: StringName, send_to: StringName = &"") -> void:
	if AudioServer.get_bus_index(bus) != -1:
		return
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus)
	if send_to != &"":
		AudioServer.set_bus_send(index, send_to)

func _loop_stream(player: AudioStreamPlayer, stream: AudioStream, volume_db: float) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / 2
	player.stream = stream
	player.volume_db = volume_db
	player.play()
