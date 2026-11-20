// bat's eye streak: its glowing eyes leave a fading streak of red light along its flight, the original's 2 x 15
// glowLine segments back along its figure-eight (22 sin a, 7 sin 2a), worked out here from the keyed clock t (the
// effect's seconds). Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/pickups/_pk.gdshaderinc"

uniform vec2 size = vec2(112.0, 80.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float period = 2.4;
uniform vec4 color : source_color = vec4(1.0, 0.2, 0.2, 1.0);
uniform vec4 canvas = vec4(-1e4, -1e4, 2e4, 2e4);
uniform float strength = 1.0;

vec2 at_(float tt) {
	float a = (tt / period) * TAU;
	return vec2(22.0 * sin(a), 7.0 * sin(2.0 * a));
}

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	vec3 l = vec3(0.0);
	for (int k = 2; k <= 16; k++) {
		vec2 A = at_(t - float(k - 1) * 0.022);
		vec2 B = at_(t - float(k) * 0.022);
		float u = 1.0 - float(k) / 17.0;
		for (int s = -1; s <= 1; s += 2) {
			vec2 e = vec2(float(s) * 1.5, -0.5);
			l += lt_glow_line(pc, A + e, B + e, 2.6, color.rgb, 0.16 * u);
		}
	}
	COLOR = vec4(min(l, vec3(1.0)) * lt_edge(pc, canvas) * strength, 1.0);
}
