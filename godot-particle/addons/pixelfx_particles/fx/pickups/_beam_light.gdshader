// loot-beam's column light (src/fx/pickups/loot-beam.js column()): a close glow on every fourth row the column draws,
// a wide haze on every sixteenth, both fading with the column toward the sky and swelling with the beat. ph and beat
// keyed every frame. Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/pickups/_pk.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_jsrand.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/pickups/_beam.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 canvas = vec4(-1e4, -1e4, 2e4, 2e4);
uniform float strength = 1.0;

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	float e = lt_edge(pc, canvas) * strength;
	vec3 l = vec3(0.0);
	for (int r = 1; r <= 37; r++) {
		float y = -4.0 * float(r);
		if (!beam_row(y)) {
			continue;
		}
		float h = -y - 0.5;
		float u = h / H;
		float fade = 1.0 - beam_smooth(0.25, 1.0, u);
		float near = beam_smooth(8.0, 20.0, h);
		float w = beam_w(h);
		l += lt_glow(pc, vec2(0.5, y), w * 2.6 + 6.0, c5.rgb, 0.36 * near * (0.3 + 0.7 * fade) * (1.0 + 0.4 * beat) * e);
		if (r % 4 == 0) {
			l += lt_glow(pc, vec2(0.5, y), 34.0, c4.rgb, 0.2 * near * (0.25 + 0.75 * fade) * e);
		}
	}
	COLOR = vec4(min(l, vec3(1.0)), 1.0);
}
