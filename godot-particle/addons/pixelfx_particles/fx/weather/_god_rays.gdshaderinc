// weather/god-rays' shafts (src/fx/weather/god-rays.js shafts(), lightAt()): six shafts fanning down from a sun high
// on the left, each breathing and swaying on whole cycles, threaded with strands that drift across them.
#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform int seed = 3;

const float D = 10.0;
const float SX = -230.0;
const float SY = -300.0;
const float AX = 0.5897880250310983;
const float AY = 0.8075581004051142;
// c, h, k, b, sw
const float SC[6] = float[](-0.27, -0.17, -0.07, 0.03, 0.12, 0.23);
const float SH[6] = float[](0.03, 0.022, 0.05, 0.018, 0.042, 0.026);
const float SK[6] = float[](0.65, 0.55, 1.0, 0.6, 0.85, 0.6);
const float SB[6] = float[](1.0, 2.0, 1.0, 3.0, 2.0, 1.0);
const float SW[6] = float[](0.006, 0.005, 0.008, 0.004, 0.007, 0.005);

float strand(int i) {
	float a = float(i) / 512.0;
	float S = float(seed);
	return 0.5 + 0.5 * sin(a * 190.0 + sin((TAU * t) / D) * 2.0 + S) * sin(a * 77.0 - (TAU * t) / D + S * 2.0);
}

// the shafts' light at angle `ang` off the fan's axis (before falloff and strands)
float shafts_e(float ang) {
	float e = 0.0;
	for (int j = 0; j < 6; j++) {
		float fj = float(j);
		float c = SC[j] + SW[j] * sin((TAU * t) / D + fj * 1.3);
		float h = SH[j] * (1.0 + 0.15 * sin((TAU * SB[j] * t) / D + fj));
		float k = SK[j] * (0.72 + 0.28 * sin((TAU * SB[j] * t) / D + fj * 2.1));
		float q = (ang - c) / h;
		if (q > -1.0 && q < 1.0) {
			float w = 1.0 - q * q;
			e += k * w * sqrt(w);
		}
	}
	return e;
}

// god-rays.js lightAt(): what a mote at (x, y) catches
float light_at(vec2 p) {
	float dx = p.x - SX;
	float dy = p.y - SY;
	float r = dx * AX + dy * AY;
	float ang = (dx * -AY + dy * AX) / r;
	float e = shafts_e(ang);
	if (e <= 0.0) {
		return 0.0;
	}
	float s = strand(int(clamp(floor((ang + 0.36) * 700.0), 0.0, 511.0)));
	float fall = clamp(1.25 - (r - 230.0) / 420.0, 0.0, 1.0);
	return e * fall * (0.7 + 0.45 * s);
}
