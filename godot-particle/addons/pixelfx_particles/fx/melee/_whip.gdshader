// The whip (whip-crack.js shape()), colour layer: a point every pixel of its length from the handle `hand`: straight
// out (with a slight bow) to the running loop at `l`, round the loop (radius 6.5 - 3.5 l / Lw), folded back under it;
// after the crack it shortens (`len`) and sags (`recoil`). dotted 0: the whip itself, 1 px lines between the points:
// white on the loop's leading half, c5 round the loop, c4 on the near half, c3 beyond, a c2 line under its first 40%,
// dithered by `fade`. dotted 1: an afterimage, every other point in dcol dithered by fade. Key l, len, recoil, fade.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec2 hand = vec2(0.0);
uniform float Lw = 76.0;
uniform float l = 20.0;
uniform float len = 76.0;
uniform float recoil = 0.0;
uniform float fade = 1.0;
uniform float before = 1.0;
uniform float dotted = 0.0;
uniform vec4 dcol : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);

vec2 pt(float s, float r) {
	vec2 p;
	if (s <= l) {
		p = vec2(hand.x + s, hand.y - sin(3.14159265 * s / max(l, 1.0)) * 2.5 * (1.0 - l / Lw));
	} else if (s <= l + 3.14159265 * r) {
		float th = (s - l) / r;
		p = vec2(hand.x + l + sin(th) * r, hand.y + r - cos(th) * r);
	} else {
		p = vec2(hand.x + l - (s - l - 3.14159265 * r), hand.y + 2.0 * r);
	}
	if (recoil > 0.0) {
		p.y += sin(3.14159265 * s / Lw) * 6.0 * recoil;
	}
	return p;
}

void fragment() {
	vec4 tint = COLOR;
	if (fade <= 0.0) {
		discard;
	}
	vec2 cell = floor((UV - 0.5) * size) + center;
	float r = 6.5 - 3.5 * (l / Lw);
	float n = floor(len) + 1.0;
	vec4 col = vec4(0.0);
	vec2 prev = floor(pt(0.0, r));
	for (int i = 1; i < 96; i++) {
		float s = float(i);
		if (s >= n) {
			break;
		}
		vec2 cur = floor(pt(s, r));
		if (dotted > 0.5) {
			if (i % 2 == 1 && cur == cell) {
				col = dcol;
			}
		} else {
			float u = s / n;
			bool in_loop = before > 0.5 && s > l && s < l + 3.14159265 * r;
			bool lead = in_loop && abs(s - l - 3.14159265 * r / 2.0) < r * 0.9;
			// a diagonal step fills the corner the original's line would pass through first
			bool on = cur == cell || prev == cell;
			if (u < 0.4 && (cur + vec2(0.0, 1.0) == cell || prev + vec2(0.0, 1.0) == cell)) {
				col = c2;
			}
			if (on) {
				col = lead ? vec4(1.0) : in_loop ? c5 : u < 0.5 ? c4 : c3;
			}
		}
		prev = cur;
	}
	if (col.a <= 0.0) {
		discard;
	}
	col.a *= fade;
	col *= tint;
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
