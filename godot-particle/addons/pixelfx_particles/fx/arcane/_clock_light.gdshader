// The light off the time-stop clock's motes in front of it (see _clock.gdshaderinc). Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/arcane/_clock.gdshaderinc"

uniform vec2 size = vec2(100.0);
uniform vec4 color : source_color = vec4(1.0);
uniform float strength = 1.0;
uniform float alpha = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size + 0.001) + 0.5;
	float sum = 0.0;
	for (int i = 0; i < 14; i++) {
		vec4 m = motes[i];
		float a = m.x + m.z * tc;
		if (sin(a) < 0.0) {
			continue;
		}
		float f = 1.0 - length(p - mote_pos(m, a)) / 5.0;
		sum += f > 0.0 ? f * f * 0.3 : 0.0;
	}
	COLOR = vec4(color.rgb * sum * alpha * strength, 1.0);
}
