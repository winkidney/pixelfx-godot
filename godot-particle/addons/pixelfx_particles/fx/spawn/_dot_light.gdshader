// The light round a tracked dot (_dot.gdshader): glow(x, y + dy, radius, color, k). Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/spawn/_track.gdshaderinc"

uniform vec4 color : source_color = vec4(1.0);
uniform float radius = 3.0;
uniform float strength = 1.0;

void vertex() {
	tk_cu = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 r1 = tk_row(1);
	float f = tk_glow(tk_q(UV), vec2(0.0, r1.z), radius) * r1.y;
	COLOR = vec4(color.rgb * f * strength * COLOR.a, 1.0);
}
