// holy/resurrection: the shaft of light's shape, shared by its colour and light passes. `t` is seconds into the
// effect (keyed); ray[i] = (offset, width, brightness, shimmer rate), ray_ph[i] its phase (the original's rays).
uniform vec2 size = vec2(80.0, 144.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform vec4 ray[6];
uniform float ray_ph[6];

const float TOP = -140.0;
const float POUR = 0.34;

float r_seg(float x, float a, float b) {
	return clamp((x - a) / (b - a), 0.0, 1.0);
}

float r_smooth(float a, float b, float x) {
	float u = r_seg(x, a, b);
	return u * u * (3.0 - 2.0 * u);
}

float shaft_k() {
	return r_smooth(0.0, 0.12, t) * (1.0 - r_smooth(3.0, 3.75, t));
}

float shaft_w() {
	float a = 1.0 - pow(1.0 - r_seg(t, 0.0, 0.6), 3.0);
	float b = pow(r_seg(t, 2.9, 3.6), 3.0);
	return mix(0.4, 1.0, a) * mix(1.0, 0.12, b);
}

float half_w(float y) {
	return mix(8.0, 25.0, (y - TOP) / -TOP) * shaft_w();
}

float front_y() {
	float u = r_seg(t, 0.0, POUR);
	return mix(TOP, 1.0, u * u);
}

// the original's profile[] (121 samples over q in -1.5..1.5) at q
float profile(float q) {
	float qi = (round(q * 40.0)) / 40.0;
	float I = 0.0;
	for (int i = 0; i < 6; i++) {
		float d = (qi - ray[i].x) / ray[i].y;
		I += ray[i].z * exp(-d * d) * (0.72 + 0.28 * sin(t * ray[i].w + ray_ph[i]));
	}
	return (I * 0.6 + 0.35 * max(0.0, 1.0 - qi * qi)) * r_smooth(1.25, 0.7, abs(qi));
}

// how bright the shaft is at local p (0 outside it)
float shaft_at(vec2 p) {
	float k = shaft_k();
	if (k <= 0.0) {
		return 0.0;
	}
	float front = front_y();
	float w0 = half_w(0.0) * 1.3;
	if (p.y < TOP || p.y > min(front, 0.5) || abs(p.x) > w0 + 1.0) {
		return 0.0;
	}
	float w = half_w(p.y);
	float q = p.x / w;
	if (q < -1.5 || q > 1.5) {
		return 0.0;
	}
	return profile(q) * k * (0.75 + 0.25 * r_smooth(TOP, 0.0, p.y)) * r_smooth(front, front - 10.0, p.y);
}
