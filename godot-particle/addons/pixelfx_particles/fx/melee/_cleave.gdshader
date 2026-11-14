// The heavy cleave's arc (heavy-cleave.js arc()) along a swing, colour layer: the band from u = T to U, w0 * shrink px
// in from the rim, thickest just behind the edge; each pixel cools by how long ago the edge passed it (it passed u at
// RAISE + SWING sqrt(u / U1); `tt` is the time now) and after the blow (HIT), white on the rim while fresh when `rim`,
// down `ramp` (darkest first, `n` colours), dissolving as it goes (`gone`). Over it the dotted trace of embers (plane
// radius tr_r, u 0 to tr_u1, tr_k (0.4 + 0.6 u / U1)). Key T, U, tt, shrink, gone, tr_u1, tr_k.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/melee/_swing.gdshaderinc"

uniform float T = 0.0;
uniform float U = 0.0;
uniform float w0 = 16.0;
uniform float shrink = 1.0;
uniform float gone = 0.0;
uniform float tt = 0.0;
uniform float U1 = 3.0;
uniform float RAISE = 0.2;
uniform float SWING = 0.135;
uniform float rim = 1.0;
uniform vec4 ramp[8];
uniform float n = 8.0;
uniform float tr_r = 30.0;
uniform float tr_u1 = 0.0;
uniform float tr_k = 0.0;
uniform vec4 tr_col : source_color = vec4(1.0);

vec4 arc(vec2 p) {
	if (U < 0.02 || T >= U - 0.02) {
		return vec4(0.0);
	}
	vec2 ra = sw_plane(p);
	float r = ra.x;
	if (r > R + 1.0 || r < R - w0 - 1.0) {
		return vec4(0.0);
	}
	float u = sw_u(ra.y, T, U);
	if (u < 0.0) {
		return vec4(0.0);
	}
	float age = max(0.0, tt - (RAISE + SWING * sqrt(clamp(u / U1, 0.0, 1.0))));
	float v = (u - T) / (U - T);
	float w = w0 * shrink * pow(max(0.0, sin(3.14159265 * pow(v, 2.2))), 0.6);
	if (w < 0.4) {
		return vec4(0.0);
	}
	float q = (R - r) / w;
	if (q < 0.0 || q > 1.0) {
		return vec4(0.0);
	}
	float ci = (rim > 0.5 && q < 0.22 && age < 0.12) ? 0.0 : floor(q * (n - 1.0) * 0.62 + age * 7.0 + max(0.0, tt - RAISE - SWING) * 10.0 - v * 0.8 + (rim > 0.5 ? 0.7 : 1.7) + 0.5);
	vec4 c = ramp[int(n) - 1 - int(clamp(ci, 0.0, n - 1.0))];
	c.a = min(1.0, v / 0.35) * (1.2 - gone);
	return c;
}

void fragment() {
	vec4 tint = COLOR;
	vec2 p = sw_px(UV);
	vec4 c = vec4(0.0);
	bool done = false;
	if (tr_k > 0.0 && tr_u1 > 0.02) {
		float u = sw_trace(floor(p), tr_r, 0.0, tr_u1, 0.6, 0.0);
		if (u >= 0.0) {
			c = tr_col;
			c.a = tr_k * (0.4 + 0.6 * u / U1);
			c *= tint;
			done = !pfx_pixel(c, FRAGCOORD.xy);
		}
	}
	if (!done) {
		c = arc(p) * tint;
		if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
			discard;
		}
	}
	COLOR = c;
}
