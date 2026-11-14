// A wave rolling in and crashing (see _wave.gdshaderinc), on the original's own noise.
//   mode 0: the sea's lit surface line, glints sliding along it (behind)
//   mode 3: the dark water under it (soft, behind)
//   mode 1: the swell's body column by column (deep blue down its back with wind lines, white water at the crest, a
//           lit window high on its face, foam streaks up it), the lip thrown off it (white along its outer edge, dark
//           underneath) and the glint at its tip, the lace left behind the surge, the white burst of the crash
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_wave.gdshaderinc"

uniform float mode = 1.0;

bool cell(vec2 a, vec2 p) {
	return all(equal(floor(a), floor(p)));
}

vec4 body(vec2 p, float t) {
	float X = floor(p.x);
	float x = X + 0.5;
	float h = swell(x, t);
	float edge = 1.0 - smoothstep(EDGE - 24.0, EDGE, abs(x));
	float Y = floor(p.y);
	if (h < 0.6 || edge <= 0.0 || Y >= 0.0 || Y < floor(-h)) {
		return vec4(0.0);
	}
	int S = int(seed);
	float xc = crest_x(t);
	float A = crest_h(t);
	bool face = x > xc;
	float near = exp(-((x - xc) / 9.0) * ((x - xc) / 9.0));
	float y = Y + 0.5;
	float u = (y + h) / h;
	float depth = y + h;
	vec4 c;
	if (depth < 1.0) {
		c = (near > 0.5 && A > 14.0 && js_noise(x * 0.6 + t * 9.0, S) > -0.35) ? pal[7] : face ? pal[5] : pal[6];
	} else if (depth < 2.4 && near > 0.35 && A > 14.0) {
		c = js_noise2(vec2(x * 0.5, y * 0.5 + t * 6.0), S + 1) > -0.1 ? pal[7] : pal[6];
	} else {
		float win = near * (1.0 - u) * 1.6;
		float up = js_noise2(vec2((x * 0.9 - y * 0.35) * 0.8, y * 0.12 + t * 5.0), S + 2);
		float wind = js_noise2(vec2(x * 0.18 - t * 2.0, y * 0.9), S + 3);
		float fi = (up > 0.55 && u < 0.85) ? 6.0 : win > 0.8 ? 5.0 : (win > 0.45 || up > 0.3) ? 4.0 : (win > 0.2 || up > 0.05) ? 3.0 : u < 0.6 ? 2.0 : 1.0;
		float bi = u < 0.14 ? 4.0 : wind > 0.55 ? 4.0 : (wind > 0.25 || u < 0.32) ? 3.0 : u < 0.7 ? 2.0 : 1.0;
		c = pal[int(floor(bi + (fi - bi) * smoothstep(xc - 5.0, xc + 5.0, x) + 0.5))];
	}
	c.a = fade_k(t) * edge * 1.4;
	return c;
}

// the lip: the original samples it along s and across q (0 its outer rim, 1 its underside); the lowest q to land in
// a cell colours it
vec4 curl(vec2 p, float t) {
	float k = lip_k(t);
	if (k <= 0.0 || t >= CRASH) {
		return vec4(0.0);
	}
	float best = 2.0;
	float bs = 0.0;
	for (int i = 0; i <= 84; i++) {
		float s = float(i) * 0.012;
		if (s > 1.0) {
			break;
		}
		vec3 a = lip(s, t);
		vec3 b = lip(min(1.0, s + 0.012), t);
		vec2 tg = b.xy - a.xy;
		float L = max(length(tg), 1e-6);
		vec2 n = vec2(tg.y, -tg.x) / L;
		float w = a.z;
		float step_q = 0.5 / max(1.0, w);
		float qc = dot(p - a.xy, n) / max(w, 1e-3) + 0.5;
		int j0 = int(floor(qc / step_q));
		for (int dj = -2; dj <= 2; dj++) {
			float q = float(j0 + dj) * step_q;
			if (q < 0.0 || q > 1.0 + 1e-6) {
				continue;
			}
			if (cell(a.xy + n * (q - 0.5) * w, p) && q < best) {
				best = q;
				bs = s;
			}
		}
	}
	if (best > 1.5) {
		return vec4(0.0);
	}
	return best < 0.18 ? pal[7] : best < 0.36 ? (bs > 0.8 ? pal[7] : pal[6]) : best < 0.56 ? pal[5] : best < 0.76 ? pal[4] : pal[3];
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float t = now;
	int S = int(seed);
	vec4 c = vec4(0.0);
	float X = floor(p.x);
	float x = X + 0.5;
	float a = fade_k(t) * (1.0 - smoothstep(EDGE - 30.0, EDGE, abs(x)));
	if (mode < 0.5) {
		if (floor(p.y) == 0.0 && a > 0.02 && abs(x) < EDGE) {
			c = js_noise(x * 0.3 - t * 3.0, S + 4) > 0.55 ? pal[6] : pal[4];
			c.a = a * 1.2;
		}
	} else if (mode > 2.5) {
		if (a > 0.02 && abs(x) < EDGE) {
			if (floor(p.y) == 1.0) {
				c = vec4(pal[2].rgb, 0.6 * a);
			} else if (floor(p.y) == 2.0) {
				c = vec4(pal[1].rgb, 0.45 * a);
			}
		}
	} else {
		c = body(p, t);
		vec4 cc = curl(p, t);
		if (cc.a > 0.0) {
			c = cc;
		}
		float k = lip_k(t);
		// the tip glints as it throws: a sparkle
		float g = sin(W_PI * clamp((k - 0.55) / 0.45, 0.0, 1.0));
		if (t < CRASH && g > 0.05) {
			float n = floor(6.0 * g + 0.5);
			vec2 q = floor(p) - floor(lip(1.0, t).xy);
			float m = max(abs(q.x), abs(q.y));
			if (n >= 1.0) {
				if ((q.x == 0.0 || q.y == 0.0) && m >= 1.0 && m <= n) {
					c = m > n * 0.6 ? pal[5] : pal[6];
				}
				if (n >= 3.0 && abs(q.x) == 1.0 && abs(q.y) == 1.0) {
					c = pal[6];
				}
				if (n >= 6.0 && abs(q.x) == 2.0 && abs(q.y) == 2.0) {
					c = pal[5];
				}
				if (m == 0.0) {
					c = pal[7];
				}
			}
		}
		// lace left on the water behind the surge, thinning out
		if (t >= CRASH && X >= -20.0 && X < crest_x(t) + 10.0) {
			float lk = 1.0 - smoothstep(CRASH + 0.4, dur - 0.15, t);
			float nn = 1.0 - abs(js_noise2(vec2(x * 0.35, t * 0.8), S + 7)) * 4.0;
			if (floor(p.y) == 0.0 && nn > 1.15 - lk * 1.1) {
				c = nn > 1.4 - lk ? pal[7] : pal[6];
			}
			if (floor(p.y) == 1.0 && nn > 1.4 - lk * 0.9) {
				c = pal[5];
			}
		}
		// the crash: a white burst where the lip lands
		float f = (t - CRASH) / 0.08;
		if (f >= 0.0 && f < 1.0) {
			float x0 = lip(1.0, CRASH - 0.001).x;
			if (distance(p, vec2(x0, -3.0)) <= 8.0 * (1.0 - f * 0.4)) {
				c = pal[7];
			}
			float d = length((p - vec2(x0, 0.0)) / vec2(14.0, 2.6));
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
