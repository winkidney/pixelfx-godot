// pixel-dissolve's blocks (colour layer): white outlines swelling in and filling with ink, rims lighting up and
// collapsing to their hearts as they wink out, pixel dust flickering round the fresh ones.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_dissolve.gdshaderinc"

// square(p, x, y, s, fill, rim): what it writes at q (-1 nothing)
vec3 pd_square(vec2 q, float x, float y, float s, vec3 fill, bool has_fill, vec3 rim, bool has_rim, vec3 col) {
	float X = pd_round(x);
	float Y = pd_round(y);
	float S = max(1.0, pd_round(s));
	if (q.x < X || q.y < Y || q.x >= X + S || q.y >= Y + S) {
		return col;
	}
	if (has_fill) {
		col = fill;
	}
	if (has_rim && S > 2.0 && (q.x == X || q.y == Y || q.x == X + S - 1.0 || q.y == Y + S - 1.0)) {
		col = rim;
	}
	return col;
}

vec3 pd_mote(vec2 q, vec2 m, vec3 c, bool cross, vec3 col) {
	vec2 d = abs(q - floor(m));
	if (d.x < 0.5 && d.y < 0.5) {
		return c;
	}
	if (cross && d.x + d.y < 1.5) {
		return c;
	}
	return col;
}

void fragment() {
	vec2 q = floor(UV * vec2(TR_W, TR_H));
	vec3 col = vec3(-1.0);
	ivec2 cq = ivec2(floor(q / CELL));
	int fi = int(fr);
	for (int gy = -1; gy <= 1; gy++) {
		for (int gx = -1; gx <= 1; gx++) {
			ivec2 c = cq + ivec2(gx, gy);
			if (c.x < 0 || c.y < 0 || c.x >= 16 || c.y >= 9) {
				continue;
			}
			vec4 ce = texelFetch(cells, c, 0);
			for (int k = 0; k < int(ce.y + 0.5); k++) {
				int bi = int(ce.x + 0.5) + k;
				vec4 b0 = texelFetch(blocks, ivec2(bi, 0), 0);
				vec4 b1 = texelFetch(blocks, ivec2(bi, 1), 0);
				float x = b0.x;
				float y = b0.y;
				float s = b0.z;
				int n = int(b0.w + 0.5);
				float ki = (t - b1.x) / P;
				float ko = (t - b1.y) / P;
				if (ki < 0.0 || ko >= 1.6) {
					continue;
				}
				// nothing of it reaches this pixel: its square swells at most a few px, its dust 4 px out
				if (q.x < x - 6.0 || q.y < y - 6.0 || q.x > x + s + 6.0 || q.y > y + s + 6.0) {
					continue;
				}
				float cx = x + s / 2.0;
				float cy = y + s / 2.0;
				if (ko < 0.0) {
					if (ki >= 1.0) {
						col = pd_square(q, x, y, s, ink.rgb, true, vec3(0.0), false, col);
					} else {
						float g = ki < 0.35 ? 0.35 + 0.65 * pd_out_back(ki / 0.35) : 1.0;
						float h = s * g;
						vec3 rim = ki < 0.45 ? vec3(1.0) : ki < 0.6 ? C[6].rgb : ki < 0.75 ? C[5].rgb : ki < 0.9 ? C[4].rgb : C[3].rgb;
						col = pd_square(q, cx - h / 2.0, cy - h / 2.0, h, ink.rgb, ki > 0.2, rim, true, col);
						if (ki < 0.3 && s >= 10.0) {
							vec2 d = abs(q - floor(vec2(cx, cy) - 0.5));
							if (d.x < 0.5 && d.y < 0.5) {
								col = vec3(1.0);
							} else if (d.x + d.y < 1.5) {
								col = C[6].rgb;
							}
						}
					}
					if (ki < 1.4 && tr_rand3(fi, n, 9) < 0.35) {
						vec2 m = vec2(x + tr_rand3(fi, n, 10) * (s + 6.0) - 3.0, y + tr_rand3(fi, n, 11) * (s + 6.0) - 3.0);
						col = pd_mote(q, m, tr_rand3(fi, n, 12) < 0.5 ? vec3(1.0) : C[6].rgb, tr_rand3(fi, n, 17) < 0.25, col);
					}
				} else {
					if (ko < 0.35) {
						float u = ko / 0.35;
						col = pd_square(q, x, y, s, ink.rgb, true, u < 0.4 ? C[4].rgb : u < 0.75 ? C[5].rgb : C[6].rgb, true, col);
					} else if (ko < 0.75) {
						float u = (ko - 0.35) / 0.4;
						float h = s * (1.0 - u * u * 0.85);
						col = pd_square(q, cx - h / 2.0, cy - h / 2.0, h, vec3(0.0), false, u < 0.5 ? vec3(1.0) : C[6].rgb, true, col);
					} else if (ko < 1.0) {
						float u = (ko - 0.75) / 0.25;
						vec2 d = abs(q - floor(vec2(cx, cy) - 0.5));
						if (d.x < 0.5 && d.y < 0.5) {
							col = vec3(1.0);
						} else if (u < 0.5 && d.x + d.y < 1.5) {
							col = C[6].rgb;
						}
					}
					if (ko > 0.3 && ko < 1.5 && tr_rand3(fi, n, 13) < 0.3) {
						vec2 m = vec2(x + tr_rand3(fi, n, 14) * (s + 6.0) - 3.0, y + tr_rand3(fi, n, 15) * (s + 6.0) - 3.0);
						col = pd_mote(q, m, tr_rand3(fi, n, 16) < 0.5 ? vec3(1.0) : C[6].rgb, tr_rand3(fi, n, 18) < 0.25, col);
					}
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
