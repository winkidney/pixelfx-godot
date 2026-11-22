// The eclipse, light layer (see _eclipse.gdshaderinc): each streamer's soft glow line (the original's glowLine from
// 4 px off the rim to 0.6 of its length, radius 3) and the sparkle of light on every other cell of the corona's
// bright streaks.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/shadow/_eclipse.gdshaderinc"

uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 q1 : source_color = vec4(1.0);
uniform vec4 q2 : source_color = vec4(1.0);
uniform float k_line = 0.12;
uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center + 0.001) + 0.5;
	vec3 sum = vec3(0.0);
	for (int i = 0; i < 30; i++) {
		float L = e_len(i);
		vec2 dir = vec2(cos(streams[i].x), sin(streams[i].x));
		vec2 a = dir * (E_R + 4.0);
		vec2 b = dir * (E_R + L * 0.6);
		vec2 ab = b - a;
		float u = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
		float d = length(a + ab * u - p) / 3.0;
		if (d < 1.0) {
			sum += q1.rgb * (1.0 - d) * (1.0 - d) * k_line;
		}
	}
	float I = e_corona(p);
	if (I > 0.45 && I < 9.0 && mod(floor(p.x) + floor(p.y), 2.0) < 0.5) {
		vec3 c = I > 0.72 ? q2.rgb : q1.rgb;
		sum += c * 0.2 * I;
	}
	COLOR = vec4(sum * strength, 1.0);
}
