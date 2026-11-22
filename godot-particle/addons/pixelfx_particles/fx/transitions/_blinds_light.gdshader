// blinds' light: along the lit rims and edges, and the warm light squeezing through each closing gap.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_blinds.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 px = floor(UV * vec2(TR_W, TR_H));
	float y = px.y;
	bool even = mod(px.x, 2.0) < 0.5;
	float fade = 1.0 - clamp((t - FADE0) / (FADE1 - FADE0), 0.0, 1.0);
	float appear = clamp(t / SHUT0, 0.0, 1.0);
	vec3 l = vec3(0.0);
	for (int n = 0; n < 12; n++) {
		float i = float(n);
		float th, h, y0, y1;
		bl_slat(i, th, h, y0, y1);
		float yc = (i + 0.5) * SH;
		if (h < 2.5) {
			float k = min(appear, fade);
			if (k > 0.0 && y == floor(yc) && even) {
				l += lt_add(C[5].rgb, 0.18 * k);
			}
			continue;
		}
		bool under = th > PI / 2.0;
		float lit = under ? 0.0 : cos(th);
		if (y == y0 && lit > 0.12 && even) {
			l += lt_add(C[5].rgb, 0.35 * lit);
		}
		float gap = SH - h;
		if (gap > 0.5 && th > 0.12 && !under) {
			float k = (0.2 + 0.45 * pow(1.0 - gap / SH, 1.5)) * min(1.0, th / 0.4);
			float gy = y1 + 1.0;
			if (y >= gy && y < min(TR_H, gy + ceil(gap))) {
				float v = (y - gy + 0.5) / gap;
				float kk = k * (1.0 - abs(v - 0.5) * 1.2);
				if (kk > 0.01) {
					l += lt_add(C[6].rgb, kk) + lt_add(C[4].rgb, kk * 0.5);
				}
			}
		}
	}
	COLOR = vec4(l * strength, 1.0);
}
