// weather/clouds: a cloud's pixels (_cloud_px.gdshaderinc) on the soft layer: see-through far, solid near.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_cloud_px.gdshaderinc"

void fragment() {
	vec2 q = wx_cell(UV) + pc.xy;
	float a;
	float lk;
	int c = cloud_px(int(cu.z + 0.5), q.x, q.y, a, lk);
	if (c < 0) {
		discard;
	}
	vec4 col = vec4(C[c].rgb, a);
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
