// The original's impact star() (melee/_lib.js), colour layer: tapered spikes sp[i] = (angle, length, width) round the
// centre, turned by `turn`, stretched by `sc`, thinned by `th`, painted in three passes (a rim 0.8 px wider, the body
// with its inner third in `inner`, a core down the first 55%) sampled every half pixel as the original paints them,
// then a disc of `inner` and a hot disc of `core` in the middle. The rect is odd-sized round the pixel holding the
// centre; frac_ is where the centre sits inside it. Key sc, th, turn and the colours.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(65.0);
uniform vec2 frac_ = vec2(0.5);
uniform vec4 sp[12];
uniform float count = 0.0;
uniform float sc = 0.0;
uniform float th = 1.0;
uniform float turn = 0.0;
uniform float squash = 1.0;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 body : source_color = vec4(1.0);
uniform vec4 inner : source_color = vec4(1.0);
uniform vec4 rim : source_color = vec4(1.0);

// does pass `pass_` of spike s paint the cell? returns the distance along it (or -1)
float hit(vec4 s, int pass_, vec2 cell) {
	float a = s.x + turn;
	vec2 e = vec2(cos(a), sin(a));
	vec2 nrm = vec2(-e.y, e.x);
	float L = s.y * sc;
	if (L <= 0.0) {
		return -1.0;
	}
	vec2 pc = cell + 0.5 - frac_;
	float d0 = floor(dot(pc, e) * 2.0) * 0.5;
	float op = dot(pc, nrm);
	float found = -1.0;
	for (int j = -2; j <= 2; j++) {
		float d = d0 + float(j) * 0.5;
		if (d < 0.0 || d > L || (pass_ == 2 && d > L * 0.55)) {
			continue;
		}
		float hw0 = s.z * th * (1.0 - d / L) * min(1.0, 0.5 + d / 3.0);
		float hw = pass_ == 0 ? hw0 + 0.8 : pass_ == 1 ? hw0 : hw0 * 0.45;
		float m0 = floor((op + hw) * 2.0);
		for (int m = -1; m <= 2; m++) {
			float o = -hw + (m0 + float(m)) * 0.5;
			if (o < -hw - 1e-4 || o > hw + 1e-4) {
				continue;
			}
			if (floor(frac_ + e * d + nrm * o) == cell) {
				found = d / L;
			}
		}
	}
	return found;
}

void fragment() {
	vec4 tint = COLOR;
	if (sc <= 0.0) {
		discard;
	}
	vec2 cell = floor((UV - 0.5) * size);
	cell.y = floor(cell.y / squash);
	vec4 c = vec4(0.0);
	bool any = false;
	for (int pass_ = 0; pass_ < 3; pass_++) {
		for (int i = 0; i < 12; i++) {
			if (float(i) >= count) {
				break;
			}
			float f = hit(sp[i], pass_, cell);
			if (f >= 0.0) {
				c = pass_ == 0 ? rim : pass_ == 1 ? (f < 0.35 ? inner : body) : core;
				any = true;
			}
		}
	}
	float r = 2.4 * sc * sqrt(th);
	vec2 pc = cell + 0.5 - frac_;
	float dc = length(pc);
	if (r + 0.8 >= 0.6 ? dc <= r + 0.8 : cell == floor(frac_)) {
		c = inner;
		any = true;
	}
	if (r >= 0.6 ? dc <= r : cell == floor(frac_)) {
		c = core;
		any = true;
	}
	if (!any) {
		discard;
	}
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
