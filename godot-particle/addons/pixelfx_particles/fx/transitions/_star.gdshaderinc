// star-iris.js draw(): the dark outside a five-point star (its ten points `pts`, keyed every frame from the original's
// curve) and the gold rim stroked along each edge out into the dark. mode: 0 nothing, 1 all ink, 2 the star.
uniform float mode = 0.0;
uniform vec2 pts[10];
uniform vec4 C[8] : source_color;
uniform vec4 ink : source_color;

const float RW = 4.0;

float st_round(float x) {
	return floor(x + 0.5);
}

// whether the row-span fill leaves pixel px in the dark
bool st_ink(vec2 px) {
	float yc = px.y + 0.5;
	float xs[10];
	int n = 0;
	for (int i = 0; i < 10; i++) {
		int j = i == 0 ? 9 : i - 1;
		vec2 a = pts[i];
		vec2 b = pts[j];
		if ((a.y > yc) != (b.y > yc)) {
			xs[n] = a.x + (yc - a.y) * (b.x - a.x) / (b.y - a.y);
			n++;
		}
	}
	for (int i = 1; i < 10; i++) {
		if (i >= n) {
			break;
		}
		float v = xs[i];
		int k = i - 1;
		while (k >= 0 && xs[k] > v) {
			xs[k + 1] = xs[k];
			k--;
		}
		xs[k + 1] = v;
	}
	float x = 0.0;
	for (int k = 0; k + 1 < n; k += 2) {
		float a = clamp(st_round(xs[k]), 0.0, TR_W);
		if (a > x && px.x >= x && px.x < a) {
			return true;
		}
		x = max(x, clamp(st_round(xs[k + 1]), 0.0, TR_W));
	}
	return px.x >= x;
}

// the rim: the last stroke dot that lands on cell q (colour index: 8 white, else C[i]); -1 none. lights: how many
// of the edges' light dots land on it
int st_rim(vec2 q, out int lights) {
	lights = 0;
	int res = -1;
	for (int i = 0; i < 10; i++) {
		int j = i == 0 ? 9 : i - 1;
		vec2 a = pts[j];
		vec2 b = pts[i];
		float L = length(b - a);
		if (L < 0.5) {
			continue;
		}
		vec2 u = (b - a) / L;
		vec2 nr = vec2(-u.y, u.x);
		bool lit = nr.x * -0.6 + nr.y * -0.8 > 0.1;
		vec2 o = q + 0.5 - a;
		float s = dot(o, u);
		float d = dot(o, nr);
		if (d < -1.5 || d > RW + 1.0 || s < -2.0 || s > L + 2.0) {
			continue;
		}
		int k0 = max(0, int(floor((s - 1.6) * 2.0)));
		int k1 = min(int(floor(L * 2.0 + 1e-4)), int(ceil((s + 1.6) * 2.0)));
		for (int k = k0; k <= k1; k++) {
			float sx = float(k) * 0.5;
			vec2 p0 = a + u * sx;
			if (p0.x < -RW || p0.y < -RW || p0.x > TR_W + RW || p0.y > TR_H + RW) {
				continue;
			}
			for (int m = 0; m < 8; m++) {
				float dd = float(m) * 0.5;
				if (all(equal(floor(p0 + nr * dd), q))) {
					res = dd < 1.0 ? (lit ? 8 : 6) : dd < 2.0 ? 5 : dd < 3.0 ? 4 : 3;
				}
			}
			if (k % 4 == 0 && all(equal(floor(p0), q))) {
				lights++;
			}
		}
	}
	return res;
}
