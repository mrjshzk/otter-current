shader_type spatial;
render_mode cull_disabled;

uniform sampler2D noise_texture : source_color, repeat_enable;
uniform float scroll_speed : hint_range(0.0, 2.0, 0.01) = 0.4;
uniform vec2 scroll_offset = vec2(0.0, 1.0);
uniform float detail_scale : hint_range(0.0, 8.0, 0.1) = 1.0;
uniform float displacement_amplitude : hint_range(0.0, 0.25, 0.005) = 0.05;

uniform vec3 deep_color : source_color = vec3(0.02, 0.18, 0.32);
uniform vec3 mid_color : source_color = vec3(0.05, 0.42, 0.55);

uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float specular : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float fresnel_radius : hint_range(0.0, 6.0, 0.01) = 2.0;
uniform vec3 fresnel_color : source_color = vec3(0.15, 0.5, 0.65);

// Water surface color parameters, matched to water_v2 so the wave blends into the sea
uniform vec3 horizon_color : source_color = vec3(0.09, 0.55, 0.68);
uniform float horizon_distance : hint_range(10.0, 500.0, 1.0) = 120.0;
uniform float horizon_softness : hint_range(0.0, 1.0, 0.01) = 0.4;

uniform float bottom_fade_height : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float bottom_fade_softness : hint_range(0.01, 1.0, 0.01) = 0.25;

varying vec3 local_pos;
varying vec3 global_pos;

void vertex() {
	local_pos = VERTEX;
	vec2 scrolled = VERTEX.xz * detail_scale + scroll_offset * scroll_speed * TIME;
	float n1 = texture(noise_texture, scrolled).r;
	float n2 = texture(noise_texture, VERTEX.xz * detail_scale * 2.0 - scroll_offset * scroll_speed * TIME * 1.4).g;
	VERTEX.y += (n1 + n2 - 1.0) * displacement_amplitude;
	global_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = clamp(local_pos.y / 1.5, 0.0, 1.0);
	vec3 col = mix(deep_color, mid_color, smoothstep(0.0, 0.6, h));

	// Approximate the water surface color (same formula as water_v2)
	float view_distance = length((VIEW_MATRIX * vec4(global_pos, 1.0)).xyz);
	float horizon_mix = smoothstep(horizon_distance * horizon_softness, horizon_distance, view_distance);
	vec3 water_color = mix(deep_color, horizon_color, horizon_mix);
	float fres = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), fresnel_radius);
	water_color = mix(water_color, fresnel_color, fres);

	// Fade the bottom into the water color so the wave belongs to the sea
	float bottom = 1.0 - smoothstep(bottom_fade_height - bottom_fade_softness, bottom_fade_height, local_pos.y);
	col = mix(col, water_color, bottom);

	ALBEDO = col;
	ROUGHNESS = mix(roughness, 1.0, bottom * 0.5);
	SPECULAR = specular;
}