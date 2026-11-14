// Shared by the holy pillar's fan shaders: the light of the shafts at a pixel. Each shaft unfolds from the middle
// with an overshoot, pours down from the sky, pulses while it holds, folds shut and lifts away, on the original's
// clock (`t` in seconds, keyed). sh[i] = (spread angle, widening, brightness, pulse offset), far[i] = 0 middle..1.
uniform float t = 0.0;
uniform int n = 7;
uniform vec4 sh[7];
uniform float far[7];

const float TOP = -204.0;
const float PY = -1.0;
const float OPEN = 0.3;
const float HIT = 0.66;
const float FOLD = 2.05;
const float SHUT = 2.45;
const float LIFT = 2.75;
const float DMAX = 203.0;

float seg(float x, float a, float b) {
	return clamp((x - a) / (b - a), 0.0, 1.0);
}

float out_back(float x, float s) {
	return x <= 0.0 ? 0.0 : x >= 1.0 ? 1.0 : 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0);
}

float in_out_cubic(float x) {
	return x < 0.5 ? 4.0 * x * x * x : 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0;
}

float fan_fade() {
	return smoothstep(OPEN, OPEN + 0.1, t) * (1.0 - smoothstep(LIFT - 0.05, LIFT + 0.05, t));
}

// x: the summed light at p; y: the brightest core line through this pixel (0..255)
vec2 fan_at(vec2 p) {
	float k = fan_fade();
	float dy = PY - p.y;
	if (k <= 0.0 || dy <= 0.0) {
		return vec2(0.0);
	}
	float lift = DMAX * pow(seg(t, SHUT + 0.05, LIFT), 2.0);
	float I = 0.0;
	float core = 0.0;
	for (int i = 0; i < n; i++) {
		float st = far[i] * 0.1;
		float a = sh[i].x * out_back(seg(t, OPEN + st, OPEN + st + 0.42), 1.5) * (1.0 - in_out_cubic(seg(t, FOLD - far[i] * 0.1, SHUT)));
		float ca = cos(a);
		float d = dy / ca;
		float front = DMAX * (1.0 - pow(seg(t, OPEN + far[i] * 0.06, HIT + far[i] * 0.06), 2.0));
		if (d < lift || d < front - 6.0) {
			continue;
		}
		float xc = tan(a) * dy;
		float hw = (1.4 + d * sh[i].y) * mix(1.0, 0.25, smoothstep(SHUT, LIFT, t)) / 2.0 / ca;
		float soft = smoothstep(front - 6.0, front + 4.0, d) * smoothstep(lift, lift + 6.0, d);
		float pulse = 1.0;
		if (t >= HIT && t <= SHUT) {
			float D = DMAX * (1.0 - fract((t - HIT) / 0.6 + sh[i].w));
			float e = (d - D) / 12.0;
			pulse = 1.0 + 0.9 * exp(-e * e);
		}
		float I0 = sh[i].z * pulse * soft * k;
		float v = (p.x - xc) / hw;
		if (abs(v) < 1.0) {
			I += I0 * pow(1.0 - v * v, 1.3);
		}
		if (floor(p.x) == round(xc - 0.5)) {
			core = max(core, min(255.0, I0 * 200.0));
		}
	}
	return vec2(I, core);
}
