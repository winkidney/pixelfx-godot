// weather/rain (src/fx/weather/rain.js): its puddles (pools(): five long strips on the wet floor that hold the sky).
#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform int seed = 4;

const float D = 8.0;
const float SLANT = -0.2;

// pool i: x0, x1, y
vec3 pool(int i) {
	float x = -150.0 + float(i) * 66.0 + rand3(seed, i, 61) * 30.0;
	return vec3(x, x + 16.0 + rand3(seed, i, 63) * 26.0, 3.0 + floor(rand3(seed, i, 62) * 3.0));
}

// poolAt(): the puddle a drop at (x, y) lands in, -1 if none
int pool_at(float x, float y) {
	for (int i = 0; i < 5; i++) {
		vec3 p = pool(i);
		if (x >= p.x + 2.0 && x <= p.y - 2.0 && abs(y - p.z) < 1.5) return i;
	}
	return -1;
}
