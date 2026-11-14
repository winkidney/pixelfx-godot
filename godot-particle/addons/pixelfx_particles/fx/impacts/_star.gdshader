// The impacts' hit star (src/fx/impacts/_lib.js star()): tapered spikes round a hot heart, in three passes, a rim
// (each spike 0.8 px fatter), a body that's paler near the root, a hot core down the first half of each spike.
// spikes[i] = (angle in radians, length, root half-width); sc stretches them, th thins them; key sc / th / the
// colours / alpha on the original's frames. Centred on the effect's star point (whole pixels).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec4 spikes[16];
uniform float count = 0.0;
uniform float sc = 1.0;
uniform float th = 1.0;
uniform float heart = 2.4;
uniform vec4 rim : source_color = vec4(1.0);
uniform vec4 body : source_color = vec4(1.0);
uniform vec4 inner : source_color = vec4(1.0);
uniform vec4 core : source_color = vec4(1.0);
uniform float alpha = 1.0;
// 0: the full star; 1: only the spikes (no heart)
uniform float no_heart = 0.0;

// half a cell's reach across a spike leaning at (c, s): the original's 0.5 px dots fill every cell they touch
float reach(vec2 u) {
	return 0.5 * (abs(u.x) + abs(u.y));
}

void fragment() {
	vec4 tint = COLOR;
	vec2 q = floor((UV - 0.5) * size) + 0.5;
	int n = int(count + 0.5);
	int pass = -1;
	vec4 c = vec4(0.0);
	for (int i = 0; i < 16; i++) {
		if (i >= n) {
			break;
		}
		vec4 s = spikes[i];
		vec2 u = vec2(cos(s.x), sin(s.x));
		float L = s.y * sc;
		if (L <= 0.0) {
			continue;
		}
		float dd = dot(q, u);
		float oo = abs(dot(q, vec2(-u.y, u.x)));
		float sl = reach(u);
		if (dd < -sl || dd > L + sl) {
			continue;
		}
		float d = clamp(dd, 0.0, L);
		float hw0 = s.z * th * (1.0 - d / L) * min(1.0, 0.5 + d / 3.0);
		// the core: first 55% of the spike, 0.45 of its width
		if (dd <= L * 0.55 + sl && oo <= hw0 * 0.45 + sl * 0.75) {
			pass = 2;
			c = core;
		} else if (pass < 2 && oo <= hw0 + sl * 0.75) {
			pass = 1;
			c = d < L * 0.35 ? inner : body;
		} else if (pass < 1 && oo <= hw0 + 0.8 + sl * 0.75) {
			pass = 0;
			c = rim;
		}
	}
	if (no_heart < 0.5) {
		float r = heart * sc * sqrt(th);
		float dq = length(q);
		if (dq <= r) {
			c = core;
			pass = 3;
		} else if (dq <= r + 0.8) {
			c = inner;
			pass = 3;
		}
	}
	if (pass < 0) {
		discard;
	}
	c.a *= alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
