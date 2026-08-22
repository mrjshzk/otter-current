shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_disable;

void vertex() {
    // bro wasted money on a bill board
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
        INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
        INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
        INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
        MODEL_MATRIX[3]
    );
}

void fragment() {
	ALBEDO = vec3(0.2, 1.0, 0.2);
	ALPHA = (1.0 - texture(albedo_texture, UV).a) * COLOR.a; // invert
}