// The original's flare() (core/sim.js), colour layer: an 8-ray star, rays `L` px on the axes left and right, 0.6 L up
// and down, 0.3 L on the diagonals, dotted every half pixel: white for the first 35%, then hi, then lo; solid for the
// first 60%, then dithered by k * 1.5 (1 - u) + 0.2. The rect is odd-sized round the pixel holding the centre; frac_
// is where the centre sits inside it. Key L and k.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(65.0);
uniform vec2 frac_ = vec2(0.5);
uniform float L = 0.0;
uniform float k = 1.0;
uniform vec4 white : source_color = vec4(1.0);
uniform vec4 hi : source_color = vec4(1.0);
uniform vec4 lo : source_color = vec4(1.0);

void fragment() {
	vec4 tint = COLOR;
	if (L < 1.0) {
		discard;
	}
	vec2 cell = floor((UV - 0.5) * size);
	vec2 pc = cell + 0.5 - frac_;
	float best = 2.0;
	for (int i = 0; i < 8; i++) {
		float an = float(i) * 0.78539816;
		vec2 e = vec2(cos(an), sin(an));
		float len = (i % 4 == 0) ? L : (i % 2 == 0) ? L * 0.6 : L * 0.3;
		float d0 = floor(dot(pc, e) * 2.0) * 0.5;
		for (int j = -2; j <= 2; j++) {
			float d = d0 + float(j) * 0.5;
			if (d < 0.0 || d > len) {
				continue;
			}
			if (floor(frac_ + e * d) == cell) {
				best = min(best, d / len);
			}
		}
	}
	if (best > 1.0) {
		discard;
	}
	float u = best;
	vec4 c = u < 0.35 ? white : u < 0.7 ? hi : lo;
	c.a = u < 0.6 ? 1.0 : k * 1.5 * (1.0 - u) + 0.2;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
