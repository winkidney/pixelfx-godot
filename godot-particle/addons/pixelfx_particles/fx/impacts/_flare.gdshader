// crit-hit's lens flare (src/fx/impacts/crit-hit.js flare()): a long level streak, thick and white at the heart, a
// shorter upright one, two short diagonals, white at the middle cooling to hi and lo, their tips dithering out as k
// falls. Key len and k.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform float len = 64.0;
uniform float k = 1.0;
uniform vec4 white : source_color = vec4(1.0);
uniform vec4 hi : source_color = vec4(1.0);
uniform vec4 lo : source_color = vec4(1.0);

void fragment() {
	vec4 tint = COLOR;
	vec2 cell = floor((UV - 0.5) * size);
	vec4 c = vec4(0.0);
	vec2 arms[4] = vec2[](vec2(1.0, 0.0), vec2(0.0, 1.0), vec2(0.7, 0.7), vec2(0.7, -0.7));
	float lens[4] = float[](len, len * 0.45, len * 0.16, len * 0.16);
	for (int ai = 0; ai < 4; ai++) {
		float L = lens[ai];
		for (int si = 0; si < 2; si++) {
			float s = si == 0 ? -1.0 : 1.0;
			for (int di = 1; di <= 80; di++) {
				float d = float(di);
				if (d > L) {
					break;
				}
				float u = d / L;
				float a = u < 0.7 ? 1.0 : k * (1.6 - u);
				if (all(equal(floor(arms[ai] * s * d + 1e-4), cell))) {
					c = vec4((u < 0.35 ? white : u < 0.7 ? hi : lo).rgb, a);
				}
				if (ai == 0 && u < 0.42 && cell.x == s * d && abs(cell.y) == 1.0) {
					c = vec4((u < 0.2 ? hi : lo).rgb, u < 0.3 ? 1.0 : k);
				}
			}
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
