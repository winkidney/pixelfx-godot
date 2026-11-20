// power-star's rays (src/fx/pickups/power-star.js drawBack): ten wedges of light turning behind the star, long and
// short by turns, swelling with the beat. cy, spin and sw (the swell) keyed every frame. Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/pickups/_pk.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform float cy = -25.0;
uniform float spin = 0.0;
uniform float sw = 0.0;
uniform vec4 canvas = vec4(-1e4, -1e4, 2e4, 2e4);
uniform float strength = 1.0;

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	float e = lt_edge(pc, canvas) * strength;
	vec3 l = vec3(0.0);
	for (int i = 0; i < 10; i++) {
		float a = spin + float(i) * TAU / 10.0;
		bool odd = i % 2 == 1;
		float len = (odd ? 22.0 : 34.0) * (1.0 + 0.18 * sw);
		float w = odd ? 0.06 : 0.09;
		float ca = cos(a);
		float sa = sin(a);
		float rx = pc.x;
		float ry = pc.y - cy;
		float d = rx * ca + ry * sa;
		if (d < 8.0 || d > len) {
			continue;
		}
		float q = abs(rx * sa - ry * ca);
		float hw = 0.5 + d * w;
		if (q > hw + 1.5) {
			continue;
		}
		float k = (0.32 + 0.22 * sw) * (q < hw ? 1.0 : 1.0 - (q - hw) / 1.5) * pow(1.0 - d / len, 1.2) * min(1.0, (d - 8.0) / 4.0);
		l += lt_add(q < hw * 0.5 ? c6.rgb : c5.rgb, k * e);
	}
	COLOR = vec4(min(l, vec3(1.0)), 1.0);
}
