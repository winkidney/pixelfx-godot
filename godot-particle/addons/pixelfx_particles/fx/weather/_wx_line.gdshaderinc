// painter.js line(): whether cell q is on the 1 px Bresenham line from cell a to cell b, and how far along (u: step
// / steps, as the original hands its colour and alpha functions).
bool on_line(vec2 qf, vec2 af, vec2 bf, out float u) {
	ivec2 q = ivec2(qf);
	ivec2 a = ivec2(af);
	ivec2 b = ivec2(bf);
	u = 0.0;
	int dx = abs(b.x - a.x);
	int dy = -abs(b.y - a.y);
	int sx = a.x < b.x ? 1 : -1;
	int sy = a.y < b.y ? 1 : -1;
	int n = max(max(dx, -dy), 1);
	if (q.x < min(a.x, b.x) || q.x > max(a.x, b.x) || q.y < min(a.y, b.y) || q.y > max(a.y, b.y)) {
		return false;
	}
	int err = dx + dy;
	ivec2 c = a;
	for (int i = 0; i < 96; i++) {
		if (c == q) {
			u = float(i) / float(n);
			return true;
		}
		if (c == b) {
			break;
		}
		int e2 = 2 * err;
		if (e2 >= dy) {
			err += dy;
			c.x += sx;
		}
		if (e2 <= dx) {
			err += dx;
			c.y += sy;
		}
	}
	return false;
}
