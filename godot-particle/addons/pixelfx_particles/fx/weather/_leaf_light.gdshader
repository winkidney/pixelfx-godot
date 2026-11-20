// The glint's glow on a leaf turned full face to the light (_leaf.gdshader's light twin).
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform vec4 P[66] : source_color;
uniform float strength = 1.0;

void fragment() {
	vec2 q = wx_cell(UV) + 0.5;
	float flip = pc.x;
	vec3 l = vec3(0.0);
	if (flip > 0.86 && pc.z >= 1.0) {
		float size = cu.z;
		vec2 h = cu.xy - vec2(cos(cu.w), sin(cu.w)) * size * 0.3 - vec2(0.0, 1.0);
		int base = (int(pc.y + 0.5) / 3) * 11;
		l = P[base + 10].rgb * glow_(q, h, 5.0 + size * 0.5, 0.22 * (flip - 0.86) / 0.14);
	}
	COLOR = vec4(l * strength, 1.0);
}
