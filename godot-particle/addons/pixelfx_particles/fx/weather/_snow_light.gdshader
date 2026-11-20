// The light of weather/snow's near crystals (snow.js crystal(): a faint halo and a bright heart; a cold glow round
// one lying on the drift): the light twin of the bodies _snow_draw.gdshader draws.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform vec4 C[8] : source_color;
uniform float strength = 1.0;

void fragment() {
	vec2 d = wx_cell(UV);
	vec2 q = d + 0.5;
	int kind = int(cu.z + 0.5);
	vec3 l = vec3(0.0);
	if (kind == 4) {
		l = C[5].rgb * glow_(q, cu.xy, 5.0, 0.25 * cu.w);
	} else if (kind == 5) {
		l = C[5].rgb * glow_(q, vec2(0.5), pc.y * 2.5 + 5.0, 0.13);
		if (d == vec2(0.0)) l += C[6].rgb * 0.4;
	}
	COLOR = vec4(l * strength, 1.0);
}
