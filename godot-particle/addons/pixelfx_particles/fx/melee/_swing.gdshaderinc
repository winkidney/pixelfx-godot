// A swing (melee/_lib.js swing()): a circle of radius R round sc, squashed to sy across its plane, turned by rot,
// swept from in-plane angle a0 in direction dir; kc lifts the band into a shallow cone (a point dr inside the rim sits
// kc * dr higher). Positions along it are u, radians from a0 in the swing's direction. The rect is drawn by build.gd
// shape(): `size` px centred on `center` (px from the effect's origin), so pixel centres are sw_px(UV).
uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec2 sc = vec2(0.0);
uniform float R = 30.0;
uniform float sy = 1.0;
uniform float rot = 0.0;
uniform float a0 = 0.0;
uniform float dir = 1.0;
uniform float kc = 0.0;
// 0: the whole band, -1: only its far half (behind a character), 1: only the near half
uniform float side = 0.0;

const float SW_TAU = 6.28318530718;

vec2 sw_px(vec2 uv) {
	return floor((uv - 0.5) * size) + 0.5 + center;
}

// the plane radius and in-plane angle under a point (the original's plane(), cone included)
vec2 sw_plane(vec2 p) {
	float c = cos(rot);
	float n = sin(rot);
	vec2 d = p - sc;
	float lx = d.x * c + d.y * n;
	float ly = -d.x * n + d.y * c;
	if (abs(kc) < 1e-6) {
		return vec2(length(vec2(lx, ly / sy)), atan(ly / sy, lx));
	}
	float m = ly + kc * R;
	float A = sy * sy - kc * kc;
	float B = 2.0 * m * kc;
	float Cc = lx * lx * sy * sy + m * m;
	float r = (-B + sqrt(B * B + 4.0 * A * Cc)) / (2.0 * A);
	return vec2(r, atan((m - kc * r) / sy, lx));
}

// the point at plane radius r, u radians along
vec2 sw_on(float r, float u) {
	float a = a0 + dir * u;
	float lx = cos(a) * r;
	float ly = sin(a) * r * sy - kc * (R - r);
	float c = cos(rot);
	float n = sin(rot);
	return sc + vec2(lx * c - ly * n, lx * n + ly * c);
}

// u for in-plane angle a: the first turn at or past u0, or -1 past u1
float sw_u(float a, float u0, float u1) {
	float u = mod(dir * (a - a0), SW_TAU);
	if (u < u0) {
		u += SW_TAU * ceil((u0 - u) / SW_TAU);
	}
	return u > u1 ? -1.0 : u;
}

bool sw_keep(float a, float half_) {
	return half_ == 0.0 || (sin(a) < 0.0 ? -1.0 : 1.0) == half_;
}

// The original's trace(): dots every `step_` px at plane radius r from u0 to u1, each in the pixel cell holding it.
// Returns the u of the dot landing in the cell `cell` (its top-left corner), or -1.
float sw_trace(vec2 cell, float r, float u0, float u1, float step_, float half_) {
	if (u1 < u0) {
		return -1.0;
	}
	float du = step_ / max(4.0, r);
	vec2 pa = sw_plane(cell + 0.5);
	float up = mod(dir * (pa.y - a0), SW_TAU);
	float best = -1.0;
	for (int turn = -1; turn <= 1; turn++) {
		float uu = up + float(turn) * SW_TAU;
		if (uu < u0 - 0.5 || uu > u1 + 0.5) {
			continue;
		}
		float i0 = floor((uu - u0) / du);
		for (int j = -12; j <= 12; j++) {
			float i = i0 + float(j);
			if (i < 0.0) {
				continue;
			}
			float u = u0 + i * du;
			if (u > u1 + 1e-5) {
				break;
			}
			if (!sw_keep(a0 + dir * u, half_)) {
				continue;
			}
			vec2 q = floor(sw_on(r, u));
			if (q == cell) {
				best = u;
			}
		}
	}
	return best;
}
