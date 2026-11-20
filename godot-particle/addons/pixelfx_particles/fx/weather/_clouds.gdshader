// weather/clouds: where each cloud is (_clouds.gdshaderinc): the particle sits on the cloud's centre and base;
// CUSTOM.z = its index, .w = its base cell's row.
shader_type particles;
render_mode disable_velocity, disable_force;

#include "res://addons/pixelfx_particles/fx/weather/_clouds.gdshaderinc"

bool body(int g, out vec2 p, out vec4 cu, out vec4 col) {
	int j;
	int i;
	cloud_id(g, j, i);
	float grow;
	float w;
	float x0;
	float base;
	float H;
	bool on = cloud_state(j, i, grow, w, x0, base, H);
	p = floor(vec2(x0, base));
	cu = vec4(0.0, 0.0, float(g), 0.0);
	col = vec4(p, 0.0, 1.0);
	return on;
}

#include "res://addons/pixelfx_particles/fx/weather/_wx_place.gdshaderinc"
