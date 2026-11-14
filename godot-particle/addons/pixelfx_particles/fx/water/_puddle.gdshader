// A puddle in the rain (see _puddle.gdshaderinc). mode 0: the water, dark and see-through; 3: the far part holding
// a little sky; 4: crests of the swell lit and troughs dark (soft layers, in that order); mode 1: the lamp's wobbling reflection, the lit far
// rim and the far halves of the crowns (colour, behind); mode 2: the near halves of the crowns, the drops falling in,
// their white hits, rebound jets and the beads pinching off them, the crisp near halves of the rings (colour, front).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_ringfn.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_puddle.gdshaderinc"

uniform float mode = 0.0;

bool crown(int i, vec2 p, bool back, out vec4 c) {
	c = vec4(0.0);
	float a = age_of(i);
	float h = crown_h(a, drop_b[i].x);
	if (h < 1.0) {
		return false;
	}
	float r0 = crown_r(a);
	vec4 q = drop_a[i];
	float cy = q.y * sy;
	bool hit = false;
	for (int f = 0; f < 10; f++) {
		float ang = q.w + float(f) / 10.0 * P_TAU;
		float s = sin(ang);
		if ((s < 0.0) != back) {
			continue;
		}
		float tip = h * (0.75 + 0.25 * tips[i * 10 + f]);
		float lean = 0.35 * tip;
		vec2 a0 = vec2(q.x + cos(ang) * r0, cy + s * r0 * sy);
		vec2 a1 = vec2(q.x + cos(ang) * (r0 + lean), cy + s * (r0 + lean) * sy - tip);
		float u;
		if (on_line(a0, a1, p, u)) {
			c = back ? (u > 0.7 ? pal[5] : pal[3]) : (u > 0.75 ? pal[7] : u > 0.35 ? pal[6] : pal[5]);
			hit = true;
		}
		if (a > 0.08 && a < 0.17 && all(equal(floor(a1 - vec2(0.0, 1.0)), floor(p)))) {
			c = back ? pal[5] : pal[7];
			hit = true;
		}
	}
	return hit;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float ry = rx * sy;
	float d = (p.x / rx) * (p.x / rx) + (p.y / ry) * (p.y / ry);
	vec4 c = vec4(0.0);
	if (mode < 0.5 || mode > 2.5) {
		// the water, as the original lays it down: its own soft layers blended one over another (mode 0 the deep water,
		// 3 a little sky in the far part, 4 the swell's lit crests and dark troughs)
		if (d > 1.0 || abs(p.x) > 88.0) {
			discard;
		}
		float edge = min(1.0, (1.0 - d) * 6.0);
		float far = (p.y + ry) / (2.0 * ry);
		if (mode < 0.5) {
			c = vec4(pal[0].rgb, (0.62 + 0.2 * far) * edge);
		} else if (mode < 3.5) {
			if (far >= 0.45) {
				discard;
			}
			c = vec4(pal[2].rgb, 0.3 * (1.0 - far / 0.45) * edge);
		} else {
			float h = field(p.x, p.y / sy);
			if (h > 0.24) {
				c = vec4((h > 0.75 ? pal[5] : pal[4]).rgb, min(0.95, (h - 0.24) * 2.2) * edge);
			} else if (h < -0.4) {
				c = vec4(pal[0].rgb, min(0.85, (-h - 0.4) * 1.8) * edge);
			} else {
				discard;
			}
		}
		// dithered between the soft layer's eight steps, so gradients don't band
		c.a += (pfx_threshold(FRAGCOORD.xy) - 0.5) / 8.0;
	} else if (mode < 1.5) {
		float k = lamp_k(p);
		if (k > 0.0) {
			c = k > 0.72 ? pal[7] : k > 0.35 ? pal[6] : pal[5];
		}
		if (abs(p.x) < 82.0) {
			float y = -sqrt(max(0.0, 1.0 - (p.x / rx) * (p.x / rx))) * ry;
			if (floor(p.y) == floor(y + 0.5)) {
				c = abs(p.x - lamp) < 10.0 ? pal[6] : pal[3];
			}
		}
		for (int i = 0; i < 8; i++) {
			vec4 ci;
			if (crown(i, p, true, ci)) {
				c = ci;
			}
		}
	} else {
		for (int i = 0; i < 8; i++) {
			vec4 q = drop_a[i];
			float a = age_of(i);
			float cy = q.y * sy;
			vec2 P = floor(p);
			float X = floor(q.x);
			// falling in: a streak dropping into the frame just before it lands
			float pre = dur - a;
			if (pre < 0.14 && cy - pre * 520.0 - 10.0 > -48.0 && P.x == X) {
				float y = cy - pre * 520.0;
				if (P.y >= floor(y - 10.0) && P.y <= floor(y)) {
					c = P.y >= floor(y - 4.0) ? pal[6] : pal[4];
				}
			}
			if (a < 0.05 && P.x == X && P.y == floor(cy)) {
				c = pal[7];
			}
			vec4 ci;
			if (crown(i, p, false, ci)) {
				c = ci;
			}
			// the rebound jet, and the bead that pinches off its top and drops back
			float jh = jet_h(a, drop_b[i].y);
			if (jh > 0.8) {
				if (P.x == X && P.y <= floor(cy - 1.0) && P.y >= floor(cy - jh)) {
					float u = (floor(cy - 1.0) - P.y) / max(1.0, floor(cy - 1.0) - floor(cy - jh));
					c = u > 0.6 ? pal[7] : pal[6];
				}
				if (P.x == X + 1.0 && P.y == floor(cy - 1.0)) {
					c = pal[5];
				}
				if (a < 0.41 && distance(p, vec2(q.x, cy - jh - 0.5)) <= 1.2) {
					c = pal[6];
				}
			}
			float ba = a - 0.41;
			float bh = drop_b[i].y + 1.0 + 24.0 * ba - 320.0 * ba * ba;
			if (ba > 0.0 && bh > 0.0) {
				if (distance(p, vec2(q.x, cy - bh)) <= 1.1) {
					c = pal[6];
				}
				if (P.x == X && P.y == floor(cy - bh - 1.0)) {
					c = pal[7];
				}
			}
		}
		for (int i = 0; i < 8; i++) {
			float a = age_of(i);
			if (a >= 1.8) {
				continue;
			}
			vec4 ci;
			float lit;
			int crest;
			vec2 o = vec2(drop_a[i].x, drop_a[i].y * sy);
			if (ring_hit(p - o, ring_r(a), sy, 0.75 * ring_k(a), 1.0, 3.0, 1.0, a < 0.1, 0.0, float(i), 0.5 + a, ci, lit, crest)) {
				c = ci;
			}
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
