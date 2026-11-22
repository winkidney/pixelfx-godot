// status/confused's spiral, seen from the front: an arm winding out from its heart (n segments, `turns` turns),
// spun by `rot` and breathing by `breathe` (keyed). at(u) is a point on it from the rect's middle; segments are walked
// as the original's p.line walks them (Bresenham between the cells the points fall in).
uniform vec2 size = vec2(24.0);
uniform vec2 center = vec2(0.0);
uniform float rot = 0.0;
uniform float breathe = 1.0;
uniform float turns = 1.8;

const int N = 72;

vec2 at(float u) {
	float th = u * turns * TAU - rot;
	float r = (0.8 + 6.6 * u) * breathe;
	return vec2(cos(th) * r, sin(th) * r * 0.9);
}

bool on_line(ivec2 p, ivec2 s, ivec2 e) {
	if (p.x < min(s.x, e.x) || p.x > max(s.x, e.x) || p.y < min(s.y, e.y) || p.y > max(s.y, e.y)) {
		return false;
	}
	int dx = abs(e.x - s.x);
	int dy = -abs(e.y - s.y);
	int stx = s.x < e.x ? 1 : -1;
	int sty = s.y < e.y ? 1 : -1;
	int err = dx + dy;
	for (int k = 0; k < 24; k++) {
		if (s == p) {
			return true;
		}
		if (s == e) {
			return false;
		}
		int e2 = 2 * err;
		if (e2 >= dy) {
			err += dy;
			s.x += stx;
		}
		if (e2 <= dx) {
			err += dx;
			s.y += sty;
		}
	}
	return false;
}

ivec2 cell_at(float u, vec2 off) {
	return ivec2(floor(at(u) + off));
}

ivec2 pixel_cell(vec2 uv) {
	return ivec2(floor(uv * size) - floor(size / 2.0));
}
