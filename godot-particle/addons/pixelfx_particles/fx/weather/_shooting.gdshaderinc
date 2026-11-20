// weather/shooting-stars (src/fx/weather/shooting-stars.js): the starfield's stars and the meteors. Shared by the
// process shader and the canvas shaders.
#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_sparkle.gdshaderinc"

uniform int seed = 4;

const float D = 10.0;
const float TRAIN = 1.6;
// t0, x, y, a / v, life, s, flare
const vec4 MA[7] = vec4[](vec4(0.5, 60.0, -170.0, 2.45), vec4(1.9, -40.0, -176.0, 2.2), vec4(3.4, 150.0, -150.0, 2.62),
	vec4(4.6, 130.0, -178.0, 2.35), vec4(6.7, -90.0, -168.0, 2.05), vec4(7.9, 20.0, -160.0, 2.5), vec4(9.2, -10.0, -176.0, 2.28));
const vec4 MB[7] = vec4[](vec4(260.0, 0.55, 0.6, 0.0), vec4(220.0, 0.7, 0.8, 0.0), vec4(300.0, 0.45, 0.5, 0.0),
	vec4(240.0, 1.05, 1.4, 1.0), vec4(200.0, 0.6, 0.7, 0.0), vec4(280.0, 0.5, 0.6, 0.0), vec4(230.0, 0.8, 1.0, 1.0));

float meteor_age(int i) {
	return mod(t - MA[i].x, D);
}

float meteor_end(int i) {
	return MB[i].y + (MB[i].w > 0.5 ? 0.5 : 0.0) + TRAIN;
}

vec2 meteor_head(int i, float age) {
	float burn = min(age, MB[i].y);
	return MA[i].yz + vec2(cos(MA[i].w), sin(MA[i].w)) * MB[i].x * burn;
}
