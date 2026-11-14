// (status/stunned: a copy of fx/ice/_flare.gdshader)
// The original's flare(): an 8-ray flare `len` px long on the axes (0.6 of it up and down, 0.3 on the diagonals), of
// dots stepping half a pixel, white near the heart, then c6, then c5, the outer part fading by `k`. Centred on the
// rect's middle pixel (odd size). Colour layer: every dot is dithered by its own alpha, the last one drawn wins.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(81.0);
uniform vec2 center = vec2(0.0);
uniform float len = 0.0;
uniform float k = 1.0;
uniform vec4 c6 : source_color = vec4(0.86, 0.98, 1.0, 1.0);
uniform vec4 c5 : source_color = vec4(0.65, 0.93, 1.0, 1.0);
uniform float alpha = 1.0;

void fragment() {
	vec4 tint = COLOR;   // the node's modulate: fade a group, tint a copy
	if (len < 1.0) {
		discard;
	}
	ivec2 P = ivec2(floor(UV * size) - floor(size / 2.0));
	float th = pfx_threshold(FRAGCOORD.xy);
	vec4 c = vec4(0.0);
	bool hit = false;
	for (int i = 0; i < 8; i++) {
		float an = float(i) * PI / 4.0;
		float L = i % 4 == 0 ? len : (i % 2 == 0 ? len * 0.6 : len * 0.3);
		vec2 dir = vec2(cos(an), sin(an));
		// only rays that can reach this pixel
		if (dot(vec2(P), dir) < -1.0) {
			continue;
		}
		int steps = int(floor(L / 0.5));
		for (int s = 0; s <= 80; s++) {
			if (s > steps) {
				break;
			}
			float d = float(s) * 0.5;
			if (ivec2(floor(dir * d + 0.5)) != P) {
				continue;
			}
			float u = d / L;
			float a = (u < 0.6 ? 1.0 : k * 1.5 * (1.0 - u) + 0.2) * alpha;
			if (a >= th) {
				c = u < 0.35 ? vec4(1.0) : (u < 0.7 ? c6 : c5);
				hit = true;
			}
		}
	}
	if (!hit) {
		discard;
	}
	c.a = 1.0;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
