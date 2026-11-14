// The void orb, colour layer (see _void-orb.gdshaderinc). mode 0: the vortex's filaments and lit arm edges; 1: its
// veil of dark dust (translucent: set `translucent`); 2: the lensing (the Einstein ring and the arcs of the specks
// behind); 3: the orb's crawling pale rim; 4: the orb's black inside with its crescent and glint, on a node above the
// light layer (the original unlights it).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/shadow/_jsrand.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/shadow/_void-orb.gdshaderinc"

uniform float mode = 0.0;
// C[0] .. C[7], white
uniform vec4 pal[9] : source_color;

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center + 0.001) + 0.5;
	vec2 cell = floor(p);
	float g = vo_gulp();
	float th = pfx_threshold(FRAGCOORD.xy);
	vec4 c = vec4(0.0);
	int m = int(mode + 0.5);
	if (m <= 1) {
		int col;
		float a;
		float k;
		int kind = vo_vortex(p, g, col, a, k);
		if (m == 0 && (kind == 1 || kind == 2)) {
			c = pal[col];
		} else if (m == 1 && kind == 3) {
			c = vec4(pal[col].rgb, a);
		} else {
			discard;
		}
	} else if (m == 2) {
		bool hit = false;
		vec2 q = p - vec2(0.0, VO_Y);
		float ap = atan(q.y, q.x);
		float rp = length(q);
		// the Einstein ring: a pixel every 0.7 px round it
		if (abs(rp - VO_E) < 1.5) {
			float st = 0.7 / VO_E;
			float apos = ap < 0.0 ? ap + TAU : ap;
			float k0 = floor(apos / st);
			for (int j = -1; j <= 2; j++) {
				float aa = (k0 + float(j)) * st;
				if (aa < 0.0 || aa >= TAU) {
					continue;
				}
				if (floor(vec2(cos(aa) * VO_E, VO_Y + sin(aa) * VO_E)) == cell) {
					float f = 0.5 + 0.5 * cos(5.0 * aa - TAU * 2.0 * t) + 0.5 * g;
					c = f > 0.85 ? pal[5] : f > 0.45 ? pal[4] : pal[3];
					hit = true;
				}
			}
		}
		// the specks behind, smeared into arcs hugging the rim
		for (int s = 0; s < 7; s++) {
			for (int w = 0; w < 2; w++) {
				float r;
				float a0;
				float hw;
				float mag;
				if (!vo_image(s, w, r, a0, hw, mag) || abs(rp - r) > 2.5) {
					continue;
				}
				float stp = 0.6 / r;
				float rel = ap - (a0 - hw);
				rel -= TAU * floor(rel / TAU);
				float n = floor((2.0 * hw + 1e-6) / stp);
				float k0 = floor(rel / stp);
				for (int j = -2; j <= 2; j++) {
					float kk = k0 + float(j);
					if (kk < 0.0 || kk > n) {
						continue;
					}
					float aa = a0 - hw + kk * stp;
					float u = hw > 0.0 ? abs(aa - a0) / hw : 0.0;
					vec2 xy = vec2(cos(aa) * r, VO_Y + sin(aa) * r);
					if (floor(xy) == cell && min(1.0, mag * 1.4) * (1.15 - u) >= th) {
						c = (u < 0.3 && mag > 0.8) ? pal[8] : u < 0.65 ? pal[7] : pal[5];
						hit = true;
					}
					if (mag > 1.2 && u < 0.6 && floor(xy + vec2(cos(aa), sin(aa))) == cell && 0.8 >= th) {
						c = pal[6];
						hit = true;
					}
				}
			}
		}
		if (!hit) {
			discard;
		}
		c.a = 1.0;
	} else {
		vec2 q = p - vec2(0.0, VO_Y);
		float d = length(q);
		if (d > VO_R + 0.5) {
			discard;
		}
		float a = atan(q.y, q.x);
		if (d > VO_R - 0.6) {
			if (m != 3) {
				discard;
			}
			float f = 0.5 * cos(3.0 * a - TAU * 2.0 * t) + 0.3 * cos(7.0 * a + TAU * 3.0 * t + 1.0) + 0.25 * cos(13.0 * a - TAU * 5.0 * t + 2.0) + g;
			c = f > 0.5 ? pal[8] : f > 0.05 ? pal[6] : f > -0.4 ? pal[5] : pal[4];
		} else {
			if (m != 4) {
				discard;
			}
			c = pal[0];
			if (VO_R - d < 1.4 && cos(a - 0.8) > 0.6) {
				c = pal[2];
			} else if (pow(q.x + VO_R * 0.42, 2.0) + pow(q.y + VO_R * 0.45, 2.0) < 1.6) {
				c = pal[3];
			}
		}
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
