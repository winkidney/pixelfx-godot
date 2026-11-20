// weather/falling-leaves' leaves (src/fx/weather/falling-leaves.js leaves(), litter()): slot i swings down a whole
// number of times a loop, a pendulum that speeds through the bottom of each arc, tilting with it and flipping, rides
// the periodic gust, lands flat in the litter and fades. front: the near ones (the rest go behind); layer 2: the
// litter already lying on the floor. Drawn by _leaf.gdshader: CUSTOM.z its size, .w its tilt; COLOR.x its flip,
// .y its shape + 3 x its colours (0..2 the ramps, 3..5 the litter's duller ones), .z its alpha.
shader_type particles;
render_mode disable_velocity, disable_force;

#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform int layer = 0;
uniform int seed = 8;

const float D = 10.0;
const float FLOOR = 1.0;

float gust(float tt) {
	return 16.0 * sin((TAU * tt) / D - 1.2) + 5.0 * sin((TAU * 3.0 * tt) / D);
}

float Hc(float th) {
	float k = floor((th + PI / 2.0) / PI);
	return 2.0 * k + 1.0 + sin(th - k * PI);
}

bool body(int i, out vec2 p, out vec4 cu, out vec4 col) {
	int S = seed;
	p = vec2(0.0);
	cu = vec4(0.0);
	col = vec4(0.0);
	if (layer == 2) {
		p = vec2(-164.0 + rand3(S, i, 91) * 328.0, FLOOR - 2.0 + floor(rand3(S, i, 92) * 4.0) * 2.0);
		float ci = floor(rand3(S, i, 93) * 3.0);
		cu = vec4(0.0, 0.0, 3.6 + rand3(S, i, 94) * 1.8, mod((rand3(S, i, 95) - 0.5) * 0.7, TAU));
		col = vec4(0.45 + rand3(S, i, 96) * 0.25, floor(rand3(S, i, 97) * 3.0) + 3.0 * (ci + 3.0), 1.0, 0.0);
		return true;
	}
	bool front = layer == 1;
	int sd = S * 19;
	float u;
	int k;
	int m;
	trip(t, D, i, sd, 2, 3, u, k, m);
	int j = imod(k, m);
	bool near = rand4(sd, i, j, 1) < 0.35;
	if (near != front) {
		return false;
	}
	float dur = D / float(m);
	float tf = dur * 0.72;
	float a = min(u * dur, tf);
	float rest = u * dur - tf;
	float w = 1.7 + rand4(sd, i, j, 2) * 1.2;
	float ph0 = rand4(sd, i, j, 3) * TAU;
	float amp = (near ? 14.0 : 8.0) + rand4(sd, i, j, 4) * 10.0;
	float x0 = -180.0 + rand4(sd, i, j, 5) * 340.0;
	float y0 = -186.0;
	float ptf = 0.45 * tf + (0.9 * (Hc(w * tf + ph0) - Hc(ph0))) / w;
	float vy = (FLOOR - y0) / ptf;
	float born = t - u * dur;
	float gk = near ? 1.0 : 0.7;
	float size = (near ? 5.8 : 4.2) + rand4(sd, i, j, 6) * 1.6;
	float shape = floor(rand4(sd, i, j, 7) * 3.0);
	float ci = floor(rand4(sd, i, j, 8) * 3.0);
	if (rest > 0.0) {
		float fade = 1.0 - rest / (dur - tf);
		p = vec2(x0 + 7.0 * tf + sin(w * tf + ph0) * amp + (gust(born + tf) - gust(born)) * gk, FLOOR - 1.0);
		cu = vec4(0.0, 0.0, size, mod((rand4(sd, i, j, 9) - 0.5) * 0.5, TAU));
		col = vec4(0.42, shape + 3.0 * ci, fade, 0.0);
		return true;
	}
	float pa = 0.45 * a + (0.9 * (Hc(w * a + ph0) - Hc(ph0))) / w;
	p = vec2(x0 + 7.0 * a + sin(w * a + ph0) * amp + (gust(born + a) - gust(born)) * gk, y0 + vy * pa);
	float tilt = cos(w * a + ph0) * 0.75 + (near ? 0.0 : 0.3);
	float flip = cos(rand4(sd, i, j, 10) * TAU + a * (rand4(sd, i, j, 11) < 0.3 ? 5.0 : 1.2));
	cu = vec4(0.0, 0.0, size, mod(tilt, TAU));
	col = vec4(flip, shape + 3.0 * ci, 1.0, 0.0);
	return true;
}

#include "res://addons/pixelfx_particles/fx/weather/_wx_place.gdshaderinc"
