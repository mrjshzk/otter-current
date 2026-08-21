shader_type spatial;
render_mode shadows_disabled;

#define FRESNEL
#define PLAYER_WAVES
#define FOAM
#define CAUSTICS

group_uniforms color;
uniform vec3 deep_color : source_color = vec3(0.02, 0.18, 0.32);
uniform vec3 horizon_color : source_color = vec3(0.09, 0.55, 0.68);
uniform float horizon_distance : hint_range(10.0, 500.0, 1.0) = 120.0;
uniform float horizon_softness : hint_range(0.0, 1.0, 0.01) = 0.4;
#ifdef FRESNEL
uniform float fresnel_radius : hint_range(0.0, 6.0, 0.01) = 2.0;
uniform vec3 fresnel_color : source_color = vec3(0.15, 0.5, 0.65);
#endif
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float specular : hint_range(0.0, 1.0, 0.01) = 0.35;

group_uniforms waves;
uniform float wave_amplitude : hint_range(0.0, 2.0, 0.01) = 0.15;
uniform float wave_frequency : hint_range(0.0, 2.0, 0.01) = 0.15;
uniform float wave_speed : hint_range(0.0, 5.0, 0.01) = 0.8;
uniform vec2 wave_direction = vec2(1.0, 0.35);
uniform float detail_amplitude : hint_range(0.0, 0.5, 0.005) = 0.04;
uniform float detail_scale : hint_range(0.0, 2.0, 0.01) = 0.15;
uniform float detail_speed : hint_range(0.0, 2.0, 0.01) = 0.2;
uniform sampler2D displacement_texture : hint_default_black, repeat_enable;

group_uniforms edge;
uniform float edge_thickness : hint_range(0.0, 1.0, 0.001) = 0.3;
uniform float edge_speed : hint_range(0.0, 1.0, 0.001) = 0.35;
uniform float edge_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform vec2 edge_noise_scale = vec2(0.4);
uniform sampler2D edge_noise : repeat_enable;
uniform sampler2D edge_ramp : repeat_disable;

#ifdef PLAYER_WAVES
group_uniforms player;
uniform float influence_size : hint_range(0.0, 4.0, 0.1) = 1.0;
uniform float player_wave_frequenzy : hint_range(0.0, 20.0, 0.1) = 10.0;
uniform float player_wave_speed : hint_range(0.0, 10.0, 0.1) = 5.0;
uniform float player_white_strength : hint_range(0.0, 1.0, 0.01) = 0.9;
#endif

#ifdef CAUSTICS
group_uniforms caustics;
uniform float caustic_scale : hint_range(0.0, 2.0, 0.01) = 0.8;
uniform float caustic_speed : hint_range(0.0, 2.0, 0.01) = 0.5;
uniform float caustic_strength : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float caustic_threshold : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform sampler2D caustic_texture : source_color, repeat_enable;
#endif

group_uniforms normal_map;
uniform float normal_map_strength : hint_range(0.0, 4.0, 0.01) = 1.0;
uniform float scroll_speed : hint_range(0.0, 1.0, 0.01) = 0.3;
uniform vec2 scroll_offset = vec2(0.1, -0.3);
uniform float scale_offset = 0.5;
uniform vec2 normal_map_scale = vec2(0.1);
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap;

#ifdef FOAM
group_uniforms foam;
uniform sampler2D foam_texture : source_color, repeat_enable;
uniform float foam_strength : hint_range(0.0, 1.0, 0.01) = 0.6;
uniform float foam_speed : hint_range(0.0, 2.0, 0.01) = 0.3;
uniform vec2 foam_offset = vec2(0.2, 0.35);
uniform float foam_scale : hint_range(0.0, 8.0, 0.1) = 0.8;
uniform float foam_threshold : hint_range(0.0, 1.0, 0.01) = 0.65;
uniform float foam_softness : hint_range(0.01, 0.5, 0.01) = 0.2;
uniform vec3 foam_color : source_color = vec3(0.85, 0.96, 1.0);
#endif

// Hidden Uniforms
#ifdef PLAYER_WAVES
global uniform vec3 player_position;
#endif
uniform sampler2D depth_texture: hint_depth_texture, filter_linear_mipmap, repeat_disable;

varying vec3 global_position;
varying float view_distance;

#ifdef FRESNEL
float fresnel(vec3 normal, vec3 view) {
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0)), fresnel_radius);
}
#endif

vec2 safe_normalize(vec2 v) {
	return length(v) < 0.0001 ? vec2(1.0, 0.0) : normalize(v);
}

void vertex() {
	global_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	vec2 dir1 = safe_normalize(wave_direction);
	vec2 dir2 = vec2(-dir1.y, dir1.x);
	float t = TIME * wave_speed;
	float swell = sin(dot(global_position.xz, dir1) * wave_frequency + t) * 0.6
		+ sin(dot(global_position.xz, dir2) * wave_frequency * 1.7 + t * 1.3) * 0.25
		+ sin(dot(global_position.xz, dir1 + dir2) * wave_frequency * 0.6 - t * 0.7) * 0.15;
	float offset = swell * wave_amplitude;

	float detail_time = TIME * detail_speed;
	float d1 = texture(displacement_texture, global_position.xz * detail_scale + vec2(detail_time, -detail_time)).r;
	float d2 = texture(displacement_texture, global_position.xz * detail_scale * 2.3 - vec2(detail_time, detail_time) * 1.4).g;
	offset += (d1 + d2 - 1.0) * detail_amplitude;

	VERTEX.y += offset;
	global_position.y += offset;
	view_distance = length((VIEW_MATRIX * vec4(global_position, 1.0)).xyz);
}


void fragment() {
	vec2 dir1 = safe_normalize(wave_direction);

	float time_factor = TIME * scroll_speed;
	vec3 n1 = textureLod(normal_map, global_position.xz * normal_map_scale + time_factor * dir1, 2.0).xyz;
	vec3 n2 = textureLod(normal_map, global_position.xz * normal_map_scale * scale_offset - time_factor * 0.8 * (dir1 + scroll_offset), 2.0).xyz;
	NORMAL_MAP = mix(n1, n2, 0.5);
	NORMAL_MAP_DEPTH = normal_map_strength;

	// Base color: gradient from deep (near) to horizon color (far)
	float horizon_mix = smoothstep(horizon_distance * horizon_softness, horizon_distance, view_distance);
	vec3 color = mix(deep_color, horizon_color, horizon_mix);

	#ifdef FRESNEL
	float fresnel_value = fresnel(NORMAL, VIEW);
	color = mix(color, fresnel_color, fresnel_value);
	#endif

	// Fake caustics: layered scrolling noise banded into a web pattern
	#ifdef CAUSTICS
	float caustic_time = TIME * caustic_speed;
	vec2 caustic_uv = global_position.xz * caustic_scale;
	float c1 = texture(caustic_texture, caustic_uv + vec2(caustic_time, -caustic_time * 0.7)).r;
	float c2 = texture(caustic_texture, caustic_uv * 1.6 - vec2(caustic_time * 1.3, caustic_time)).g;
	float caustic_pattern = smoothstep(caustic_threshold, caustic_threshold + 0.35, (c1 + c2) * 0.75);
	color = mix(color, vec3(1.0), caustic_pattern * caustic_strength);
	#endif

	// Shoreline white strip where geometry meets the water surface
	float depth_tex = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_tex);
	vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	world.xyz /= world.w;
	float relative_depth = global_position.y - world.y;
	float edge_blend = clamp(1.0 - relative_depth / max(edge_thickness, 0.001), 0.0, 1.0);
	vec2 edge_noise_uv = global_position.xz * edge_noise_scale - dir1 * TIME * edge_speed;
	float edge_noise_sample = texture(edge_noise, edge_noise_uv).r;
	float edge_mask = texture(edge_ramp, vec2(edge_noise_sample * (1.0 - edge_blend), 0.0)).r * edge_blend;
	color = mix(color, vec3(1.0), edge_mask * edge_strength);

	// Player: white splash where the player is below the water surface
	#ifdef PLAYER_WAVES
	vec3 player_relative = global_position - player_position;
	float under = smoothstep(0.05, -0.8, player_relative.y);
	float player_distance = length(player_relative.xz);
	float player_influence = smoothstep(influence_size, 0.0, player_distance);
	color = mix(color, vec3(1.0), under * player_influence * player_white_strength);
	float rings = sin(player_distance * player_wave_frequenzy - TIME * player_wave_speed) * 0.5 + 0.5;
	float ripple = pow(rings, 4.0) * player_influence * under * 0.4;
	color = mix(color, foam_color, ripple);
	#endif

	#ifdef FOAM
	float foam_time = TIME * foam_speed;
	vec2 foam_uv = global_position.xz * foam_scale + foam_offset * foam_time;
	float foam_n1 = texture(foam_texture, foam_uv).r;
	float foam_n2 = texture(foam_texture, global_position.xz * foam_scale * 2.0 - foam_offset * foam_time * 1.3).g;
	float foam_mask = smoothstep(foam_threshold, foam_threshold + foam_softness, (foam_n1 + foam_n2) * 0.5);
	color = mix(color, foam_color, foam_mask * foam_strength); // Apply Whitecaps
	#endif

	ALBEDO = color;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}