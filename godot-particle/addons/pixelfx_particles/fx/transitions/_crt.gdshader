// crt-off's picture closing in (colour layer): the inks above and below, the strip's lit edges, the humming line with
// its fringes and flecks of static.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_crt.gdshaderinc"

void fragment() {
	vec2 px = floor(UV * vec2(TR_W, TR_H));
	float thr = pfx_threshold(FRAGCOORD.xy);
	if ((t >= OPEN1 + 0.02 && t < OPEN1 + 0.6) || h >= TR_H) {
		discard;
	}
	float top = crt_round(YC - h / 2.0);
	float bot = crt_round(YC + h / 2.0);
	vec3 col = vec3(-1.0);
	if (px.y < top || px.y >= bot) {
		col = ink.rgb;
	}
	if (h > 2.0) {
		float sq = 1.0 - h / TR_H;
		if (px.y == top - 1.0 || px.y == bot) {
			col = sq > 0.6 ? C[6].rgb : C[5].rgb;
		}
	} else if (h > 0.0 && w >= 1.0) {
		float x0 = floor(XC - w);
		float x1 = ceil(XC + w);
		float x = px.x;
		if (x >= max(0.0, x0) && x < min(TR_W, x1)) {
			float u;
			float y = crt_line_y(x, u);
			bool fresh = t < SQ1 + 0.08 || (t > ON0 && t < ON1 + 0.04);
			if (px.y == y) {
				col = u < 0.85 ? vec3(1.0) : C[6].rgb;
			}
			if (u < 0.92) {
				if (px.y == y - 1.0) {
					col = C[6].rgb;
				}
				if (px.y == y + 1.0) {
					col = u < 0.6 ? C[6].rgb : C[5].rgb;
				}
			}
			if (fresh && u < 0.8 && abs(px.y - y) == 2.0 && tr_put(0.5, thr)) {
				col = C[4].rgb;
			}
			int xi = int(x);
			int fi = int(fr);
			if (tr_rand3(xi, fi, seed + 3) < 0.06) {
				float fy = y + (tr_rand3(xi, fi, seed + 4) < 0.5 ? -1.0 : 1.0) * (2.0 + floor(tr_rand3(xi, fi, seed + 5) * 4.0));
				if (px.y == fy) {
					col = tr_rand3(xi, fi, 6) < 0.5 ? vec3(1.0) : C[5].rgb;
				}
			}
		}
	}
	if (col.r < 0.0) {
		discard;
	}
	vec4 o = vec4(col, 1.0);
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
