// weather/storm's light over the sky, the deck and the floor (_storm.gdshaderinc pass 0).
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/weather/_storm.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec4 c;
	int mode;
	vec3 l;
	storm_px(p, c, mode, l);
	COLOR = vec4(l * strength, 1.0);
}
