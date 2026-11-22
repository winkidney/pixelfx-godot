// The light the original's Particles give off (p.glow round sparks, motes, streaks, star glints, embers, fires, and
// vapour's haze): the light twin of a _parts.gdshader emitter, on the light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/spawn/_track.gdshaderinc"

uniform vec4 cols[48] : source_color;
uniform vec4 sparks[4] : source_color;
uniform vec4 fire[9] : source_color;
uniform vec4 smoke[5] : source_color;
uniform vec4 white : source_color = vec4(1.0);
uniform vec4 haze : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float strength = 1.0;

void vertex() {
	tk_cu = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 h1 = tk_head(1);
	vec4 r0 = tk_row(0);
	vec4 r1 = tk_row(1);
	int kind = int(h1.x + 0.5);
	vec3 col = h1.y < -0.5 ? vec3(0.0) : cols[int(h1.y + 0.5)].rgb;
	float size = h1.z;
	float k = r0.w;
	vec2 q = tk_q(UV);
	vec3 l = vec3(0.0);
	if (kind == 0) {
		vec3 hd = k > 0.6 ? sparks[0].rgb : k > 0.3 ? sparks[1].rgb : sparks[2].rgb;
		l = hd * tk_glow(q, vec2(0.0), 3.0) * 0.45 * k;
	} else if (kind == 1) {
		l = col * tk_glow(q, vec2(0.0), 2.5 + size) * 0.4 * k;
	} else if (kind == 2) {
		l = col * tk_glow(q, vec2(0.0), 4.0) * 0.4;
	} else if (kind == 4) {
		l = haze.rgb * tk_glow(q, vec2(0.0), size * (0.6 + (1.0 - k) * 0.9) * 1.8) * 0.16 * k;
	} else if (kind == 6) {
		float tw = r1.z;
		if (size < 1.0) {
			l = col * tk_glow(q, vec2(0.0), 3.0) * 0.4 * k * tw;
		} else {
			float n = floor(size * tw * min(1.0, k * 3.0) + 0.5);
			if (n >= 1.0) {
				l = col * tk_glow(q, vec2(0.0), 4.0 + n * 2.0) * 0.5 * k * tw;
			}
		}
	} else if (kind == 7) {
		if (r1.z < 0.5) {
			vec3 c = k > 0.6 ? sparks[0].rgb : k > 0.3 ? sparks[1].rgb : sparks[2].rgb;
			l = c * tk_glow(q, vec2(0.0), 3.0 + size) * 0.35 * k;
		}
	} else if (kind == 9) {
		int idx = int(r1.z + 0.5);
		if (idx < 6) {
			l = fire[idx].rgb * tk_glow(q, vec2(0.0), r1.w * 2.4 + 2.0) * 0.18 * k;
		}
	}
	COLOR = vec4(l * strength * COLOR.a, 1.0);
}
