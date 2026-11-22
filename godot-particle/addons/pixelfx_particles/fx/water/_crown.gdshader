// A stone's splash in still water (water/splash): the crown, a thin sheet from its foot to a rolled scalloped lip that
// leaps up, flares out and falls back lane by lane, fingers rising off its lip with a bead on each until they tear
// away; the cavity it punches; lacy foam after; the jet that bounces back up the middle; the flat white hit. `u` is
// the time since the hit (key it); phi, seed and the fingers' lengths are the original's. Seen at a low angle: sy.
//   mode 3: the cavity (behind)         mode 0: the far wall and its fingers (behind)
//   mode 1: the near wall's see-through sheet (soft, front)
//   mode 2: the lace, the near wall's streaks and lit edges, its lip and fingers, the jet, the hit (front)
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float u = -1.0;
uniform float now = 0.0;
uniform float sy = 0.22;
uniform float phi = 0.0;
uniform float seed = 3.0;
uniform float spike_l[12];
uniform float mode = 2.0;

const float C_TAU = 6.28318530718;
const float TEAR = 0.11;
const float JET = 0.3;

float out_cubic(float x) {
	x = clamp(x, 0.0, 1.0);
	return 1.0 - (1.0 - x) * (1.0 - x) * (1.0 - x);
}

float in_quad(float x) {
	x = clamp(x, 0.0, 1.0);
	return x * x;
}

float height(float v) {
	return 19.0 * out_cubic(v / 0.09) * (1.0 - in_quad((v - 0.12) / 0.3));
}

float foot(float v) {
	return 3.0 + 7.5 * out_cubic(v / 0.45);
}

float lip(float v) {
	return foot(v) + height(v) * 0.42 + 3.0 * out_cubic(v / 0.25);
}

float jet_h(float v) {
	return 26.0 * (out_cubic(v / 0.12) - in_quad((v - 0.15) / 0.28));
}

float scallop(float a, float h) {
	return h * (0.86 + 0.14 * js_noise(cos(a) * 2.2 + sin(a) * 1.3 + phi * 3.0, int(seed)));
}

bool same(vec2 a, vec2 p) {
	return all(equal(floor(a), floor(p)));
}

// a 1 px line from cell a to cell b, as the original rasterises it
bool on_line(vec2 a, vec2 b, vec2 p) {
	vec2 A = floor(a);
	vec2 B = floor(b);
	vec2 P = floor(p);
	vec2 d = B - A;
	float n = max(max(abs(d.x), abs(d.y)), 1.0);
	if (abs(d.x) >= abs(d.y)) {
		float i = (P.x - A.x) * (d.x < 0.0 ? -1.0 : 1.0);
		return i >= 0.0 && i <= n && P.y == A.y + floor(d.y * i / n + 0.5);
	}
	float i = (P.y - A.y) * (d.y < 0.0 ? -1.0 : 1.0);
	return i >= 0.0 && i <= n && P.x == A.x + floor(d.x * i / n + 0.5);
}

// the crown's sheet at pixel p: the highest-ranked cell the original would put there (rank -1: none)
void sheet(vec2 p, bool back, out vec4 col, out float alpha, out int rank) {
	col = vec4(0.0);
	alpha = 1.0;
	rank = -1;
	float h = height(u);
	if (u < 0.0 || h < 0.7) {
		return;
	}
	float r0 = foot(u);
	float rt = lip(u);
	bool white = u < 0.045;
	int n = int(ceil(rt * C_TAU * 1.6));
	float X = floor(p.x);
	float Y = floor(p.y);
	for (int i = 0; i < 256; i++) {
		if (i >= n) {
			break;
		}
		float a = float(i) / float(n) * C_TAU;
		float s = sin(a);
		float c = cos(a);
		if ((s < 0.0) != back) {
			continue;
		}
		// which samples up this column of the sheet could fall in this pixel's column
		float lo = 0.0;
		float hi = 1.0;
		if (abs(c) > 0.02) {
			float ra = X / c;
			float rb = (X + 1.0) / c;
			float rl = max(min(ra, rb), r0);
			float rh = min(max(ra, rb), rt);
			if (rl > rh + 0.01) {
				continue;
			}
			lo = pow(clamp((rl - r0) / max(rt - r0, 1e-3), 0.0, 1.0), 1.0 / 2.2);
			hi = pow(clamp((rh - r0) / max(rt - r0, 1e-3), 0.0, 1.0), 1.0 / 2.2);
		}
		int lane = int(floor((a + phi) * rt / 2.2));
		bool streak = js_rand2(lane, 31) < 0.3;
		float H = scallop(a, h);
		float keep = 1.0 - clamp((u - 0.13 - 0.14 * js_rand2(lane, 7)) / 0.1, 0.0, 1.0);
		float steps = ceil(H * 1.4) + 2.0;
		int k0 = max(0, int(floor(lo * steps)) - 1);
		int k1 = min(int(floor(steps * keep + 1e-4)), int(ceil(hi * steps)) + 1);
		for (int k = k0; k <= k1; k++) {
			float v = float(k) / steps;
			float r = r0 + (rt - r0) * pow(v, 2.2);
			if (!same(vec2(c * r, s * r * sy - H * v), p)) {
				continue;
			}
			vec4 cc;
			int rk;
			float al = 1.0;
			if (white) {
				cc = pal[7];
				rk = 3;
			} else if (back) {
				cc = v > 0.72 ? (streak ? pal[5] : pal[4]) : (streak ? pal[3] : pal[2]);
				rk = 1;
			} else if (abs(c) > 0.9) {
				cc = c < 0.0 ? (abs(c) > 0.97 ? pal[7] : pal[6]) : pal[4];
				rk = 2;
			} else if (v < 0.1) {
				cc = v < 0.05 ? pal[7] : pal[6];
				rk = 2;
			} else if (streak) {
				cc = c < -0.2 ? pal[6] : pal[5];
				rk = 1;
			} else {
				cc = c < 0.0 ? pal[5] : pal[4];
				rk = 0;
				al = 0.22;
			}
			if (rk > rank) {
				rank = rk;
				col = cc;
				alpha = al;
			}
		}
		// the rolled lip
		if (!white && keep >= 1.0) {
			vec2 L = vec2(c * rt, s * rt * sy - H);
			if (same(L, p) && 3 > rank) {
				rank = 3;
				col = back ? pal[5] : (c < 0.45 ? pal[7] : pal[6]);
				alpha = 1.0;
			}
			if (!back && c < 0.2 && same(L + vec2(0.0, 1.0), p) && 2 > rank) {
				rank = 2;
				col = pal[6];
				alpha = 1.0;
			}
		}
	}
}

// fingers off the lip, and the beads on their tips until they tear away
bool fingers(vec2 p, bool back, out vec4 col) {
	col = vec4(0.0);
	float h = height(u);
	float reach = 1.0 - smoothstep(TEAR, TEAR + 0.1, u);
	if (u < 0.0 || h < 0.7 || reach <= 0.0) {
		return false;
	}
	float rt = lip(u);
	bool hit = false;
	for (int k = 0; k < 12; k++) {
		float a = mod(float(k) * C_TAU / 12.0 + phi, C_TAU);
		if ((sin(a) < 0.0) != back) {
			continue;
		}
		float H = scallop(a, h);
		float L = h * spike_l[k] * reach;
		vec2 a0 = vec2(cos(a) * rt, sin(a) * rt * sy - H);
		vec2 a1 = a0 + vec2(cos(a) * L * 0.45, -L);
		if (L >= 1.0 && on_line(a0, a1, p)) {
			col = u < 0.045 ? pal[7] : back ? pal[4] : pal[6];
			hit = true;
		}
		if (u > 0.04 && u < TEAR) {
			vec2 b = a1 + vec2(back ? 0.0 : -0.5, -1.0);
			if (back) {
				if (same(b, p)) {
					col = pal[5];
					hit = true;
				}
			} else {
				vec2 B = floor(b);
				vec2 d = floor(p) - B;
				if (d.x >= 0.0 && d.x <= 1.0 && d.y >= 0.0 && d.y <= 1.0) {
					col = d.y < 0.5 ? (d.x < 0.5 ? pal[7] : pal[6]) : (d.x < 0.5 ? pal[5] : pal[4]);
					hit = true;
				}
			}
		}
	}
	return hit;
}

bool lace(vec2 p, out vec4 col) {
	col = vec4(0.0);
	if (u <= 0.2) {
		return false;
	}
	float rx = 4.0 + 11.0 * out_cubic((u - 0.2) / 0.7);
	float k = smoothstep(0.2, 0.32, u) * (1.0 - smoothstep(0.5, 2.0, u)) * 0.9;
	float ry = rx * sy + 0.5;
	if (k <= 0.01) {
		return false;
	}
	float dx = p.x / rx;
	float dy = p.y / ry;
	float d = dx * dx + dy * dy;
	if (d > 1.0) {
		return false;
	}
	float s = ry / rx;
	float uu = p.x * 0.36;
	float vv = (p.y / s) * 0.36;
	int sd = int(seed);
	float nn = js_noise2(vec2(uu + seed * 7.13, vv - now * 0.35), sd);
	float m = js_noise2(vec2(uu * 2.2 - now * 0.3, vv * 2.2 + seed * 3.1), sd + 9);
	float net = 1.0 - abs(nn) * 4.6 + m * 0.3;
	float need = 1.02 - k * (1.15 - d * 0.9);
	if (net < need) {
		return false;
	}
	col = net > need + 0.4 ? pal[7] : pal[6];
	return true;
}

bool jet(vec2 p, out vec4 col) {
	col = vec4(0.0);
	float v = u - JET;
	float h = jet_h(v);
	if (v < 0.0 || h < 0.8) {
		return false;
	}
	bool hit = false;
	float top = -h;
	// a mound of water heaves up under it
	vec2 e = p / vec2(5.0, 2.4);
	if (length(e) <= 1.0 && e.y <= 0.0) {
		col = length(e) < 0.5 ? pal[7] : e.x < 0.0 ? pal[6] : pal[5];
		hit = true;
	}
	if (p.x >= -3.0 && p.x <= 3.0 && p.y >= top - 2.0 && p.y <= 0.0) {
		float vv = clamp((p.y - top) / h, 0.0, 1.0);
		float q = p.x / (1.15 + 1.5 * vv * vv * vv);
		if (abs(q) <= 1.0) {
			col = q < -0.5 ? pal[6] : q < 0.3 ? pal[7] : q < 0.72 ? pal[5] : pal[4];
			hit = true;
		}
	}
	if (v < 0.12) {
		if (distance(p, vec2(0.0, top - 1.0)) <= 1.7) {
			col = pal[5];
			hit = true;
		}
		if (distance(p, vec2(-0.3, top - 1.3)) <= 1.1) {
			col = pal[6];
			hit = true;
		}
		if (same(vec2(-1.0, top - 2.0), p)) {
			col = pal[7];
			hit = true;
		}
	}
	return hit;
}

bool flash(vec2 p, out vec4 col) {
	col = vec4(0.0);
	if (u < 0.0 || u >= 0.07) {
		return false;
	}
	bool hit = false;
	float d = length(p / vec2(10.0, 2.4));
	if (d <= 1.0) {
		col = d < 0.6 ? pal[7] : pal[6];
		hit = true;
	}
	// a sparkle: a cross of arms, the tips lighter, a white heart
	float n = floor(5.0 * (1.0 - u / 0.07) + 0.5);
	vec2 q = floor(p) - vec2(0.0, -3.0);
	if (n >= 1.0) {
		float m = max(abs(q.x), abs(q.y));
		if ((q.x == 0.0 || q.y == 0.0) && m >= 1.0 && m <= n) {
			col = m > n * 0.6 ? pal[5] : pal[6];
			hit = true;
		}
		if (n >= 3.0 && abs(q.x) == 1.0 && abs(q.y) == 1.0) {
			col = pal[6];
			hit = true;
		}
		if (q.x == 0.0 && q.y == 0.0) {
			col = pal[7];
			hit = true;
		}
	}
	return hit;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec4 c = vec4(0.0);
	vec4 cc;
	float al;
	int rank;
	if (mode > 2.5) {
		if (u > 0.0 && u < 0.26) {
			float r = foot(u) * 0.85 * (1.0 - smoothstep(0.12, 0.26, u));
			vec2 e = p / vec2(r, r * sy + 0.6);
			if (r > 0.0 && length(e) <= 1.0) {
				c = e.y < 0.0 ? pal[1] : pal[2];
			}
		}
	} else if (mode < 0.5) {
		sheet(p, true, cc, al, rank);
		if (rank >= 0) {
			c = cc;
		}
		if (fingers(p, true, cc)) {
			c = cc;
		}
	} else if (mode < 1.5) {
		sheet(p, false, cc, al, rank);
		if (rank == 0) {
			c = vec4(cc.rgb, al);
		}
	} else {
		if (lace(p, cc)) {
			c = cc;
		}
		sheet(p, false, cc, al, rank);
		if (rank > 0) {
			c = cc;
		}
		if (fingers(p, false, cc)) {
			c = cc;
		}
		if (jet(p, cc)) {
			c = cc;
		}
		if (flash(p, cc)) {
			c = cc;
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
