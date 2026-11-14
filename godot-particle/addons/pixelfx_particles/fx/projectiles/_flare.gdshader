// The original's flare() (and, with `cross`, a pop's cross): an 8-ray star, long rays (`len` px) across, 0.6 of that up and down, 0.3 on the diagonals,
// white near the heart, then c_hi, then c_lo, the outer 40% fading with `k`. The rect is odd-sized and centred on the
// flare's pixel. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(41.0);
uniform float len = 8.0;
uniform float k = 1.0;
uniform vec4 white : source_color = vec4(1.0);
uniform vec4 c_hi : source_color = vec4(0.93, 0.78, 1.0, 1.0);
uniform vec4 c_lo : source_color = vec4(0.78, 0.52, 1.0, 1.0);
uniform float alpha = 1.0;
// the up-down rays' and the diagonals' length against the long rays (0: none)
uniform float vert = 0.6;
uniform float diag = 0.3;
// 1: a pop's cross instead (white to 0.3 of the way, c_hi to 0.65, then c_lo, alpha 1.15 - u all along)
uniform float cross = 0.0;

void fragment() {
	ivec2 q = ivec2(floor(UV * size)) - ivec2(floor(size * 0.5));
	if (len < 1.0) {
		discard;
	}
	float ax = abs(float(q.x));
	float ay = abs(float(q.y));
	float d = -1.0;
	float l = len;
	if (q.y == 0) {
		d = ax;
	} else if (q.x == 0 && vert > 0.0) {
		d = ay;
		l = len * vert;
	} else if (ax == ay && diag > 0.0) {
		d = ax * 1.41421;
		l = len * diag;
	}
	if (d < 0.0 || d > l + 0.25) {
		discard;
	}
	float u = d / l;
	vec4 c;
	if (cross > 0.5) {
		c = u < 0.3 ? white : u < 0.65 ? c_hi : c_lo;
		c.a = clamp(1.15 - u, 0.0, 1.0) * alpha;
	} else {
		c = u < 0.35 ? white : u < 0.7 ? c_hi : c_lo;
		c.a = (u < 0.6 ? 1.0 : k * 1.5 * (1.0 - u) + 0.2) * alpha;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
