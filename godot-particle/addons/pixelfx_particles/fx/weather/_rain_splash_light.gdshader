// The glint where a near drop lands on the floor (rain.js layer(): glow(x, z - 1, 5)), _rain_splash.gdshader's twin.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform vec4 glow_color : source_color = vec4(1.0);
uniform float strength = 1.0;

void fragment() {
	vec2 q = wx_cell(UV) + 0.5;
	COLOR = vec4(glow_color.rgb * glow_(q, cu.xy - vec2(0.0, 1.0), 5.0, pc.w) * strength, 1.0);
}
