// weather/snow's flakes (src/fx/weather/snow.js layer()): slot i of a depth falls a whole number of times a loop
// (trips), swaying and blown by the periodic gust, and lies on the drift for the rest of its fall. CUSTOM.z: what to
// draw (0 a far speck, 1 a flake lying on the drift, 2 a big flake, 3 a small one, 4 a crystal lying down, 5 a
// crystal in the air), CUSTOM.w: its alpha; COLOR.x: the speck's tone or the crystal's sprite.
shader_type particles;
render_mode disable_velocity, disable_force;

#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform int layer = 0;
uniform int seed = 6;

const float D = 12.0;

float bank(float x) {
	return -3.0 + 1.6 * sin(x * 0.045 + 1.3) + 1.1 * sin(x * 0.12 + 0.4) + 0.6 * sin(x * 0.31 + 2.0);
}

float gust(float tt) {
	return 10.0 * sin((TAU * tt) / D + 0.6) + 4.0 * sin((TAU * 2.0 * tt) / D + 2.1);
}

bool body(int i, out vec2 p, out vec4 cu, out vec4 col) {
	p = vec2(0.0);
	cu = vec4(0.0);
	col = vec4(0.0);
	int L = layer;
	int sd = seed * 13 + L;
	int m0 = L == 0 ? 1 : 2;
	int m1 = L == 0 ? 2 : 3;
	float air = L == 0 ? 1.0 : L == 1 ? 0.8 : 0.74;
	vec2 sway = L == 0 ? vec2(1.0, 3.0) : L == 1 ? vec2(3.0, 7.0) : vec2(8.0, 15.0);
	float wind = L == 0 ? 3.0 : L == 1 ? 6.0 : 9.0;
	float gk = L == 0 ? 0.4 : L == 1 ? 0.7 : 1.0;
	float u;
	int k;
	int m;
	trip(t, D, i, sd, m0, m1, u, k, m);
	int j = imod(k, m);
	float dur = D / float(m);
	float tf = dur * air;
	float age = min(u * dur, tf);
	float sw = sway.x + rand4(sd, i, j, 3) * (sway.y - sway.x);
	float f = 0.25 + rand4(sd, i, j, 4) * 0.35;
	float ph = rand4(sd, i, j, 5) * TAU;
	float x0 = -175.0 + rand4(sd, i, j, 2) * 350.0;
	float b0 = t - u * dur;
	float x = x0 + wind * age + (gust(b0 + age) - gust(b0)) * gk + sw * sin(TAU * f * age + ph);
	float xl = x0 + wind * tf + (gust(b0 + tf) - gust(b0)) * gk + sw * sin(TAU * f * tf + ph);
	float y0 = -176.0;
	float y1 = L > 0 ? bank(xl) - 0.5 : -110.0 + rand4(sd, i, j, 1) * 106.0;
	float y = y0 + (y1 - y0) * (age / tf);
	float rest = u * dur - tf;
	float r6 = rand4(sd, i, j, 6);
	if (L == 0) {
		p = vec2(x, y);
		cu = vec4(0.0, 0.0, 0.0, min(1.0, (1.0 - u) * 6.0));
		col = vec4(r6 < 0.5 ? 0.0 : 1.0, 0.0, 0.0, 1.0);
		return true;
	}
	float fade = rest > 0.0 ? 1.0 - rest / (dur - tf) : 1.0;
	if (L == 1) {
		if (rest > 0.0) {
			p = vec2(xl, y1);
			cu = vec4(0.0, 0.0, 1.0, fade * 0.9);
		} else {
			p = vec2(x, y);
			cu = vec4(0.0, 0.0, r6 < 0.3 ? 2.0 : 3.0, 1.0);
		}
		col = vec4(1.0);
		return true;
	}
	if (rest > 0.0) {
		p = vec2(xl, y1);
		cu = vec4(0.0, 0.0, 4.0, fade);
		col = vec4(1.0);
		return true;
	}
	float r = r6 < 0.4 ? 3.0 : r6 < 0.8 ? 4.0 : 5.0;
	float spin = 1.5 + rand4(sd, i, j, 7) * 2.5;
	float turn = mod(floor(age * spin + rand4(sd, i, j, 8) * 2.0), 2.0);
	p = floor(vec2(x, y) + 0.5);
	cu = vec4(0.0, 0.0, 5.0, 1.0);
	col = vec4((r - 3.0) * 2.0 + turn, r, 0.0, 1.0);
	return true;
}

#include "res://addons/pixelfx_particles/fx/weather/_wx_place.gdshaderinc"
