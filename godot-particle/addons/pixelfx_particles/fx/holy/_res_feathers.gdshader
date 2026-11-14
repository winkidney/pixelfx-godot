// holy/resurrection: feathers of light as the original's feather() draws them (src/fx/holy/_lib.js), up to 32, in
// order (a later one lays over an earlier one): fa[i] = (quill x, quill y, angle, length), fb[i] = (vane width,
// alpha, hot, side). A white shaft, a lit leading rim, a warm dark trailing edge, a body cooling from cream at the
// quill to gold, a tip thinning into light. For a wing: its leading edge (arm[0..3], a white bone of light with a
// gold underside, at arm_a) and the trails its primaries' tips leave on the downstroke (3 x 10 points in tr[], at
// tr_fade). Colour layer; keyed every frame.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(96.0);
uniform vec2 center = vec2(0.0);
// the wing ramp, dark to bright: C2 C3 C4 C5 C6 white
uniform vec4 R[6] : source_color;
uniform vec4 fa[32];
uniform vec4 fb[32];
uniform int count = 0;
uniform float quill = 0.02;
uniform vec2 arm[4];
uniform float arm_a = 0.0;
uniform vec2 tr[30];
uniform float tr_fade = 0.0;

// a 1 px segment from a to b: true when this pixel's centre is on it
bool on_seg(vec2 p, vec2 a, vec2 b) {
	vec2 d = b - a;
	float L = length(d);
	if (L < 0.01) {
		return floor(p) == floor(a);
	}
	vec2 u = d / L;
	float along = dot(p - a, u);
	if (along < -0.5 || along > L + 0.5) {
		return false;
	}
	float across = abs(-(p - a).x * u.y + (p - a).y * u.x);
	return across / max(abs(u.x), abs(u.y)) < 0.5;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float th = pfx_threshold(FRAGCOORD.xy);
	vec4 c = vec4(0.0);
	for (int i = 0; i < 32; i++) {
		if (i >= count) {
			break;
		}
		vec4 A = fa[i];
		vec4 B = fb[i];
		float len = A.w;
		float wid = B.x;
		float a = B.y;
		if (len < 1.5 || a <= 0.02) {
			continue;
		}
		bool h = B.z > 0.5;
		float side = B.w;
		vec2 d = p - A.xy;
		float ca = cos(A.z);
		float sa = sin(A.z);
		float u = (d.x * ca + d.y * sa) / len;
		if (u < 0.0 || u > 1.05) {
			continue;
		}
		float v = (-d.x * sa + d.y * ca) * side;
		float av = abs(v);
		vec3 edge = h ? R[3].rgb : R[1].rgb;
		vec3 lead = h ? vec3(1.0) : R[4].rgb;
		vec3 b0 = h ? vec3(1.0) : R[4].rgb;
		vec3 b1 = h ? vec3(1.0) : R[3].rgb;
		vec3 b2 = h ? R[4].rgb : R[2].rgb;
		float w = wid * sqrt(clamp((u - quill) / 0.22, 0.0, 1.0)) * sqrt(max(0.0, 1.0 - pow(max(0.0, (u - 0.55) / 0.47), 2.0)));
		float lim = v < 0.0 ? w * 0.42 : w;
		float fade = u < 0.72 ? 1.0 : 1.0 - (u - 0.72) * 1.6;
		vec4 q = vec4(0.0);
		if (av < 0.5 && u < 0.9) {
			q = vec4(u < 0.5 ? vec3(1.0) : b0, a);
		} else if (av > lim + 0.05 || w < 0.5) {
			continue;
		} else if (lim - av < 1.0) {
			q = v > 0.0 ? vec4(u > 0.85 ? b2 : edge, a * fade) : vec4(lead, a);
		} else if (u < 0.72) {
			q = vec4(u < 0.38 ? b0 : b1, a);
		} else {
			q = vec4(b2, a * fade);
		}
		if (q.a >= 1.0 || q.a > th) {
			c = vec4(q.rgb, 1.0);
		}
	}
	// the wing's leading edge
	if (arm_a > 0.0 && arm_a > th) {
		for (int i = 0; i < 3; i++) {
			if (on_seg(p, arm[i] + vec2(0.0, 1.0), arm[i + 1] + vec2(0.0, 1.0))) {
				c = vec4(R[3].rgb, 1.0);
			}
		}
		for (int i = 0; i < 3; i++) {
			if (on_seg(p, arm[i], arm[i + 1])) {
				c = vec4(1.0);
			}
		}
	}
	// trails off the primaries' tips
	if (tr_fade > 0.0) {
		for (int s = 0; s < 3; s++) {
			for (int j = 1; j < 10; j++) {
				vec2 a0 = tr[s * 10 + j - 1];
				vec2 a1 = tr[s * 10 + j];
				if (a0.x > 900.0 || a1.x > 900.0) {
					continue;
				}
				if (tr_fade * (1.1 - float(j) / 10.0) > th && on_seg(p, a0, a1)) {
					c = vec4(j < 3 ? vec3(1.0) : j < 6 ? R[4].rgb : R[2].rgb, 1.0);
				}
			}
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
