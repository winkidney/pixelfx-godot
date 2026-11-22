// burn-away's light from the burning: warm light ahead of the fire and on the ember line, flecks and cracks.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_burn.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	ivec2 q = ivec2(floor(UV * vec2(TR_W, TR_H)));
	int kind;
	vec3 col;
	float sa, l1, l2;
	bn_shade(q, kind, col, sa, l1, l2);
	COLOR = vec4((lt_add(warm.rgb, l1) + lt_add(warm.rgb, l2)) * strength, 1.0);
}
