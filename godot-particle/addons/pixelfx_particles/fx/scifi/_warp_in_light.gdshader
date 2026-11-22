// Warp in's light (src/fx/scifi/warp-in.js), from the effect's clock `t`: the pool on the floor, light riding the
// column's walls (or down its middle before it opens), the guide thread's head, under each ring, the hero's rows
// fresh off the scanline, the scanline's band and its glints, the slam's star. (The slam's and the snap's flashes are
// keyed glows.) Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/scifi/_scifi_light.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_jsrand.gdshaderinc"

uniform vec2 size = vec2(192.0, 168.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform int seed = 3;
uniform float W = 15.0;
uniform sampler2D tex : filter_nearest;
uniform vec4 pal[8] : source_color;
uniform float rings[12];
uniform int ring_count = 0;
uniform float strength = 1.0;

const float SLAM = 0.34;
const float OPEN = 0.52;
const float SCAN0 = 0.62;
const float SCAN1 = 1.4;
const float COOL = 0.42;
const float DONE = 1.82;
const float CLOSE = 1.9;
const float SNAP = 2.16;
const float TOP = -128.0;
const int AX = -12;
const int AY = -38;
const int AW = 24;
const int AH = 38;


bool on_body(ivec2 p) {
	ivec2 q = p - ivec2(AX, AY);
	if (q.x < 0 || q.y < 0 || q.x >= AW || q.y >= AH) {
		return false;
	}
	return texelFetch(tex, q, 0).a > 0.5;
}

float width_at(float tt) {
	if (tt < SLAM) {
		return 0.0;
	}
	if (tt < CLOSE) {
		return W * (1.0 + 0.45 * exp(-(tt - SLAM) * 14.0) + 0.03 * sin(tt * 31.0));
	}
	return mix(W, 0.7, e_out_cubic((tt - CLOSE) / (SNAP - CLOSE)));
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size + 0.001);
	vec2 pc = cell + 0.5;
	ivec2 P = ivec2(cell);
	vec3 l = vec3(0.0);
	float w = width_at(t);
	float on = t < SLAM ? e_smooth(0.0, SLAM, t) * 0.5 : 1.0 - e_smooth(SNAP, SNAP + 0.5, t);
	if (on > 0.01) {
		float rx = W * 1.9 + (t < SLAM ? 0.0 : 2.0 * sin(t * 6.0));
		for (int i = -1; i <= 1; i++) {
			l += pal[4].rgb * glow_at(pc, vec2(float(i) * rx * 0.6, -1.0), rx * 1.3) * 0.3 * on;
		}
	}
	for (int i = 0; i < 12; i++) {
		if (i >= ring_count) {
			break;
		}
		float k = (t - rings[i]) / 0.5;
		if (k >= 0.0 && k < 1.0) {
			float y = mix(TOP + 6.0, -1.0, e_in_quad(k));
			l += pal[5].rgb * glow_at(pc, vec2(0.0, y), w * 1.18 + 1.0 + 6.0) * 0.25;
		}
	}
	if (w > 0.05 && t <= SNAP + 0.14) {
		float bottom = t - SLAM < 0.06 ? mix(TOP, 0.0, e_in_cubic(clamp((t - SLAM) / 0.06, 0.0, 1.0) * 0.5 + 0.5)) : t > SNAP ? mix(0.0, TOP, e_out_expo((t - SNAP) / 0.14)) : 0.0;
		bool hero = t - SLAM < 0.07;
		float hollow = 0.78 * e_smooth(OPEN - 0.16, OPEN, t);
		for (float y = TOP; y < bottom; y += 8.0) {
			if (abs(pc.y - y) > 64.0) {
				continue;
			}
			if (hollow < 0.4) {
				l += pal[4].rgb * glow_at(pc, vec2(0.0, y), min(w * 2.6 + 6.0, y - TOP + 2.0)) * (hero ? 0.55 : 0.32);
			} else {
				float r = min(w + 8.0, y - TOP + 2.0);
				l += pal[4].rgb * (glow_at(pc, vec2(-(w + 3.0), y), r) + glow_at(pc, vec2(w + 3.0, y), r)) * 0.24;
			}
		}
	}
	if (t < SLAM) {
		float a = e_smooth(0.0, SLAM * 0.8, t) * 0.8;
		float head = mix(TOP, 0.0, e_out_cubic(t / (SLAM * 0.6)));
		l += pal[5].rgb * glow_at(pc, vec2(0.0, head), 10.0) * 0.5 * a;
	}
	// the hero's fresh rows give off light
	if (t < DONE && t >= SCAN0 - 0.2) {
		for (int dxi = 1; dxi >= -1; dxi--) {
			ivec2 b = P - ivec2(dxi, 0);
			if (!on_body(b)) {
				continue;
			}
			float a = t - (SCAN0 + ((SCAN1 - SCAN0) * acos(1.0 - 2.0 * clamp((float(b.y) + 0.5 - (float(AY) - 2.0)) / (3.0 - float(AY)), 0.0, 1.0))) / PI);
			if (a < 0.0) {
				continue;
			}
			float j = float(js_hash3(seed, b.x - AX, b.y - AY)) / 4294967296.0;
			int dx = a < 0.06 && j < 0.3 ? (j < 0.15 ? -1 : 1) : 0;
			float k = a / COOL;
			if (dx == dxi && k < 0.5) {
				l += pal[5].rgb * 0.22 * (1.0 - k / 0.5);
			}
		}
	}
	if (t > SCAN0 && t < SCAN1) {
		float y = floor(mix(float(AY) - 2.0, 1.0, e_in_out_sine((t - SCAN0) / (SCAN1 - SCAN0))));
		float ww = w * 1.5;
		l += pal[5].rgb * glow_seg(pc, vec2(-ww, y), vec2(ww, y), 5.0) * 0.5;
		int my = int(y) - AY;
		if (my >= 0 && my < AH) {
			int r0 = 1000;
			int r1 = -1000;
			for (int i = 0; i < 64; i++) {
				if (i >= AW) {
					break;
				}
				if (texelFetch(tex, ivec2(i, my), 0).a > 0.5) {
					r0 = min(r0, AX + i);
					r1 = max(r1, AX + i);
				}
			}
			if (r1 >= r0) {
				l += pal[6].rgb * (glow_at(pc, vec2(float(r0) + 0.5, y), 8.0) + glow_at(pc, vec2(float(r1) + 0.5, y), 8.0)) * 0.3;
			}
		}
	}
	if (t > SLAM && t < SLAM + 0.16) {
		float n = floor(12.0 * (1.0 - (t - SLAM) / 0.16) + 0.5);
		if (n >= 1.0) {
			l += pal[6].rgb * glow_at(pc, vec2(0.0, -2.0), 4.0 + n * 2.0) * 0.6;
		}
	}
	COLOR = vec4(l * strength, 1.0);
}
