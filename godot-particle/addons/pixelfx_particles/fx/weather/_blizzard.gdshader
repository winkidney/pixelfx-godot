// weather/blizzard's streaks and grains (src/fx/weather/blizzard.js streaks(), ground()): slot i of a depth crosses
// the canvas a whole number of times a loop at its own height, dipping as it goes; a gust rolling by stretches and
// brightens it (and fills the far depths in). layer 3: the grains skipping along the drift's crest. Drawn by
// _streak.gdshader (mode 0; grains mode 2).
shader_type particles;
render_mode disable_velocity, disable_force;

#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform int layer = 0;
uniform int seed = 9;

const float D = 8.0;

float gust_at(float x, float tt) {
	return 0.5 + 0.5 * sin(TAU * ((x + 160.0) / 400.0 - (2.0 * tt) / D) + 0.8);
}

float bank(float x) {
	return -2.0 + 1.2 * sin(x * 0.05 + 2.0) + 0.8 * sin(x * 0.15 + 1.0);
}

bool body(int i, out vec2 p, out vec4 cu, out vec4 col) {
	p = vec2(0.0);
	cu = vec4(0.0);
	col = vec4(0.0);
	float u;
	int k;
	int m;
	if (layer == 3) {
		int S = seed;
		trip(t, D, i, S * 23, 8, 10, u, k, m);
		int j = imod(k, m);
		float x = -175.0 + 350.0 * u;
		float y = bank(x) - 1.0 - rand4(S, i, j, 1) * 6.0 * abs(sin(u * 9.0 + float(i)));
		p = vec2(x, y);
		col = vec4(0.0, 0.0, rand4(S, i, j, 2) < 0.5 ? 1.0 : 0.0, 0.0);
		return true;
	}
	int L = layer;
	int sd = seed * 17 + L;
	ivec2 mm = L == 0 ? ivec2(3, 4) : L == 1 ? ivec2(4, 5) : ivec2(6, 7);
	vec2 len = L == 0 ? vec2(2.0, 4.0) : L == 1 ? vec2(5.0, 8.0) : vec2(10.0, 16.0);
	vec2 dr = L == 0 ? vec2(10.0, 40.0) : L == 1 ? vec2(20.0, 60.0) : vec2(30.0, 70.0);
	bool near = L == 2;
	trip(t, D, i, sd, mm.x, mm.y, u, k, m);
	int j = imod(k, m);
	float drop = dr.x + rand4(sd, i, j, 3) * (dr.y - dr.x);
	float x = -190.0 + 380.0 * u;
	float y = -178.0 + rand4(sd, i, j, 1) * 182.0 + drop * u + 3.0 * sin(u * TAU * (1.0 + rand4(sd, i, j, 5)) + rand4(sd, i, j, 6) * 6.0);
	if (y > bank(x) - 1.0) {
		return false;
	}
	float g = gust_at(x, t);
	if (!near && rand4(sd, i, j, 7) > 0.45 + 0.75 * g) {
		return false;
	}
	float Ls = (len.x + rand4(sd, i, j, 2) * (len.y - len.x)) * (0.7 + 0.6 * g);
	float dx = 380.0 / (D / float(m));
	float dy = drop / (D / float(m));
	float l = sqrt(dx * dx + dy * dy);
	p = vec2(x, y);
	cu = vec4(0.0, 0.0, Ls, 1.0);
	col = vec4(dx / l, dy / l, (g > 0.6 && near) ? 1.0 : 0.0, 0.12 + 0.12 * g);
	return true;
}

#include "res://addons/pixelfx_particles/fx/weather/_wx_place.gdshaderinc"
