// The homing missile's scorch (projectiles/homing-missile.js drawBack): three rows of the floor under the hit,
// white-hot in the middle as it lands, cooling through the fire to soot over 1.4 s; it spreads to `rx` px in a blink
// and fades late (alpha, dithered). Cells are the original's, relative to the origin. Colour layer, behind.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(40.0, 8.0);
uniform vec2 center = vec2(0.0);
uniform float age = 0.0;
uniform float rx = 16.0;
uniform float alpha = 1.0;
// the fire palette F[0] (darkest) .. F[8] (white)
uniform vec4 fire[9];
uniform vec4 soot : source_color = vec4(0.05, 0.04, 0.07, 1.0);
uniform vec4 soot2 : source_color = vec4(0.09, 0.07, 0.11, 1.0);

float h(float x) {
	return fract(sin(x * 12.9898 + 3.0 * 78.233) * 43758.5453);
}

void fragment() {
	vec2 c = floor(UV * size) - size * 0.5 + center;
	if (c.y < 0.0 || c.y > 2.0 || rx <= 0.0) {
		discard;
	}
	float d = length(vec2((c.x + 0.5) / rx, (c.y + 0.5) / 4.0));
	if (d > 1.0) {
		discard;
	}
	float T = pow(clamp(1.0 - age / 1.4, 0.0, 1.0), 1.4) * (1.25 - d) - h(c.x * 31.0 + c.y) * 0.35;
	vec4 col = T > 0.06 ? fire[int(clamp(round(T * 8.0), 1.0, 8.0))] : (d < 0.5 ? soot : soot2);
	col.a *= alpha;
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
