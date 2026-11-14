// The spin slash (spin-slash.js) along a swing, colour layer. mode 0, the smear: the band from u = 0 to U, w0 px in
// from the rim, thickest just behind the edge and thinning and cooling where the edge passed longer ago (it passed u at
// SW (1 - (1 - u / TAU)^(1 / 1.6)), `tt` is the time now), white at the rim while fresh when `rim`, down `ramp`
// (darkest first). mode 1, the closed ring flaring: the whole turn, th px in from the rim, white then stepping down
// the ramp by `fstep` as f runs 0 -> 1, dissolving; with it the dotted trace (plane radius tr_r, the whole turn) whose
// dots break up at random as tr_k falls. Key U, tt (mode 0); R, th, f, fstep, tr_k (mode 1).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/melee/_swing.gdshaderinc"

uniform float mode = 0.0;
uniform float U = 0.0;
uniform float tt = 0.0;
uniform float w0 = 16.0;
uniform float rim = 1.0;
uniform float SW = 0.17;
uniform float th = 0.0;
uniform float f = 0.0;
uniform float fstep = 6.0;
uniform vec4 ramp[8];
uniform float n = 7.0;
uniform float tr_r = 30.0;
uniform float tr_k = 0.0;
uniform vec4 tr_col : source_color = vec4(1.0);

float h1(float x) {
	return fract(sin(x * 91.3458 + 5.0 * 47.123) * 43758.5453);
}

vec4 body(vec2 p) {
	if (U < 0.02) {
		return vec4(0.0);
	}
	vec2 ra = sw_plane(p);
	float r = ra.x;
	if (r > R + 1.0 || r < R - w0 - 1.0 || !sw_keep(ra.y, side)) {
		return vec4(0.0);
	}
	float u = sw_u(ra.y, 0.0, U);
	if (u < 0.0) {
		return vec4(0.0);
	}
	float age = tt - SW * (1.0 - pow(1.0 - clamp(u / SW_TAU, 0.0, 1.0), 1.0 / 1.6));
	float lead = U - u;
	float w = w0 * pow(clamp(lead / 0.85, 0.0, 1.0), 0.5) * (0.3 + 0.7 * exp(-age / 0.075)) * pow(clamp(u / 1.3, 0.0, 1.0), 0.7);
	if (w < 0.45) {
		return vec4(0.0);
	}
	float q = (R - r) / w;
	if (q < 0.0 || q > 1.0) {
		return vec4(0.0);
	}
	float ci = (rim > 0.5 && q < 0.26 && age < 0.06) ? 0.0 : floor(q * (n - 1.0) * 0.7 + age * 13.0 + (rim > 0.5 ? 0.4 : 1.4) + 0.5);
	vec4 c = ramp[int(n) - 1 - int(clamp(ci, 0.0, n - 1.0))];
	c.a = min(1.0, u / 1.1 + 0.2);
	return c;
}

vec4 flare(vec2 p) {
	if (f >= 1.0 || th <= 0.0) {
		return vec4(0.0);
	}
	vec2 ra = sw_plane(p);
	float r = ra.x;
	if (r > R + 1.0 || r < R - th - 1.0 || !sw_keep(ra.y, side)) {
		return vec4(0.0);
	}
	float q = (R - r) / th;
	if (q < 0.0 || q > 1.0) {
		return vec4(0.0);
	}
	int st = int(fstep);
	vec4 c = f < 0.13 ? (q < 0.6 ? vec4(1.0) : ramp[5]) : q < 0.45 ? ramp[st] : ramp[st - 1];
	c.a = f < 0.4 ? 1.0 : 1.3 - f;
	return c;
}

void fragment() {
	vec4 tint = COLOR;
	vec2 p = sw_px(UV);
	vec4 c = vec4(0.0);
	bool done = false;
	if (mode > 0.5 && tr_k > 0.0) {
		float u = sw_trace(floor(p), tr_r, 0.0, SW_TAU, 0.6, side);
		if (u >= 0.0) {
			c = tr_col;
			c.a = clamp(tr_k * 1.5 - h1(floor(u * 30.0)) * 0.8, 0.0, 1.0) * 0.95;
			c *= tint;
			done = c.a > 0.0 && !pfx_pixel(c, FRAGCOORD.xy);
		}
	}
	if (!done) {
		c = (mode > 0.5 ? flare(p) : body(p)) * tint;
		if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
			discard;
		}
	}
	COLOR = c;
}
