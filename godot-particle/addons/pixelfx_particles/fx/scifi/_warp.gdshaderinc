// Shared by the warp shaders (src/fx/scifi/warp-in.js, warp-out.js): the stand-in's mask (`tex`, feet at the origin),
// sim.js band() worked out per pixel (a ring on the floor, th px thick, the ramp's brightest step at its rim) and the
// original's sparkle(). Declare `pal` first; include after pixel.gdshaderinc and _scifi.gdshaderinc.

const int AX = -12;
const int AY = -38;
const int AW = 24;
const int AH = 38;

bool on_body(ivec2 p) {
	ivec2 q = p - ivec2(AX, AY);
	if (q.x < 0 || q.y < 0 || q.x >= AW || q.y >= AH) {
		return false;
	}
	return texelFetch(tex, q, 0).a > 0.5;
}

vec4 body_px(ivec2 p) {
	return texelFetch(tex, p - ivec2(AX, AY), 0);
}

// sim.js band(cx, cy, r, sy, th, k, ramp, keep, hot): side 1 the near half (sin >= 0), -1 the far, 0 all of it
void band_at(inout vec4 c, ivec2 P, vec2 cen, float rr, float sy, float th, float k, vec4 r0, vec4 r1, vec4 r2, vec4 r3, int side, bool hot, float thr) {
	if (rr <= 0.0 || k <= 0.0) {
		return;
	}
	vec2 pc = vec2(P) + 0.5 - cen;
	if (abs(pc.y) > rr * sy + 2.0 || abs(pc.x) > rr + 2.0) {
		return;
	}
	int m = int(ceil(rr * TAU * 1.2));
	float ang = atan(pc.y / max(sy, 1e-4), pc.x);
	if (ang < 0.0) {
		ang += TAU;
	}
	int j0 = int(floor(ang / TAU * float(m)));
	for (int dj = -5; dj <= 5; dj++) {
		int jj = imod(j0 + dj, m);
		float a = float(jj) / float(m) * TAU;
		float sa = sin(a);
		if ((side > 0 && sa < 0.0) || (side < 0 && sa >= 0.0)) {
			continue;
		}
		for (float o = th; o >= -1e-4; o -= 0.5) {
			float u = o / th;
			vec2 p = cen + vec2(cos(a) * (rr - o), sa * (rr - o) * sy);
			if (all(equal(floor(p), vec2(P)))) {
				float al = k * (u < 0.4 ? 1.2 : 1.15 - u);
				if (al >= thr) {
					c = u < 0.15 ? (hot ? vec4(1.0) : r3) : u < 0.4 ? r2 : u < 0.7 ? r1 : r0;
				}
			}
		}
	}
}

// sim.js sparkle(): arms `arm` px (rounded) round the cell under `at`, in c with tips in tip, a white heart
void sparkle_at(inout vec4 c, ivec2 P, vec2 at, float arm, vec4 cc, vec4 tip) {
	int n = int(floor(arm + 0.5));
	if (n < 1) {
		return;
	}
	ivec2 d = P - ivec2(floor(at));
	int ax = abs(d.x);
	int ay = abs(d.y);
	if (d == ivec2(0)) {
		c = vec4(1.0);
	} else if ((d.x == 0 && ay <= n) || (d.y == 0 && ax <= n)) {
		c = float(max(ax, ay)) > float(n) * 0.6 ? tip : cc;
	} else if (n >= 3 && ax == 1 && ay == 1) {
		c = cc;
	} else if (n >= 6 && ax == 2 && ay == 2) {
		c = tip;
	}
}
