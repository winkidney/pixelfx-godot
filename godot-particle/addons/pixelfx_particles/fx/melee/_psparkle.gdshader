// A particle drawn as the original's sparkle() (melee/_kinds.gdshader STAR), colour layer: the quad is 2 n + 1 px
// across, n (the arm) arrives in the alpha as (n + 1.5) / 16. Arms in the colour with their outer 40% at 0.75 of it,
// short diagonals from 3, longer ones from 6, a white heart (n = 0: one pixel in the colour).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform float tip_k = 0.75;

void fragment() {
	int n = int(floor(COLOR.a * 16.0 + 0.01)) - 1;
	if (n < 0) {
		discard;
	}
	float w = 2.0 * float(n) + 1.0;
	ivec2 q = ivec2(floor(UV * w)) - ivec2(n);
	int ax = abs(q.x);
	int ay = abs(q.y);
	vec4 c = vec4(COLOR.rgb, 1.0);
	vec4 tip = vec4(COLOR.rgb * tip_k, 1.0);
	vec4 col;
	if (ax == 0 && ay == 0) {
		col = n == 0 ? c : vec4(1.0);
	} else if ((q.x == 0 && ay <= n) || (q.y == 0 && ax <= n)) {
		col = float(max(ax, ay)) > float(n) * 0.6 ? tip : c;
	} else if (n >= 3 && ax == 1 && ay == 1) {
		col = c;
	} else if (n >= 6 && ax == 2 && ay == 2) {
		col = tip;
	} else {
		discard;
	}
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
