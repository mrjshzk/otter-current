shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

const vec2 TARGET_RESOLUTION = vec2(640.0, 360.0);
const float COLORS_PER_CHANNEL = 16.0;

void fragment() {
    // Pixelate the screen to 320x180
    vec2 pixel_uv = floor(SCREEN_UV * TARGET_RESOLUTION) / TARGET_RESOLUTION;

    // Get the screen color
    vec3 color = texture(screen_texture, pixel_uv).rgb;

    // Reduce the number of colors
    color = floor(color * COLORS_PER_CHANNEL) / COLORS_PER_CHANNEL;

    // Output
    COLOR = vec4(color, 1.0);
}