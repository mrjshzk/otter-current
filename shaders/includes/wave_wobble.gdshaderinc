uniform float wobble_amplitude : hint_range(0.0, 0.5, 0.01) = 0.15;
uniform float wobble_frequency : hint_range(0.05, 2.0, 0.01) = 0.9;
uniform float wobble_speed : hint_range(0.0, 4.0, 0.01) = 1.2;
uniform vec2 wobble_direction = vec2(0.0, -1.0);

float wave_wobble_offset(vec3 world_pos) {
	vec2 dir = wobble_direction == vec2(0.0) ? vec2(0.0, -1.0) : normalize(wobble_direction);
	vec2 perp = vec2(-dir.y, dir.x);
	float t = TIME * wobble_speed;
	float swell = sin(dot(world_pos.xz, dir) * wobble_frequency + t);
	float cross = sin(dot(world_pos.xz, perp) * wobble_frequency * 1.9 + t * 1.3) * 0.35;
	float bob = sin(t * 0.5) * 0.15;
	return (swell + cross + bob) * wobble_amplitude;
}