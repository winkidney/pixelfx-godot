// star-iris's cover (colour layer): ink outside the star, the gold rim along its edges.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_star.gdshaderinc"

void fragment() {
	vec2 px = floor(UV * vec2(TR_W, TR_H));
	vec3 col = vec3(-1.0);
	if (mode > 0.5 && mode < 1.5) {
		col = ink.rgb;
	} else if (mode > 1.5) {
		if (st_ink(px)) {
			col = ink.rgb;
		}
		int n;
		int r = st_rim(px, n);
		if (r >= 0) {
			col = r == 8 ? vec3(1.0) : C[r].rgb;
		}
	}
	if (col.r < 0.0) {
		discard;
	}
	vec4 o = vec4(col, 1.0);
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
