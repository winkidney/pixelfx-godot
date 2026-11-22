// weather/rain's floor and mist (_rain_sky.gdshaderinc): the soft layer takes the translucent pixels (soft), the
// colour layer the rest.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_rain_sky.gdshaderinc"

uniform bool soft = false;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec4 c;
	int mode;
	vec3 l;
	rain_px(p, c, mode, l);
	if (mode == 0 || (mode == 1) != soft || c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
