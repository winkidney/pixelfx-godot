// A firefly's lantern light (_firefly.gdshader's light twin): one glow far, two nearer, three near.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/weather/_fireflies.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform vec4 C[6] : source_color;
uniform float strength = 1.0;

void fragment() {
	vec2 q = wx_cell(UV) + 0.5;
	int i = int(cu.z + 0.5);
	float g = cu.w;
	int depth = fly_depth(i);
	vec2 xy = pc.xy;
	vec3 l = vec3(0.0);
	if (depth == 0) {
		if (g >= 0.08) l = C[2].rgb * glow_(q, xy, 6.0, 0.45 * g);
	} else if (depth == 1) {
		l = C[2].rgb * glow_(q, xy, 9.0, 0.5 * g) + C[4].rgb * glow_(q, xy, 3.0, 0.5 * g);
	} else {
		l = C[2].rgb * glow_(q, xy, 28.0, 0.45 * g) + C[4].rgb * glow_(q, xy, 10.0, 0.5 * g) + C[5].rgb * glow_(q, xy, 4.0, 0.5 * g);
	}
	COLOR = vec4(l * strength, 1.0);
}
