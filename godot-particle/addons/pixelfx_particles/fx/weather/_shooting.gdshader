// weather/shooting-stars' meteors, each sitting on its head while it burns and its train glows (CUSTOM.z its index;
// COLOR.xy its head's cell). Drawn by _meteor.gdshader.
shader_type particles;
render_mode disable_velocity, disable_force;

#include "res://addons/pixelfx_particles/fx/weather/_shooting.gdshaderinc"

bool body(int i, out vec2 p, out vec4 cu, out vec4 col) {
	p = vec2(0.0);
	cu = vec4(0.0);
	col = vec4(0.0);
	float age = meteor_age(i);
	if (age > meteor_end(i)) {
		return false;
	}
	p = floor(meteor_head(i, age));
	cu = vec4(0.0, 0.0, float(i), 0.0);
	col = vec4(p, 0.0, 1.0);
	return true;
}

#include "res://addons/pixelfx_particles/fx/weather/_wx_place.gdshaderinc"
