// The light round a tracked line (the original's p.glowLine): (1 - d / radius)^2 * k of `color`. Light layer.
//   rows: 0 (x, y, on, k), 1 (tail x, tail y, head x, head y: px from the particle's exact position)
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/spawn/_track.gdshaderinc"

uniform vec4 color : source_color = vec4(1.0);
uniform float radius = 3.0;
uniform float k = 1.0;
uniform float strength = 1.0;

void vertex() {
	tk_cu = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 r0 = tk_row(0);
	vec4 r1 = tk_row(1);
	float f = tk_glow_line(tk_q(UV), r1.xy, r1.zw, radius) * r0.w * k;
	COLOR = vec4(color.rgb * f * strength * COLOR.a, 1.0);
}
