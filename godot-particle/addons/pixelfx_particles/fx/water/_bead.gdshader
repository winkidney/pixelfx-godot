// One bead of water, centred on the rect's middle (key the node's position to move it):
//   style 0: a falling bead (the original's bead(s = 3)): a round C4 bead, a lighter middle, a white highlight, and
//            a tail `tail` px long trailing back along `dir` (its motion), darker at its end
//   style 1: a bead swelling under a tip: an ellipse rx x ry, lit rim on its left, a light core on its right, a white
//            highlight, a neck `neck` px long up to the tip (the rect's top is the tip when neck > 0)
//   style 2: a plain blob rx x ry in pal[fill]
//   style 3: a small falling bead (bead(s = 2)): a shaded 2 x 2 (white, lighter, light, mid) with its tail
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"

uniform vec2 size = vec2(16.0, 24.0);
uniform float style = 0.0;
uniform float rx = 1.75;
uniform float ry = 1.75;
// the bead's middle, px from the rect's centre (the falling bead sits on a pixel boundary as the original's does)
uniform vec2 offset = vec2(0.0);
uniform vec2 dir = vec2(0.0, 1.0);
uniform float tail = 0.0;
uniform float neck = 0.0;
uniform float alpha = 1.0;
uniform float fill = 4.0;

bool on_tail(vec2 p, vec2 a, vec2 b, out float u) {
	// a 1 px line from a to b: the pixel's square holds a point of the segment
	vec2 d = b - a;
	float L = max(length(d), 1e-3);
	u = clamp(dot(p - a, d) / (L * L), 0.0, 1.0);
	vec2 q = a + d * u;
	vec2 e = abs(p - q);
	return max(e.x, e.y) <= 0.5;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 - offset;
	vec4 c = vec4(0.0);
	int s = int(style + 0.5);
	if (s == 0) {
		if (length(p) <= 1.75) {
			c = pal[4];
			if (length(p + vec2(0.25)) <= 1.15) {
				c = pal[6];
			}
			if (distance(p, vec2(-0.5)) < 0.1) {
				c = pal[7];
			}
		} else if (tail >= 1.0) {
			float u;
			vec2 n = normalize(dir);
			if (on_tail(p, -n * (tail + 1.0), -n * 1.2, u)) {
				c = u < 0.45 ? pal[3] : pal[5];
			}
		}
	} else if (s == 1) {
		vec2 q = p / vec2(rx, ry);
		float d = length(q);
		if (d <= 1.0) {
			float a = atan(q.y, q.x);
			c = d > 0.72 ? ((cos(a) < 0.0 && sin(a) < 0.3) ? pal[5] : pal[3]) : (d < 0.35 && cos(a) > 0.0) ? pal[6] : pal[4];
			vec2 hl = floor(vec2(-rx * 0.4, -ry * 0.45)) + 0.5;
			if (rx > 1.0 && distance(p, hl) < 0.1) {
				c = pal[7];
			}
		} else if (neck > 0.2 && abs(p.x - 0.5) < 0.1 && p.y < -ry && p.y > -ry - neck - 1.0) {
			c = pal[5];
		}
	} else if (s == 2) {
		if (length(p / vec2(rx, ry)) <= 1.0) {
			c = pal[int(fill + 0.5)];
		}
	} else {
		if (p.x > 0.0 && p.x < 2.0 && p.y > 0.0 && p.y < 2.0) {
			c = p.y < 1.0 ? (p.x < 1.0 ? pal[7] : pal[6]) : (p.x < 1.0 ? pal[5] : pal[4]);
		} else if (tail >= 1.0) {
			float u;
			vec2 n = normalize(dir);
			if (on_tail(p, vec2(0.5) - n * (tail + 1.0), vec2(0.5) - n * 1.2, u)) {
				c = u < 0.45 ? pal[3] : pal[5];
			}
		}
	}
	c.a *= alpha;
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
