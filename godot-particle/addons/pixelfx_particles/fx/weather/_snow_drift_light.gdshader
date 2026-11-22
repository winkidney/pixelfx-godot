// weather/snow's drift and its glints, light layer (_snow_drift.gdshaderinc).
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/weather/_snow_drift.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec4 c;
	vec3 l;
	drift(p, c, l);
	COLOR = vec4(l * strength, 1.0);
}
