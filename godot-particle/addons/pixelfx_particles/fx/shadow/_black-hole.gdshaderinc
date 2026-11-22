// The black hole (after src/fx/shadow/black-hole.js hole()), shared by its colour pass (_black-hole.gdshader) and
// light pass (_black-hole_light.gdshader): a tilted disk of banded rings, ray by ray: the near half straight in front,
// the far half seen through the bend (an arch over the hole and a thin second image under it), the shadow and the
// photon ring at its edge. Coordinates are px from the effect's origin; `t` runs 0..1 over the 4 s loop.
uniform vec2 size = vec2(128.0, 84.0);
uniform vec2 center = vec2(0.0, -70.0);
uniform float t = 0.0;

const float BH_Y = -70.0;
const float BH_RS = 13.5;
const float BH_E = 17.5;
const float BH_SI = 0.25;
const float BH_SI_ARCH = 0.46;
const float BH_TILT = -0.14;

float bh_pulse() {
	return pow(max(0.0, cos(TAU * 2.0 * t)), 12.0);
}

// the disk's brightness at (X, Z) of its plane: x = I (-1: no band there), y = doppler (-X / rho)
vec2 bh_disk(float X, float Z) {
	float rho = length(vec2(X, Z));
	vec4 bands[4] = vec4[](vec4(18.0, 24.0, 5.0, 1.35), vec4(26.0, 34.0, 3.0, 0.92), vec4(35.5, 46.0, 2.0, 0.64), vec4(47.5, 60.0, 1.0, 0.42));
	float ks[4] = float[](0.3, 1.9, 3.7, 5.2);
	for (int i = 0; i < 4; i++) {
		vec4 b = bands[i];
		if (rho < b.x || rho > b.y) {
			continue;
		}
		float k = ks[i];
		float w = (rho - b.x) / (b.y - b.x);
		float ph = atan(Z, X) - TAU * b.z * t;
		float streak = 0.62 + 0.22 * cos(7.0 * ph + rho * 0.8 + k) + 0.16 * cos(13.0 * ph - rho * 1.6 + k * 2.0);
		float lane = 0.72 + 0.28 * cos(rho * 2.3 + k);
		float edge = smoothstep(0.0, 0.18, w) * (1.0 - smoothstep(0.78, 1.0, w));
		return vec2(b.w * streak * lane * (0.35 + 0.65 * edge), -X / rho);
	}
	return vec2(-1.0, 0.0);
}

// what the hole draws at cell centre p: 0 nothing, 1 shadow, 2 photon ring (ring_f set), 3 disk (s set).
// unlit: inside the original's unlight() mask (the shadow, where no disk passes in front)
int bh_hole(vec2 p, out vec2 s, out float ring_f, out bool unlit) {
	float dx = p.x;
	float dy = p.y - BH_Y;
	float ct = cos(BH_TILT);
	float st = sin(BH_TILT);
	float u = dx * ct + dy * st;
	float v = -dx * st + dy * ct;
	float r = length(vec2(u, v));
	s = vec2(-1.0, 0.0);
	ring_f = 0.0;
	bool front = false;
	if (v > 0.0) {
		s = bh_disk(u, -v / BH_SI);
		front = s.x >= 0.0;
	}
	unlit = r * r < (BH_RS - 0.6) * (BH_RS - 0.6) && !front;
	if (s.x < 0.0 && r > BH_RS) {
		float k = 1.0 - (BH_E * BH_E) / (r * r);
		float bu = u * k;
		float bv = v * k;
		float si = k > 0.0 ? BH_SI_ARCH : BH_SI;
		if (-bv / si > 0.0) {
			s = bh_disk(bu, -bv / si);
		}
	}
	if (s.x < 0.06) {
		if (r < BH_RS - 0.4) {
			return 1;
		}
		if (r < BH_RS + 0.7) {
			float a = atan(v, u);
			ring_f = 0.5 + 0.5 * cos(3.0 * a + TAU * 2.0 * t) + bh_pulse() * 0.4;
			return 2;
		}
		return 0;
	}
	return 3;
}
