// The dark pool opened in the floor (the lib's floorPool()), seen at a slant: radius `rx` (key it), centred on the
// floor at the origin; the far lip lit, the near lip dark, ripples (rip[i] = x, t0, life, w) running out across it, a
// sheen along the far side, a wet fringe. `t` is seconds. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/shadow/_jsrand.gdshaderinc"

uniform vec2 size = vec2(96.0, 24.0);
uniform vec2 center = vec2(0.0);
uniform float rx = 40.0;
uniform float t = 0.0;
uniform vec4 pal[8] : source_color;
uniform vec4 rip[48];
uniform int rip_n = 0;

float noise1(float x, int seed) {
	float i = floor(x);
	float f = x - i;
	float u = f * f * (3.0 - 2.0 * f);
	float a = float(js_hash2(int(i), seed)) / 4294967296.0;
	float b = float(js_hash2(int(i) + 1, seed)) / 4294967296.0;
	return mix(a, b, u) * 2.0 - 1.0;
}

void fragment() {
	if (rx < 1.0) {
		discard;
	}
	vec2 p = floor((UV - 0.5) * size + center + 0.001) + 0.5;
	float ry = rx * 0.17 + 0.6;
	float dx = p.x / rx;
	float dy = (p.y - 0.5) / ry;
	float d = length(vec2(dx, dy));
	if (d > 1.18 || abs(p.x) > rx + 3.0 || abs(p.y) > ry + 2.0) {
		discard;
	}
	vec4 c = vec4(0.0);
	if (d > 1.0) {
		if (dy < 0.0 && d < 1.09) {
			c = abs(dx) < 0.55 ? pal[6] : abs(dx) < 0.85 ? pal[5] : pal[4];
		} else if (dy >= 0.0 && d < 1.09) {
			c = pal[2];
		} else if (p.y > -0.5 && noise1(p.x * 0.7, 9) > 0.15) {
			c = pal[1];
		} else {
			discard;
		}
	} else {
		bool hit = false;
		for (int i = 0; i < rip_n; i++) {
			vec4 r = rip[i];
			float age = t - r.y;
			if (age < 0.0 || age >= r.z) {
				continue;
			}
			float rr = age * 46.0 * r.w + 1.0;
			float ex = p.x - r.x;
			float ey = (p.y - 0.5) / 0.17;
			float e = max(length(vec2(ex, ey)), 1e-4);
			float g = length(vec2(ex, ey / 0.17)) / e;
			if (abs(e - rr) < 0.55 * g) {
				c = age < r.z * 0.5 ? pal[4] : pal[3];
				hit = true;
				break;
			}
		}
		if (!hit) {
			if (dy < -0.55 && dy > -0.85 && noise1(p.x * 0.25 + t * 1.3, 4) > 0.2) {
				c = noise1(p.x * 0.6 - t * 2.0, 6) > 0.55 ? pal[5] : pal[2];
			} else if (dy < -0.35 && d > 0.72) {
				c = d > 0.9 ? pal[3] : pal[2];
			} else {
				c = d > 0.86 ? pal[1] : pal[0];
			}
		}
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
