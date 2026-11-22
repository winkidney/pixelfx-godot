// The tractor beam's cycle() particles (src/fx/scifi/tractor-beam.js), each slot one of the original's, born and
// living as its rng(seed, i, 911) says and placed from the keyed clock `t` along the haul up the beam:
//   mode 0: dust drawn up in soft puffs, thinning as it goes (`bits` rows: born, life, r0, th0 | dir)
//   mode 1: grit and motes hauled up in a quick spiral, a streak from a little way back to the head (born, life, r0,
//           th0 | dir, turns, mote | head colour | tail colour); mode 2: the motes' white heads
//   mode 3: twinkles caught in the light (born, life, r0, th0 | dir, progress)
// Drawn by _tractor_bit.gdshader (CUSTOM: disc radius / the streak's tail colour / the twinkle's arm).
shader_type particles;
render_mode disable_velocity, disable_force;

uniform float t = 0.0;
uniform int mode = 0;
uniform sampler2D bits : filter_nearest, repeat_disable;
uniform vec4 dust_a : source_color = vec4(1.0);
uniform vec4 dust_b : source_color = vec4(1.0);

#include "res://addons/pixelfx_particles/fx/scifi/_tractor.gdshaderinc"

mat4 quad(vec2 c, float ang, vec2 sc) {
	float ca = cos(ang);
	float sa = sin(ang);
	return mat4(vec4(ca * sc.x, sa * sc.x, 0.0, 0.0), vec4(-sa * sc.y, ca * sc.y, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(c, 0.0, 1.0));
}

void place(int i, inout mat4 tr, inout vec4 col, inout vec4 cu) {
	vec4 a = texelFetch(bits, ivec2(i, 0), 0);
	vec4 b = texelFetch(bits, ivec2(i, 1), 0);
	tr = quad(vec2(0.0), 0.0, vec2(0.0));
	cu = vec4(0.0);
	float age = mod(t - a.x, D);
	if (age >= a.y) {
		return;
	}
	float k = age / a.y;
	if (mode == 0) {
		vec3 h = haul(a.z, a.w, b.x, 0.8, k);
		tr = quad(h.xy, 0.0, vec2(1.0));
		col = vec4(mix(dust_a.rgb, dust_b.rgb, 0.25 + 0.5 * k), 0.4 * min(1.0, k * 6.0) * (1.0 - k));
		cu = vec4(mix(4.0, 1.5, k), 0.0, 0.0, 0.0);
	} else if (mode == 1 || mode == 2) {
		bool mote = b.z > 0.5;
		vec3 h = haul(a.z, a.w, b.x, b.y, k);
		vec3 h1 = haul(a.z, a.w, b.x, b.y, k - (mote ? 0.13 : 0.06));
		if (mode == 2) {
			if (mote) {
				tr = quad(floor(h.xy) + 0.5, 0.0, vec2(1.0));
				col = vec4(1.0);
			}
			return;
		}
		vec2 ca = floor(h1.xy) + 0.5;
		vec2 cb = floor(h.xy) + 0.5;
		vec2 e = cb - ca;
		float L = length(e);
		float ang = L > 0.01 ? atan(e.y, e.x) : 0.0;
		tr = quad((ca + cb) * 0.5, ang, vec2(L + 1.0, 1.0));
		vec4 hc = texelFetch(bits, ivec2(i, 2), 0);
		vec4 tc = texelFetch(bits, ivec2(i, 3), 0);
		col = vec4(h.z > 0.0 ? hc.rgb : hc.rgb * 0.7, 1.0);
		cu = vec4(L, tc.rgb);
	} else {
		vec3 h = haul(a.z, a.w, b.x, 0.6, b.y + k * 0.15);
		float arm = floor(2.0 * sin(PI * k) + 0.5);
		if (arm > 0.0) {
			tr = quad(floor(h.xy) + 0.5, 0.0, vec2(1.0));
			col = vec4(1.0);
			cu = vec4(arm, 0.0, 0.0, 0.0);
		}
	}
}

void start() {
	VELOCITY = vec3(0.0);
	place(int(INDEX), TRANSFORM, COLOR, CUSTOM);
}

void process() {
	VELOCITY = vec3(0.0);
	place(int(INDEX), TRANSFORM, COLOR, CUSTOM);
}
