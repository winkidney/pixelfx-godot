// weather/god-rays' dust motes (god-rays.js motes()): each drifts on whole cycles, invisible in the dark, and shows
// only while it crosses a beam. CUSTOM.z: its colour (0 C4, 1 C5, 2 white), .w: big (a front mote, lit enough);
// COLOR.x its glow's strength, .y its radius.
shader_type particles;
render_mode disable_velocity, disable_force;

#include "res://addons/pixelfx_particles/fx/weather/_god_rays.gdshaderinc"

uniform int first = 0;
uniform bool front = false;

bool body(int ii, out vec2 p, out vec4 cu, out vec4 col) {
	int i = ii + first;
	int S = seed;
	p = vec2(0.0);
	cu = vec4(0.0);
	col = vec4(0.0);
	float n1 = 1.0 + floor(rand3(S, i, 1) * 2.0);
	float n2 = 1.0 + floor(rand3(S, i, 2) * 2.0);
	float x = -170.0 + rand3(S, i, 3) * 340.0 + (8.0 + rand3(S, i, 4) * 14.0) * sin((TAU * n1 * t) / D + rand3(S, i, 5) * TAU);
	float y = -170.0 + rand3(S, i, 6) * 172.0 + (6.0 + rand3(S, i, 7) * 10.0) * sin((TAU * n2 * t) / D + rand3(S, i, 8) * TAU)
		+ 4.0 * sin((TAU * 3.0 * t) / D + float(i));
	p = vec2(x, y);
	float e = light_at(p);
	if (e < 0.12) {
		return false;
	}
	bool big = front && rand3(S, i, 9) < 0.5;
	float k = min(1.0, e);
	cu = vec4(0.0, 0.0, k > 0.6 ? 2.0 : k > 0.3 ? 1.0 : 0.0, (big && k > 0.5) ? 1.0 : 0.0);
	col = vec4(0.4 * k, big ? 6.0 : 4.0, 0.0, 1.0);
	return true;
}

#include "res://addons/pixelfx_particles/fx/weather/_wx_place.gdshaderinc"
