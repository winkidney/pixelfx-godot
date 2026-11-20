// A meteor of weather/shooting-stars (_meteor.gdshaderinc), placed on its head by _shooting.gdshader.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_meteor.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

void fragment() {
	vec2 Q = wx_cell(UV) + pc.xy;
	vec4 c = meteor_px(int(cu.z + 0.5), Q, pfx_threshold(FRAGCOORD.xy));
	if (c.a <= 0.0) {
		discard;
	}
	c.a = 1.0;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
