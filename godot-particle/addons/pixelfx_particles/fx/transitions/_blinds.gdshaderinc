// blinds.js: twelve slats turning shut top to bottom and open again, keyed with the original's own clock `t`.
uniform float t = 0.0;
uniform vec4 C[8] : source_color;
uniform vec4 ink : source_color;

const float N = 12.0;
const float SH = 15.0;
const float SHUT0 = 0.08;
const float OPEN0 = 1.02;
const float STEP = 0.038;
const float TURN = 0.42;
const float OSTEP = 0.03;
const float OTURN = 0.4;
const float FADE0 = 1.72;
const float FADE1 = 1.94;

float bl_out_back(float x, float s) {
	if (x <= 0.0) {
		return 0.0;
	}
	if (x >= 1.0) {
		return 1.0;
	}
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0);
}

float bl_in_out_cubic(float x) {
	return x < 0.5 ? 4.0 * x * x * x : 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0;
}

// how far slat i has turned: 0 edge-on, PI / 2 flat and shut
float bl_angle(float i) {
	if (t < OPEN0) {
		return (PI / 2.0) * bl_out_back(clamp((t - SHUT0 - i * STEP) / TURN, 0.0, 1.0), 1.6);
	}
	return (PI / 2.0) * (1.0 - bl_in_out_cubic(clamp((t - OPEN0 - i * OSTEP) / OTURN, 0.0, 1.0)));
}

// slat i: its turn, its height on screen and the rows it covers
void bl_slat(float i, out float th, out float h, out float y0, out float y1) {
	th = bl_angle(i);
	h = max(1.0, (SH + 1.0) * abs(sin(th)));
	float yc = (i + 0.5) * SH;
	y0 = max(0.0, ceil(yc - h / 2.0 - 0.5));
	y1 = min(TR_H - 1.0, floor(yc + h / 2.0 - 0.5));
}
