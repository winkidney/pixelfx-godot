// The light on a puddle in the rain (see _puddle.gdshaderinc), additive: the lamp's reflection, a flash where each
// drop hits, the glow of its crown and of its rebound jet.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_puddle.gdshaderinc"

uniform float strength = 1.0;

float soft(vec2 p, vec2 c, float r) {
	float d = distance(p, c) / r;
	return d < 1.0 ? (1.0 - d) * (1.0 - d) : 0.0;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec3 l = pal[5].rgb * 0.2 * lamp_k(p);
	for (int i = 0; i < 8; i++) {
		vec4 q = drop_a[i];
		float a = age_of(i);
		float cy = q.y * sy;
		if (a < 0.05) {
			l += pal[5].rgb * 0.5 * (1.0 - a / 0.05) * soft(p, vec2(q.x, cy - 2.0), 12.0);
		}
		float h = crown_h(a, drop_b[i].x);
		if (h >= 1.0) {
			l += pal[5].rgb * 0.3 * (h / drop_b[i].x) * soft(p, vec2(q.x, cy - h * 0.6), 6.0 + h * 0.6);
		}
		float jh = jet_h(a, drop_b[i].y);
		if (jh > 0.8) {
			l += pal[5].rgb * 0.3 * soft(p, vec2(q.x, cy - jh * 0.6), 6.0);
		}
	}
	COLOR = vec4(l * strength, 1.0);
}
