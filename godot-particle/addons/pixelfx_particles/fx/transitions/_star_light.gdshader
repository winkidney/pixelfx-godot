// star-iris's rim light: a dot of light every other px along each edge.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_star.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 px = floor(UV * vec2(TR_W, TR_H));
	vec3 l = vec3(0.0);
	if (mode > 1.5) {
		int n;
		st_rim(px, n);
		for (int i = 0; i < n; i++) {
			l += lt_add(C[5].rgb, 0.5);
		}
	}
	COLOR = vec4(l * strength, 1.0);
}
