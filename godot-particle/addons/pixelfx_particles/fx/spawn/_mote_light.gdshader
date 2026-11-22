// The light round each mote (_mote.gdshader): a little glow in its colour, or the ash's glow in `ash`. Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/spawn/_track.gdshaderinc"

uniform vec4 cols[128] : source_color;
uniform vec4 ash : source_color = vec4(1.0);
uniform float radius = 2.5;
uniform float ash_radius = 3.0;
uniform float strength = 1.0;

void vertex() {
	tk_cu = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 r0 = tk_row(0);
	vec4 r1 = tk_row(1);
	bool is_ash = int(r1.w + 0.5) == 2;
	vec3 col = is_ash ? ash.rgb : cols[int(r1.z + 0.5)].rgb;
	float f = tk_glow(tk_q(UV), vec2(0.0), is_ash ? ash_radius : radius) * r0.w;
	COLOR = vec4(col * f * strength * COLOR.a, 1.0);
}
