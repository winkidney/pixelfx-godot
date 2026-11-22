// weather/fog's banks and streaks (src/fx/weather/fog.js bank(), streaks()): a baked tiling noise F, warped by a
// second one G, scrolled a whole tile a loop, cut into three translucent tones with Bayer edges, a lit crest where a
// band's top meets thinner fog two rows up. pass_ 0..2: the banks far to near; 3: the streaks of mist in front.
#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform vec2 size = vec2(320.0, 180.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform vec4 crest : source_color = vec4(1.0);
uniform vec4 tones[3] : source_color;
uniform sampler2D F : filter_nearest;
uniform sampler2D G : filter_nearest;
uniform int pass_ = 0;

const float D = 12.0;

// [top, base, bot, sx], [sy, alpha, warp, crestFrom]
const vec4 BA[3] = vec4[](vec4(-84.0, -40.0, -20.0, 1.6), vec4(-62.0, -24.0, -2.0, 1.0667), vec4(-42.0, -8.0, 10.0, 0.8));
const vec4 BB[3] = vec4[](vec4(2.2, 0.24, 16.0, 3.0), vec4(2.5, 0.3, 22.0, 2.0), vec4(2.8, 0.36, 28.0, 1.0));

// the bank's density at column i (0..319), row centre y
float dens(int n, float i, float y) {
	vec4 a = BA[n];
	vec4 b = BB[n];
	float y0 = floor(a.x - 2.0) + 0.5;
	if (y < y0) {
		return 0.0;
	}
	float prof = smooth_(a.x, a.y, y) * (1.0 - smooth_(a.z - (a.z < 10.0 ? 14.0 : 4.0), a.z + 1.0, y));
	if (prof <= 0.01) {
		return 0.0;
	}
	float fn = float(n);
	float ie = i - mod(i, 2.0);
	float w = fsample(G, ie * 0.35 + fn * 70.0, y * 0.5 + (128.0 * t) / D) - 0.5;
	float br = 2.0 * sin((TAU * t) / D + (i - 160.0) * 0.006 + fn * 1.7);
	float x = i - 160.0 + 0.5;
	float s = fsample(F, x * a.w + (256.0 * t) / D + w * b.z, (y + br) * b.x + w * 8.0);
	float nn = clamp((s - 0.5) * 2.6 + 0.5, 0.0, 1.0) - 0.5;
	return (prof * 0.72 + nn * 0.95) * (0.6 + 0.5 * prof);
}

void fog_px(vec2 p, out vec4 c, out vec3 l) {
	c = vec4(0.0);
	l = vec3(0.0);
	float i = p.x + 160.0 - 0.5;
	float y = p.y;
	if (pass_ == 3) {
		if (y < -40.0 || y > 7.0) {
			return;
		}
		float env = smooth_(-40.0, -30.0, y) * (1.0 - smooth_(-4.0, 6.0, y));
		float s = (fsample(F, p.x * 0.4 + (256.0 * t) / D, y * 6.5 + 30.0) - 0.64) * 3.0 * env;
		if (s <= 0.05) {
			return;
		}
		c = vec4((s > 0.35 ? C[5] : C[4]).rgb, min(0.4, s));
		l = C[5].rgb * s * 0.05;
		return;
	}
	int n = pass_;
	vec4 a = BA[n];
	if (y > a.z + 1.0) {
		return;
	}
	float f = dens(n, i, y);
	if (f <= 0.3) {
		return;
	}
	float above = dens(n, i, y - 2.0);
	float th = bayer_(i, y) * 0.06;
	int band = f > 0.7 + th ? 2 : f > 0.5 + th ? 1 : 0;
	int solid = f > 0.7 ? 2 : f > 0.5 ? 1 : 0;
	float ts = solid == 2 ? 0.7 : solid == 1 ? 0.5 : 0.3;
	float alpha = BB[n].y;
	if (float(solid) >= BB[n].w && above < ts) {
		c = vec4(crest.rgb, alpha * 0.95);
		l = C[6].rgb * 0.07;
	} else {
		c = vec4(tones[band].rgb, alpha * (0.55 + 0.25 * float(band)));
		if (band == 2) {
			l = C[5].rgb * (0.03 + 0.02 * float(n));
		}
	}
}
