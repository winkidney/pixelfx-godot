// status/burning's flame tongues at one hot spot (the original's tongue() from _lib.js): up to three tongues standing
// on `spot` (feet coords, its .5 fraction kept), each [dx, base height, noise seed] in `tg`, filled in nested layers
// (a deep rim c6, orange c4, yellow c2, a white heart c0 once tall enough), rows rippling with looping noise, tips
// swept by the wind; every 0.6 s they flare (2.6 x as tall). The rect's top-left cell is `top_left` (feet coords).
// Keyed: t (0..1 over the loop). Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/status/_burning.gdshaderinc"

uniform vec2 size = vec2(20.0, 32.0);
uniform vec2 center = vec2(0.0);
uniform vec2 top_left = vec2(0.0);
uniform vec2 spot = vec2(0.0);
uniform vec3 tg[3];
uniform int count = 1;
uniform float t = 0.0;
uniform vec4 c0 : source_color;
uniform vec4 c2 : source_color;
uniform vec4 c4 : source_color;
uniform vec4 c6 : source_color;

const float D = 1.2;
const float TICK = 0.6;
const float WIND = -14.0;

void fragment() {
	vec2 q = floor(UV * size) + top_left;
	float T = t * D;
	float fl = exp(-mod(T, TICK) / 0.12);
	vec4 c = vec4(0.0);
	// a layer: width, height, colour
	vec3 L[4] = vec3[](vec3(1.0, 1.0, 6.0), vec3(0.76, 0.86, 4.0), vec3(0.54, 0.68, 2.0), vec3(0.3, 0.42, 0.0));
	for (int k = 0; k < 3; k++) {
		if (k >= count) {
			break;
		}
		int n = int(tg[k].z);
		float x = spot.x + tg[k].x;
		float h = tg[k].y * (0.85 + 0.25 * b_tnoise(T, D, 5.0, n, 0.0)) * (1.0 + 1.6 * fl);
		if (h < 1.0) {
			continue;
		}
		float w = 1.1 + 0.3 * fl;
		float sx = WIND * 0.08 * h / 4.0 + b_tnoise(T, D, 3.0, n + 9, 0.0) * 0.8;
		float r = spot.y + 0.5 - q.y;
		if (r < 0.0) {
			continue;
		}
		for (int l = 0; l < 4; l++) {
			if (l == 3 && h < 4.0) {
				continue;
			}
			float H = h * L[l].y;
			if (r > H) {
				continue;
			}
			float u = r / max(1.0, H);
			float half_w = w * L[l].x * pow(1.0 - u, 0.85) * min(1.0, (r + 1.5) / 3.5) + b_tnoise(T, D, 9.0, n, r * 0.45) * 0.5;
			if (half_w < 0.3) {
				continue;
			}
			float cx = x + sx * u * u * L[l].y + b_tnoise(T, D, 4.0, n + 7, r * 0.2) * u * 1.1;
			if (q.x >= b_round(cx - half_w) && q.x <= b_round(cx + half_w)) {
				c = l == 0 ? c6 : (l == 1 ? c4 : (l == 2 ? c2 : c0));
			}
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	c *= COLOR;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
