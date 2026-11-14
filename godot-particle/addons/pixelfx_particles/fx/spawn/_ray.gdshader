// A 1 px ray of light (the original's p.line with colour and alpha along it), from the track: white near its root,
// then c1, then c2, thinning out toward its tip as (1 - u^2) * alpha, dithered. Colour layer.
//   rows: 0 (x, y, on, alpha), 1 (.., .., tip x, tip y: px from the root)
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_track.gdshaderinc"

uniform vec4 c0 : source_color = vec4(1.0);
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec2 split = vec2(0.3, 0.65);

void vertex() {
	tk_cu = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 r0 = tk_row(0);
	vec4 r1 = tk_row(1);
	vec2 fr = tk_fr();
	float u = tk_line(tk_cell(UV), vec2(0.0), floor(fr + r1.zw));
	if (u < 0.0) {
		discard;
	}
	float a = (1.0 - u * u) * r0.w;
	if (!(a >= 1.0 || a > pfx_threshold(FRAGCOORD.xy))) {
		discard;
	}
	COLOR = vec4((u < split.x ? c0 : u < split.y ? c1 : c2).rgb, 1.0);
}
