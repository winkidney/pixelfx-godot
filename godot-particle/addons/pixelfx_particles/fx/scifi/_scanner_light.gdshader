// The scanner's light (src/fx/scifi/scanner.js), from the keyed clock `t`: a glow on each bracket's corner, the
// scan line's band of light and the glints at its ends, the readout's glow. Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/scifi/_scifi_light.gdshaderinc"

uniform vec2 size = vec2(112.0, 78.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D tex : filter_nearest;
uniform float t = 0.0;
uniform vec4 pal[8] : source_color;
uniform float strength = 1.0;

const float LOCK = 0.3;
const float SCAN0 = 0.42;
const float SCAN1 = 1.6;
const float LET = 2.5;

void fragment() {
	ivec2 ts = textureSize(tex, 0);
	int AW = ts.x;
	int AH = ts.y;
	int AX = -AW / 2;
	int AY = -AH;
	vec2 pc = floor(center + (UV - 0.5) * size + 0.001) + 0.5;
	float bx0 = float(AX - 4);
	float bx1 = float(AX + AW + 3);
	float by0 = float(AY - 4);
	float by1 = 3.0;
	float lock = e_out_back(t / LOCK, 2.2);
	float outk = e_in_cubic((t - LET) / 0.45);
	float spread = (1.0 - lock) * 14.0 + outk * 12.0;
	bool gone = t > LET + 0.45 || (t > LET + 0.25 && int(floor((t - LET) * 20.0)) % 2 == 1);
	float vis = gone ? 0.0 : 1.0;
	vec3 l = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		float x = (i % 2 == 0) ? bx0 - spread : bx1 + spread;
		float y = (i < 2) ? by0 - spread : by1 + spread;
		l += pal[4].rgb * glow_at(pc, vec2(x, y), 6.0) * 0.35 * vis;
	}
	if (t > SCAN0 && t < SCAN1) {
		float y = floor(mix(float(AY - 3), 1.0, e_in_out_sine((t - SCAN0) / (SCAN1 - SCAN0))));
		l += pal[5].rgb * glow_seg(pc, vec2(bx0, y), vec2(bx1, y), 6.0) * 0.45;
		int my = int(y) - AY;
		if (my >= 0 && my < AH) {
			int r0 = 1000;
			int r1 = -1000;
			for (int i = 0; i < 64; i++) {
				if (i >= AW) {
					break;
				}
				if (texelFetch(tex, ivec2(i, my), 0).a > 0.5) {
					r0 = min(r0, AX + i);
					r1 = max(r1, AX + i);
				}
			}
			if (r1 >= r0) {
				l += pal[6].rgb * (glow_at(pc, vec2(float(r0) - 0.5, y + 0.5), 8.0) + glow_at(pc, vec2(float(r1) + 1.5, y + 0.5), 8.0)) * 0.3;
			}
		}
	}
	if (vis > 0.0 && (t - LOCK) / 0.1 >= 1.0) {
		l += pal[4].rgb * glow_at(pc, vec2(bx1 + spread + 6.0 + 16.0, by0 - spread + 2.0 + 6.0), 18.0) * 0.2;
	}
	COLOR = vec4(l * strength, 1.0);
}
