// weather/clouds' clouds (src/fx/weather/clouds.js cloud()): cloud g (0..17: 7 far, 6 middle, 5 near) is born once a
// loop, swells into shape, drifts and thins away; its outline a row of puffs on a flat base and a tier heaped in
// the middle. Shared by the process shader (where it is) and the canvas shader (its pixels).
#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform int seed = 7;

const float D = 12.0;
const float MX = 92.0;
const float MY = -128.0;
const vec2 LW[3] = vec2[](vec2(40.0, 70.0), vec2(60.0, 100.0), vec2(90.0, 140.0));
const vec2 LH[3] = vec2[](vec2(6.0, 11.0), vec2(9.0, 15.0), vec2(12.0, 20.0));
const vec2 LY[3] = vec2[](vec2(-150.0, -110.0), vec2(-120.0, -70.0), vec2(-80.0, -30.0));
const float LV[3] = float[](3.0, 6.0, 10.0);
const vec2 LL[3] = vec2[](vec2(8.0, 11.0), vec2(8.0, 11.0), vec2(9.0, 12.0));
const ivec4 LT[3] = ivec4[](ivec4(2, 3, 4, 5), ivec4(1, 2, 4, 6), ivec4(1, 2, 3, 6));
const float LA[3] = float[](0.7, 0.88, 1.0);

void cloud_id(int g, out int j, out int i) {
	j = g < 7 ? 0 : g < 13 ? 1 : 2;
	i = g < 7 ? g : g < 13 ? g - 7 : g - 13;
}

float CR(int j, int i, int k) {
	return rand4(seed, j, i, k);
}

// false while it's unborn or too thin to draw; else its grow, width, centre x0, base and puff height H
bool cloud_state(int j, int i, out float grow, out float w, out float x0, out float base, out float H) {
	float life = LL[j].x + CR(j, i, 1) * (LL[j].y - LL[j].x);
	float age = mod(t - CR(j, i, 2) * D, D);
	grow = 0.0;
	w = 0.0;
	x0 = 0.0;
	base = 0.0;
	H = 0.0;
	if (age >= life) {
		return false;
	}
	float u = age / life;
	grow = min(1.0, u * 4.0) * min(1.0, (1.0 - u) * 4.0);
	w = (LW[j].x + CR(j, i, 3) * (LW[j].y - LW[j].x)) * (0.6 + 0.4 * grow);
	x0 = -200.0 + CR(j, i, 4) * 330.0 + LV[j] * age;
	base = LY[j].x + CR(j, i, 5) * (LY[j].y - LY[j].x);
	H = (LH[j].x + CR(j, i, 6) * (LH[j].y - LH[j].x)) * grow;
	return H >= 1.5;
}
