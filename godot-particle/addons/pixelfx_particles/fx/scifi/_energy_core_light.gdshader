// The energy core's light (src/fx/scifi/energy-core.js), from the keyed clock `t` and the frame's data: the plinth's
// glow and its status lights', the filaments' tips, the orbit rings' beads, the cap's emitter, light along the arcs
// and where they strike, the shock rings', the core's heat and its white heart, all swelling on each thump.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/scifi/_scifi_light.gdshaderinc"

uniform vec2 size = vec2(112.0, 100.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float frame = 0.0;
uniform float slot = 0.0;
uniform float k = 1.0;
uniform sampler2D data : filter_nearest, repeat_disable;
uniform vec4 pal[8] : source_color;
uniform float strength = 1.0;

const float D = 2.4;
const float CY = -36.0;
const float R0 = 11.0;
const float TOPY = -64.0;

float env(float a) {
	return a < 0.03 ? a / 0.03 : exp(-(a - 0.03) / 0.12);
}

float pulse_at(float tt) {
	float m = env(mod(tt - 0.05, D));
	m = max(m, 0.5 * env(mod(tt - 0.25, D)));
	m = max(m, env(mod(tt - 1.25, D)));
	m = max(m, 0.5 * env(mod(tt - 1.45, D)));
	return m;
}

vec3 ring_pt(float r, float tilt, float spin, float a) {
	float x = r * cos(a);
	float z0 = r * sin(a);
	float y = -z0 * sin(tilt);
	float z = z0 * cos(tilt);
	return vec3(x * cos(spin) + z * sin(spin), CY - y, -x * sin(spin) + z * cos(spin));
}

float glow_ring(vec2 pc, vec2 at, float R, float r) {
	float d = abs(length(pc - at) - R) / r;
	return d < 1.0 ? (1.0 - d) * (1.0 - d) : 0.0;
}

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size + 0.001) + 0.5;
	float pulse = pulse_at(t);
	vec3 l = vec3(0.0);
	// the plinth
	for (int i = 0; i < 7; i++) {
		float kk = 0.5 + 0.5 * cos(TAU * (2.0 * (t / D) - float(i) / 7.0));
		if (kk > 0.6) {
			l += pal[4].rgb * glow_at(pc, vec2(-18.0 + float(i) * 6.0, -3.0), 4.0) * 0.3 * kk;
		}
	}
	l += pal[4].rgb * glow_at(pc, vec2(0.0, -8.0), 26.0) * (0.25 + 0.3 * pulse);
	// the filaments' tips
	int f = clamp(int(frame + 0.5), 0, 71);
	for (int j = 0; j < 3; j++) {
		l += pal[5].rgb * glow_at(pc, texelFetch(data, ivec2(j * 9 + 8, f), 0).xy, 4.0) * 0.4;
	}
	// the rings' beads
	float bead = (t / D) * TAU * 3.0;
	l += pal[5].rgb * glow_at(pc, ring_pt(17.0, 1.15, TAU * (t / D), bead).xy, 6.0) * 0.5;
	l += pal[5].rgb * glow_at(pc, ring_pt(19.0, -0.9, -TAU * 2.0 * (t / D) + 1.0, bead).xy, 6.0) * 0.5;
	l += pal[4].rgb * glow_at(pc, vec2(0.0, TOPY - 7.0), 5.0) * (0.4 + 0.4 * pulse);
	// the arcs: light every third joint, a glow where each strikes
	if (k > 0.0) {
		int row = 72 + clamp(int(slot + 0.5), 0, 23);
		int cur = -1;
		int idx = 0;
		vec2 prev = vec2(0.0);
		float w = 1.0;
		for (int j = 0; j < 64; j++) {
			vec4 q = texelFetch(data, ivec2(j, row), 0);
			bool last = q.z < -0.5;
			int sid = int(q.z + 0.5);
			if (last || sid != cur) {
				if (cur >= 0 && w > 0.9) {
					l += pal[5].rgb * glow_at(pc, prev, 8.0) * 0.6 * k;
				}
				if (last) {
					break;
				}
				idx = 0;
			} else {
				idx += 1;
				if (idx % 3 == 0) {
					l += pal[4].rgb * glow_at(pc, prev, 9.0 * q.w) * 0.45 * k;
				}
			}
			cur = sid;
			prev = q.xy;
			w = q.w;
		}
	}
	// the shock rings
	for (int i = 0; i < 2; i++) {
		float b = i == 0 ? 0.05 : 1.25;
		float a = mod(t - b, D);
		if (a > 0.45) {
			continue;
		}
		float q = a / 0.45;
		float r = R0 + 34.0 * (1.0 - pow(1.0 - q, 3.0));
		l += pal[4].rgb * glow_ring(pc, vec2(0.0, CY), r, 6.0) * 0.35 * (1.0 - q);
	}
	l += pal[4].rgb * glow_at(pc, vec2(0.0, CY), 46.0) * (0.2 + 0.3 * pulse);
	l += glow_at(pc, vec2(0.0, CY), 9.0) * (0.35 + 0.4 * pulse);
	COLOR = vec4(l * strength, 1.0);
}
