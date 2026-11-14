// One dot of the original's (p.dot: a pixel at an alpha, dithered), tracked: swirling motes. Colour layer.
//   rows: 0 (x, y, on, alpha), 1 (colour index, glow, glow dy, ..)
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_track.gdshaderinc"

uniform vec4 cols[8] : source_color;

void vertex() {
	tk_cu = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 r0 = tk_row(0);
	vec4 r1 = tk_row(1);
	if (!all(equal(tk_cell(UV), vec2(0.0)))) {
		discard;
	}
	vec4 c = vec4(cols[int(r1.x + 0.5)].rgb, r0.w);
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
