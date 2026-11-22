// weather/fireflies: the flies (layer 0: depths 0 and 1, behind the front grass; 1: the near ones) and the meadow's
// blades (layer 2 the back row, 3 the front row). A fly sits on its rounded pixel, CUSTOM.z its index, .w its glow
// (drawn by _firefly.gdshader). A blade sits on its root, CUSTOM.z its height, .w its sway; COLOR.x its tone, .y the
// light on its tip from a lit fly nearby, .z 1 with a seed head (drawn by _blade.gdshader).
shader_type particles;
render_mode disable_velocity, disable_force;

#include "res://addons/pixelfx_particles/fx/weather/_fireflies.gdshaderinc"

uniform int layer = 0;

bool body(int ii, out vec2 p, out vec4 cu, out vec4 col) {
	p = vec2(0.0);
	cu = vec4(0.0);
	col = vec4(0.0);
	if (layer < 2) {
		int i = ii + (layer == 1 ? 26 : 0);
		vec2 xy = fly_pos(i, t);
		float g = fly_glow(i);
		p = floor(xy + 0.5);
		cu = vec4(0.0, 0.0, float(i), g);
		col = vec4(xy - p, 0.0, 1.0);
		return true;
	}
	bool front = layer == 3;
	int i = ii;
	int sd = seed * 3 + (front ? 1 : 0);
	float n = front ? 150.0 : 230.0;
	float x = -162.0 + (float(i) + rand3(sd, i, 1)) * (324.0 / n);
	float h = (front ? 4.0 : 5.0) + rand3(sd, i, 2) * (front ? 8.0 : 11.0) + (rand3(sd, i, 3) < 0.1 ? 6.0 : 0.0);
	float base = (front ? 9.0 : 2.0) - rand3(sd, i, 4) * 3.0;
	float sway = (1.2 + rand3(sd, i, 5)) * sin(cyc(t, 2.0, -x * 0.03) + rand3(sd, i, 6)) + 0.6 * sin(cyc(t, 5.0, x * 0.07));
	float tone = front ? 1.0 + floor(rand3(sd, i, 7) * 3.0) : 1.0 + floor(rand3(sd, i, 7) * 2.0);
	float tip = 0.0;
	for (int f = 14; f < 32; f++) {
		float g = fly_glow(f);
		if (g <= 0.25) continue;
		vec2 fp = fly_pos(f, t);
		float d = length(fp - vec2(x + sway, base - h));
		if (d < 28.0) tip = max(tip, g * (1.0 - d / 28.0));
	}
	p = vec2(x, base);
	cu = vec4(0.0, 0.0, h, sway);
	col = vec4(tone, tip, rand3(sd, i, 8) < 0.07 ? 1.0 : 0.0, 1.0);
	return true;
}

#include "res://addons/pixelfx_particles/fx/weather/_wx_place.gdshaderinc"
