// painter.js line() from cell a to cell b (whole cells): whether cell q is on it.
bool on_line(vec2 q, vec2 a, vec2 b) {
	int sx = int(a.x);
	int sy = int(a.y);
	int ex = int(b.x);
	int ey = int(b.y);
	int dx = abs(ex - sx);
	int dy = -abs(ey - sy);
	int stx = sx < ex ? 1 : -1;
	int sty = sy < ey ? 1 : -1;
	int err = dx + dy;
	ivec2 c = ivec2(q);
	for (int i = 0; i < 256; i++) {
		if (sx == c.x && sy == c.y) {
			return true;
		}
		if (sx == ex && sy == ey) {
			break;
		}
		int e2 = 2 * err;
		if (e2 >= dy) {
			err += dy;
			sx += stx;
		}
		if (e2 <= dx) {
			err += dx;
			sy += sty;
		}
	}
	return false;
}
