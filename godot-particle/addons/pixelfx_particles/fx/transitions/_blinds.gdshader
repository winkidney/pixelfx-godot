// blinds' slats (colour layer): row by row, a lit rim, a sheen, a face darkening as it turns flat, a shadowed underside;
// edge-on, just its lit edge brightening in and fading out.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_blinds.gdshaderinc"

void fragment() {
	float y = floor(UV.y * TR_H);
	float fade = 1.0 - clamp((t - FADE0) / (FADE1 - FADE0), 0.0, 1.0);
	float appear = clamp(t / SHUT0, 0.0, 1.0);
	vec3 col = vec3(-1.0);
	for (int n = 0; n < 12; n++) {
		float i = float(n);
		float th, h, y0, y1;
		bl_slat(i, th, h, y0, y1);
		float yc = (i + 0.5) * SH;
		if (h < 2.5) {
			float k = min(appear, fade);
			if (k <= 0.0) {
				continue;
			}
			float yy = floor(yc - 0.5 + 0.5);
			if (y == yy) {
				col = k > 0.66 ? C[6].rgb : k > 0.33 ? C[4].rgb : C[2].rgb;
			} else if (h >= 1.5 && y == yy + 1.0) {
				col = k > 0.5 ? C[3].rgb : C[1].rgb;
			}
			continue;
		}
		if (y < y0 || y > y1) {
			continue;
		}
		bool under = th > PI / 2.0;
		float lit = under ? 0.0 : cos(th);
		float r = y - y0;
		bool last = y == y1;
		float v = r / max(1.0, y1 - y0);
		float f = lit * (1.0 - v * 0.8);
		if (r == 0.0) {
			col = lit > 0.55 ? vec3(1.0) : lit > 0.3 ? C[6].rgb : lit > 0.12 ? C[4].rgb : ink.rgb;
		} else if (r == 1.0) {
			col = lit > 0.45 ? C[5].rgb : lit > 0.2 ? C[3].rgb : ink.rgb;
		} else if (last) {
			col = ink.rgb;
		} else {
			col = f > 0.55 ? C[3].rgb : f > 0.35 ? C[2].rgb : f > 0.15 ? C[1].rgb : ink.rgb;
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
