// weather/blizzard's sheets and drift, colour (soft) layer (_blizzard_sky.gdshaderinc).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_blizzard_sky.gdshaderinc"

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec4 c;
	vec3 l;
	sky_px(p, c, l);
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
