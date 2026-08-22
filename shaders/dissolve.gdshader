shader_type spatial;
//render_mode unshaded;

uniform float t = 0.0;
uniform vec3 albedo_and_emissive_color : source_color = vec3(1.0);
uniform sampler2D noise_tex;
uniform float noise_scale = 1.0;
uniform sampler2D albedo_texture : source_color;
uniform vec2 scroll_direction = vec2(1.0, 0.0);
uniform float scroll_speed = 0.25;

void fragment() {
	// Offset UV coordinates over time.
    vec2 scrolling_uv =
        UV + scroll_direction * scroll_speed * TIME;

	float noise = texture(noise_tex, scrolling_uv * noise_scale).r;
	float mask = step(t, noise);
	if (mask < 1.0) { discard; }
	ALBEDO = albedo_and_emissive_color;
	EMISSION = albedo_and_emissive_color;
}
