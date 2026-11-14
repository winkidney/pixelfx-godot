// A 1 px line between two points (the original's p.line), from the track: speed lines, streaks. Colour layer.
//   rows: 0 (x, y, on, alpha), 1 (tail x, tail y, head x, head y: px from the particle's exact position)
// The line is `tail_c` from the tail and `head_c` past `split` of the way to the head.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_track.gdshaderinc"

uniform vec4 tail_c : source_color = vec4(1.0);
uniform vec4 head_c : source_color = vec4(1.0);
uniform float split = 0.6;

void vertex() {
	tk_cu = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 r0 = tk_row(0);
	vec4 r1 = tk_row(1);
	vec2 fr = tk_fr();
	float u = tk_line(tk_cell(UV), floor(fr + r1.xy), floor(fr + r1.zw));
	if (u < 0.0) {
		discard;
	}
	vec4 c = u > split ? head_c : tail_c;
	c.a = r0.w;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
