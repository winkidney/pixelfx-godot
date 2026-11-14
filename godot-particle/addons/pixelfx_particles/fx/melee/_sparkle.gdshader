// The original's sparkle() (core/sim.js) as a shape, colour layer: a star glint whose arms are `arm` px (rounded) in
// `c` with the outer 40% in `tip`, short diagonals from 3, longer ones from 6, a white heart. The rect is odd-sized and
// centred on the glint's pixel (melee/_melee.gd sparkle()); its light is a glow of its own.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(25.0);
uniform float arm = 3.0;
uniform vec4 c : source_color = vec4(1.0);
uniform vec4 tip : source_color = vec4(1.0);
uniform vec4 heart : source_color = vec4(1.0);

void fragment() {
	vec4 tint = COLOR;
	ivec2 q = ivec2(floor(UV * size)) - ivec2(floor(size * 0.5));
	int n = int(floor(arm + 0.5));
	if (n < 1) {
		discard;
	}
	int ax = abs(q.x);
	int ay = abs(q.y);
	vec4 col;
	if (q.x == 0 && q.y == 0) {
		col = heart;
	} else if ((q.x == 0 && ay <= n) || (q.y == 0 && ax <= n)) {
		col = float(max(ax, ay)) > float(n) * 0.6 ? tip : c;
	} else if (n >= 3 && ax == 1 && ay == 1) {
		col = c;
	} else if (n >= 6 && ax == 2 && ay == 2) {
		col = tip;
	} else {
		discard;
	}
	col *= tint;
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
