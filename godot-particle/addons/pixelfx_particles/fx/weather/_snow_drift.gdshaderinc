// weather/snow's drift (snow.js drift()): a lumpy bank with a white crest, blue shade below, and glints that
// twinkle on it. drift() gives a pixel's colour (alpha 0: none) and its light.
#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform vec2 size = vec2(320.0, 180.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform vec4 white : source_color = vec4(1.0);
uniform int seed = 6;

const float D = 12.0;

float bank(float x) {
	return -3.0 + 1.6 * sin(x * 0.045 + 1.3) + 1.1 * sin(x * 0.12 + 0.4) + 0.6 * sin(x * 0.31 + 2.0);
}

void drift(vec2 p, out vec4 c, out vec3 l) {
	c = vec4(0.0);
	l = vec3(0.0);
	if (p.y > -7.0 && p.y < 10.0) {
		float dd = p.y - bank(p.x);
		if (dd >= 0.0) {
			c = dd < 1.0 ? white : dd < 2.0 ? C[7] : dd < 3.5 ? C[6] : dd < 6.0 ? C[5] : C[4];
			if (dd < 1.0) l = C[6].rgb * 0.12;
		}
	}
	vec2 cell = floor(p);
	for (int i = 0; i < 18; i++) {
		float x = -156.0 + rand3(seed, i, 81) * 312.0;
		float cy = 1.0 + floor(rand3(seed, i, 82) * 3.0);
		float tw = sin((TAU * cy * t) / D + rand3(seed, i, 83) * TAU);
		if (tw < 0.55) continue;
		float y = ceil(bank(x)) + floor(rand3(seed, i, 84) * 3.0);
		float k = (tw - 0.55) / 0.45;
		vec2 g = floor(vec2(x, y));
		if (cell == g) c = white;
		else if (k > 0.5 && (cell == g + vec2(1.0, 0.0) || cell == g + vec2(-1.0, 0.0) || cell == g + vec2(0.0, -1.0))) c = C[6];
		l += C[6].rgb * glow_(p, vec2(x, y) + 0.5, 6.0, 0.35 * k);
	}
}
