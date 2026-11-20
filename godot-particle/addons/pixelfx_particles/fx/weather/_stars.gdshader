// A night sky's stars (weather/shooting-stars sky(), weather/aurora stars()): star i at a hashed place, twinkling on
// whole cycles: a dim speck (r < 0.6), a steady point (r < cut), or a little glint. CUSTOM.z what it is, .w its
// twinkle; COLOR.x which steady colour (r >= sel: the second). Drawn by _star.gdshader.
shader_type particles;
render_mode disable_velocity, disable_force;

#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform int seed = 4;
uniform float D = 10.0;
uniform float ylen = 178.0;
uniform float cut = 0.94;
uniform float sel = 0.8;

bool body(int i, out vec2 p, out vec4 cu, out vec4 col) {
	int S = seed;
	p = vec2(-160.0 + rand3(S, i, 1) * 320.0, -180.0 + rand3(S, i, 2) * ylen);
	float r = rand3(S, i, 3);
	float c = 1.0 + floor(rand3(S, i, 4) * 4.0);
	float tw = 0.5 + 0.5 * sin((TAU * c * t) / D + rand3(S, i, 5) * TAU);
	cu = vec4(0.0, 0.0, r < 0.6 ? 0.0 : r < cut ? 1.0 : 2.0, tw);
	col = vec4(r < sel ? 0.0 : 1.0, 0.0, 0.0, 1.0);
	return true;
}

#include "res://addons/pixelfx_particles/fx/weather/_wx_place.gdshaderinc"
