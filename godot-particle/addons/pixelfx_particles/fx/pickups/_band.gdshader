// sim.js band(): a ring of light lying on the floor (radius r, squashed by sy, th px thick), dots stepping in from its
// rim in the ramp's brightest step (white while hot) to its darker ones, dithered by k; back: only the far half (the
// one behind the item), else the near half. The last of the original's dots on a pixel that survives its dither wins.
// Keyed every frame. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 ramp[4] : source_color;
uniform float cx = 0.5;
uniform float cy = 0.0;
uniform float sy = 0.2;
uniform float r = 0.0;
uniform float th = 1.0;
uniform float k = 0.0;
uniform bool hot = false;
uniform bool back = false;

// cos and sin of (j / m) turn, exactly the original's at the quarter turns (the GPU's sin(pi) is below 0)
vec2 dir(int j, int m) {
	if (j == 0) {
		return vec2(1.0, 0.0);
	}
	if (4 * j == m) {
		return vec2(6.123234e-17, 1.0);
	}
	if (2 * j == m) {
		return vec2(-1.0, 1.2246468e-16);
	}
	if (4 * j == 3 * m) {
		return vec2(-1.8369702e-16, -1.0);
	}
	float a = float(j) / float(m) * TAU;
	return vec2(cos(a), sin(a));
}

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	vec2 cell = floor(pc);
	if (r <= 0.0 || k <= 0.0 || abs(pc.x - cx) > r + 2.0 || abs(pc.y - cy) > r * sy + 2.0) {
		discard;
	}
	int m = int(ceil(r * TAU * 1.2));
	int steps = int(floor(th / 0.5)) + 1;
	float thr = pfx_threshold(FRAGCOORD.xy);
	vec4 c = vec4(0.0);
	// the last dot drawn first: j from the end, and within a j the inner-most o (drawn last) first
	for (int j = m - 1; j >= 0; j--) {
		vec2 d = dir(j, m);
		if ((d.y < 0.0) != back) {
			continue;
		}
		for (int s = steps - 1; s >= 0; s--) {
			float o = th - 0.5 * float(s);
			vec2 p = vec2(cx + d.x * (r - o), cy + d.y * (r - o) * sy);
			if (floor(p) != cell) {
				continue;
			}
			float u = o / th;
			float a = k * (u < 0.4 ? 1.2 : 1.15 - u);
			if (a <= 0.0 || (a < 1.0 && a <= thr)) {
				continue;
			}
			c = vec4(u < 0.15 ? (hot ? vec3(1.0) : ramp[3].rgb) : u < 0.4 ? ramp[2].rgb : u < 0.7 ? ramp[1].rgb : ramp[0].rgb, 1.0);
			break;
		}
		if (c.a > 0.0) {
			break;
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
