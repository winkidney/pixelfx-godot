// A meteor's light (_meteor.gdshaderinc), the light twin of _meteor.gdshader.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/weather/_meteor.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 p = wx_cell(UV) + pc.xy + 0.5;
	COLOR = vec4(meteor_light(int(cu.z + 0.5), p) * strength, 1.0);
}
