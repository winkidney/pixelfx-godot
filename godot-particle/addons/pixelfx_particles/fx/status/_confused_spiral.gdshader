// status/confused's spiral (see _confused_spiral.gdshaderinc): a dark underlay (c1) under the outer arm, a step down
// and right, then the arm brightening as it winds out (c2 at the heart, c3, c4, c5 at the tip). Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/status/_confused_spiral.gdshaderinc"

uniform vec4 c1 : source_color = vec4(0.3, 0.1, 0.4, 1.0);
uniform vec4 c2 : source_color = vec4(0.5, 0.2, 0.7, 1.0);
uniform vec4 c3 : source_color = vec4(0.8, 0.4, 0.9, 1.0);
uniform vec4 c4 : source_color = vec4(0.9, 0.7, 1.0, 1.0);
uniform vec4 c5 : source_color = vec4(1.0);

void fragment() {
	vec4 tint = COLOR;
	ivec2 p = pixel_cell(UV);
	int hit = -1;
	ivec2 a = cell_at(0.0, vec2(0.0));
	for (int i = 1; i <= N; i++) {
		ivec2 b = cell_at(float(i) / float(N), vec2(0.0));
		if (on_line(p, a, b)) {
			hit = i;
		}
		a = b;
	}
	vec4 c;
	if (hit >= 0) {
		float u = float(hit) / float(N);
		c = u > 0.88 ? c5 : (u > 0.62 ? c4 : (u > 0.3 ? c3 : c2));
	} else {
		bool under = false;
		vec2 off = vec2(0.5, 0.7);
		a = cell_at(float(32) / float(N), off);
		for (int i = 33; i <= N; i++) {
			ivec2 b = cell_at(float(i) / float(N), off);
			if (on_line(p, a, b)) {
				under = true;
			}
			a = b;
		}
		if (!under) {
			discard;
		}
		c = c1;
	}
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
