// weather/cherry-blossoms' petals (src/fx/weather/cherry-blossoms.js petals(), blossoms(), scatter()): layer 0 / 1
// the petals behind / in front, each tumbling in a little spiral down a whole number of times a loop, drifting on
// the periodic breeze and flipping; landed, it settles and shrinks away. 2: the petals already lying on the floor.
// 3: the whole blossoms spinning as they sink. Drawn by _petal.gdshader: CUSTOM.z the petal's length (a blossom's
// radius), .w its angle (a blossom's turn); COLOR.x its flip, .y 1 when it flashes, .z 1 for a blossom, .w its light.
shader_type particles;
render_mode disable_velocity, disable_force;

#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform int layer = 0;
uniform int seed = 12;

const float D = 10.0;
const float FLOOR = 1.0;

float gust(float tt) {
	return 22.0 * sin((TAU * tt) / D + 0.4) + 7.0 * sin((TAU * 2.0 * tt) / D - 1.0);
}

bool body(int i, out vec2 p, out vec4 cu, out vec4 col) {
	int S = seed;
	p = vec2(0.0);
	cu = vec4(0.0);
	col = vec4(0.0);
	if (layer == 2) {
		p = vec2(-164.0 + rand3(S, i, 71) * 328.0, FLOOR + floor(rand3(S, i, 72) * 3.0) * 2.0);
		cu = vec4(0.0, 0.0, 2.6 + rand3(S, i, 73), mod((rand3(S, i, 74) - 0.5) * 1.2, TAU));
		col = vec4(0.5, 0.0, 0.0, 0.0);
		return true;
	}
	float u;
	int k;
	int m;
	if (layer == 3) {
		int sd = S * 31;
		trip(t, D, i, sd, 1, 1, u, k, m);
		if (u > 0.9) {
			return false;
		}
		float y = -190.0 + (FLOOR + 2.0 + 190.0) * min(1.0, u / 0.9);
		float born = t - u * D;
		float x = -190.0 + rand3(sd, i, 1) * 330.0 + 14.0 * u * D * 0.1 + (gust(t) - gust(born)) + 6.0 * sin(u * TAU * 2.0 + rand3(sd, i, 2) * 6.0);
		float rot = rand3(sd, i, 3) * TAU + u * D * (rand3(sd, i, 4) - 0.5) * 2.0;
		p = vec2(x, y);
		cu = vec4(0.0, 0.0, 3.6 + rand3(sd, i, 5) * 1.2, mod(rot, TAU));
		col = vec4(1.0, 0.0, 1.0, 0.2);
		return true;
	}
	bool near = layer == 1;
	int sd = S * 7 + layer;
	trip(t, D, i, sd, 1, 2, u, k, m);
	int j = imod(k, m);
	float dur = D / float(m);
	float tf = dur * 0.84;
	float a = min(u * dur, tf);
	float rest = u * dur - tf;
	float born = t - u * dur;
	float x0 = -200.0 + rand4(sd, i, j, 1) * 330.0;
	float y0 = -184.0;
	float vy = (FLOOR + (near ? 2.0 : 0.0) - y0) / tf;
	float vx = 9.0 + rand4(sd, i, j, 2) * 10.0;
	float rho = (near ? 3.0 : 2.0) + rand4(sd, i, j, 3) * 3.0;
	float w = 2.2 + rand4(sd, i, j, 4) * 2.8;
	float ph = rand4(sd, i, j, 5) * TAU;
	float gk = near ? 1.0 : 0.6;
	float len = (near ? 3.6 : 2.6) + rand4(sd, i, j, 6) * 1.1;
	float aa = rest > 0.0 ? tf : a;
	p = vec2(x0 + vx * aa + (gust(born + aa) - gust(born)) * gk + rho * cos(w * aa + ph), y0 + vy * aa + rho * 0.6 * sin(w * aa + ph));
	if (rest > 0.0) {
		float fade = 1.0 - rest / (dur - tf);
		if (fade <= 0.15) {
			return false;
		}
		cu = vec4(0.0, 0.0, len * (0.35 + 0.65 * fade), mod((rand4(sd, i, j, 7) - 0.5) * 1.2, TAU));
		col = vec4(0.5, 0.0, 0.0, 0.0);
		return true;
	}
	float flip = cos(rand4(sd, i, j, 8) * TAU + a * (3.0 + rand4(sd, i, j, 9) * 5.0));
	float ang = rand4(sd, i, j, 10) * TAU + a * (rand4(sd, i, j, 11) - 0.5) * 3.0;
	float g = flip > 0.9 ? (flip - 0.9) / 0.1 : 0.0;
	cu = vec4(0.0, 0.0, len, mod(ang, TAU));
	col = vec4(flip, flip > 0.9 ? 1.0 : 0.0, 0.0, (near ? 0.32 : 0.22) * g);
	return true;
}

#include "res://addons/pixelfx_particles/fx/weather/_wx_place.gdshaderinc"
