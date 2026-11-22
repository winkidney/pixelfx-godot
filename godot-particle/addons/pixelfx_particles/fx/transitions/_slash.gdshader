// slash-wipe's cover (colour layer): ink behind the sweeping blade edge and its cooling smear, the halves of the cover
// with their white-hot cut faces, the second cut's smear and trace.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_slash.gdshaderinc"

void fragment() {
	vec2 q = floor(UV * vec2(TR_W, TR_H));
	float thr = pfx_threshold(FRAGCOORD.xy);
	vec3 col = vec3(-1.0);
	if (sw_on > 0.5) {
		float CS = sl_cs();
		float Ls = clamp(sp * 0.0065, 1.5, 8.0);
		float echo = clamp(sp / 900.0, 0.0, 1.0) * 0.6;
		float xe = e + (TR_H / 2.0 - (q.y + 0.5)) * SL;
		float ia = clamp(floor(xe - (Ls + 10.0) / CS), 0.0, TR_W);
		float ib = clamp(ceil(xe + HALO / CS), 0.0, TR_W);
		if (q.x < ia) {
			col = ink.rgb;
		} else if (q.x < ib) {
			float d = (xe - (q.x + 0.5)) * CS;
			if (d >= 0.0) {
				if (d < 1.0) {
					col = vec3(1.0);
				} else if (d < 2.0) {
					col = C[6].rgb;
				} else {
					float u = (d - 2.0) / Ls;
					col = u < 0.3 ? C[5].rgb : u < 0.55 ? C[4].rgb : u < 0.8 ? C[3].rgb : u < 1.0 ? C[2].rgb : ink.rgb;
					if (echo > 0.0 && abs(d - Ls - 7.0) < 0.5 && int(q.x + q.y) % 3 == 0 && tr_put(echo, thr)) {
						col = C[4].rgb;
					}
				}
			}
		}
	}
	if (h_on > 0.5) {
		for (int k = 0; k < 2; k++) {
			if (!sl_in_half(q, k)) {
				continue;
			}
			vec2 a = ha[k];
			vec2 m = hm[k];
			float d = (q.x + 0.5 - a.x) * m.x + (q.y + 0.5 - a.y) * m.y;
			float dp = k == 0 ? deep.x : deep.y;
			if (d < dp) {
				int i = max(0, int(floor(d)));
				col = i == 0 ? (heat > 0.55 ? vec3(1.0) : heat > 0.25 ? C[6].rgb : C[5].rgb) : i == 1 ? (heat > 0.4 ? C[6].rgb : C[4].rgb) : i == 2 ? (heat > 0.3 ? C[5].rgb : C[3].rgb) : (heat > 0.3 ? C[4].rgb : ink.rgb);
			} else {
				col = ink.rgb;
			}
		}
	}
	if (sm_on > 0.5) {
		int ci;
		float al, qq;
		if (sl_smear(q, ci, al, qq) && tr_put(al, thr)) {
			col = C[7 - clamp(ci, 0, 7)].rgb;
		}
	}
	if (tr_on > 0.5) {
		// the trace: a dot every 1.6 px back from the tail; the last that lands here wins
		vec2 o = q + 0.5 - A;
		float s0 = dot(o, U);
		int k0 = max(0, int(floor((s0 - 2.0) / 1.6)));
		for (int k = k0; k < k0 + 4; k++) {
			float s = float(k) * 1.6;
			if (s >= tail) {
				break;
			}
			if (all(equal(floor(A + U * s), q)) && tr_put(0.7 * (0.4 + 0.6 * s / LC), thr)) {
				col = C[5].rgb;
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
