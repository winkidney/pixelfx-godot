// The drum (explosions/barrel-explosion): a steel drum standing on the floor, BW x BH px, red with two ribs, a lit left
// side, a dark right side, an outline and a pale band; its lid (a dark ellipse with a lit rim) bulges up with `k`.
// `shake` moves it (px, sub-pixel). The original's drawBarrel, pixel for pixel. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(32.0);
uniform vec2 center = vec2(0.0);
uniform vec2 shake = vec2(0.0);
uniform float k = 0.0;
uniform float bw = 8.0;
uniform float bh = 22.0;
uniform vec4 c1 : source_color;
uniform vec4 c2 : source_color;
uniform vec4 c3 : source_color;
uniform vec4 c4 : source_color;
uniform vec4 c5 : source_color;
uniform vec4 band_lit : source_color = vec4(0.91, 0.85, 0.69, 1.0);
uniform vec4 band_mid : source_color = vec4(0.72, 0.66, 0.53, 1.0);
uniform vec4 band_dark : source_color = vec4(0.43, 0.38, 0.31, 1.0);
uniform vec4 outline : source_color;

vec4 ramp(int i) {
	return i <= 1 ? c1 : i == 2 ? c2 : i == 3 ? c3 : i == 4 ? c4 : c5;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float x = shake.x;
	float y = shake.y;
	float bulge = floor(k * k * 2.0 + 0.5);
	vec4 c = vec4(0.0);
	bool hit = false;
	// the drum
	float dx = (p.x - x) / bw;
	float v = (y - p.y) / bh;
	if (p.x >= x - bw - 1.0 && p.x <= x + bw + 1.0 && p.y >= y - bh - 3.0 && p.y <= y + 0.5 && abs(dx) <= 1.1 && v >= 0.0 && v <= 1.05) {
		hit = true;
		if (abs(dx) > 0.92 || v > 0.97 || v < 0.04) {
			c = outline;
		} else {
			bool rib = abs(v - 0.33) < 0.035 || abs(v - 0.67) < 0.035;
			bool rib_lit = abs(v - 0.31) < 0.03 || abs(v - 0.65) < 0.03;
			float lit = -dx;
			int i = lit > 0.55 ? 5 : lit > 0.15 ? 4 : lit > -0.35 ? 3 : lit > -0.75 ? 2 : 1;
			if (v > 0.44 && v < 0.56) {
				c = lit > 0.3 ? band_lit : lit > -0.4 ? band_mid : band_dark;
			} else {
				if (rib) {
					i = max(1, i - 2);
				} else if (rib_lit) {
					i = min(5, i + 1);
				}
				c = ramp(i);
			}
		}
	}
	// the lid
	vec2 lc = vec2(x, y - bh - bulge * 0.5);
	vec2 lr = vec2(bw - 0.5, 2.2 + bulge * 0.4);
	vec2 q = (p - lc) / lr;
	if (abs(p.x - lc.x) <= lr.x && abs(p.y - lc.y) <= lr.y && dot(q, q) <= 1.0) {
		hit = true;
		c = length(q) > 0.7 ? (q.y < 0.0 ? c4 : c2) : c1;
	}
	if (!hit) {
		discard;
	}
	c.a = 1.0;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
