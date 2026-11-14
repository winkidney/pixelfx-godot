// A wave rolling in and crashing (water/wave-crash), shared by _wave.gdshader and _wave_light.gdshader: the
// original's curves for the swell's crest (where, how tall, how steep its face) and the lip it throws, all functions
// of `now` (seconds; key it). The lip's tip lands at `crash`.
uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float now = 0.0;
uniform float dur = 3.2;
uniform float seed = 6.0;

const float W_PI = 3.14159265359;
const float CRASH = 1.2;
const float LIP0 = 0.62;
const float EDGE = 110.0;

float in_out_sine(float x) {
	return -(cos(W_PI * x) - 1.0) / 2.0;
}

float wv_out_cubic(float x) {
	x = clamp(x, 0.0, 1.0);
	return 1.0 - (1.0 - x) * (1.0 - x) * (1.0 - x);
}

float crest_x(float t) {
	return t < CRASH ? -80.0 + 72.0 * in_out_sine(t / CRASH) : -8.0 + 30.0 * wv_out_cubic((t - CRASH) / 1.4);
}

float crest_h(float t) {
	return t < CRASH ? 5.0 + 33.0 * in_out_sine(clamp(t / (CRASH * 0.92), 0.0, 1.0))
		: 38.0 * (1.0 - wv_out_cubic((t - CRASH) / 0.45)) + 5.0 * (1.0 - smoothstep(CRASH, CRASH + 1.6, t));
}

float face_w(float t) {
	return t < CRASH ? 24.0 - 16.0 * smoothstep(0.3, CRASH, t) : 8.0 + 14.0 * smoothstep(CRASH, CRASH + 0.6, t);
}

float lip_k(float t) {
	return clamp((t - LIP0) / (CRASH - LIP0), 0.0, 1.0);
}

float swell(float x, float t) {
	float dx = x - crest_x(t);
	float w = dx < 0.0 ? 30.0 : face_w(t);
	return crest_h(t) * exp(-(dx / w) * (dx / w));
}

// a point on the lip at s (0 at the crest, 1 at its tip), and its thickness there
vec3 lip(float s, float t) {
	float k = lip_k(t);
	float A = crest_h(t);
	return vec3(crest_x(t) + 1.0 + s * 30.0 * pow(k, 0.8), -A - 4.0 * s * (1.0 - s) * (1.0 + 4.0 * k) + s * s * A * k * k * 0.98,
		(11.0 - 8.5 * s) * (0.5 + 0.5 * k));
}

float fade_k(float t) {
	return smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(dur - 0.7, dur - 0.1, t));
}

float wv_glow(vec2 p, vec2 c, float r) {
	float d = distance(p, c) / max(r, 1e-3);
	return d < 1.0 ? (1.0 - d) * (1.0 - d) : 0.0;
}
