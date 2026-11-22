// weather/god-rays' air and beams, light layer (_god_rays_sky.gdshaderinc).
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/weather/_god_rays_sky.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec4 c;
	vec3 l;
	rays_px(p, c, l);
	COLOR = vec4(l * strength, 1.0);
}
