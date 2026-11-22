// The light of spawn/summon-rise's burning ring (_summon_floor.gdshaderinc): a glow at every 11th of the original's
// 220 points round it, as far as it has burnt in. Light layer.
shader_type canvas_item;
render_mode blend_add;

uniform float strength = 1.0;

#include "res://addons/pixelfx_particles/fx/spawn/_summon_floor.gdshaderinc"

void fragment() {
	vec2 q = floor(center + (UV - 0.5) * size) + 0.5;
	vec3 l = vec3(0.0);
	if (heat_k > 0.01) {
		float prog = clamp(t / ign_t, 0.0, 1.0) * PI;
		for (int j = 0; j < 220; j += 11) {
			float a = (float(j) / 220.0) * TAU;
			float d = abs(mod(a - PI / 2.0 + PI * 3.0, TAU) - PI);
			if (d > prog) {
				continue;
			}
			float f = js_noise(a * 6.0 + t * 5.0, 4) * 0.5 + 0.5;
			float k = heat_k * (0.7 + 0.5 * f);
			vec2 c = vec2(cos(a) * r0, sin(a) * r0 * sy);
			float g = 1.0 - length(q - c) / 9.0;
			if (g > 0.0) {
				l += pal[4].rgb * g * g * 0.22 * k;
			}
		}
	}
	COLOR = vec4(l * strength * COLOR.a, 1.0);
}
