// Comic hit lines jabbing in at a body (src/fx/impacts/hit-flash.js): wedges round the centre, point toward it and
// fat end out, each sliding 6 px in and shrinking away over `life` s from its own start; white then `late`, edged in
// `ink`. jabs[i] = (angle, distance, length, t0); t is the effect's time (keyed).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec4 jabs[12];
uniform float count = 0.0;
uniform float t = 0.0;
uniform float life = 0.16;
uniform vec4 ink : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 white : source_color = vec4(1.0);
uniform vec4 late : source_color = vec4(1.0);

float cross2(vec2 a, vec2 b) {
	return a.x * b.y - a.y * b.x;
}

bool in_tri(vec2 p, vec2 a, vec2 b, vec2 c) {
	float d1 = cross2(b - a, p - a);
	float d2 = cross2(c - b, p - b);
	float d3 = cross2(a - c, p - c);
	return !((d1 < 0.0 || d2 < 0.0 || d3 < 0.0) && (d1 > 0.0 || d2 > 0.0 || d3 > 0.0));
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
		vec4 j = jabs[i];
		float u = (t - j.w) / life;
		if (u < 0.0 || u >= 1.0) {
			continue;
		}
		float d0 = j.y - 6.0 * (1.0 - pow(1.0 - u, 3.0));
		float L = j.z * (1.0 - u);
		if (L < 1.0) {
			continue;
		}
		vec2 dir = vec2(cos(j.x), sin(j.x) * 1.15);
		float w = (2.8 - 1.6 * u) / 2.0;
		vec2 nn = vec2(-dir.y, dir.x) * w;
		vec2 e = dir * (d0 + L);
		vec2 p0 = dir * d0;
		if (in_tri(p, p0 - dir, e + nn * 1.5 + dir, e - nn * 1.5 + dir)) {
			c = ink;
		}
		if (in_tri(p, p0, e + nn, e - nn)) {
			c = u < 0.5 ? white : late;
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
