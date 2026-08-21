shader_type canvas_item;

uniform float flash_speed : hint_range(0.0, 5.0, 0.01) = 0.8;
uniform float stripe_width : hint_range(0.01, 1.0, 0.01) = 0.12;
uniform float stripe_angle = -0.35;
uniform float flash_intensity : hint_range(0.0, 2.0, 0.01) = 0.8;
uniform vec4 flash_color : source_color = vec4(1.0, 0.95, 0.7, 1.0);

// Wobble controls.
uniform float wobble_amplitude : hint_range(0.0, 0.05, 0.001) = 0.008;
uniform float wobble_frequency : hint_range(0.0, 20.0, 0.1) = 5.0;
uniform float wobble_speed : hint_range(0.0, 10.0, 0.1) = 2.0;

void fragment() {
    // Offset the sampled texture vertically.
    vec2 wobble_uv = UV;

    float wobble = sin(
        UV.x * wobble_frequency * 6.28318 +
        TIME * wobble_speed
    ) * wobble_amplitude;

    wobble_uv.y += wobble;

    // Preserve the original logo texture.
    vec4 base_color = texture(TEXTURE, wobble_uv);

    // Rotate coordinates for the diagonal flash stripe.
    vec2 centered_uv = UV - vec2(0.5);

    float rotated_x =
        centered_uv.x * cos(stripe_angle) -
        centered_uv.y * sin(stripe_angle);

    float stripe_position = fract(TIME * flash_speed) * 2.0 - 1.0;

    float distance_to_stripe = abs(rotated_x - stripe_position);

    float stripe = 1.0 - smoothstep(
        stripe_width * 0.35,
        stripe_width,
        distance_to_stripe
    );

    vec3 flashed_rgb = mix(
        base_color.rgb,
        base_color.rgb + flash_color.rgb * flash_intensity,
        stripe
    );

    COLOR = vec4(flashed_rgb, base_color.a);
}