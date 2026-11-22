// Root snare's roots, as the original draws them: each root runs from the floor outside the feet, spiralling in round
// the legs and climbing as it thins to its tip (48 segments), revealed as it grows (g0..g4: 0..1 of its length) and
// pulled in by `squeeze` as it cinches. Each segment is a stroke of bark, lit on its upper side, dark beneath, with
// a ridge of grain and rootlet hairs; side 1 draws the segments on the near side (in front of the character), -1
// the far ones (behind, a step darker). white 1: the near segments' midline flashes white (just before they break).
// Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

const int NR = 5;
const int NP = 48;
const float SY = 0.34;
uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float side = 1.0;
uniform float squeeze = 0.0;
uniform float white = 0.0;
// -1: every root; 0..4: only that one (so what's drawn after a root, its buds, can go between it and the next)
uniform float only = -1.0;
// 1: draw only the white flash (a pass over every root, after them all)
uniform float white_only = 0.0;
uniform float g0 = 0.0;
uniform float g1 = 0.0;
uniform float g2 = 0.0;
uniform float g3 = 0.0;
uniform float g4 = 0.0;
// per root: (th0, dir, turns, r0), (leg, h, 0, 0)
uniform vec4 root_a[NR];
uniform vec4 root_b[NR];
// the bark ramp (8), dark to bright
uniform sampler2D pal : filter_nearest;
// rand(k, 3) for k = 0..40 (the original's grain along a root)
uniform sampler2D grain : filter_nearest;

float out_cubic(float x) {
	x = clamp(x, 0.0, 1.0);
	return 1.0 - (1.0 - x) * (1.0 - x) * (1.0 - x);
}

vec3 pt(vec4 a, vec4 b, float s, float cinch) {
	float th = a.x + a.y * TAU * a.z * s;
	float r = mix(a.w, b.x - cinch * 1.6, out_cubic(min(1.0, s * 3.5)));
	return vec3(cos(th) * r, -b.y * pow(s, 1.05) + sin(th) * r * SY, sin(th));
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 cell = floor(p);
	if (cell.y > 1.0 || (cell.y > 0.0 && white_only < 0.5)) {
		discard;
	}
	int ci = -1;
	bool wh = false;
	bool back = side < 0.0;
	int dim = back ? 1 : 0;
	for (int j = 0; j < NR; j++) {
		float g = j == 0 ? g0 : j == 1 ? g1 : j == 2 ? g2 : j == 3 ? g3 : g4;
		int n = int(floor(float(NP) * g));
		if (only >= 0.0 && abs(float(j) - only) > 0.5) {
			continue;
		}
		vec4 ra = root_a[j];
		vec4 rb = root_b[j];
		if (n <= 0) {
			continue;
		}
		if (white_only > 0.5) {
			n = 0;
		}
		vec3 A = pt(ra, rb, 0.0, squeeze);
		for (int i = 0; i < NP; i++) {
			if (i >= n) {
				break;
			}
			float s = float(i) / float(NP);
			vec3 B = pt(ra, rb, float(i + 1) / float(NP), squeeze);
			bool front = (A.z + B.z) / 2.0 >= 0.0;
			if (front != back) {
				vec2 dd = B.xy - A.xy;
				float L = max(length(dd), 1e-4);
				vec2 nn = vec2(-dd.y / L, dd.x / L);
				float up = nn.x * -0.6 + nn.y * -0.8 > 0.0 ? 1.0 : -1.0;
				float w = (1.4 + 3.6 * pow(1.0 - s, 0.8)) / 2.0 + 0.35;
				vec2 q = cell + 0.5 - A.xy;
				float u = dot(q, dd) / (L * L);
				if (u >= -0.2 && u <= 1.2 && cell.x >= floor(min(A.x, B.x) - w - 1.0) && cell.x <= ceil(max(A.x, B.x) + w + 1.0)
						&& cell.y >= floor(min(A.y, B.y) - w - 1.0) && cell.y <= ceil(max(A.y, B.y) + w + 1.0)) {
					float d = dot(q, nn);
					if (abs(d) <= w) {
						float sd = sign(d) * up;
						float qq = abs(d) / w;
						int k = qq > 0.72 ? (sd > 0.0 ? 7 : 1) : sd > 0.0 ? (qq > 0.3 ? 6 : 5) : (qq > 0.35 ? 2 : 3);
						if (qq < 0.25 && texelFetch(grain, ivec2(int(floor(s * 40.0 + 0.5)), 0), 0).r < 0.4) {
							k = 4;
						}
						ci = max(1, k - dim);
					}
				}
				// rootlet hairs off its underside now and then
				if (i % 7 == 3 && w > 1.2 && floor(A.xy - nn * up * (w + 1.0)) == cell) {
					ci = 2 - dim;
				}
			}
			A = B;
		}
		if (white > 0.5 && !back) {
			for (int i = 0; i <= NP; i++) {
				vec3 W = pt(ra, rb, float(i) / float(NP), 1.0);
				if (W.z >= 0.0 && floor(W.xy) == cell) {
					wh = true;
				}
			}
		}
	}
	if (wh) {
		ci = 8;
	}
	if (ci < 0) {
		discard;
	}
	vec4 c = ci >= 8 ? vec4(1.0) : vec4(texelFetch(pal, ivec2(ci, 0), 0).rgb, 1.0);
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
