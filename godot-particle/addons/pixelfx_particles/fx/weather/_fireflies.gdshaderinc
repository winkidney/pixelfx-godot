// weather/fireflies' flies (src/fx/weather/fireflies.js fly()): fly i's path (whole cycles a loop plus a looping
// noise) and its glow (a quick rise, a hold, a slow fade, dark; some flash twice). depth 0 far (0..13), 1 (14..25),
// 2 near (26..31).
#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform int seed = 2;

const float D = 12.0;

float cyc(float tt, float n, float ph) {
	return (TAU * n * tt) / D + ph;
}

float noise2(float x, float y, int sd) {
	float ix = floor(x);
	float iy = floor(y);
	float fx = x - ix;
	float fy = y - iy;
	float ux = fx * fx * (3.0 - 2.0 * fx);
	float uy = fy * fy * (3.0 - 2.0 * fy);
	int a = int(ix);
	int b = int(iy);
	float n00 = rand3(a, b, sd);
	float n10 = rand3(a + 1, b, sd);
	float n01 = rand3(a, b + 1, sd);
	float n11 = rand3(a + 1, b + 1, sd);
	return mix(mix(n00, n10, ux), mix(n01, n11, ux), uy) * 2.0 - 1.0;
}

float loop_noise(float phase, float r, int sd) {
	float a = phase * TAU;
	return noise2(cos(a) * r + 50.0, sin(a) * r + 50.0, sd);
}

int fly_depth(int i) {
	return i < 14 ? 0 : i < 26 ? 1 : 2;
}

vec2 fly_pos(int i, float tt) {
	int S = seed;
	int depth = fly_depth(i);
	float k = depth == 0 ? 0.5 : depth == 1 ? 0.8 : 1.0;
	float cx = -150.0 + rand3(S, i, 1) * 300.0;
	float cy = -16.0 - rand3(S, i, 2) * (depth == 2 ? 70.0 : 130.0);
	float ax = (14.0 + rand3(S, i, 3) * 26.0) * k;
	float ay = (8.0 + rand3(S, i, 4) * 14.0) * k;
	float n1 = 1.0 + floor(rand3(S, i, 5) * 2.0);
	float n2 = 1.0 + floor(rand3(S, i, 6) * 3.0);
	return vec2(cx + ax * sin(cyc(tt, n1, rand3(S, i, 7) * TAU)) + 10.0 * k * loop_noise(tt / D, 1.5, i * 3),
		cy + ay * sin(cyc(tt, n2, rand3(S, i, 8) * TAU)) + 6.0 * k * loop_noise(tt / D, 1.5, i * 3 + 1));
}

float pulse(float v) {
	return v < 0.06 ? v / 0.06 : v < 0.14 ? 1.0 : v < 0.4 ? 1.0 - (v - 0.14) / 0.26 : 0.0;
}

float fly_glow(int i) {
	int S = seed;
	float per = D / (3.0 + floor(rand3(S, i, 9) * 4.0));
	float u = fract(t / per + rand3(S, i, 10));
	bool two = rand3(S, i, 11) < 0.35;
	return max(pulse(u), two ? pulse(u - 0.22) * 0.8 : 0.0);
}
