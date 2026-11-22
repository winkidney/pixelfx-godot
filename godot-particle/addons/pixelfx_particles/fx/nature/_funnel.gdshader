// The tornado's funnel, after the original: an axis that snakes (a wave running up it) and a radius that flares at the
// top. pass 0 draws what's behind (the crown's dark underside and far bands, the far halves of the wind bands),
// pass 1 the body (a translucent column of sheared noise, lit from the left, dusty at its foot), pass 2 what's in
// front (the near halves of the bands and the crown, the scuffs swept round the floor). The wind bands, crown
// bands, noise and scuffs are the original's own seeded numbers (uniform arrays and two small lookup textures).
// Key `t` 0 -> 1 over the loop and `flash` (the crown lighting up). Colour layer, translucent: it blends.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

const int NB = 58;
const int NC = 16;
const int NS = 7;
const float FH = 112.0;
const float SY = 0.28;
uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float flash = 0.0;
uniform float pass = 0.0;
// wind bands: (u, radius factor, head at t = 0, span), (turns per loop, level, 0, 0)
uniform vec4 band_a[NB];
uniform vec4 band_b[NB];
// crown bands: (radius factor, head at t = 0, span, th0), (turns per loop, lift, 0, 0)
uniform vec4 crown_a[NC];
uniform vec4 crown_b[NC];
// scuffs on the floor: (radius, head at t = 0, span, 0)
uniform vec4 scuff[NS];
// the palette (8) and the dust (5), dark to bright, as 1 px textures
uniform sampler2D pal : filter_nearest;
uniform sampler2D dust : filter_nearest;
// the body's value noise: rand(x, iy, seed) for x 0..5, iy -39..1 (row iy + 39), and each row's spin (rand(y) < 0.35)
uniform sampler2D noise : filter_nearest;
uniform sampler2D rows : filter_nearest;

vec3 C(int i) {
	return texelFetch(pal, ivec2(clamp(i, 0, 7), 0), 0).rgb;
}

vec3 D(int i) {
	return texelFetch(dust, ivec2(clamp(i, 0, 4), 0), 0).rgb;
}

float smooth_(float a, float b, float x) {
	float u = clamp((x - a) / (b - a), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

float ax(float u) {
	float ph = TAU * t;
	return 8.5 * sin(ph - 2.6 * u) * (0.2 + 0.8 * u) + 3.0 * sin(2.0 * ph + 1.3 - 4.5 * u) * u;
}

float rad(float u) {
	float f = smooth_(0.78, 1.0, u);
	return 3.0 + 20.0 * pow(u, 1.5) + 17.0 * f * f;
}

void over(inout vec4 acc, vec3 c, float a) {
	a = clamp(a, 0.0, 1.0);
	float na = a + acc.a * (1.0 - a);
	acc.rgb = (c * a + acc.rgb * acc.a * (1.0 - a)) / max(na, 1e-4);
	acc.a = na;
}

// where a ring of radius r round cx crosses pixel column X on one branch (br 1: sin > 0, near; -1 far): the y range
// of the curve there (y0 + r * sy * sin), and the angle at the column's middle. false if it doesn't.
bool ring_cross(float X, float cx, float r, float sy, float y0, float br, out float lo, out float hi, out float th) {
	float c0 = (X - cx) / r;
	float c1 = (X + 1.0 - cx) / r;
	if (c1 < -1.0 || c0 > 1.0) {
		return false;
	}
	float ya = y0 + r * sy * br * sqrt(1.0 - clamp(c0 * c0, 0.0, 1.0));
	float yb = y0 + r * sy * br * sqrt(1.0 - clamp(c1 * c1, 0.0, 1.0));
	lo = min(ya, yb);
	hi = max(ya, yb);
	if (c0 < 0.0 && c1 > 0.0) {
		float ym = y0 + r * sy * br;
		lo = min(lo, ym);
		hi = max(hi, ym);
	}
	th = br * acos(clamp((X + 0.5 - cx) / r, -1.0, 1.0));
	return true;
}

float vnoise(float x, float y) {
	float ix = floor(x);
	float iy = floor(y);
	float fx = x - ix;
	float fy = y - iy;
	float ux = fx * fx * (3.0 - 2.0 * fx);
	float uy = fy * fy * (3.0 - 2.0 * fy);
	int x0 = int(mod(ix, 6.0));
	int x1 = int(mod(ix + 1.0, 6.0));
	int y0 = clamp(int(iy) + 39, 0, 40);
	int y1 = clamp(int(iy) + 40, 0, 40);
	float a = texelFetch(noise, ivec2(x0, y0), 0).r;
	float b = texelFetch(noise, ivec2(x1, y0), 0).r;
	float c = texelFetch(noise, ivec2(x0, y1), 0).r;
	float d = texelFetch(noise, ivec2(x1, y1), 0).r;
	return mix(mix(a, b, ux), mix(c, d, ux), uy) * 2.0 - 1.0;
}

void bands(inout vec4 acc, vec2 cell, float br) {
	for (int j = 0; j < NB; j++) {
		vec4 a = band_a[j];
		vec4 b = band_b[j];
		float u = a.x;
		if (u > 0.97) {
			continue;
		}
		float y0 = -u * FH;
		float r = rad(u) * a.y;
		if (abs(cell.y + 0.5 - y0) > r * SY + 1.5) {
			continue;
		}
		float cx = ax(u);
		float lo;
		float hi;
		float th;
		if (!ring_cross(cell.x, cx, r, SY, y0, br, lo, hi, th)) {
			continue;
		}
		if (hi < cell.y || lo >= cell.y + 1.0) {
			continue;
		}
		float head = a.z + TAU * b.x * t;
		float s = mod(head - th, TAU);
		if (s > a.w) {
			continue;
		}
		float k = s / a.w;
		bool lit = cos(th) < 0.2;
		float lvl = b.y;
		int i = lvl < 0.18 ? 2 : (k < 0.15 && lvl > 0.55) ? 7 : k < 0.45 ? (lit ? 6 : 5) : (lit ? 5 : 4);
		if (br < 0.0) {
			i = max(1, i - 2);
		}
		over(acc, C(i), k < 0.5 ? 1.0 : 2.0 * (1.0 - k));
		// a white glint on the head of the brightest
		if (br > 0.0 && lvl > 0.6 && sin(head) > 0.0) {
			vec2 hp = floor(vec2(cx + r * cos(head), y0 + r * SY * sin(head)));
			if (hp == cell) {
				over(acc, vec3(1.0), 1.0);
			}
		}
	}
}

void crown(inout vec4 acc, vec2 cell, float br) {
	float cx = ax(1.0);
	float r = rad(1.0);
	float y0 = -FH - 3.0;
	bool back = br < 0.0;
	int d = back ? 1 : 0;
	for (int j = 0; j < NC; j++) {
		vec4 a = crown_a[j];
		vec4 b = crown_b[j];
		float rr = r * a.x;
		float lift = b.y;
		if (abs(cell.y + 0.5 - (y0 + lift)) > rr * SY + 5.0) {
			continue;
		}
		float lo;
		float hi;
		float th;
		if (!ring_cross(cell.x, cx, rr, SY, y0 + lift, br, lo, hi, th)) {
			continue;
		}
		float head = a.y + TAU * b.x * t;
		float s2 = mod(head - th, TAU);
		if (s2 > a.z) {
			continue;
		}
		float k = s2 / a.z;
		float th2 = a.w * sin(PI * pow(1.0 - k, 0.7));
		float T = max(1.0, floor(th2 + 0.5));
		float top = floor(lo - T / 2.0);
		float bot = floor(hi - T / 2.0) + T;
		if (cell.y < top || cell.y >= bot) {
			continue;
		}
		float i = clamp(cell.y - floor(y0 + lift + rr * SY * sin(th) - T / 2.0), 0.0, T - 1.0);
		bool lit = cos(th) < 0.3;
		vec3 c;
		if (i < 0.5) {
			c = C((lit ? 6 : 5) - d);
		} else if (i > T - 1.5 && T > 2.0) {
			c = C(1);
		} else {
			c = C((i < 1.5 ? 4 : 3) - d);
		}
		if (!(i > T - 1.5 && T > 2.0 && i > 0.5)) {
			c = mix(c, C(7), flash * 0.6);
		}
		over(acc, c, (0.55 + 0.35 * (1.0 - k)) * (back ? 0.75 : 1.0));
	}
}

void blob(inout vec4 acc, vec2 p, vec2 c, vec2 rr, vec3 col, float a) {
	vec2 d = (p - c) / rr;
	if (dot(d, d) <= 1.0) {
		over(acc, col, a);
	}
}

void body(inout vec4 acc, vec2 cell) {
	float y = cell.y;
	if (y < -ceil(FH) + 2.0 || y > 0.0) {
		return;
	}
	float u = -y / FH;
	float cx = ax(u);
	float r = rad(u);
	float c = (cell.x + 0.5 - cx) / r;
	if (abs(c) > 1.0) {
		return;
	}
	float K = 2.0 + (texelFetch(rows, ivec2(0, clamp(int(y) + 111, 0, 111)), 0).r > 0.5 ? 1.0 : 0.0);
	float rot = TAU * K * t;
	float fade = min(1.0, u * 8.0 + 0.25) * (1.0 - smooth_(0.9, 1.02, u));
	float n = vnoise((acos(c) + rot) * 6.0 / TAU, y * 0.34);
	float v = -c * 0.55 + 0.15 + n * 0.55;
	vec3 col = v > 0.6 ? C(6) : v > 0.28 ? C(5) : v > -0.05 ? C(4) : v > -0.4 ? C(3) : C(2);
	if (u < 0.3) {
		col = mix(col, D(v > 0.3 ? 3 : v > -0.2 ? 2 : 1), 0.7 * (1.0 - u / 0.3));
	}
	over(acc, col, (0.14 + 0.36 * sqrt(1.0 - c * c)) * fade);
}

void scuffs(inout vec4 acc, vec2 cell, vec2 fc) {
	float cx = ax(0.0);
	for (int j = 0; j < NS; j++) {
		vec4 a = scuff[j];
		float r = a.x;
		for (int b = 0; b < 2; b++) {
			float br = b == 0 ? 1.0 : -1.0;
			float lo;
			float hi;
			float th;
			if (!ring_cross(cell.x, cx, r, 0.18, 0.5, br, lo, hi, th)) {
				continue;
			}
			if (hi < cell.y || lo >= cell.y + 1.0) {
				continue;
			}
			float head = a.y + TAU * 3.0 * t;
			float s = mod(head - th, TAU);
			if (s >= a.z) {
				continue;
			}
			if (1.0 - s / a.z < pfx_threshold(fc)) {
				continue;
			}
			over(acc, D(s < a.z * 0.4 ? 3 : 2), 1.0);
		}
	}
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 cell = floor(p);
	vec4 acc = vec4(0.0);
	if (pass < 0.5) {
		float cx = ax(1.0);
		float r = rad(1.0);
		float y0 = -FH - 3.0;
		blob(acc, p, vec2(cx, y0 + 1.0), vec2(r * 0.85, 6.0), C(1), 0.6);
		blob(acc, p, vec2(cx - 4.0, y0 - 3.0), vec2(r * 0.6, 3.5), mix(C(3), C(7), flash * 0.6), 0.45);
		crown(acc, cell, -1.0);
		bands(acc, cell, -1.0);
	} else if (pass < 1.5) {
		body(acc, cell);
	} else {
		bands(acc, cell, 1.0);
		crown(acc, cell, 1.0);
		scuffs(acc, cell, FRAGCOORD.xy);
	}
	if (acc.a <= 0.0) {
		discard;
	}
	vec4 col = acc;
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
