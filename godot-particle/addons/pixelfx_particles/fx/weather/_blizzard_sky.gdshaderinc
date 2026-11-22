// weather/blizzard's per-pixel passes (blizzard.js sheets(), ground()): pass_ 0 the far sheets (the whiteout haze
// behind everything), 1 the near sheets of blown snow, 2 the drift with spindrift streaming low along it.
#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform vec2 size = vec2(320.0, 180.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform vec4 white : source_color = vec4(1.0);
uniform vec4 haze : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D F : filter_nearest;
uniform int pass_ = 0;

const float D = 8.0;

float gust_at(float x, float tt) {
	return 0.5 + 0.5 * sin(TAU * ((x + 160.0) / 400.0 - (2.0 * tt) / D) + 0.8);
}

float bank(float x) {
	return -2.0 + 1.2 * sin(x * 0.05 + 2.0) + 0.8 * sin(x * 0.15 + 1.0);
}

void sky_px(vec2 p, out vec4 c, out vec3 l) {
	c = vec4(0.0);
	l = vec3(0.0);
	float x = p.x;
	float y = p.y;
	float g = gust_at(x, t);
	if (pass_ < 2) {
		float near = float(pass_);
		float y0 = pass_ == 1 ? -110.0 : -170.0;
		if (y < y0 || y > 5.0) {
			return;
		}
		float shift = (256.0 * (pass_ == 1 ? 3.0 : 2.0) * t) / D;
		float sy = pass_ == 1 ? 4.5 : 3.2;
		float th = pass_ == 1 ? 0.58 : 0.54;
		float fade = pass_ == 1 ? smooth_(-110.0, -40.0, y) : 1.0;
		float xi = x - 0.5;
		float wv = 5.0 * sin(xi * 0.021 - (TAU * t) / D + near * 2.0);
		float n = fsample(F, xi * 0.16 - shift, (y + wv) * sy + 40.0);
		float d = (n - th) * 2.2 * (0.35 + g) * fade;
		if (pass_ == 1) {
			if (d <= 0.02) {
				return;
			}
			c = vec4(C[6].rgb, min(0.5, d));
		} else {
			c = vec4((d > 0.08 ? C[5] : haze).rgb, 0.3 + 0.12 * g + min(0.42, max(0.0, d)));
		}
		if (d > 0.05) {
			l = C[5].rgb * d * 0.08;
		}
		return;
	}
	if (y < -16.0 || y > 10.0) {
		return;
	}
	float d = y - bank(x);
	if (d >= 0.0) {
		c = d < 1.0 ? white : d < 2.0 ? C[6] : d < 4.0 ? C[5] : C[4];
		if (d < 1.0) {
			l = C[6].rgb * 0.1;
		}
		return;
	}
	if (y < -14.0) {
		return;
	}
	float n = fsample(F, x * 0.5 - (256.0 * 4.0 * t) / D, y * 3.0 + 9.0);
	float s = (n - 0.5) * 3.0 * smooth_(-14.0, -1.0, y) * (0.4 + g);
	if (s > 0.02) {
		c = vec4(C[6].rgb, min(0.55, s));
	}
}
