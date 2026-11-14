// The original's Lights (glows that flare, shrink a little and die), one tracked particle each: (1 - d / r)^2 * k of
// its colour at pixel centres. Light layer.
//   rows: 0 (x, y, on, k), 1 (r, colour index, .., ..)
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/spawn/_track.gdshaderinc"

uniform vec4 pal[8] : source_color;
uniform float strength = 1.0;

void vertex() {
	tk_cu = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 r0 = tk_row(0);
	vec4 r1 = tk_row(1);
	float f = tk_glow(tk_q(UV), vec2(0.0), r1.x) * r0.w;
	COLOR = vec4(pal[int(r1.y + 0.5)].rgb * f * strength * COLOR.a, 1.0);
}
