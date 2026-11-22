// blunt-hit's inked wedges (src/fx/impacts/blunt-hit.js): each jabs out from the blob at its own length and pace and
// snaps back, a white (then hi) triangle pointing in, inked round with `ink`. wa[i] = (angle, length, width, r0),
// wt[i] = (t0, out, back, 0); t is the effect's time (key it from 0 to the end).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec4 wa[12];
uniform vec4 wt[12];
uniform float count = 0.0;
uniform float t = 0.0;
uniform vec4 ink : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 white : source_color = vec4(1.0);
uniform vec4 hi : source_color = vec4(1.0);

float cross2(vec2 a, vec2 b) {
	return a.x * b.y - a.y * b.x;
}

bool in_tri(vec2 p, vec2 a, vec2 b, vec2 c) {
	float d1 = cross2(b - a, p - a);
	float d2 = cross2(c - b, p - b);
	float d3 = cross2(a - c, p - c);
	bool neg = d1 < 0.0 || d2 < 0.0 || d3 < 0.0;
	bool pos = d1 > 0.0 || d2 > 0.0 || d3 > 0.0;
	return !(neg && pos);
}

void fragment() {
	vec4 tint = COLOR;
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	int n = int(count + 0.5);
	vec4 c = vec4(0.0);
	for (int i = 0; i < 12; i++) {
		if (i >= n) {
			break;
		}
		vec4 g = wa[i];
		vec4 w = wt[i];
		float u = t - w.x;
		if (u < 0.0 || u > w.y + w.z) {
			continue;
		}
		float s = u < w.y ? 1.0 - pow(1.0 - u / w.y, 3.0) : 1.0 - pow((u - w.y) / w.z, 2.0);
		float L = g.y * s;
		if (L < 1.5) {
			continue;
		}
		vec2 dir = vec2(cos(g.x), sin(g.x));
		float r0 = g.w + 2.0 * s;
		float hw = g.z * (0.6 + 0.4 * s) / 2.0;
		vec2 tip = dir * r0;
		vec2 e = dir * (r0 + L);
		vec2 nn = vec2(-dir.y, dir.x) * hw;
		if (in_tri(p, tip - dir, e + nn * 1.45 + dir, e - nn * 1.45 + dir)) {
			c = ink;
		}
		if (in_tri(p, tip, e + nn, e - nn)) {
			c = u < w.y + 0.02 ? white : hi;
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
