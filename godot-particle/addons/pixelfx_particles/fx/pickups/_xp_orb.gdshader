// xp-orb's comet (colour layer): the tail, 60 discs along the orb's own path behind it, tapering and cooling down the
// ramp, a bright core line down its middle, then the orb (a dark rim, a bright body, a white heart, a highlight).
// Each pixel takes the last of the original's draws that covers it and survives its dither. `t` is keyed to the
// reference's clock every frame.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/pickups/_pk.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/pickups/_xp_orb.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform vec4 ink : source_color = vec4(0.04, 0.08, 0.024, 1.0);

bool passes(float a, vec2 fc) {
	return a > 0.0 && (a >= 1.0 || a > pfx_threshold(fc));
}

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	vec2 cell = floor(pc);
	vec2 fc = FRAGCOORD.xy;
	vec2 o = orb_at(t);
	vec2 X = vec2(js_round(o.x), js_round(o.y));
	vec4 c = vec4(0.0);
	bool done = false;
	// the orb, drawn last: its highlight pixels, its body, its rim
	if (cell == X + vec2(-1.0, -2.0)) {
		c = vec4(C[7].rgb, 1.0);
		done = true;
	} else if (cell == X + vec2(-2.0, -2.0)) {
		c = vec4(1.0);
		done = true;
	} else {
		vec2 q = pc - X;
		float d2 = dot(q, q);
		if (d2 <= 3.6 * 3.6) {
			float d = sqrt(d2) / 3.6;
			float ca = cos(atan(q.y, q.x) + 2.4);
			c = vec4(d > 0.72 ? (ca > 0.3 ? C[5].rgb : C[3].rgb) : d > 0.4 ? (ca > -0.2 ? C[6].rgb : C[5].rgb) : vec3(1.0), 1.0);
			done = true;
		} else if (d2 <= 4.4 * 4.4) {
			c = vec4(ink.rgb, 1.0);
			done = true;
		}
	}
	// the core line, head first (it was drawn from i = 36 down to 1)
	for (int i = 1; i <= 36 && !done; i++) {
		float u = float(i) / 60.0;
		vec2 p = orb_at(t - u * 0.48);
		if (cell == floor(p) && passes((0.6 - u) * 4.0, fc)) {
			c = vec4(u < 0.2 ? vec3(1.0) : C[6].rgb, 1.0);
			done = true;
		}
	}
	// the ribbon, head first (drawn from i = 60 down to 1)
	for (int i = 1; i <= 60 && !done; i++) {
		float u = float(i) / 60.0;
		vec2 p = orb_at(t - u * 0.48);
		float r = 3.1 * pow(1.0 - u, 1.1);
		vec3 col = u < 0.25 ? C[5].rgb : u < 0.55 ? C[4].rgb : C[3].rgb;
		bool on;
		float a;
		if (r > 0.6) {
			vec2 q = pc - p;
			on = dot(q, q) <= r * r;
			a = u < 0.7 ? 1.0 : (1.0 - u) * 3.3;
		} else {
			on = cell == floor(p);
			a = (1.0 - u) * 3.0;
		}
		if (on && passes(a, fc)) {
			c = vec4(col, 1.0);
			done = true;
		}
	}
	if (!done || pfx_pixel(c, fc)) {
		discard;
	}
	COLOR = c;
}
