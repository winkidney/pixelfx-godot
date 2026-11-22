// The EMP blast (src/fx/scifi/emp-blast.js), from the frame's state (`data`, one column a frame, worked out by
// replaying the original's update() at its 120 Hz steps with its own generator: the clock, the bubble's radius,
// whether it cuts out, its torn rows, junk blocks) and the frame's arcs (`arcs`: the original's bolt paths, stroked
// as _lib.js strokeArc: a dark halo, a bright body, a white core while fresh):
//   mode 0: the bubble's far rim on the floor
//   mode 1: the charge (a mote swelling, ticking, crackling); the bubble: thin glass brighter toward its rim,
//           interference lines rolling down it, torn rows burning bright and slipping sideways with a pink split
//           edge, junk blocks; the pop's white disc, the ring racing out, the star; the arcs
// Colour layer (the glass translucent).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_scifi.gdshaderinc"

uniform vec2 size = vec2(152.0, 116.0);
uniform vec2 center = vec2(0.0);
uniform float frame = 0.0;
uniform int mode = 0;
uniform sampler2D data : filter_nearest, repeat_disable;
uniform sampler2D arcs : filter_nearest, repeat_disable;
uniform int arc_width = 320;
uniform vec4 pal[8] : source_color;
uniform vec4 fringe : source_color = vec4(1.0, 0.35, 0.85, 1.0);
uniform float rm = 56.0;

const float POP = 0.42;

vec4 F(int row) {
	return texelFetch(data, ivec2(clamp(int(frame + 0.5), 0, textureSize(data, 0).x - 1), row), 0);
}

int shift_at(int y) {
	int s = 0;
	for (int i = 0; i < 3; i++) {
		vec4 q = F(1 + i);
		if (int(q.x) == y) {
			s = int(q.y);
		}
		if (int(q.z) == y) {
			s = int(q.w);
		}
	}
	return s;
}

// the bubble at cell P: colour and alpha (alpha < 1: translucent), near or far side
vec4 bubble(ivec2 P, bool near) {
	vec4 m = F(0);
	float t = m.x;
	float r = m.y;
	if (r <= 1.0 || m.z > 0.5) {
		return vec4(0.0);
	}
	float ry = r * 0.16;
	float age = t - POP;
	float roll = age * 40.0;
	int y = P.y;
	int x = P.x;
	if (float(y) < floor(-r) || float(y) > ceil(ry) || float(x) < floor(-r) || float(x) > ceil(r)) {
		return vec4(0.0);
	}
	int shift = shift_at(y);
	float sx = float(x - shift);
	float fy = float(y);
	float d = length(vec2(sx + 0.5, y < 0 ? fy + 0.5 : 0.0)) / r;
	vec4 c = vec4(0.0);
	if (d > 1.0) {
		if (near && y < 0 && d < 1.0 + 1.4 / r && ((x + y) & 1) == 0) {
			c = fringe;
		}
	} else if (y >= 0) {
		float e = length(vec2((sx + 0.5) / r, (fy + 0.5) / ry));
		if (!(e > 1.0 || e < 0.92 || (y > 0) != near)) {
			c = e > 0.97 ? pal[6] : pal[4];
		}
	} else if (near) {
		float rim = pow(d, 6.0);
		bool line = mod(fy - roll, 4.0) < 1.0;
		bool band = mod(fy - roll * 0.5, 22.0) < 4.0;
		if (d > 0.965) {
			c = shift != 0 ? vec4(1.0) : -fy > r * 0.55 && sx < 0.0 ? vec4(1.0) : pal[6];
		} else if (d > 0.93) {
			c = pal[4];
		} else if (shift != 0) {
			c = abs(sx) > r * 0.8 ? fringe : (x & 1) == 1 ? pal[6] : pal[5];
		} else {
			vec3 bc = line && band ? pal[6].rgb : line ? pal[5].rgb : band ? pal[4].rgb : pal[3].rgb;
			c = vec4(bc, 0.06 + 0.42 * rim + (line ? 0.14 + 0.24 * rim : 0.0) + (band ? 0.16 : 0.0));
		}
	}
	if (near) {
		// junk blocks flicker on inside it
		for (int i = 0; i < 3; i++) {
			vec4 j = F(4 + i);
			vec4 jc = F(7 + i);
			if (jc.y > 0.5 && x >= int(j.x) && y >= int(j.y) && x < int(j.x) + int(j.z) && y < int(j.y) + int(j.w)) {
				c = jc.x > 0.5 ? vec4(1.0) : pal[5];
			}
		}
	}
	return c;
}

// the frame's arc strokes over cell P (halo, body, white core; the later strokes over the earlier)
void strokes(inout vec4 c, vec2 pc, int set0, int set1) {
	int f = clamp(int(frame + 0.5), 0, textureSize(arcs, 0).y - 1);
	int cur = -1;
	float dmin = 1e9;
	float cheb = 1e9;
	float k = 0.0;
	float w = 1.0;
	int set = 0;
	for (int j = 0; j < 512; j++) {
		if (j >= arc_width) {
			break;
		}
		vec4 q = texelFetch(arcs, ivec2(j, f), 0);
		bool last = q.z < -0.5;
		int sid = int(q.z + 0.5);
		if (last || (cur >= 0 && sid != cur)) {
			if (cur >= 0 && set >= set0 && set <= set1) {
				float rh = (k > 0.6 ? 1.6 : 1.1) * w;
				float rb = (k > 0.6 ? 0.9 : 0.6) * w;
				vec4 halo = set == 1 ? pal[3] : pal[2];
				vec4 body = set == 1 ? pal[6] : pal[5];
				if (cheb <= 0.45 && k > 0.3) {
					c = vec4(1.0);
				} else if ((rb < 0.6 && cheb <= 0.45) || dmin <= rb) {
					c = body;
				} else if ((rh < 0.6 && cheb <= 0.45) || dmin <= rh) {
					c = halo;
				}
			}
			dmin = 1e9;
			cheb = 1e9;
			if (last) {
				break;
			}
		}
		if (sid == cur) {
			vec2 a = texelFetch(arcs, ivec2(j - 1, f), 0).xy;
			vec2 e = q.xy - a;
			float u = clamp(dot(pc - a, e) / max(dot(e, e), 1e-9), 0.0, 1.0);
			vec2 foot = a + e * u;
			dmin = min(dmin, length(foot - pc));
			vec2 fd = abs(foot - pc);
			cheb = min(cheb, max(fd.x, fd.y));
		}
		cur = sid;
		set = sid / 1000;
		k = q.w;
		w = set == 0 ? 0.5 : set == 1 ? 1.3 : 0.8;
	}
}

// sim.js band() round the floor at radius rr, thickness th, alpha k (all the way round)
void ring_band(inout vec4 c, ivec2 P, float rr, float th, float k, bool hot, float thr) {
	float sy = 0.16;
	if (abs(float(P.y)) > rr * sy + 2.0 || abs(float(P.x)) > rr + 2.0) {
		return;
	}
	int m = int(ceil(rr * TAU * 1.2));
	vec2 pc = vec2(P) + 0.5;
	float ang = atan(pc.y / sy, pc.x);
	if (ang < 0.0) {
		ang += TAU;
	}
	int j0 = int(floor(ang / TAU * float(m)));
	for (int dj = -4; dj <= 4; dj++) {
		int j = j0 + dj;
		int jj = imod(j, m);
		float a = float(jj) / float(m) * TAU;
		for (float o = th; o >= -1e-4; o -= 0.5) {
			float u = o / th;
			vec2 p = vec2(cos(a) * (rr - o), sin(a) * (rr - o) * sy);
			if (all(equal(floor(p), vec2(P)))) {
				float al = k * (u < 0.4 ? 1.2 : 1.15 - u);
				if (al >= thr && al > 0.0) {
					c = u < 0.15 ? (hot ? vec4(1.0) : vec4(1.0)) : u < 0.4 ? pal[6] : u < 0.7 ? pal[5] : pal[3];
				}
			}
		}
	}
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size + 0.001);
	ivec2 P = ivec2(cell);
	vec2 pc = cell + 0.5;
	float thr = pfx_threshold(FRAGCOORD.xy);
	vec4 m = F(0);
	float t = m.x;
	vec4 c = vec4(0.0);
	if (mode == 0) {
		c = bubble(P, false);
	} else {
		// the charge: a mote of light just off the floor, swelling, blinking faster
		if (t < POP) {
			float k = t / POP;
			float r = 1.0 + 3.2 * k * k;
			bool tick = sin(TAU * (2.0 * t + 10.0 * t * t)) > 0.0;
			float d = length(pc - vec2(0.0, -7.0));
			if (d <= r + 1.0) {
				c = pal[4];
			}
			if (r < 0.6 ? all(equal(cell, vec2(0.0, -7.0))) : d <= r) {
				c = tick ? vec4(1.0) : pal[6];
			}
			strokes(c, pc, 0, 0);
		}
		vec4 b = bubble(P, true);
		if (b.a > 0.0) {
			c = b.a >= 0.999 ? b : blend_over(c, b.rgb, b.a);
		}
		float a = t - POP;
		if (a >= 0.0 && a < 0.06) {
			float d = length(pc - vec2(0.0, -7.0));
			if (d <= 12.0 * (1.0 - a / 0.06) + 3.0) {
				c = pal[6];
			}
			if (d <= 9.0 * (1.0 - a / 0.06) + 1.0) {
				c = vec4(1.0);
			}
		}
		if (a >= 0.0 && a < 0.4) {
			float k = a / 0.4;
			ring_band(c, P, 6.0 + (rm + 14.0) * e_out_cubic(k), max(1.0, 3.0 * (1.0 - k)), 1.2 - k, k < 0.3, thr);
		}
		if (a >= 0.0 && a < 0.16) {
			int n = int(floor(10.0 * (1.0 - a / 0.16) + 0.5));
			ivec2 dd = P - ivec2(0, -7);
			int ax = abs(dd.x);
			int ay = abs(dd.y);
			if (n >= 1) {
				if (dd == ivec2(0)) {
					c = vec4(1.0);
				} else if ((dd.x == 0 && ay <= n) || (dd.y == 0 && ax <= n)) {
					c = float(max(ax, ay)) > float(n) * 0.6 ? pal[5] : pal[6];
				} else if (n >= 3 && ax == 1 && ay == 1) {
					c = pal[6];
				} else if (n >= 6 && ax == 2 && ay == 2) {
					c = pal[5];
				}
			}
		}
		strokes(c, pc, 1, 2);
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (px_out(c, FRAGCOORD.xy, c.a < 0.999)) {
		discard;
	}
	COLOR = c;
}
