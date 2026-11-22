// crt-off's light: the squeezed picture brightening as it narrows, the line's glow, the warm-up glow and the refresh
// band rolling down once it's back on.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_crt.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 px = floor(UV * vec2(TR_W, TR_H));
	vec2 pc = px + 0.5;
	vec3 l = vec3(0.0);
	bool odd = mod(px.y, 2.0) > 0.5;
	if (t >= OPEN1 + 0.02 && t < OPEN1 + 0.6) {
		float u = (t - OPEN1) / 0.6;
		float band = -20.0 + u * (TR_H + 40.0);
		float k = 0.22 * (1.0 - u) * (1.0 - u) + 0.3 * pow(max(0.0, 1.0 - abs(px.y - band) / 10.0), 2.0) * (1.0 - u) + (odd ? 0.05 * (1.0 - u) : 0.0);
		if (k > 0.01) {
			l = lt_add(C[5].rgb, k);
		}
	} else if (h < TR_H) {
		float top = crt_round(YC - h / 2.0);
		float bot = crt_round(YC + h / 2.0);
		if (h > 2.0) {
			float sq = 1.0 - h / TR_H;
			if (px.y >= top && px.y < bot) {
				float e = min(px.y - top, bot - 1.0 - px.y);
				float k = 0.55 * sq * sq + (odd ? 0.08 * sq : 0.0) + 0.35 * pow(max(0.0, 1.0 - e / 6.0), 2.0);
				l = lt_add(C[5].rgb, k * fl);
			}
		} else if (h > 0.0 && w >= 1.0) {
			float x0 = floor(XC - w);
			float x1 = ceil(XC + w);
			if (px.x >= max(0.0, x0) && px.x < min(TR_W, x1)) {
				float u;
				float y = crt_line_y(px.x, u);
				if (px.y == y) {
					l += lt_add(C[6].rgb, 0.5 * fl * (1.0 - u * 0.6));
				}
			}
			for (float x = x0; x <= x1; x += 9.0) {
				if (abs(x - pc.x) < 11.0) {
					l += lt_glow(pc, vec2(x, YC), 10.0, C[5].rgb, 0.35 * fl);
				}
			}
			l += lt_glow(pc, vec2(XC, YC), min(70.0, 16.0 + w * 0.4), C[5].rgb, 0.4 * fl);
		}
	}
	COLOR = vec4(l * strength, 1.0);
}
