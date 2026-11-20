// weather/aurora's light (_aurora.gdshaderinc): the curtains' light by height, and the bloom of it.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/weather/_aurora.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec4 c;
	bool blend;
	vec3 l;
	aurora_px(p, true, c, blend, l);
	COLOR = vec4(l * strength, 1.0);
}
