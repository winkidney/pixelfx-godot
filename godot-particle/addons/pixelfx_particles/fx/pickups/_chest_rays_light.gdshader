// chest-open's rays (src/fx/pickups/chest-open.js draw): nine wedges of light fanning out of the open chest. ra[j]:
// where ray j leaves the mouth (x), its direction, the tan of its half-angle (fixed); rb[j]: its length and strength
// (keyed every frame). Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/pickups/_pk.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 ra[9];
uniform vec2 rb[9];
uniform vec4 canvas = vec4(-1e4, -1e4, 2e4, 2e4);
uniform float strength = 1.0;

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	float e = lt_edge(pc, canvas) * strength;
	vec3 l = vec3(0.0);
	for (int j = 0; j < 9; j++) {
		float k = rb[j].y;
		float len = rb[j].x;
		if (k <= 0.01) {
			continue;
		}
		vec2 o = vec2(ra[j].x, -12.0);
		vec2 dv = ra[j].yz;
		float rx = pc.x - o.x;
		float ry = pc.y - o.y;
		float d = rx * dv.x + ry * dv.y;
		if (d < 0.0 || d > len) {
			continue;
		}
		float q = abs(rx * dv.y - ry * dv.x);
		float hw = 0.6 + d * ra[j].w;
		float f = q < hw ? 1.0 - 0.35 * (q / hw) : 0.65 * (1.0 - (q - hw) / 1.6);
		if (f <= 0.0) {
			continue;
		}
		float s = clamp((d - 5.0) / 9.0, 0.0, 1.0);
		l += lt_add(q < hw * 0.45 ? c6.rgb : c5.rgb, k * 0.55 * f * pow(1.0 - d / len, 1.4) * s * s * (3.0 - 2.0 * s) * e);
	}
	COLOR = vec4(min(l, vec3(1.0)), 1.0);
}
