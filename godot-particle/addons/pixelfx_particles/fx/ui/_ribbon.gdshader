// quest-complete's ribbon (src/fx/ui/quest-complete.js ribbon()): two notched tails dropping out behind with their
// dark folds, the band (dark edge, lit top, shaded bottom, gold stitching), and while it unrolls the rolled-up ends
// riding its edges. Half-length l and the tails' drop keyed every frame. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 Rb[7] : source_color;
uniform vec4 stitch : source_color;
uniform float l = 0.0;
uniform float tails = 0.0;

const float BH = 8.0;

bool in_tri(vec2 p, vec2 a, vec2 b, vec2 c) {
	vec2 P[3] = vec2[](a, b, c);
	bool inside = false;
	for (int i = 0, j = 2; i < 3; j = i++) {
		if ((P[i].y > p.y) != (P[j].y > p.y) && p.x < ((P[j].x - P[i].x) * (p.y - P[i].y)) / (P[j].y - P[i].y) + P[i].x) {
			inside = !inside;
		}
	}
	return inside;
}

bool rect_(vec2 cell, float x, float y, float w, float h) {
	float X0 = floor(x + 0.5);
	float Y0 = floor(y + 0.5);
	return cell.x >= X0 && cell.y >= Y0 && cell.x < floor(x + w + 0.5) && cell.y < floor(y + h + 0.5);
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	vec2 pc = cell + 0.5;
	if (l < 1.0) {
		discard;
	}
	vec3 c = vec3(0.0);
	bool hit = false;
	// the rolled-up ends (drawn last)
	if (tails < 0.02) {
		for (int k = 1; k >= 0 && !hit; k--) {
			float s = k == 0 ? -1.0 : 1.0;
			float X = floor(s * l + 0.5);
			if (cell.x == X - 1.0 && cell.y == -BH - 1.0) {
				hit = true;
				c = Rb[6].rgb;
			} else if (rect_(cell, X, -BH - 1.0, 1.0, BH * 2.0 + 2.0)) {
				hit = true;
				c = Rb[2].rgb;
			} else if (rect_(cell, X - 1.0, -BH - 1.0, 1.0, BH * 2.0 + 2.0)) {
				hit = true;
				c = Rb[4].rgb;
			} else if (rect_(cell, X - 2.0, -BH - 2.0, 4.0, BH * 2.0 + 4.0)) {
				hit = true;
				c = Rb[0].rgb;
			}
		}
	}
	// the band
	if (!hit && cell.x >= floor(-l - 1.0) && cell.x <= ceil(l + 1.0)) {
		float ax = abs(pc.x);
		float v = pc.y;
		if (!(ax > l || abs(v) > BH)) {
			hit = true;
			float e = min(l - ax, BH - abs(v));
			float m = floor(pc.x + 0.5);
			if (e < 1.0) {
				c = Rb[0].rgb;
			} else if (v < -BH + 2.0) {
				c = Rb[5].rgb;
			} else if (v > BH - 2.0) {
				c = Rb[1].rgb;
			} else if ((abs(v + BH - 2.5) < 0.5 || abs(v - BH + 3.5) < 0.5) && mod(abs(m), 3.0) != 0.0 && ax < l - 3.0) {
				c = stitch.rgb;
			} else {
				c = v < -1.0 ? Rb[4].rgb : Rb[3].rgb;
			}
		}
	}
	// the tails, the right one over the left, each with its fold over it
	if (!hit && tails > 0.02) {
		for (int k = 1; k >= 0 && !hit; k--) {
			float s = k == 0 ? -1.0 : 1.0;
			float drop = 6.0 * tails;
			if (in_tri(pc, vec2(s * (l - 8.0), BH), vec2(s * (l - 1.0), BH), vec2(s * (l - 8.0), BH + drop))) {
				hit = true;
				c = Rb[0].rgb;
				break;
			}
			float x0 = s * (l - 8.0);
			float x1 = s * (l + 16.0 * tails);
			if (cell.x < floor(min(x0, x1) - 1.0) || cell.x > ceil(max(x0, x1) + 1.0) || cell.y < floor(-BH + drop - 1.0) || cell.y > ceil(BH + drop + 1.0)) {
				continue;
			}
			float u = (pc.x - x0) / (x1 - x0);
			float v = pc.y - drop;
			if (u < 0.0 || u > 1.0 || abs(v) > BH) {
				continue;
			}
			if (u > 1.0 - (0.3 * (BH - abs(v))) / BH) {
				continue;
			}
			hit = true;
			float e = min(BH - abs(v), (1.0 - u) * (x1 - x0) * s);
			c = (e < 1.0 || u < 0.02) ? Rb[0].rgb : v < -BH + 2.0 ? Rb[3].rgb : v < 0.0 ? Rb[2].rgb : Rb[1].rgb;
		}
	}
	if (!hit) {
		discard;
	}
	vec4 o = vec4(c, 1.0);
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
