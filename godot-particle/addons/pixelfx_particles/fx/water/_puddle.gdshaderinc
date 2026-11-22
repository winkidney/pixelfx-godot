// A low close-up on one puddle in the rain (water/rain-splash), shared by _puddle.gdshader and
// _puddle_light.gdshader. Eight big drops land on it, each on its own beat (drop_a: x, z, landing time, spin;
// drop_b: crown height, jet height; tips: each crown finger's length), throwing a crown of fingers and a rebound jet,
// a ring spreading from each; the water's swell sums every ring so crests catch the light and crossings beat; a lamp's
// reflection wobbles on it, pushed about by the swell. Key `t` 0 -> 1 over the loop.
uniform vec2 size = vec2(184.0, 80.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float dur = 2.4;
uniform float sy = 0.3;
uniform float rx = 92.0;
uniform float lamp = 34.0;
uniform vec4 drop_a[8];
uniform vec2 drop_b[8];
uniform float tips[80];

const float P_TAU = 6.28318530718;
const float P_PI = 3.14159265359;

float age_of(int i) {
	return mod(t * dur - drop_a[i].z, dur);
}

float ring_r(float a) {
	return 3.0 + 34.0 * pow(a / 1.8, 0.7);
}

float ring_k(float a) {
	return a < 1.8 ? 1.3 * pow(1.0 - a / 1.8, 1.3) * min(1.0, a / 0.06) : 0.0;
}

float crown_h(float a, float H) {
	return a < 0.3 ? H * pow(sin(P_PI * clamp(a / 0.3, 0.0, 1.0)), 0.8) : 0.0;
}

float crown_r(float a) {
	return 1.5 + 4.5 * sqrt(clamp(a / 0.3, 0.0, 1.0));
}

float jet_h(float a, float J) {
	return (a > 0.26 && a < 0.56) ? J * sin(P_PI * (a - 0.26) / 0.3) : 0.0;
}

// the swell at (x, z): every live ring's crest summed
float field(float x, float z) {
	float h = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = age_of(i);
		if (a >= 1.8) {
			continue;
		}
		float R = ring_r(a);
		float d = length(vec2(x - drop_a[i].x, z - drop_a[i].y)) - R;
		float w = 3.6 + a * 3.0;
		if (d > 2.0 * w || d < -3.0 * w) {
			continue;
		}
		h += ring_k(a) * cos(d * 1.1) * exp(-(d / w) * (d / w));
	}
	return h;
}

// the lamp's reflection at pixel p: 0 outside its dash, else how strongly
float lamp_k(vec2 p) {
	float ry = rx * sy;
	float d = (p.x / rx) * (p.x / rx) + (p.y / ry) * (p.y / ry);
	if (d > 1.0 || p.x < lamp - 14.0 || p.x > lamp + 14.0) {
		return 0.0;
	}
	float Y = floor(p.y);
	float far = (p.y + ry) / (2.0 * ry);
	float ph = t;
	float dash = (1.5 + far * 4.0) * (0.35 + 0.65 * (0.5 + 0.5 * sin(Y * 1.73 + ph * P_TAU * 3.0 + sin(Y * 0.61) * 3.0)));
	float z = p.y / sy;
	float hx = field(p.x, z) - field(p.x - 1.0, z);
	float lx = abs(p.x - lamp - hx * 9.0 - sin(p.y * 0.8 + ph * P_TAU * 2.0) * 1.4);
	if (lx >= dash) {
		return 0.0;
	}
	return (1.0 - lx / dash) * min(1.0, (1.0 - d) * 6.0);
}

// a 1 px line from cell a to cell b (as the original rasterises them): true when pixel p is on it, u along it
bool on_line(vec2 a, vec2 b, vec2 p, out float u) {
	vec2 A = floor(a);
	vec2 B = floor(b);
	vec2 P = floor(p);
	vec2 d = B - A;
	float n = max(max(abs(d.x), abs(d.y)), 1.0);
	u = 0.0;
	if (abs(d.x) >= abs(d.y)) {
		float i = (P.x - A.x) * sign(d.x == 0.0 ? 1.0 : d.x);
		if (i < 0.0 || i > n) {
			return false;
		}
		u = i / n;
		return P.y == A.y + floor(d.y * i / n + 0.5);
	}
	float i = (P.y - A.y) * sign(d.y);
	if (i < 0.0 || i > n) {
		return false;
	}
	u = i / n;
	return P.x == A.x + floor(d.x * i / n + 0.5);
}
