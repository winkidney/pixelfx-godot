// The floor under the cleave (heavy-cleave.js drawBack), colour layer: an ellipse of floor 19 px wide and 3 deep,
// white hot, cooling through `ramp` to soot (dark in the middle, shade round it, ragged at its rim) as `q` (s since
// the blow, keyed) runs; `fade` dithers it out. The rect's top-left pixel is (-9, 0) from the blow.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(20.0, 4.0);
uniform float q = -1.0;
uniform float fade = 1.0;
uniform vec4 ramp[8];
uniform vec4 dark : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 shade : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float h2(vec2 x, float s) {
	return fract(sin(dot(x, vec2(127.1, 311.7)) + s * 74.7) * 43758.5453);
}

void fragment() {
	vec4 tint = COLOR;
	if (q < 0.0) {
		discard;
	}
	vec2 c = floor(UV * size) - vec2(9.0, 0.0);
	if (c.x > 9.0 || c.y > 2.0) {
		discard;
	}
	float d = length(vec2((c.x + 0.5) / 9.0, (c.y + 0.5) / 3.5));
	if (d > 1.0) {
		discard;
	}
	float Th = pow(clamp(1.0 - q / 0.8, 0.0, 1.0), 1.4) * (1.2 - d) - h2(c, 3.0) * 0.3;
	vec4 col;
	if (Th > 0.08) {
		col = ramp[int(clamp(floor(Th * 9.0 + 0.5), 1.0, 7.0))];
		col.a = fade;
	} else {
		col = d < 0.5 ? dark : shade;
		col.a = (d < 0.9 - h2(c, 9.0) * 0.3 ? 1.0 : 1.0 - d) * fade;
	}
	col *= tint;
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
