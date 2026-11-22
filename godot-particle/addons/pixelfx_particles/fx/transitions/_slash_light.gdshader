// slash-wipe's light: ahead of and along the blade edge, on the halves' cut faces and pouring from the seam, along the
// second cut's smear.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_slash.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 q = floor(UV * vec2(TR_W, TR_H));
	vec2 pc = q + 0.5;
	vec3 l = vec3(0.0);
	if (sw_on > 0.5) {
		float CS = sl_cs();
		float Ls = clamp(sp * 0.0065, 1.5, 8.0);
		float xe = e + (TR_H / 2.0 - (q.y + 0.5)) * SL;
		float ia = clamp(floor(xe - (Ls + 10.0) / CS), 0.0, TR_W);
		float ib = clamp(ceil(xe + HALO / CS), 0.0, TR_W);
		if (q.x >= ia && q.x < ib) {
			float d = (xe - (q.x + 0.5)) * CS;
			if (d < 0.0) {
				float u = 1.0 + d / HALO;
				l += lt_add(C[5].rgb, 0.32 * u * u);
				if (d > -4.0) {
					l += lt_add(vec3(1.0), 0.3 * pow(1.0 + d / 4.0, 2.0));
				}
			} else if (d < Ls + 2.0) {
				l += lt_add(C[5].rgb, 0.3 * (1.0 - d / (Ls + 2.0)));
			}
		}
	}
	if (h_on > 0.5) {
		for (int k = 0; k < 2; k++) {
			if (sl_in_half(q, k)) {
				vec2 a = ha[k];
				vec2 m = hm[k];
				float d = (pc.x - a.x) * m.x + (pc.y - a.y) * m.y;
				float dp = k == 0 ? deep.x : deep.y;
				if (d < dp && d < 2.0) {
					l += lt_add(C[5].rgb, 0.4 * heat * (1.0 - d / 2.0));
				}
			}
			if (heat > 0.0) {
				vec2 b = hb[k];
				float r = 12.0 + (k == 0 ? sep.x : sep.y) * 0.15;
				for (int i = 0; i < 8; i++) {
					float u = (float(i) + 0.5) / 8.0;
					l += lt_glow(pc, ha[k] + (b - ha[k]) * u, r, C[5].rgb, 0.3 * heat);
				}
			}
		}
	}
	if (sm_on > 0.5) {
		int ci;
		float al, qq;
		if (sl_smear(q, ci, al, qq) && qq < 0.5) {
			l += lt_add(C[5].rgb, 0.4 * (1.0 - age));
		}
	}
	COLOR = vec4(l * strength, 1.0);
}
