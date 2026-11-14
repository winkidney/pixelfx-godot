// A claw mark (claw-swipe.js) along a swing, colour layer: a lens from u = lo to hi, sharp at both ends of the full
// span S and thickest in its middle, W px wide round plane radius R - W / 2, thinning as it closes (c: 0 -> 1); white-
// hot at the core while `heat` is high, cooling outward and with time down `ramp` (darkest first, `n` colours), a
// touch darker toward its start while the head is still tearing (head < S). Over it the dotted scar: dots at plane
// radius tr_r from tr_a.x to tr_a.y and from tr_b.x to tr_b.y in tr_col, dithered by tr_k. Key lo, hi, c, heat, head,
// tr_a, tr_b, tr_k.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/melee/_swing.gdshaderinc"

uniform float lo = 0.0;
uniform float hi = 0.0;
uniform float W = 4.0;
uniform float S = 1.0;
uniform float c = 0.0;
uniform float heat = 1.0;
uniform float head = 0.0;
uniform vec4 ramp[8];
uniform float n = 8.0;
uniform float tr_r = 30.0;
uniform vec2 tr_a = vec2(0.0);
uniform vec2 tr_b = vec2(0.0);
uniform float tr_k = 0.0;
uniform vec4 tr_col : source_color = vec4(1.0);

vec4 lens(vec2 p) {
	if (hi - lo <= 0.02) {
		return vec4(0.0);
	}
	vec2 ra = sw_plane(p);
	float r = ra.x;
	if (r > R + 2.0 || r < R - W - 1.0) {
		return vec4(0.0);
	}
	float u = sw_u(ra.y, lo, hi);
	if (u < 0.0) {
		return vec4(0.0);
	}
	float v = u / S;
	float w = W * pow(max(0.0, sin(3.14159265 * v)), 1.15) * (1.0 - 0.55 * c);
	float off = abs(r - (R - W / 2.0)) / (w / 2.0 + 0.01);
	if (w < 0.5 || off > 1.0) {
		return vec4(0.0);
	}
	float ci = floor((1.0 - heat) * 5.2 + off * 1.6 + (head < S ? (S - u) / S : 0.0) * 0.5 + 0.5);
	vec4 col = ramp[int(n) - 1 - int(clamp(ci, 0.0, n - 2.0))];
	col.a = 1.0;
	return col;
}

void fragment() {
	vec4 tint = COLOR;
	vec2 p = sw_px(UV);
	vec4 col = vec4(0.0);
	bool done = false;
	if (tr_k > 0.0) {
		float ua = sw_trace(floor(p), tr_r, tr_a.x, tr_a.y, 0.6, 0.0);
		float ub = sw_trace(floor(p), tr_r, tr_b.x, tr_b.y, 0.6, 0.0);
		if (ua >= 0.0 || ub >= 0.0) {
			col = tr_col;
			col.a = tr_k;
			col *= tint;
			done = !pfx_pixel(col, FRAGCOORD.xy);
		}
	}
	if (!done) {
		col = lens(p) * tint;
		if (col.a <= 0.0 || pfx_pixel(col, FRAGCOORD.xy)) {
			discard;
		}
	}
	COLOR = col;
}
