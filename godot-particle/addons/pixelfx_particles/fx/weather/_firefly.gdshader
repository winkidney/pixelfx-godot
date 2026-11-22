// A firefly as the original draws it (fireflies.js firefly()): far, a point of light; nearer, a short trail of light
// where it has just been and a lantern; near, a dark body with wings beating above it, the lantern at its tail and a
// glint at its peak. Placed by _fireflies.gdshader on its rounded pixel; the trail and its heading from the same
// path (fly_pos) at the clock `t`; `beat` is the wings' frame parity, keyed.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_fireflies.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform vec4 C[6] : source_color;
uniform vec4 wing : source_color = vec4(1.0);
uniform float beat = 0.0;

void fragment() {
	vec2 d = wx_cell(UV);
	int i = int(cu.z + 0.5);
	float g = cu.w;
	int depth = fly_depth(i);
	vec2 X = floor(fly_pos(i, t) + 0.5);
	vec4 c = vec4(0.0);
	if (depth == 0) {
		if (g >= 0.08 && d == vec2(0.0)) c = vec4((g > 0.6 ? C[4] : C[3]).rgb, min(1.0, g * 1.6));
	} else if (depth == 1) {
		if (d == vec2(0.0)) c = g > 0.5 ? C[5] : g > 0.15 ? C[3] : C[1];
		else if (g > 0.4 && d == vec2(0.0, 1.0)) c = C[2];
	} else {
		float nx = fly_pos(i, t + 0.05).x;
		float dir = nx >= fly_pos(i, t).x ? 1.0 : -1.0;
		float b = beat;
		if (d == vec2(-dir, 0.0)) c = g > 0.5 ? C[4] : g > 0.15 ? C[3] : C[1];
		else if (d == vec2(0.0)) c = g > 0.3 ? C[5] : C[1];
		else if (g > 0.6 && d == vec2(-dir, 1.0)) c = C[3];
		else if (d == vec2(0.0, -1.0 - b) || d == vec2(dir, -1.0 - b)) c = vec4(wing.rgb, 0.7);
		else if (d == vec2(dir, 0.0) || d == vec2(2.0 * dir, 0.0)) c = C[0];
		if (g > 0.7) {
			vec2 e = d - vec2(-dir, 0.0);
			if (e == vec2(0.0, -2.0) || e == vec2(0.0, 2.0) || e == vec2(-2.0, 0.0) || e == vec2(2.0, 0.0)) {
				c = vec4(C[3].rgb, (g - 0.7) * 3.0);
			}
		}
	}
	if (c.a <= 0.0 && depth > 0 && g > 0.3) {
		for (int j = 4; j >= 1; j--) {
			vec2 tp = fly_pos(i, t - float(j) * 0.05);
			if (d == floor(tp) - X) {
				c = vec4(C[2].rgb, (g - 0.3) * (1.0 - float(j) / 5.0) * 1.3);
				break;
			}
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
