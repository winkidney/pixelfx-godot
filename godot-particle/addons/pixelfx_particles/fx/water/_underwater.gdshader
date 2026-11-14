// Under water (see _underwater.gdshaderinc). mode 0: the water, deeper toward the floor (soft layer); mode 1: the
// surface, a lit line with glints running along it and a darker band under it (colour layer).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_underwater.gdshaderinc"

uniform float mode = 0.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float ph = t;
	vec4 c;
	if (mode < 0.5) {
		if (p.y > 0.0 || p.y < top - 2.0 || abs(p.x) > half_w || p.y < surface_y(p.x, ph)) {
			discard;
		}
		float e = 1.0 - smoothstep(half_w - 14.0, half_w, abs(p.x));
		float depth = (p.y - top) / -top;
		// dithered between the soft layer's eight steps, so the deepening doesn't band
		c = vec4(pal[1].rgb, (0.22 + 0.22 * depth) * e + (pfx_threshold(FRAGCOORD.xy) - 0.5) / 8.0);
	} else {
		if (abs(p.x) > half_w) {
			discard;
		}
		float row = floor(surface_y(p.x, ph));
		float e = 1.0 - smoothstep(half_w - 12.0, half_w, abs(p.x));
		if (floor(p.y) == row) {
			c = vec4((surface_glint(p.x, ph) ? pal[7] : pal[5]).rgb, e * 1.3);
		} else if (floor(p.y) == row + 1.0) {
			c = vec4(pal[3].rgb, e * 1.3);
		} else {
			discard;
		}
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
