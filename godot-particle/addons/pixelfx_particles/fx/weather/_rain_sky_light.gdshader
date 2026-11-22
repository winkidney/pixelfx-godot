// weather/rain's floor and mist light (_rain_sky.gdshaderinc pass 0).
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/weather/_rain_sky.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec4 c;
	int mode;
	vec3 l;
	rain_px(p, c, mode, l);
	COLOR = vec4(l * strength, 1.0);
}
