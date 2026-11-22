// The hex sigil's glints (the original's sparkle()): arms `arm` px along the axes in c with the outer 40% in tip, short
// diagonals once it's 3 px, longer ones at 6, a white heart. Colour layer. The rect is odd-sized and centred on the
// glint's pixel.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(19.0);
uniform float arm = 3.0;
uniform vec4 c : source_color = vec4(0.78, 0.52, 1.0, 1.0);
uniform vec4 tip : source_color = vec4(0.6, 0.28, 0.92, 1.0);
uniform vec4 heart : source_color = vec4(1.0);
uniform float alpha = 1.0;

void fragment() {
	ivec2 q = ivec2(floor(UV * size)) - ivec2(floor(size * 0.5));
	int n = int(round(arm));
	if (n < 1) {
		discard;
	}
	int ax = abs(q.x);
	int ay = abs(q.y);
	vec4 col;
	if (q.x == 0 && q.y == 0) {
		col = heart;
	} else if ((q.x == 0 && ay <= n) || (q.y == 0 && ax <= n)) {
		int dd = max(ax, ay);
		col = float(dd) > float(n) * 0.6 ? tip : c;
	} else if (n >= 3 && ax == 1 && ay == 1) {
		col = c;
	} else if (n >= 6 && ax == 2 && ay == 2) {
		col = tip;
	} else {
		discard;
	}
	col.a *= alpha;
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
