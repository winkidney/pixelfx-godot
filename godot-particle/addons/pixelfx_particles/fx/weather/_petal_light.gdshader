// The flash of a petal turned full face to the light, and a blossom's glow (_petal.gdshader's light twin).
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform vec4 glow_color : source_color = vec4(1.0);
uniform float radius = 5.0;
uniform float strength = 1.0;

void fragment() {
	vec2 q = wx_cell(UV) + 0.5;
	float r = pc.z > 0.5 ? 8.0 : radius;
	COLOR = vec4(glow_color.rgb * glow_(q, cu.xy, r, pc.w) * strength, 1.0);
}
