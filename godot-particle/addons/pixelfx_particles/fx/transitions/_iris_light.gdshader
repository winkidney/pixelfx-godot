// iris's light: on the rim's inner bevel, and pooling just inside the hole.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_iris.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 px = floor(UV * vec2(TR_W, TR_H));
	vec3 l = vec3(0.0);
	float a0, b1, g;
	if (mode > 0.5 && mode < 1.5 && ir_span(px, a0, b1, g) && px.x >= a0 && px.x < b1) {
		float dx = px.x + 0.5 - focus.x;
		float dy = px.y + 0.5 - focus.y;
		float d = length(vec2(dx, dy)) - r;
		if (abs(dx) >= g) {
			if (d >= 0.0) {
				float q = d / rw;
				float lit = 0.5 - 0.5 * (dx * 0.7 + dy * 0.7) / (r + d + 0.01);
				float h = hot * (0.55 + 0.6 * lit);
				if (q < 0.5) {
					l = lt_add(C[5].rgb, 0.45 * h * (1.0 - q * 2.0));
				}
			} else if (d > -GLO) {
				l = lt_add(C[5].rgb, (0.18 + 0.3 * hot) * pow(1.0 + d / GLO, 2.0));
			}
		}
	}
	COLOR = vec4(l * strength, 1.0);
}
