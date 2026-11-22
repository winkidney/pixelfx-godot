// The eclipse (after src/fx/shadow/eclipse.js), shared by its colour pass (_eclipse.gdshader) and light pass
// (_eclipse_light.gdshader). Coordinates are px from the moon's centre (the effect's origin); `t` runs 0..1 over the
// 4 s loop. streams[i] = (angle, length, curl, phase) of the original's 30 streamers; each breathes 1 + i % 3 times
// a loop.
uniform vec2 size = vec2(160.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform vec4 streams[30];

const float E_R = 19.0;
const float E_BEAD = -0.72;

float e_breathe(float k, float ph) {
	return sin(TAU * k * t + ph);
}

float e_b() {
	return 1.0 + 0.08 * e_breathe(1.0, 0.0);
}

float e_len(int i) {
	return streams[i].y * (1.0 + 0.18 * e_breathe(1.0 + float(i % 3), streams[i].w));
}

// the corona's level at a cell centre p: -1 none, 9 the white collar, otherwise I (the original's intensity)
float e_corona(vec2 p) {
	float b = e_b();
	float r = length(p);
	if (r < E_R - 0.5 || r > E_R + 9.0 * b) {
		return -1.0;
	}
	float a = atan(p.y, p.x);
	float e = (r - E_R) / (9.0 * b);
	float streak = 0.55 + 0.3 * cos(a * 23.0 + sin(a * 5.0) * 2.0) + 0.15 * cos(a * 41.0 - TAU * t);
	float I = pow(1.0 - e, 2.2) * streak * (0.75 + 0.4 * abs(cos(a)));
	if (r < E_R + 0.9) {
		return 9.0;
	}
	return I;
}

vec2 e_bead() {
	return vec2(cos(E_BEAD), sin(E_BEAD)) * (E_R + 0.4);
}

float e_bead_k() {
	return 0.75 + 0.25 * e_breathe(2.0, 1.0);
}
