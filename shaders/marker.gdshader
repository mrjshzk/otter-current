shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_disable;

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb * COLOR.rgb;
	ALPHA = texture(albedo_texture, UV).a * COLOR.a;
}