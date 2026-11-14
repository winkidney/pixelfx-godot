// A fountain's water (water/fountain). mode 0: the water in the basin, dark and see-through with a lit band at its far
// side (soft layer); mode 1: the jet, a glassy column white down its middle wobbling a little at the top, the bloom
// where it opens out and the foam where it leaves the spout (colour layer). by: the floor plane under the basin's
// middle; level: the water's height above it; jet: the jet's height. Key `t` 0 -> 1 over the loop.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float by = -12.24;
uniform float level = 8.8;
uniform float jet = 54.0;
uniform float pool_r = 29.5;
uniform float sy = 0.34;
uniform float seed = 3.0;
uniform float mode = 0.0;

const float F_TAU = 6.28318530718;

bool cell(vec2 a, vec2 p) {
	return all(equal(floor(a), floor(p)));
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float T = t * F_TAU;
	vec4 c = vec4(0.0);
	if (mode < 0.5) {
		float ry = pool_r * sy;
		float cy = by - level;
		float dx = p.x / pool_r;
		float dy = (p.y - cy) / ry;
		if (dx * dx + dy * dy > 1.0) {
			discard;
		}
		c = dy < -0.55 ? vec4(pal[3].rgb, 0.8) : vec4(pal[1].rgb, 0.85);
	} else {
		float v = (by - 16.0 - p.y) / (jet - 16.0);
		if (p.y >= by - jet - 1.0 && p.y <= by - 16.0 && abs(p.x) <= 3.0) {
			float sway = sin(T * 2.0 + v * 5.0) * 0.5 * v;
			float w = 1.3 + 0.5 * v + 0.3 * sin(T * 3.0 + p.y * 0.4);
			float q = (p.x - sway) / w;
			if (abs(q) <= 1.0) {
				float nz = w_noise2(vec2(p.x * 0.9, mod(p.y * 0.15 + t * 16.0, 16.0)), seed);
				c = q < -0.4 ? pal[6] : q < 0.35 ? (nz > -0.3 ? pal[7] : pal[6]) : pal[5];
			}
		}
		vec2 top = vec2(0.0, by - jet - 1.0);
		if (distance(p, top) <= 2.4) {
			c = pal[6];
		}
		if (distance(p, top + vec2(-0.4, -0.5)) <= 1.4) {
			c = pal[7];
		}
		for (int i = 0; i < 4; i++) {
			float fi = float(i);
			if (cell(vec2(sin(T * 3.0 + fi * 1.7) * 2.5, by - 16.0 - mod(fi, 2.0)), p)) {
				c = mod(fi, 2.0) > 0.5 ? pal[6] : pal[7];
			}
		}
		if (c.a <= 0.0) {
			discard;
		}
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
