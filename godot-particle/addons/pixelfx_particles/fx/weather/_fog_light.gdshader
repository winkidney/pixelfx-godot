// weather/fog's banks and streaks, light layer (_fog.gdshaderinc).
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/weather/_fog.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec4 c;
	vec3 l;
	fog_px(p, c, l);
	COLOR = vec4(l * strength, 1.0);
}
