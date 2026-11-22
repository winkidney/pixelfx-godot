// The glow round a mote (_mote.gdshader's light twin): COLOR.x strong, COLOR.y px wide, at the mote's own point.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform vec4 glow_color : source_color = vec4(1.0);
uniform float strength = 1.0;

void fragment() {
	vec2 q = wx_cell(UV) + 0.5;
	COLOR = vec4(glow_color.rgb * glow_(q, cu.xy, pc.y, pc.x) * strength, 1.0);
}
