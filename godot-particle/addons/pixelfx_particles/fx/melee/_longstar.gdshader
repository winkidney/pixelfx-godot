// The thrust's long four-point star (thrust.js longStar()), colour layer: arms dotted every half pixel from 1 px out,
// L forward (right), 0.7 L back, 0.42 L up and down; white, then c5, then c4 down each arm, fading over its last 30%;
// thick at the heart (a pixel either side over the first quarter of arms longer than 6); short diagonals; a white
// centre. The rect is odd-sized round the centre's pixel (frac_: where the centre sits in it). Key L.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(65.0);
uniform vec2 frac_ = vec2(0.5);
uniform float L = 0.0;
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);

void fragment() {
	vec4 tint = COLOR;
	if (L < 1.0) {
		discard;
	}
	vec2 cell = floor((UV - 0.5) * size);
	vec4 col = vec4(0.0);
	bool hit = false;
	vec3 arms[4] = vec3[](vec3(1.0, 0.0, L), vec3(-1.0, 0.0, L * 0.7), vec3(0.0, -1.0, L * 0.42), vec3(0.0, 1.0, L * 0.42));
	for (int i = 0; i < 4; i++) {
		vec2 e = arms[i].xy;
		float len = arms[i].z;
		for (float d = 1.0; d <= 64.0; d += 0.5) {
			if (d > len) {
				break;
			}
			float u = d / len;
			vec2 p = frac_ + e * d;
			vec4 c = u < 0.3 ? vec4(1.0) : u < 0.65 ? c5 : c4;
			c.a = u < 0.7 ? 1.0 : 1.0 - (u - 0.7) / 0.35;
			if (floor(p) == cell && pfx_threshold(FRAGCOORD.xy) <= c.a * alpha_scale) {
				col = c;
				hit = true;
			}
			if (u < 0.25 && len > 6.0) {
				vec2 side_ = vec2(-e.y, e.x);
				if (floor(p + side_) == cell || floor(p - side_) == cell) {
					col = c5;
					hit = true;
				}
			}
		}
	}
	vec2 rel = cell - floor(frac_);
	float dd = min(3.0, L * 0.14);
	if (abs(rel.x) == abs(rel.y) && abs(rel.x) >= 1.0 && abs(rel.x) <= dd) {
		col = abs(rel.x) < 2.0 ? c5 : c4;
		hit = true;
	}
	if (rel == vec2(0.0)) {
		col = vec4(1.0);
		hit = true;
	}
	if (!hit) {
		discard;
	}
	col.a = 1.0;
	col *= tint;
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
