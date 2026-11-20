// weather/aurora's curtains (src/fx/weather/aurora.js curtain()): each walked along in half-pixel steps, every step
// dropping a ray's light into the columns it covers, so folds along the line of sight pile up and burn brightest.
// The original sums all of it into a buffer; here a pixel gathers the steps that land on its column (accum()), and
// for the bloom the box blur (radius 5) of that buffer over its 11 x 11 neighbourhood.
#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform vec2 size = vec2(320.0, 180.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D F : filter_nearest;
uniform vec4 G[7] : source_color;
uniform vec4 U[7] : source_color;
uniform vec4 GM[7] : source_color;

const float D = 12.0;
// y, slope, amp, lam / fold, flam, height, k / s0, s1, rip, hue / cycles c0, c1, c2
const vec4 CA[3] = vec4[](vec4(-132.0, -0.08, 8.0, 210.0), vec4(-88.0, 0.22, 13.0, 250.0), vec4(-38.0, -0.05, 5.0, 150.0));
const vec4 CB[3] = vec4[](vec4(14.0, 150.0, 40.0, 0.6), vec4(19.0, 165.0, 82.0, 1.5), vec4(10.0, 110.0, 20.0, 0.45));
const vec4 CC[3] = vec4[](vec4(-210.0, 210.0, 1.6, 0.35), vec4(-195.0, 180.0, 2.4, 0.0), vec4(-210.0, 210.0, 1.4, 0.0));
const vec3 CY[3] = vec3[](vec3(1.0, 1.0, 2.0), vec3(1.0, 2.0, 3.0), vec3(2.0, 1.0, 3.0));

float cyc(float c, float ph) {
	return (TAU * c * t) / D + ph;
}

float prof(float v, float h) {
	if (v >= 0.0) {
		float q = min(200.0, floor(v * 200.0)) / 200.0;
		return q < 0.035 ? 2.6 : q < 0.22 ? 1.15 - q : pow(1.0 - q, 1.5) * 0.9;
	}
	return max(0.0, 0.45 + v * h * 0.16);
}

// the light piled on column X (0..319), row Y (0..179): I, its height-weighted sum HV, and (blur) the box blur BL
void accum(int X, int Y, bool blur, out float I, out float HV, out float BL) {
	I = 0.0;
	HV = 0.0;
	BL = 0.0;
	float breath = 0.75 + 0.25 * sin(cyc(1.0, -1.2));
	float fast = (256.0 * 2.0 * t) / D;
	float slow = (256.0 * t) / D;
	float X0 = -160.0;
	float Y0 = -180.0;
	for (int n = 0; n < 3; n++) {
		vec4 a = CA[n];
		vec4 b = CB[n];
		vec4 c = CC[n];
		vec3 cy = CY[n];
		float fn = float(n);
		float reach = b.x + 7.0 + (blur ? 5.0 : 0.0);
		float sx = float(X) + X0 + 0.5;
		int lo = max(int(c.x * 2.0), int(floor((sx - reach) * 2.0)));
		int hi = min(int(c.y * 2.0) - 1, int(ceil((sx + reach) * 2.0)));
		float ph0 = cyc(cy.x, fn * 2.0);
		float ph2 = cyc(cy.z, fn);
		for (int st = lo; st <= hi; st++) {
			float s = float(st) * 0.5;
			float x = s + b.x * sin((TAU * s) / b.y + ph0) + 5.0 * sin((TAU * s) / 64.0 + ph2);
			if (x < X0 - 2.0 || x >= X0 + 321.0) continue;
			float xf = floor(x - X0);
			int xi = int(xf);
			bool hit = xi == X || xi + 1 == X;
			bool near = blur && xi + 1 >= X - 5 && xi <= X + 5;
			if (!hit && !near) continue;
			float env = smooth_(c.x, c.x + 60.0, s) * (1.0 - smooth_(c.y - 70.0, c.y, s));
			float r1 = clamp((fsample(F, s * 5.0 - fast + fn * 40.0, 10.0 + fn * 30.0) - 0.38) * 3.2, 0.0, 1.0);
			float r2 = clamp((fsample(F, s * 4.3 + fast * 0.7 + fn * 90.0, 50.0 + fn * 13.0) - 0.35) * 3.0, 0.0, 1.0);
			float patch = fsample(F, s * 0.7 + slow + fn * 17.0, 80.0 + fn * 9.0);
			float k = b.w * env * breath * (0.2 + 0.8 * r1) * (0.3 + 1.4 * max(0.0, patch - 0.3));
			if (k < 0.01) continue;
			if (xi < -1 || xi >= 320) continue;
			float hem = a.x + a.y * s + a.z * sin((TAU * s) / a.w + cyc(cy.y, fn * 1.7)) + c.z * sin((TAU * s) / 23.0 - cyc(7.0, fn));
			float h = b.z * (0.45 + 0.75 * r2) * (0.75 + 0.5 * patch);
			float fr = x - X0 - xf;
			float top = max(0.0, floor(hem - h - Y0));
			float bot = min(179.0, floor(hem - Y0) + 3.0);
			float inv = 1.0 / h;
			float k0 = k * 0.5 * (1.0 - fr);
			float k1 = k * 0.5 * fr;
			float v0 = (hem - Y0 - 0.5 - top) * inv;
			if (hit && float(Y) >= top && float(Y) <= bot) {
				float v = v0 - (float(Y) - top) * inv;
				float pr = prof(v, h);
				float hv = clamp(v + c.w, 0.0, 1.0);
				float kk = (xi == X ? k0 : 0.0) + (xi + 1 == X ? k1 : 0.0);
				I += kk * pr;
				HV += kk * pr * hv;
			}
			if (near) {
				float kk = (xi >= max(0, X - 5) && xi <= X + 5 ? k0 : 0.0) + (xi + 1 >= X - 5 && xi + 1 <= min(319, X + 5) ? k1 : 0.0);
				float y0 = max(top, float(Y) - 5.0);
				float y1 = min(bot, float(Y) + 5.0);
				for (float yy = y0; yy <= y1; yy += 1.0) {
					BL += kk * prof(v0 - (yy - top) * inv, h);
				}
			}
		}
	}
	BL /= 121.0;
}

// the rows pass: a pixel's colour (alpha 0: none; blend: translucent) and light
void aurora_px(vec2 p, bool blur, out vec4 c, out bool blend, out vec3 l) {
	c = vec4(0.0);
	blend = false;
	l = vec3(0.0);
	if (p.y > -11.0) {
		return;
	}
	int X = int(p.x + 159.5);
	int Y = int(p.y + 179.5);
	float raw;
	float hv;
	float bl;
	accum(X, Y, blur, raw, hv, bl);
	float k = bl > 0.015 ? min(0.4, bl * 0.6) : 0.0;
	vec3 lc = G[4].rgb;
	if (raw >= 0.03) {
		float e = (raw * 1.5) / (1.0 + raw * 1.5);
		float v = hv / raw;
		float th = e > 0.45 ? bayer_(float(X), p.y) * 0.06 : 0.0;
		int lv = e > 0.86 + th ? 6 : e > 0.72 + th ? 5 : e > 0.56 + th ? 4 : e > 0.4 + th ? 3 : e > 0.24 ? 2 : 1;
		if (v > 0.35) lv = min(lv, 5);
		int which = v < 0.3 ? 0 : v < 0.5 ? 1 : 2;
		vec4 col = which == 0 ? G[lv] : which == 1 ? GM[lv] : U[lv];
		if (lv >= 3) {
			c = vec4(col.rgb, clamp((e - 0.3) * 2.2, 0.0, 1.0));
			blend = lv < 5;
			lc = v < 0.4 ? G[4].rgb : U[4].rgb;
		} else {
			lc = which == 0 ? G[4].rgb : which == 2 ? U[4].rgb : GM[4].rgb;
		}
		k += e * (lv >= 3 ? 0.28 : 0.72);
	}
	l = lc * k;
}
