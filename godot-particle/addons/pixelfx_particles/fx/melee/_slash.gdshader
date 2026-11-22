// A slash crescent along a swing (melee/_lib.js slash(), Sprite Fusion's recipe), colour layer: the band from u = T
// (tail) to U (head), thickest just behind the edge (or, `lens`, in the middle), `W` px in from the rim, white on the
// rim while young and stepping down `ramp` (darkest first, `n` colours) inward, with `age` and toward the tail; `hot`
// flashes it white. Over it, the dotted trace of the blade's path (plane radius tr_r, u from 0 to tr_u1, alpha tr_k
// * (0.4 + 0.6 u / span)) in tr_col. Key T, U, W, age, hot, tr_u1, tr_k.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/melee/_swing.gdshaderinc"

uniform float T = 0.0;
uniform float U = 0.0;
uniform float W = 8.0;
uniform float wmax = 8.0;
uniform float age = 0.0;
uniform float hot = 0.0;
uniform float lens = 0.0;
uniform float span = 3.0;
uniform vec4 ramp[8];
uniform float n = 7.0;
uniform float tr_r = 30.0;
uniform float tr_u1 = 0.0;
uniform float tr_k = 0.0;
uniform float tr_step = 0.6;
uniform vec4 tr_col : source_color = vec4(1.0);

vec4 smear(vec2 p, vec4 tint) {
	if (U - T < 0.01 || W <= 0.0) {
		return vec4(0.0);
	}
	vec2 ra = sw_plane(p);
	float r = ra.x;
	if (r > R + 1.0 || r < R - wmax - 1.0 || !sw_keep(ra.y, side)) {
		return vec4(0.0);
	}
	float u = sw_u(ra.y, T, U);
	if (u < 0.0) {
		return vec4(0.0);
	}
	float v = (u - T) / (U - T);
	float w = W * pow(sin(3.14159265 * pow(v, lens > 0.5 ? 1.0 : 2.2)), lens > 0.5 ? 0.75 : 0.6);
	if (w < 0.35) {
		return vec4(0.0);
	}
	float q = (R - r) / w;
	if (q < 0.0 || q > 1.0) {
		return vec4(0.0);
	}
	float ci = ((q < 0.22 && age < 0.5) || q < hot * 0.7) ? 0.0 : floor(q * (n - 1.0) * 0.75 + age * 2.4 - v * 0.8 + 0.4 - hot * 3.0 + 0.5);
	int idx = int(n) - 1 - int(clamp(ci, 0.0, n - 1.0));
	vec4 c = ramp[idx];
	c.a = min(1.0, v / (lens > 0.5 ? 0.1 : 0.4));
	return c * tint;
}

void fragment() {
	vec4 tint = COLOR;
	vec2 p = sw_px(UV);
	vec4 c = vec4(0.0);
	bool done = false;
	// the trace goes over the smear
	if (tr_k > 0.0 && tr_u1 > 0.02) {
		float u = sw_trace(floor(p), tr_r, 0.0, tr_u1, tr_step, side);
		if (u >= 0.0) {
			c = tr_col;
			c.a = tr_k * (0.4 + 0.6 * u / span);
			c *= tint;
			done = !pfx_pixel(c, FRAGCOORD.xy);
		}
	}
	if (!done) {
		c = smear(p, tint);
		if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
			discard;
		}
	}
	COLOR = c;
}
