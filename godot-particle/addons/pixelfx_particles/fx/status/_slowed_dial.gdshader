// status/slowed's clock dial behind the head, on a rect centred on it (R = 18): `pass` 0 is the glassy face (two
// translucent discs; give it translucent = true), 1 the rim (a dark edge, a bright band lit from the top left that
// turns white while `hot`, a thin inner line), the minute dots, the hour marks (quarters longer and brighter), the
// short hand (`short_ang`), the long heavy hand (`ang`), the hub, and the ripple thrown by each tick (`ripple_r`,
// `ripple_a`). Keyed: ang, short_ang, hot, ripple_r, ripple_a. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float pass = 1.0;
uniform float ang = -1.5708;
uniform float short_ang = 0.63;
uniform float hot = 0.0;
uniform float ripple_r = 0.0;
uniform float ripple_a = 0.0;
uniform vec4 cols[8];

const float R = 18.0;

// the original's p.line between the cells of a and b (Bresenham)
bool on_line(ivec2 p, ivec2 s, ivec2 e) {
	int dx = abs(e.x - s.x);
	int dy = -abs(e.y - s.y);
	int stx = s.x < e.x ? 1 : -1;
	int sty = s.y < e.y ? 1 : -1;
	int err = dx + dy;
	for (int k = 0; k < 12; k++) {
		if (s == p) {
			return true;
		}
		if (s == e) {
			return false;
		}
		int e2 = 2 * err;
		if (e2 >= dy) {
			err += dy;
			s.x += stx;
		}
		if (e2 <= dx) {
			err += dx;
			s.y += sty;
		}
	}
	return false;
}

// the original's p.beam: pixel centres within w / 2 of the segment from the centre to b; u along it
bool beam(vec2 q, vec2 b, float w, out float u) {
	u = clamp(dot(q, b) / max(dot(b, b), 1e-9), 0.0, 1.0);
	return length(b * u - q) <= w * 0.5;
}

void fragment() {
	vec2 cellp = floor(UV * size) - floor(size / 2.0);
	vec2 q = cellp + 0.5;
	float d = length(q);
	float a = atan(q.y, q.x);
	vec4 c = vec4(0.0);
	if (pass < 0.5) {
		if (d <= R - 1.0) {
			c = vec4(cols[2].rgb, 0.2);
			if (length(q - vec2(-R * 0.25, -R * 0.3)) <= R * 0.5) {
				c = vec4(mix(cols[2].rgb, cols[4].rgb, 0.3), 0.26);
			}
		}
	} else {
		if (d <= R + 1.0 && d >= R) {
			c = cols[0];
		}
		if (d <= R - 3.5 && d >= R - 4.5) {
			c = vec4(cols[3].rgb, 0.6);
		}
		ivec2 ip = ivec2(cellp);
		for (int i = 0; i < 60; i++) {
			if (i % 5 == 0) {
				continue;
			}
			float g = float(i) / 60.0 * TAU;
			if (ivec2(floor(vec2(cos(g), sin(g)) * (R - 2.6))) == ip) {
				c = vec4(cols[4].rgb, 0.8);
			}
		}
		for (int i = 0; i < 12; i++) {
			float g = float(i) / 12.0 * TAU;
			bool big = i % 3 == 0;
			vec2 dir = vec2(cos(g), sin(g));
			if (on_line(ip, ivec2(floor(dir * (R - 2.5))), ivec2(floor(dir * (R - (big ? 6.0 : 4.5)))))) {
				c = big ? cols[6] : cols[5];
			}
		}
		if (d <= R && d >= R - 2.0) {
			float v = (d - (R - 2.0)) / 2.0;
			c = sin(a + 0.8) < -0.3 ? (hot > 0.5 ? cols[7] : cols[6]) : (v > 0.5 ? cols[5] : cols[4]);
		}
		float u;
		if (beam(q, vec2(cos(short_ang), sin(short_ang)) * R * 0.5, 2.2, u)) {
			c = cols[5];
		}
		if (beam(q, vec2(cos(ang), sin(ang)) * (R - 4.0), 2.4, u)) {
			c = u > 0.8 ? cols[7] : cols[6];
		}
		if (d <= 2.0) {
			c = cols[6];
		}
		if (cellp == vec2(0.0)) {
			c = cols[1];
		}
		if (ripple_a > 0.02 && d <= ripple_r && d >= ripple_r - 1.0) {
			c = vec4(cols[5].rgb, ripple_a);
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	c *= COLOR;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
