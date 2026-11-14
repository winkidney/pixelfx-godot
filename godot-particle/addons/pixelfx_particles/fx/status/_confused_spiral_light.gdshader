// status/confused's spiral, its light: every sixth point along the arm adds `color` at 0.4 u (u: how far out).
// Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/status/_confused_spiral.gdshaderinc"

uniform vec4 color : source_color = vec4(1.0);
uniform float strength = 1.0;

void fragment() {
	ivec2 p = pixel_cell(UV);
	float k = 0.0;
	for (int i = 6; i <= N; i += 6) {
		float u = float(i) / float(N);
		if (cell_at(u, vec2(0.0)) == p) {
			k += 0.4 * u;
		}
	}
	if (k <= 0.0) {
		discard;
	}
	COLOR = vec4(color.rgb * k * strength, 1.0);
}
