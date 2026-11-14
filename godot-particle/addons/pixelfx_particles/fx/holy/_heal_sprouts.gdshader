// Plus signs sprouting where the healing ring passes (holy/heal-aoe, colour layer): each pops as a sparkle, swells
// into a bevelled plus (glinting on the near side), floats up swaying with a thread of light still tying it to the
// floor, then bursts into four flying dots. side 1: the sites on the far half (behind, dimmer, a size smaller), -1
// the near half. `time` is the effect's clock in seconds.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(220.0, 96.0);
uniform vec2 center = vec2(0.0);
uniform float time = 0.0;
uniform float side = 1.0;
uniform vec4 pal[8] : source_color;
// x, z (on the floor), t0, rise
uniform vec4 sa[26];
// life, sway, L, thick
uniform vec4 sb[26];

const float SY = 0.2;

float out_cubic(float x) {
	return 1.0 - pow(1.0 - clamp(x, 0.0, 1.0), 3.0);
}

float out_back(float x, float s) {
	if (x <= 0.0) {
		return 0.0;
	}
	if (x >= 1.0) {
		return 1.0;
	}
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0);
}

bool ins(int i, int j, int L, int w) {
	return (abs(i) <= w && abs(j) <= L) || (abs(j) <= w && abs(i) <= L);
}

// R(i) of the plus's ramp: all eight on the near side, the first seven (no white) on the far
vec4 R(int i, bool back) {
	return pal[clamp(i, 0, 7)];
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 cell = floor(p);
	float t = time;
	bool back = side > 0.0;
	float thr = pfx_threshold(FRAGCOORD.xy);
	vec4 c = vec4(0.0);
	int n = back ? 7 : 8;
	for (int s = 0; s < 26; s++) {
		float a = t - sa[s].z;
		float life = sb[s].x;
		if (a < 0.0 || a > life || (sa[s].y < 0.0) != back) {
			continue;
		}
		float u = a / life;
		float h = sa[s].w * out_cubic(u);
		float x = sa[s].x + sin(a * 4.0 + sb[s].y) * 1.5 * u;
		float y = sa[s].y * SY - 2.0 - h;
		float pop = out_back(clamp(a / 0.12, 0.0, 1.0), 2.6);
		float end = life - 0.15;
		int L = max(1, int(round(sb[s].z * pop - (back ? 1.0 : 0.0))));
		if (a < 0.04) {
			// the sparkle it pops out of: arms 3, white, c6 tips
			ivec2 o = ivec2(cell - floor(vec2(x, y)));
			int ax = abs(o.x);
			int ay = abs(o.y);
			if (o == ivec2(0)) {
				c = vec4(1.0);
			} else if ((o.x == 0 && ay <= 3) || (o.y == 0 && ax <= 3)) {
				c = float(max(ax, ay)) > 1.8 ? vec4(pal[6].rgb, 1.0) : vec4(1.0);
			} else if (ax == 1 && ay == 1) {
				c = vec4(1.0);
			}
		} else if (a < end) {
			int th = (back && L < 3) ? 1 : int(sb[s].w);
			int w = th > 1 ? 1 : 0;
			float al = back ? 0.8 : 1.0;
			bool glint = !back && sin(a * 12.0 + sb[s].y * 3.0) > 0.8;
			ivec2 o = ivec2(cell - floor(vec2(x, y) + 0.5));
			int i = o.x;
			int j = o.y;
			if (abs(i) <= L + 1 && abs(j) <= L + 1) {
				if (!ins(i, j, L, w)) {
					if (w > 0 && (ins(i - 1, j, L, w) || ins(i + 1, j, L, w) || ins(i, j - 1, L, w) || ins(i, j + 1, L, w)) && al * 0.9 > thr) {
						c = vec4(R(max(0, n - 6), back).rgb, 1.0);
					}
				} else if (al > thr) {
					vec4 cc;
					if (w == 0) {
						cc = (i == 0 && j == 0) ? vec4(1.0) : (abs(i) + abs(j) >= L ? R(n - 3, back) : R(n - 2, back));
					} else if (i == 0 && j == 0) {
						cc = vec4(1.0);
					} else if (i == 0 || j == 0) {
						cc = abs(i) + abs(j) < L ? R(n - 2, back) : R(n - 3, back);
					} else {
						cc = (i < 0 || j < 0) ? R(n - 3, back) : R(n - 5, back);
					}
					if (glint && ((i == 0 && j == -L) || (i == -L && j == 0))) {
						cc = vec4(1.0);
					}
					c = vec4(cc.rgb, 1.0);
				}
			}
		} else {
			// the burst: four dots flying out diagonally
			float v = (a - end) / 0.15;
			for (int q = 0; q < 4; q++) {
				vec2 d = vec2(q % 2 == 0 ? 1.0 : -1.0, q < 2 ? 1.0 : -1.0);
				vec2 at = vec2(x, y) + d * (2.0 + v * 5.0) - vec2(0.0, v * 2.0);
				if (cell == floor(at) && 1.0 - v > thr) {
					c = v < 0.4 ? vec4(1.0) : vec4(pal[6].rgb, 1.0);
				}
			}
		}
		// a thread of light still ties it to the floor while it rises
		if (u < 0.5 && cell.x == floor(sa[s].x)) {
			float base = sa[s].y * SY - 2.0 - h + 3.0;
			float top = h * (1.0 - u * 2.0);
			for (float jj = 1.0; jj < 40.0; jj += 1.5) {
				if (jj >= top) {
					break;
				}
				if (cell.y == floor(base + jj) && (1.0 - jj / h) * (1.0 - u * 2.0) * (back ? 0.5 : 0.8) > thr) {
					c = vec4(pal[5].rgb, 1.0);
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
