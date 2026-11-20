// burn-away's scorch (soft layer): the picture just ahead of the fire browned, blended as the original blends it.
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
	if (kind != 2 || sa <= 0.004) {
		discard;
	}
	COLOR = vec4(scorch.rgb, sa);
}
