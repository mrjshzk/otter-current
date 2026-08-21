shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D streak_texture : source_color, repeat_enable;
uniform float scroll_speed : hint_range(0.0, 3.0, 0.01) = 1.2;
uniform vec2 scroll_direction = vec2(0.0, -1.0);
uniform float streak_scale : hint_range(0.1, 8.0, 0.1) = 1.0;
uniform float streak_stretch : hint_range(1.0, 30.0, 0.5) = 8.0;
uniform float streak_strength : hint_range(0.0, 1.0, 0.01) = 0.6;
uniform float foam_brightness : hint_range(0.0, 2.0, 0.01) = 1.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 dir = normalize(scroll_direction);
	vec2 perp = vec2(-dir.y, dir.x);

	// Stretch the noise along the motion axis so the pattern reads as speed lines
	vec2 uv = vec2(dot(local_pos.xz, perp), dot(local_pos.xz, dir));
	uv.x *= streak_scale;
	uv.y *= streak_scale / streak_stretch;

	float t = TIME * scroll_speed;
	float s1 = texture(streak_texture, uv + dir * t).r;
	float s2 = texture(streak_texture, uv * 2.3 - dir * t * 1.4).g;

	float streak = smoothstep(0.35, 0.75, (s1 + s2) * 0.6);
	float foam = mix(1.0 - streak_strength * 0.4, 1.0, streak);

	ALBEDO = vec3(foam * foam_brightness);
}