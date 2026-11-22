// shatter-wipe's pane light: along the falling edge and spilling onto the picture below it, and on the fresh cracks.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_pane.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 q = floor(UV * vec2(TR_W, TR_H));
	vec3 l = vec3(0.0);
	if (r1 > 0.0 && shine > 0.0) {
		float k = max(0.0, 1.0 - abs(q.x - gx) / 28.0);
		if (k > 0.0 && q.y == r1 - 1.0 && r1 - 1.0 < TR_H) {
			l += lt_add(C[6].rgb, 0.5 * k);
		}
		float d = q.y - r1;
		if (d >= 0.0 && d < 14.0) {
			l += lt_add(C[5].rgb, 0.3 * shine * pow(1.0 - d / 14.0, 2.0) * (0.6 + 0.8 * k));
		}
	}
	if (cracks_on > 0.5) {
		vec4 cp = texelFetch(cpix, ivec2(q), 0);
		int s0 = int(cp.x + 0.5);
		int n = int(cp.y + 0.5);
		for (int i = 0; i < 256; i++) {
			if (i >= n) {
				break;
			}
			float e = pn_entry(s0 + i);
			if (e < 0.0) {
				continue;
			}
			float age = t - e;
			if (age >= 0.0 && age < 0.3) {
				l += lt_add(C[5].rgb, 0.55 * (1.0 - age / 0.3));
			}
			if (wbeat > 0.0) {
				l += lt_add(C[6].rgb, 0.4 * wbeat);
			}
		}
	}
	COLOR = vec4(l * strength, 1.0);
}
