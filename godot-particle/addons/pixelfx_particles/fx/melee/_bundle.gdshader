// The thrust's bundle (thrust.js), colour layer: up to 8 streaks fanned at the hand that shoot out to meet at the
// point, hold, then are drawn in to it. Streak i: sa[i] = (x0, y0, len, t0) (where it starts, its row at the hand,
// how much of the way it reaches, when it sets off), sb[i].x = 1 for the hot middle one (2 px thick). The tip is
// (TX, TY); `t` is the effect's time (keyed). Dots every half pixel along x, each the pixel cell holding it, white at
// the head, cooling back down the streak, fading in at its tail.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 sa[8];
uniform vec4 sb[8];
uniform float count = 0.0;
uniform float t = 0.0;
uniform float OUT = 0.07;
uniform float HOLD = 0.06;
uniform float PULL = 0.2;
uniform vec2 tip = vec2(0.0);
uniform vec4 c3 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);

float smooth_(float a, float b, float x) {
	float u = clamp((x - a) / (b - a), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

void fragment() {
	vec4 tint = COLOR;
	vec2 cell = floor((UV - 0.5) * size) + center;
	float pull = smooth_(OUT + HOLD, OUT + HOLD + PULL, t);
	vec4 col = vec4(0.0);
	for (int i = 0; i < 8; i++) {
		if (float(i) >= count) {
			break;
		}
		vec4 s = sa[i];
		float u = clamp((t - s.w) / OUT, 0.0, 1.0);
		float head = u >= 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * u);
		if (u <= 0.0 || pull >= 1.0) {
			continue;
		}
		bool hot = sb[i].x > 0.5;
		float x0 = s.x;
		float y0 = s.y;
		float end = x0 + (tip.x - x0) * s.z;
		float x1 = x0 + (end - x0) * head;
		float xa = x0 + (end - x0) * max(pull, head * 0.35 * (1.0 - s.z) * 3.0);
		float j0 = ceil((cell.x - xa) / 0.5);
		for (int j = 0; j < 2; j++) {
			float x = xa + (j0 + float(j)) * 0.5;
			if (x < xa - 1e-4 || x > x1 + 1e-4 || floor(x) != cell.x) {
				continue;
			}
			float y = y0 + (tip.y - y0) * clamp((x - x0) / (tip.x - x0), 0.0, 1.0) * 0.85;
			float v = (x - xa) / max(1.0, x1 - xa);
			if (floor(y) == cell.y) {
				vec4 c = v > 0.88 ? vec4(1.0) : hot ? (v > 0.35 ? c6 : c5) : v > 0.55 ? c5 : v > 0.25 ? c4 : c3;
				c.a = v < 0.12 ? v / 0.12 : 1.0;
				if (pfx_threshold(FRAGCOORD.xy) <= c.a * alpha_scale) {
					col = c;
				}
			} else if (hot && v > 0.1 && floor(y + 1.0) == cell.y) {
				vec4 c = v > 0.6 ? c5 : c3;
				c.a = v < 0.2 ? v / 0.2 : 1.0;
				if (pfx_threshold(FRAGCOORD.xy) <= c.a * alpha_scale) {
					col = c;
				}
			}
		}
	}
	if (col.a <= 0.0) {
		discard;
	}
	col.a = 1.0;
	col *= tint;
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
