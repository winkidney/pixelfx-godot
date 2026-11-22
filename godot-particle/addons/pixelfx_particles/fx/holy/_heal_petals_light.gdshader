// The glow on each petal's tip (holy/heal, light layer).
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/holy/_heal_petal.gdshaderinc"

uniform vec2 size = vec2(64.0, 32.0);
uniform vec2 center = vec2(0.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float l = 0.0;
	for (int k = 0; k < NP; k++) {
		float b;
		bool near;
		vec4 q = petal_at(k, b, near);
		if (b <= 0.02) {
			continue;
		}
		float f = max(0.0, 1.0 - length(p - q.zw) / 5.0);
		l += f * f * 0.35 * min(1.0, b);
	}
	COLOR = vec4(c5.rgb * min(l, 1.0) * strength, 1.0);
}
