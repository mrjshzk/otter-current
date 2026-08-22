shader_type spatial;

#include "res://shaders/includes/wave_wobble.gdshaderinc"

void vertex() {
	VERTEX.y += wave_wobble_offset((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
}