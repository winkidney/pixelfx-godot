// slash-wipe.js draw(): the blade edge sweeping the cover in (sw_on: edge e, speed sp), the second cut's smear and its
// dotted trace (sm_on / tr_on: head, tail, age, Wc), and the two halves of the cover slipping and flying apart
// (h_on: each half's corners hp (6 a half, hc of them), its moved cut point ha, its cut face's normal hm, depth deep;
// heat). All keyed every frame from the original's formulas on its own clock.
uniform float sw_on = 0.0;
uniform float e = 0.0;
uniform float sp = 0.0;
uniform float h_on = 0.0;
uniform float heat = 0.0;
uniform vec2 hp[12];
uniform vec2 hc = vec2(0.0);
uniform vec2 ha[2];
uniform vec2 hb[2];
uniform vec2 hm[2];
uniform vec2 deep = vec2(1.0);
uniform vec2 sep = vec2(0.0);
uniform float sm_on = 0.0;
uniform float tr_on = 0.0;
uniform float head = 0.0;
uniform float tail = 0.0;
uniform float age = 0.0;
uniform float wc = 3.6;
// the cut: from A to B along (ux, uy), normal (nx, ny), LC long
uniform vec2 A = vec2(0.0);
uniform vec2 B = vec2(0.0);
uniform vec2 U = vec2(1.0, 0.0);
uniform vec2 NR = vec2(0.0, 1.0);
uniform float LC = 1.0;
uniform vec4 C[8] : source_color;
uniform vec4 ink : source_color;

const float SL = 0.55;
const float HALO = 18.0;

float sl_cs() {
	return 1.0 / sqrt(1.0 + SL * SL);
}

// _lib.js fillConvex(): whether pixel q is filled by half k's polygon
bool sl_in_half(vec2 q, int k) {
	float yc = q.y + 0.5;
	int n = int((k == 0 ? hc.x : hc.y) + 0.5);
	float xl = 1e9;
	float xr = -1e9;
	for (int i = 0; i < 6; i++) {
		if (i >= n) {
			break;
		}
		int j = i == 0 ? n - 1 : i - 1;
		vec2 pi = hp[k * 6 + i];
		vec2 pj = hp[k * 6 + j];
		if ((pi.y > yc) == (pj.y > yc)) {
			continue;
		}
		float x = pi.x + (yc - pi.y) * (pj.x - pi.x) / (pj.y - pi.y);
		xl = min(xl, x);
		xr = max(xr, x);
	}
	float c0 = max(0.0, ceil(xl - 0.5));
	float c1 = min(TR_W - 1.0, floor(xr - 0.5));
	return q.x >= c0 && q.x <= c1;
}

// the smear at pixel q: its colour step ci and alpha, or false
bool sl_smear(vec2 q, out int ci, out float al, out float qq) {
	float span = head - tail;
	float px = q.x + 0.5 - A.x;
	float py = q.y + 0.5 - A.y;
	float x0 = A.x + (q.y + 0.5 - A.y) * U.x / U.y;
	float hw = (wc + 1.0) / abs(NR.x);
	if (q.x < max(0.0, floor(x0 - hw)) || q.x >= min(TR_W, ceil(x0 + hw))) {
		return false;
	}
	float s = px * U.x + py * U.y;
	float v = (s - tail) / span;
	if (v < 0.0 || v > 1.0) {
		return false;
	}
	float w = wc * pow(sin(PI * pow(v, 2.2)), 0.6);
	if (w < 0.35) {
		return false;
	}
	qq = abs(px * NR.x + py * NR.y) / w;
	if (qq > 1.0) {
		return false;
	}
	ci = (qq < 0.34 && age < 0.5) ? 0 : int(floor(qq * 7.0 * 0.75 + age * 2.4 - v * 0.8 + 0.4 + 0.5));
	al = min(1.0, v / 0.4);
	return true;
}
