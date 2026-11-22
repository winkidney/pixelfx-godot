// The light round a streak's head (the light twin of _streak.gdshader's bodies): a glow of `radius` at the head
// (moved by `off`), COLOR.w strong.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform vec4 glow_color : source_color = vec4(1.0);
uniform float radius = 5.0;
uniform vec2 off = vec2(0.0);
uniform float strength = 1.0;

void fragment() {
	vec2 q = wx_cell(UV) + 0.5;
	COLOR = vec4(glow_color.rgb * glow_(q, cu.xy + off, radius, pc.w) * strength, 1.0);
}
