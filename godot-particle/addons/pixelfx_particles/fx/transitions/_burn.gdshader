// burn-away's cover (colour layer): the ember line white-hot at the edge and cooling into char, glowing flecks and the
// smouldering web of cracks; or all ink while it's covered.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_burn.gdshaderinc"

void fragment() {
	ivec2 q = ivec2(floor(UV * vec2(TR_W, TR_H)));
	int kind;
	vec3 col;
	float sa, l1, l2;
	bn_shade(q, kind, col, sa, l1, l2);
	if (kind != 1) {
		discard;
	}
	COLOR = vec4(col, 1.0);
}
