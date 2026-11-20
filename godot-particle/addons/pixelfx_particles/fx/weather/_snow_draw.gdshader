// weather/snow's flakes as the original draws them (snow.js layer(), crystal()), placed by _snow.gdshader: a far
// speck, a flake (a point with a smaller one beside it, or a plus), a flake lying on the drift, a spinning crystal
// (its sprite from `atlas`: palette steps, 9 = white) and a crystal lying down.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform vec4 C[8] : source_color;
uniform vec4 white : source_color = vec4(1.0);
uniform sampler2D atlas : filter_nearest, repeat_disable;

void fragment() {
	vec2 d = wx_cell(UV);
	int kind = int(cu.z + 0.5);
	float a = cu.w;
	vec4 c = vec4(0.0);
	bool o = d == vec2(0.0);
	if (kind == 0) {
		if (o) c = vec4((pc.x > 0.5 ? C[5] : C[4]).rgb, a);
	} else if (kind == 1) {
		if (o) c = vec4(C[7].rgb, a);
	} else if (kind == 2) {
		if (o) c = white;
		else if (abs(d.x) + abs(d.y) == 1.0) c = C[5];
	} else if (kind == 3) {
		if (o) c = C[7];
		else if (d == vec2(1.0, 0.0) || d == vec2(0.0, 1.0)) c = C[6];
		else if (d == vec2(1.0, 1.0)) c = C[5];
	} else if (kind == 4) {
		if (o) c = vec4(white.rgb, a);
		else if (d.y == 0.0 && abs(d.x) == 1.0) c = vec4(C[6].rgb, a);
	} else if (kind == 5) {
		if (abs(d.x) < 8.0 && abs(d.y) < 8.0) {
			int v = int(texelFetch(atlas, ivec2(int(pc.x + 0.5) * 16 + 8 + int(d.x), 8 + int(d.y)), 0).r * 255.0 + 0.5);
			if (v > 0) c = v == 9 ? white : C[v - 1];
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
