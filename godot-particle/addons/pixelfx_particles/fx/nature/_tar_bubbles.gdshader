// nature/toxic-puddle: fat bubbles on the tar (the original's bubbles()): each domes up dark and glossy with light
// glowing up through it, stretches thin, then pops in a ring rippling out flat across the tar. Bubble i repeats every
// `period` s: ba[i] = (born s, life s, swell s, x), bb[i].x = its biggest radius. Key `t` 0 -> 1 over the loop.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "_tar.gdshaderinc"

uniform float count = 8.0;
uniform vec4 ba[8];
uniform vec4 bb[8];

float out_cubic(float x) {
	return 1.0 - pow(1.0 - clamp(x, 0.0, 1.0), 3.0);
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 q = floor(p);
	float T = t * period;
	vec4 col = vec4(0.0);
	for (int i = 0; i < 8; i++) {
		if (float(i) >= count) {
			break;
		}
		float age = mod(T - ba[i].x, period);
		if (age >= ba[i].y) {
			continue;
		}
		float swell = ba[i].z;
		float x = ba[i].w;
		float rmax = bb[i].x;
		float sy = tar_surf(x) + 0.5;
		if (age < swell) {
			float k = age / swell;
			float st = smoothstep(0.65, 1.0, k);
			float gr = out_cubic(min(1.0, k * 1.3));
			float rx = rmax * gr * (1.0 - 0.18 * st);
			float ry = rmax * gr * (1.0 + 0.5 * st);
			vec2 X = floor(vec2(x, sy) + 0.5);
			vec2 ij = q - X;
			vec3 c = vec3(-1.0);
			// the gloss: a curved band of sheen on its upper left, a bright highlight
			if (rx > 1.8) {
				for (float a = 3.5; a < 4.7; a += 0.16) {
					if (all(equal(floor(X + vec2(cos(a) * rx, sin(a) * ry) * 0.68), q))) {
						c = a < 3.9 ? tar_S(3.0) : a < 4.3 ? tar_C(7.0) : tar_S(1.0);
					}
				}
			}
			if (rx > 1.2) {
				vec2 hl = X - floor(vec2(rx * 0.35, ry * 0.62) + 0.5);
				if (all(equal(hl, q))) {
					c = vec3(1.0);
				} else if (all(equal(hl + vec2(1.0, 0.0), q))) {
					c = tar_C(7.0);
				}
			}
			if (c.r < 0.0 && ij.y <= 0.0 && ij.y >= -ceil(ry) - 1.0) {
				float dd = length(vec2(ij.x / max(0.6, rx), ij.y / max(0.6, ry)));
				if (dd <= 1.1) {
					float inner = 0.35 + 0.65 * k;
					if (dd > 0.9) {
						c = tar_C(0.0);
					} else if (dd < 0.55 * inner && ij.y > -ry * 0.75) {
						c = dd < 0.3 * inner ? tar_C(6.0) : tar_C(5.0);
					} else if (dd < 0.8 * inner) {
						c = tar_C(4.0);
					} else {
						c = ij.y < -ry * 0.5 ? tar_C(2.0) : tar_C(3.0);
					}
				}
			}
			if (c.r >= 0.0) {
				col = vec4(c, 1.0);
			}
			continue;
		}
		float e = age - swell;
		if (e < 0.3) {
			// the pop: a ring rippling out flat across the tar
			float k = e / 0.3;
			float rr = 2.0 + 14.0 * out_cubic(k);
			if (abs(p.x) < W * 0.95) {
				float lo = 1e9;
				float hi = -1e9;
				for (int cy = 0; cy < 2; cy++) {
					for (int cx = 0; cx < 2; cx++) {
						vec2 d = q + vec2(float(cx), float(cy)) - vec2(x, sy);
						float f = length(vec2(d.x, d.y / 0.22)) - rr;
						lo = min(lo, f);
						hi = max(hi, f);
					}
				}
				if (lo <= 0.0 && hi >= 0.0) {
					vec3 c = k < 0.4 ? vec3(1.0) : k < 0.7 ? tar_C(7.0) : tar_C(6.0);
					col = vec4(c, clamp((1.0 - k) * 1.4, 0.0, 1.0));
				}
			}
		}
	}
	if (col.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
