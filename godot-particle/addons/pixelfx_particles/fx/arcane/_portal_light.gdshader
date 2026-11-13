// The portal's rift, light pass (see _portal.gdshaderinc): light off the rim's bright line and the brightest crests.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/arcane/_portal.gdshaderinc"

uniform vec4 c6 : source_color = vec4(1.0);
uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center + 0.001) + 0.5;
	int col;
	float level;
	float lk;
	int kind = p_rift(p, col, level, lk);
	vec3 c = col == 7 ? vec3(1.0) : c6.rgb;
	COLOR = vec4(c * lk * strength, 1.0);
}
