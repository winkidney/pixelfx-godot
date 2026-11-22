// A geyser (see _geyser.gdshaderinc).
//   mode 0: the pool's water (soft, behind)    mode 3: its lit far rim (soft, behind)
//   mode 1: behind: the far half of the blast ring, the umbrella of streaks off the head, the head's far billows
//   mode 2: in front: the near half of the blast ring, the lace round the foot, the heaving mound, the spurts, the
//           column, the billows boiling at its foot, the head's near billows, the white burst of the blast
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_ringfn.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_geyser.gdshaderinc"

uniform float mode = 2.0;

bool cell(vec2 a, vec2 p) {
	return all(equal(floor(a), floor(p)));
}

bool disc(vec2 p, vec2 c, float r) {
	return r < 0.6 ? cell(c, p) : distance(p, c) <= r;
}

bool seg(vec2 a, vec2 b, vec2 p) {
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

// a billow of churning foam: a shadowed underside, a body, a lit cap (the original's billow())
bool billow(vec2 p, vec2 c, float r, vec4 under, vec4 body, out vec4 col) {
	col = vec4(0.0);
	if (r < 0.9) {
		if (cell(c, p)) {
			col = body;
			return true;
		}
		return false;
	}
	bool hit = false;
	if (disc(p, c + vec2(r * 0.12, r * 0.2), r)) {
		col = under;
		hit = true;
	}
	if (disc(p, c, r * 0.84)) {
		col = body;
		hit = true;
	}
	if (r > 1.6 && disc(p, c - vec2(r * 0.3, r * 0.32), r * 0.46)) {
		col = pal[7];
		hit = true;
	}
	return hit;
}

bool blast_ring(vec2 p, float side, out vec4 col) {
	col = vec4(0.0);
	float u = (now - ERUPT) / 0.4;
	if (u <= 0.0 || u >= 1.0) {
		return false;
	}
	float lit;
	int crest;
	return ring_hit(p - vec2(0.0, 0.5), 6.0 + 42.0 * g_out_cubic(u), sy, 1.5 * (1.0 - u), 3.0, 1.6 + 2.0 * u, side, u < 0.3, 0.0, 9.0, 0.0, col, lit, crest);
}

// the head's billows, churning round its top (back: the far ones, in a darker ramp)
bool head(vec2 p, bool back, out vec4 col) {
	col = vec4(0.0);
	float t = now;
	float H = top_h(t);
	float k = head_k(t);
	if (k <= 0.01 || H < 4.0) {
		return false;
	}
	int S = int(seed);
	bool hit = false;
	if (back) {
		// the umbrella: streaks pouring off the rim of the head, running down and thinning out
		for (int i = 0; i < 16; i++) {
			float side = i % 2 == 1 ? 1.0 : -1.0;
			float x0 = side * (5.0 + 9.0 * js_rand2(i, S + 20)) * k;
			float len = (14.0 + 26.0 * js_rand2(i, S + 21)) * k;
			float speed = 70.0 + 50.0 * js_rand2(i, S + 22);
			for (int j = 0; j < 3; j++) {
				float f = fract(t * speed / len + float(j) / 3.0 + js_rand2(i, S + 23));
				if (f >= 0.85) {
					continue;
				}
				float y0 = -H + 2.0 + f * len;
				float x = x0 + side * f * f * 6.0;
				float L = 1.0 + 4.0 * f * (1.0 - f) * 2.0;
				if (seg(vec2(x, y0), vec2(x + side * 0.6, y0 + L), p)) {
					col = f < 0.4 ? pal[6] : f < 0.7 ? pal[5] : pal[4];
					hit = true;
				}
			}
		}
	}
	for (int i = 0; i < 12; i++) {
		float a = float(i) / 12.0 * G_TAU + t * (i % 2 == 1 ? 1.3 : -1.1);
		float z = sin(a);
		if ((z < 0.0) != back) {
			continue;
		}
		float rho = (3.0 + 7.0 * js_rand2(i, S)) * k;
		float x = cos(a) * rho * 1.25 + js_noise(t * 3.0 + float(i), S + 8) * 2.5;
		float y = -H + z * rho * 0.45 + (rho / 10.0) * 4.0 - 4.0 * (1.0 - rho / (10.0 * k)) + js_noise(t * 3.0 + float(i) + 50.0, S + 9) * 2.5;
		float r = (2.0 + 2.6 * js_rand2(i, S + 2) + 0.7 * sin(t * 7.0 + float(i))) * k;
		vec4 cc;
		if (back) {
			if (billow(p, vec2(x, y), r, pal[3], pal[5], cc)) {
				col = cc;
				hit = true;
			}
		} else {
			if (disc(p, vec2(x + r * 0.15, y + r * 0.25), r)) {
				col = pal[4];
				hit = true;
			}
			if (disc(p, vec2(x, y), r * 0.82)) {
				col = rho > 6.0 * k ? pal[5] : pal[6];
				hit = true;
			}
			if (disc(p, vec2(x - r * 0.25, y - r * 0.3), r * 0.5)) {
				col = pal[7];
				hit = true;
			}
		}
	}
	return hit;
}

bool lace(vec2 p, out vec4 col) {
	col = vec4(0.0);
	float t = now;
	float fk = smoothstep(ERUPT, ERUPT + 0.3, t) * (1.0 - smoothstep(GONE - 0.3, 4.4, t));
	if (fk <= 0.01) {
		return false;
	}
	float rx = 8.0 + 10.0 * fk;
	float ry = rx * sy + 0.5;
	float dx = p.x / rx;
	float dy = p.y / ry;
	float d = dx * dx + dy * dy;
	if (d > 1.0) {
		return false;
	}
	float s = ry / rx;
	float uu = p.x * 0.36;
	float vv = (p.y / s) * 0.36;
	int S = int(seed);
	float nn = js_noise2(vec2(uu + seed * 7.13, vv - t * 0.35), S);
	float m = js_noise2(vec2(uu * 2.2 - t * 0.3, vv * 2.2 + seed * 3.1), S + 9);
	float net = 1.0 - abs(nn) * 4.6 + m * 0.3;
	float need = 1.02 - fk * (1.15 - d * 0.9);
	if (net < need) {
		return false;
	}
	col = net > need + 0.4 ? pal[7] : pal[6];
	return true;
}

bool column(vec2 p, out vec4 col) {
	col = vec4(0.0);
	float t = now;
	float H = top_h(t);
	float th = thin_k(t);
	if (H < 1.0 || p.y > 0.0 || p.y < -H - 2.0 || abs(p.x) > 22.0) {
		return false;
	}
	int S = int(seed);
	float V0 = sqrt(2.0 * GG * hmax);
	float h = -p.y;
	float v = h / H;
	float sway = js_noise(t * 1.6 + h * 0.025, S + 5) * 2.5 * v;
	float rag = js_noise2(vec2(h * 0.2 - t * 11.0, p.x < sway ? 3.0 : 7.0), S + 6) * (0.5 + 1.8 * v);
	float w = (3.6 + 7.5 * pow(v, 1.8)) * th + rag;
	float q = (p.x - sway) / max(1.0, w);
	float aq = abs(q);
	if (aq > 1.0) {
		return false;
	}
	float tau = (V0 - sqrt(max(0.0, V0 * V0 - 2.0 * GG * min(h, hmax * 0.96)))) / GG;
	float X = floor(p.x);
	float streak = js_noise2(vec2(X * 1.618 + 0.3, (tau - t) * 14.0), S);
	float body = js_noise2(vec2(floor((p.x + 40.0) / 2.0) * 2.3, (tau - t) * 5.0), S + 1);
	int lvl = aq < 0.42 ? 0 : aq < 0.7 ? 1 : aq < 0.9 ? 2 : 3;
	if (q > 0.38) {
		lvl++;
	}
	if (streak > 0.28) {
		lvl--;
	}
	if (body < -0.4) {
		lvl++;
	}
	lvl = clamp(lvl, 0, 4);
	col = lvl == 0 ? pal[7] : lvl == 1 ? pal[6] : lvl == 2 ? pal[5] : lvl == 3 ? pal[4] : pal[3];
	return true;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float t = now;
	vec4 c = vec4(0.0);
	vec4 cc;
	if (mode < 0.5 || mode > 2.5) {
		float pr = pool_r(t);
		float pk = pool_k(t);
		if (pk <= 0.0) {
			discard;
		}
		vec2 e = p / vec2(pr, pr * sy);
		float d = dot(e, e);
		if (d > 1.0) {
			discard;
		}
		if (mode < 0.5) {
			c = vec4((d < 0.15 ? pal[2] : pal[1]).rgb, 0.6 * pk * min(1.0, (1.0 - d) * 4.0));
		} else if (p.y < 0.0 && d > 0.78 && d < 0.95) {
			c = vec4(pal[4].rgb, 0.7 * pk);
		}
	} else if (mode < 1.5) {
		if (blast_ring(p, -1.0, cc)) {
			c = cc;
		}
		if (head(p, true, cc)) {
			c = cc;
		}
	} else {
		if (blast_ring(p, 1.0, cc)) {
			c = cc;
		}
		if (lace(p, cc)) {
			c = cc;
		}
		float k = clamp(t / ERUPT, 0.0, 1.0);
		float H = top_h(t);
		float hk = head_k(t);
		float th = thin_k(t);
		// the heaving mound while it builds, beating faster
		if (t < ERUPT + 0.05) {
			float beat = pow(max(0.0, sin(t * (8.0 + 18.0 * k * k))), 3.0);
			float rd = 4.0 + 3.5 * k + 1.5 * beat;
			float hd = 1.5 + 3.0 * k + 3.0 * beat;
			float dx = p.x / rd;
			float dy = p.y / hd;
			float d = dx * dx + dy * dy;
			if (d <= 1.0 && p.y <= 0.5) {
				float lit = -dx * 0.7 - dy * 0.7;
				c = d > 0.68 ? (lit > 0.3 ? pal[7] : lit > -0.15 ? pal[6] : pal[4]) : lit > 0.55 ? pal[6] : lit > 0.12 ? pal[5] : lit > -0.3 ? pal[4] : pal[3];
			}
			if (cell(vec2(-rd * 0.35, -hd * 0.6), p)) {
				c = pal[7];
			}
		}
		// spurts while it builds and sputters as it dies
		float sp = spurt_h(t);
		if (sp > 1.0 && H < 1.0) {
			if (p.x >= -2.0 && p.x <= 2.0 && p.y >= -sp - 1.0 && p.y <= 0.0) {
				float q = p.x / (1.0 + 0.8 * (1.0 + p.y / sp));
				if (abs(q) <= 1.0) {
					c = q < -0.3 ? pal[6] : q < 0.35 ? pal[7] : pal[5];
				}
			}
			if (disc(p, vec2(0.0, -sp), 1.3)) {
				c = pal[6];
			}
			if (cell(vec2(0.0, -sp - 1.0), p)) {
				c = pal[7];
			}
		}
		if (column(p, cc)) {
			c = cc;
		}
		// the foot: billows boil out round it
		if (hk > 0.0 || (H > 1.0 && t < GONE)) {
			for (int i = 0; i < 7; i++) {
				float a = float(i) / 7.0 * G_TAU + t * 2.1;
				float r = 4.0 + 2.0 * sin(t * 5.0 + float(i) * 1.7);
				vec2 b = vec2(cos(a) * r * 1.3, sin(a) * r * sy - 2.0);
				if (billow(p, b, (1.6 + 1.2 * js_rand2(i, int(seed) + 4)) * max(hk, th * 0.6), pal[4], pal[6], cc)) {
					c = cc;
				}
			}
		}
		if (head(p, false, cc)) {
			c = cc;
		}
		// the blast's first two frames: a white burst at the vent
		float f = (t - ERUPT) / 0.07;
		if (f >= 0.0 && f < 1.0) {
			if (distance(p, vec2(0.0, -4.0)) <= 7.0 * (1.0 - f * 0.4)) {
				c = pal[7];
			}
			float d = length(p / vec2(12.0, 2.6));
			if (d <= 1.0) {
				c = d < 0.6 ? pal[7] : pal[6];
			}
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
