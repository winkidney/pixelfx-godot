// Streaks of rain or blown snow as the weather originals draw them (rain.js / blizzard.js / storm.js), placed by an
// effect's process shader: CUSTOM.z the streak's length L, .w its alpha; COLOR.xy its direction (unit), .z which
// colours (0..2: lit by a flash, or a white head), .w its light. mode 0: a tail line from L back to `split` L
// (alpha a (ta0 + ta1 v) along it), a body line from there to 1 px behind the head, the head pixel; mode 1: a body
// line from L to `split` L and a head line from there to the head; mode 2: the head pixel and one behind it (a
// grain); mode 3: the head and one dot along the streak behind it (a far drop, alpha 0.8 a).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_line.gdshaderinc"

uniform int mode = 0;
uniform float split = 0.45;
uniform float ta0 = 0.3;
uniform float ta1 = 0.7;
uniform vec4 tail[3] : source_color;
uniform vec4 bodyc[3] : source_color;
uniform vec4 head[3] : source_color;

void fragment() {
	vec2 d = wx_cell(UV);
	vec2 P = cu.xy;
	float L = cu.z;
	float a = cu.w;
	vec2 dir = pc.xy;
	int s = int(pc.z + 0.5);
	vec4 c = vec4(0.0);
	float u;
	if (mode == 0) {
		if (d == vec2(0.0)) {
			c = vec4(head[s].rgb, a);
		} else if (on_line(d, floor(P - dir * L * split), floor(P - dir), u)) {
			c = vec4(bodyc[s].rgb, a);
		} else if (on_line(d, floor(P - dir * L), floor(P - dir * L * split), u)) {
			c = vec4(tail[s].rgb, a * (ta0 + ta1 * u));
		}
	} else if (mode == 1) {
		if (on_line(d, floor(P - dir * L * split), floor(P), u)) {
			c = vec4(head[s].rgb, a);
		} else if (on_line(d, floor(P - dir * L), floor(P - dir * L * split), u)) {
			c = vec4(bodyc[s].rgb, a);
		}
	} else if (mode == 2) {
		if (d == vec2(0.0)) {
			c = vec4(head[s].rgb, 1.0);
		} else if (d == vec2(-1.0, 0.0)) {
			c = vec4(bodyc[0].rgb, 1.0);
		}
	} else {
		if (d == vec2(0.0)) {
			c = vec4(head[s].rgb, a);
		} else if (d == floor(P - dir)) {
			c = vec4(bodyc[s].rgb, a * 0.8);
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
