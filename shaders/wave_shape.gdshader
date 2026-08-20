shader_type spatial;

uniform sampler2D noise_texture : source_color, repeat_enable;
uniform float scroll_speed : hint_range(0.0, 2.0, 0.01) = 0.4;
uniform vec2 scroll_offset = vec2(0.0, 1.0);
uniform float detail_scale : hint_range(0.0, 8.0, 0.1) = 1.0;
uniform float displacement_amplitude : hint_range(0.0, 0.25, 0.005) = 0.05;

uniform vec3 deep_color : source_color = vec3(0.02, 0.18, 0.32);
uniform vec3 mid_color : source_color = vec3(0.05, 0.42, 0.55);
uniform vec3 crest_color : source_color = vec3(0.85, 0.96, 1.0);
uniform float foam_start : hint_range(0.0, 1.5, 0.01) = 0.95;
uniform float foam_softness : hint_range(0.01, 0.6, 0.01) = 0.25;
uniform float foam_noise_scale : hint_range(0.0, 1.0, 0.01) = 0.55;

uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float specular : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float fresnel_strength : hint_range(0.0, 2.0, 0.01) = 0.8;
uniform vec3 fresnel_color : source_color = vec3(0.4, 0.9, 1.0);

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
	vec2 scrolled = VERTEX.xz * detail_scale + scroll_offset * scroll_speed * TIME;
	float n1 = texture(noise_texture, scrolled).r;
	float n2 = texture(noise_texture, VERTEX.xz * detail_scale * 2.0 - scroll_offset * scroll_speed * TIME * 1.4).g;
	VERTEX.y += (n1 + n2 - 1.0) * displacement_amplitude;
}

void fragment() {
	vec2 scrolled = local_pos.xz * detail_scale + scroll_offset * scroll_speed * TIME;
	float n1 = texture(noise_texture, scrolled).r;
	float n2 = texture(noise_texture, local_pos.xz * detail_scale * 2.0 - scroll_offset * scroll_speed * TIME * 1.4).g;
	float detail = (n1 + n2) * 0.5;

	float h = clamp(local_pos.y / 1.5, 0.0, 1.0);
	vec3 base = mix(deep_color, mid_color, smoothstep(0.0, 0.6, h));
	float foam = smoothstep(foam_start, foam_start + foam_softness, local_pos.y);
	float patch = mix(1.0 - foam_noise_scale, 1.0, detail);
	foam *= patch;
	vec3 col = mix(base, crest_color, foam);

	float ndv = max(dot(NORMAL, VIEW), 0.0);
	float fres = pow(1.0 - ndv, 3.0);

	ALBEDO = col;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	EMISSION = fresnel_color * fres * fresnel_strength * (1.0 - foam * 0.5);
}