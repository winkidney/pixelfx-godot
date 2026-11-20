// weather/aurora's curtains, colour layer (_aurora.gdshaderinc): the bright parts in crisp colour, on the soft layer
// (translucent: the body) or the dithered one (`dither`: the hot hems), so the stars shine through the faint light.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_aurora.gdshaderinc"

uniform bool dither = false;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec4 c;
	bool blend;
	vec3 l;
	aurora_px(p, false, c, blend, l);
	if (c.a <= 0.0 || blend == dither || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
