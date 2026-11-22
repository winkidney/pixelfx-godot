// Shared by the transitions' shaders (build/fx/transitions/_transitions.gd): the originals' screen is 320 x 180 with its
// origin at the top-left, so a pixel's cell is its place on the canvas. Here: painter.js put()'s dithered alpha test
// (on the screen's own Bayer cell), the originals' deterministic hashes and noise (src/core/math.js), and _lib.js
// glint() / sim.js sparkle() / flare() as "which colour does this cell end up with" (the last write that lands wins).
#include "res://addons/pixelfx_particles/fx/scifi/_jsrand.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/pickups/_pk.gdshaderinc"

const float TR_W = 320.0;
const float TR_H = 180.0;

// painter.js put(): a write at alpha a lands when a is 1 or above the cell's Bayer threshold
bool tr_put(float a, float thr) {
	return a > 0.0 && (a >= 1.0 || a > thr);
}

// math.js rand(a, b[, c]) in [0, 1)
float tr_rand2(int a, int b) {
	return float(js_hash2(a, b)) / 4294967296.0;
}

float tr_rand3(int a, int b, int c) {
	return float(js_hash3(a, b, c)) / 4294967296.0;
}

// math.js noise(x, seed): smooth 1D value noise in [-1, 1]
float tr_noise(float x, int seed) {
	float i = floor(x);
	float f = x - i;
	float u = f * f * (3.0 - 2.0 * f);
	return mix(tr_rand2(int(i), seed), tr_rand2(int(i) + 1, seed), u) * 2.0 - 1.0;
}

// math.js noise2(x, y, seed)
float tr_noise2(float x, float y, int seed) {
	float ix = floor(x);
	float iy = floor(y);
	float fx = x - ix;
	float fy = y - iy;
	float ux = fx * fx * (3.0 - 2.0 * fx);
	float uy = fy * fy * (3.0 - 2.0 * fy);
	int X = int(ix);
	int Y = int(iy);
	float a = tr_rand3(X, Y, seed);
	float b = tr_rand3(X + 1, Y, seed);
	float c = tr_rand3(X, Y + 1, seed);
	float d = tr_rand3(X + 1, Y + 1, seed);
	return mix(mix(a, b, ux), mix(c, d, ux), uy) * 2.0 - 1.0;
}

// _lib.js glint(p, x, y, L, ang, c1, c2, a) at cell q: -1 untouched, 0 white, 1 c1, 2 c2
int tr_glint(vec2 q, vec2 p, float L, float ang, float a, float thr) {
	if (L < 0.8 || a <= 0.0) {
		return -1;
	}
	vec2 o = q + 0.5 - p;
	if (abs(o.x) > L + 2.5 || abs(o.y) > L + 2.5) {
		return -1;
	}
	int res = -1;
	for (int i = 0; i < 8; i++) {
		bool diag = (i % 2) == 1;
		float an = ang + float(i) * TAU / 8.0;
		float len = diag ? L * 0.42 : L;
		float ca = cos(an);
		float sa = sin(an);
		// this ray passes no nearer than the cell's distance to its line allows: skip rays that can't reach it
		float across = abs(-o.x * sa + o.y * ca);
		if (across > 2.6) {
			continue;
		}
		for (int s = 0; s < 200; s++) {
			float d = float(s) * 0.5;
			if (d > len) {
				break;
			}
			float u = d / len;
			int c = diag ? (u < 0.5 ? 1 : 2) : (u < 0.3 ? 0 : u < 0.65 ? 1 : 2);
			float al = a * (u < 0.7 ? 1.0 : 1.0 - (u - 0.7) / 0.35);
			vec2 sp = p + vec2(ca, sa) * d;
			if (all(equal(floor(sp), q)) && tr_put(al, thr)) {
				res = c;
			}
			if (!diag && u < 0.22 && L > 4.0) {
				if (all(equal(floor(sp + vec2(-sa, ca)), q)) && tr_put(a, thr)) {
					res = 1;
				}
				if (all(equal(floor(sp + vec2(sa, -ca)), q)) && tr_put(a, thr)) {
					res = 1;
				}
			}
		}
	}
	if (all(equal(floor(p), q)) && tr_put(a, thr)) {
		res = 0;
	}
	return res;
}

// _lib.js glint()'s two lights
vec3 tr_glint_light(vec2 pc, vec2 p, float L, float a, vec3 c1) {
	if (L < 0.8 || a <= 0.0) {
		return vec3(0.0);
	}
	return lt_glow(pc, p, 4.0 + L * 1.4, c1, 0.5 * a) + lt_glow(pc, p, 2.0 + L * 0.5, vec3(1.0), 0.4 * a);
}

// sim.js sparkle(p, x, y, arm, c, tip): -1 untouched, 0 white, 1 c, 2 tip
int tr_sparkle(vec2 q, vec2 p, float arm) {
	float n = floor(arm + 0.5);
	if (n < 1.0) {
		return -1;
	}
	vec2 d = q - floor(p);
	vec2 ad = abs(d);
	if (ad.x < 0.5 && ad.y < 0.5) {
		return 0;
	}
	int res = -1;
	if ((ad.x < 0.5 || ad.y < 0.5) && max(ad.x, ad.y) <= n + 0.1) {
		res = max(ad.x, ad.y) > n * 0.6 ? 2 : 1;
	}
	if (n >= 3.0 && ad.x > 0.5 && ad.x < 1.5 && ad.y > 0.5 && ad.y < 1.5) {
		res = 1;
	}
	if (n >= 6.0 && ad.x > 1.5 && ad.x < 2.5 && ad.y > 1.5 && ad.y < 2.5) {
		res = 2;
	}
	return res;
}

// sim.js flare(p, x, y, L, k, ramp): -1 untouched, 0 white, 1 ramp[n - 2], 2 ramp[n - 3]
int tr_flare(vec2 q, vec2 p, float L, float k, float thr) {
	if (L < 1.0) {
		return -1;
	}
	vec2 o = q + 0.5 - p;
	if (abs(o.x) > L + 2.0 || abs(o.y) > L + 2.0) {
		return -1;
	}
	int res = -1;
	for (int i = 0; i < 8; i++) {
		float an = float(i) * PI / 4.0;
		float len = i % 4 == 0 ? L : i % 2 == 0 ? L * 0.6 : L * 0.3;
		float ca = cos(an);
		float sa = sin(an);
		if (abs(-o.x * sa + o.y * ca) > 1.6) {
			continue;
		}
		for (int s = 0; s < 200; s++) {
			float d = float(s) * 0.5;
			if (d > len) {
				break;
			}
			float u = d / len;
			if (all(equal(floor(p + vec2(ca, sa) * d), q)) && tr_put(u < 0.6 ? 1.0 : k * 1.5 * (1.0 - u) + 0.2, thr)) {
				res = u < 0.35 ? 0 : u < 0.7 ? 1 : 2;
			}
		}
	}
	return res;
}

// painter.js line() from cell a to cell b: the step index of cell q along it (u = i / n), or -1 off it
int tr_line_step(vec2 q, vec2 a, vec2 b, out float n_out) {
	int sx = int(a.x);
	int sy = int(a.y);
	int ex = int(b.x);
	int ey = int(b.y);
	int dx = abs(ex - sx);
	int dy = -abs(ey - sy);
	int stx = sx < ex ? 1 : -1;
	int sty = sy < ey ? 1 : -1;
	int n = max(max(dx, -dy), 1);
	n_out = float(n);
	int err = dx + dy;
	ivec2 qi = ivec2(q);
	int hit = -1;
	for (int i = 0; i < 1024; i++) {
		if (sx == qi.x && sy == qi.y) {
			hit = i;
		}
		if (sx == ex && sy == ey) {
			break;
		}
		int e2 = 2 * err;
		if (e2 >= dy) {
			err += dy;
			sx += stx;
		}
		if (e2 <= dx) {
			err += dx;
			sy += sty;
		}
	}
	return hit;
}

// the cell's colour index into pal (white is index 8 for an 8-step ramp): a negative index draws nothing
vec3 tr_pal(vec4 pal[16], int i) {
	return pal[clamp(i, 0, 15)].rgb;
}
