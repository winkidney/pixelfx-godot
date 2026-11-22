// weather/clouds: the silver lining's light on a cloud's top near the moon (_cloud_px.gdshaderinc).
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/weather/_cloud_px.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 q = wx_cell(UV) + pc.xy;
	float a;
	float lk;
	int c = cloud_px(int(cu.z + 0.5), q.x, q.y, a, lk);
	COLOR = vec4(c < 0 ? vec3(0.0) : C[6].rgb * lk * strength, 1.0);
}
