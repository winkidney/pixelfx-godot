// weather/storm's rain (storm.js rain()): layer 0 the far drops, thin and dim, ending in the air; 1 the near drops,
// long with bright heads, landing on the floor; 2 the splash of each near slot's last drop. The flash lights every
// drop near the bolt (COLOR.z: 0..2). Streaks drawn by _streak.gdshader (far: mode 1, near: mode 0); a splash by
// _splash.gdshader (CUSTOM.z its age, .w its size; COLOR.x its light, .y the slot, .z its drop).
shader_type particles;
render_mode disable_velocity, disable_force;

#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform int layer = 0;
uniform int seed = 5;
uniform float f = 0.0;

const float D = 10.0;
const float SLANT = 0.42;
const float BX1 = 52.0;

float lit_at(float x) {
	float L = f * (0.3 + 0.7 * max(0.0, 1.0 - abs(x - BX1) / 170.0));
	return L > 0.45 ? 2.0 : L > 0.15 ? 1.0 : 0.0;
}

bool body(int i, out vec2 p, out vec4 cu, out vec4 col) {
	int S = seed;
	p = vec2(0.0);
	cu = vec4(0.0);
	col = vec4(0.0);
	float u;
	int k;
	int m;
	float h = 1.0 / sqrt(SLANT * SLANT + 1.0);
	vec2 dir = vec2(SLANT * h, h);
	if (layer == 0) {
		trip(t, D, i, S * 7 + 1, 22, 28, u, k, m);
		int j = imod(k, m);
		float stop = -14.0 - rand4(S, i, j, 1) * 90.0;
		float y = -176.0 + (stop + 176.0) * u;
		float x = -170.0 + rand4(S, i, j, 2) * 360.0 - (stop - y) * SLANT;
		p = vec2(x, y);
		cu = vec4(0.0, 0.0, 3.0 + rand4(S, i, j, 3) * 2.0, 1.0);
		col = vec4(dir, lit_at(x), 0.0);
		return true;
	}
	trip(t, D, i, S * 7 + 2, 30, 38, u, k, m);
	int j = imod(k, m);
	if (layer == 1) {
		float z = 1.0 + rand4(S, i, j, 1) * 4.0;
		float y = -180.0 + (z + 180.0) * u;
		float x = -175.0 + rand4(S, i, j, 2) * 370.0 - (z - y) * SLANT;
		p = vec2(x, y);
		cu = vec4(0.0, 0.0, 9.0 + rand4(S, i, j, 3) * 5.0, 1.0);
		col = vec4(dir, lit_at(x), 0.0);
		return true;
	}
	float age = u * (D / float(m));
	if (age >= 0.4) {
		return false;
	}
	int jp = imod(k - 1, m);
	float zp = 1.0 + rand4(S, i, jp, 1) * 4.0;
	float xp = -175.0 + rand4(S, i, jp, 2) * 370.0;
	p = vec2(xp, zp);
	cu = vec4(0.0, 0.0, age, 0.25 + (zp - 1.0) / 5.3);
	col = vec4(lit_at(xp), float(i), float(jp), 1.0);
	return true;
}

#include "res://addons/pixelfx_particles/fx/weather/_wx_place.gdshaderinc"
