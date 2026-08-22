extends Node
class_name ProceduralVoice

const MIX_RATE := 22050.0
const BASE_FREQ := 140.0
const SYLLABLES_PER_SECOND := 11.0
const JITTER := 0.08
const BREATH_AMOUNT := 0.05
const RISE_AMOUNT := 0.35
const RISE_TIME := 0.12

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _noise := RandomNumberGenerator.new()

var _active := false
var _ending := false
var _base_pitch := 1.0
var _tone := 0.5
var _freq := BASE_FREQ
var _syllable_duration := 0.09
var _syllable_timer := 0.0
var _syllable_time := 0.0
var _in_syllable := false
var _phase := 0.0
var _rise_timer := 0.0

func _ready() -> void:
	_noise.seed = hash(get_instance_id())
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.1
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.bus = &"UI"
	_player.volume_db = 2.0
	add_child(_player)

func start(pitch: float = 1.0, speed: float = 1.0, tone: float = 0.5) -> void:
	_base_pitch = maxf(pitch, 0.3)
	_syllable_duration = 1.0 / (SYLLABLES_PER_SECOND * maxf(speed, 0.3))
	_tone = clampf(tone, 0.0, 1.0)
	_active = true
	_ending = false
	_in_syllable = false
	_syllable_timer = 0.0
	_rise_timer = 0.0
	if not _player.playing:
		_player.play()
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback

func stop() -> void:
	if not _active or _ending:
		return
	_ending = true
	_rise_timer = RISE_TIME

func _process(delta: float) -> void:
	if not _active or _playback == null:
		return
	var rise_progress := -1.0
	if _ending:
		_rise_timer = maxf(0.0, _rise_timer - delta)
		rise_progress = clampf(1.0 - _rise_timer / RISE_TIME, 0.0, 1.0)
		if rise_progress >= 1.0:
			_active = false
			_player.stop()
			return
		_freq = BASE_FREQ * _base_pitch * (1.0 + RISE_AMOUNT * rise_progress)
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	_syllable_timer += delta
	while _syllable_timer >= _syllable_duration:
		_syllable_timer -= _syllable_duration
		if not _ending:
			_in_syllable = true
			_syllable_time = 0.0
			_freq = BASE_FREQ * _base_pitch * randf_range(1.0 - JITTER, 1.0 + JITTER)
	var step := 1.0 / MIX_RATE
	for i in frames:
		var sample := 0.0
		if _in_syllable or _ending:
			if _ending:
				var fade := 1.0 - rise_progress * 0.7
				sample = _wave() * 0.85 * fade
			else:
				_syllable_time += step
				if _syllable_time >= _syllable_duration:
					_in_syllable = false
				else:
					var env := _envelope(_syllable_time / _syllable_duration)
					sample = _wave() * env
					sample += _noise.randf_range(-1.0, 1.0) * BREATH_AMOUNT * env
		_playback.push_frame(Vector2(sample, sample))

func _wave() -> float:
	_phase += TAU * _freq / MIX_RATE
	if _phase >= TAU:
		_phase = fmod(_phase, TAU)
	var sine := sin(_phase)
	var bright := 0.6 * sine + 0.4 * sin(_phase * 2.0)
	return lerpf(sine, bright, _tone)

func _envelope(t: float) -> float:
	if t < 0.08:
		return t / 0.08
	if t < 0.7:
		return 1.0
	return 1.0 - (t - 0.7) / 0.3
