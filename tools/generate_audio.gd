extends SceneTree

const RATE := 44100
const OUT_DIR := "res://assets/audio"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	randi()
	write_wav("splash.wav", _splash(), RATE)
	write_wav("dive.wav", _dive(), RATE)
	write_wav("whoosh.wav", _whoosh(), RATE)
	write_wav("bubble.wav", _bubble(), RATE)
	write_wav("step.wav", _step(), RATE)
	write_wav("chime.wav", _chime(), RATE)
	write_wav("jingle.wav", _jingle(), RATE)
	write_wav("buzz.wav", _buzz(), RATE)
	write_wav("blip.wav", _blip(), RATE)
	write_wav("ambience_loop.wav", _ambience(), RATE)
	write_wav("music_loop.wav", _music(), RATE)
	print("Generated ", _generated, " audio files in ", OUT_DIR)
	quit()

var _generated := 0

func write_wav(file_name: String, samples: PackedFloat32Array, rate: int) -> void:
	var buf := PackedByteArray()
	buf.append_array("RIFF".to_ascii_buffer())
	buf.append_array(_u32(36 + samples.size() * 2))
	buf.append_array("WAVE".to_ascii_buffer())
	buf.append_array("fmt ".to_ascii_buffer())
	buf.append_array(_u32(16))
	buf.append_array(_u16(1))
	buf.append_array(_u16(1))
	buf.append_array(_u32(rate))
	buf.append_array(_u32(rate * 2))
	buf.append_array(_u16(2))
	buf.append_array(_u16(16))
	buf.append_array("data".to_ascii_buffer())
	buf.append_array(_u32(samples.size() * 2))
	for s in samples:
		buf.append_array(_s16(int(clampf(s, -1.0, 1.0) * 32767.0)))
	var f := FileAccess.open(OUT_DIR + "/" + file_name, FileAccess.WRITE)
	if f == null:
		push_error("Could not write " + file_name)
		return
	f.store_buffer(buf)
	f.close()
	_generated += 1

func _u32(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, v)
	return b

func _u16(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(2)
	b.encode_u16(0, v)
	return b

func _s16(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(2)
	b.encode_s16(0, v)
	return b

func _noise(n: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		a[i] = randf() * 2.0 - 1.0
	return a

func _lowpass(a: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(a.size())
	var prev := 0.0
	for i in a.size():
		prev += k * (a[i] - prev)
		out[i] = prev
	return out

func _env(a: PackedFloat32Array, attack_s: float, release_s: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(a.size())
	var attack_n := int(attack_s * RATE)
	var release_n := int(release_s * RATE)
	for i in a.size():
		var g := 1.0
		if i < attack_n:
			g = float(i) / float(attack_n)
		elif i > a.size() - release_n:
			g = clampf(float(a.size() - i) / float(release_n), 0.0, 1.0)
		out[i] = a[i] * g
	return out

func _mix(a: PackedFloat32Array, b: PackedFloat32Array, gain_b := 1.0) -> PackedFloat32Array:
	if a.is_empty():
		a = b.duplicate()
		if gain_b != 1.0:
			for i in a.size():
				a[i] *= gain_b
		return a
	var n := mini(a.size(), b.size())
	for i in n:
		a[i] += b[i] * gain_b
	return a

func _normalize(a: PackedFloat32Array, peak := 0.9) -> PackedFloat32Array:
	var m := 0.0
	for i in a.size():
		m = maxf(m, absf(a[i]))
	if m > 0.0:
		var g := peak / m
		for i in a.size():
			a[i] *= g
	return a

func _sine(freq: float, seconds: float, decay := 0.0, gain := 1.0) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		var t := float(i) / RATE
		var g := gain
		if decay > 0.0:
			g *= exp(-t * decay)
		a[i] = sin(TAU * freq * t) * g
	return a

func _pad(a: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE) + a.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for i in a.size():
		out[i + int(seconds * RATE)] = a[i]
	return out

func _splash() -> PackedFloat32Array:
	var a := _noise(int(0.35 * RATE))
	a = _lowpass(a, 0.12)
	a = _env(a, 0.005, 0.32)
	return _normalize(a, 0.85)

func _dive() -> PackedFloat32Array:
	var a := _noise(int(0.6 * RATE))
	a = _lowpass(a, 0.06)
	a = _env(a, 0.01, 0.55)
	var thump := _sine(120.0, 0.25, 12.0, 0.5)
	a = _mix(a, thump, 1.0)
	return _normalize(a, 0.9)

func _whoosh() -> PackedFloat32Array:
	var a := _noise(int(0.3 * RATE))
	var bright := _lowpass(a, 0.5)
	var dark := _lowpass(a, 0.04)
	for i in a.size():
		a[i] = bright[i] - dark[i] * 0.6
	a = _env(a, 0.04, 0.24)
	return _normalize(a, 0.7)

func _bubble() -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for j in 3:
		var blip := _sine(randf_range(420.0, 620.0), 0.12, 28.0, 0.5)
		a = _mix(a, _pad(blip, j * 0.07 + 0.12), 1.0)
	return _normalize(a, 0.6)

func _step() -> PackedFloat32Array:
	var a := _sine(90.0, 0.09, 42.0, 0.9)
	var tap := _lowpass(_noise(int(0.03 * RATE)), 0.2)
	a = _mix(a, tap, 0.4)
	return _normalize(a, 0.55)

func _chime() -> PackedFloat32Array:
	var a := _sine(659.26, 0.35, 9.0, 0.7)
	var b := _sine(880.0, 0.5, 8.0, 0.7)
	a = _mix(a, _pad(b, 0.06), 1.0)
	return _normalize(a, 0.6)

func _jingle() -> PackedFloat32Array:
	var notes := [659.26, 830.61, 987.77, 1318.51]
	var a := PackedFloat32Array()
	for i in notes.size():
		var tone := _sine(notes[i], 0.55, 7.0, 0.8)
		a = _mix(a, _pad(tone, i * 0.16), 1.0)
	return _normalize(a, 0.65)

func _buzz() -> PackedFloat32Array:
	var a := _sine(160.0, 0.24, 10.0, 0.8)
	a = _mix(a, _sine(480.0, 0.24, 10.0, 0.3), 1.0)
	a = _env(a, 0.004, 0.16)
	return _normalize(a, 0.6)

func _blip() -> PackedFloat32Array:
	var a := _sine(700.0, 0.07, 40.0, 0.7)
	return _normalize(a, 0.5)

func _ambience() -> PackedFloat32Array:
	var n := int(4.0 * RATE)
	var a := PackedFloat32Array()
	a.resize(n)
	var prev := 0.0
	for i in n:
		prev = prev + 0.02 * (randf() * 2.0 - 1.0)
		prev *= 0.985
		a[i] = prev
	a = _lowpass(a, 0.04)
	a = _env(a, 0.25, 0.25)
	return _normalize(a, 0.4)

func _music() -> PackedFloat32Array:
	var n := int(8.0 * RATE)
	var a := PackedFloat32Array()
	a.resize(n)
	var chord_index := 0
	for i in n:
		var t := float(i) / RATE
		var pos := fmod(t, 4.0)
		var chord := chord_index if pos < 4.0 else (chord_index + 1) % 2
		var g := 0.5 - 0.5 * cos(minf(pos * 1.2, 1.0) * PI)
		var fade := 1.0
		if pos > 3.0:
			fade = 0.5 + 0.5 * cos((pos - 3.0) * PI)
		var freqs := [261.63, 329.63, 392.0] if chord == 0 else [220.0, 261.63, 329.63]
		var v := 0.0
		for f in freqs:
			v += sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t)
		a[i] = v * g * fade * 0.15
	return _normalize(a, 0.5)