// src/fx/ui/_lib.js panel(): a UI plate, a rounded rectangle with a dark outline, a lit top rim, a body that darkens
// towards the bottom, a shaded bottom edge and an optional diagonal shine. Which of its colours pixel centre pc takes:
// -1 none, 0 outline, 1 rim, 2 top, 3 body, 4 low, 5 white (the shine's core). rc: x, y, w, h (the original's
// floats); the original's shade() visits cells floor(x) .. ceil(x + w).
int panel_px(vec2 pc, vec4 rc, float r, bool has_shine, float shine) {
	float x = rc.x;
	float y = rc.y;
	float w = rc.z;
	float h = rc.w;
	if (w < 2.0 || h < 2.0) {
		return -1;
	}
	vec2 cell = floor(pc);
	float X1 = x + w;
	float Y1 = y + h;
	if (cell.x < floor(x) || cell.x > ceil(X1) || cell.y < floor(y) || cell.y > ceil(Y1)) {
		return -1;
	}
	float px = pc.x;
	float py = pc.y;
	float cx = max(max(x + r - px, 0.0), px - (X1 - r));
	float cy = max(max(y + r - py, 0.0), py - (Y1 - r));
	float e = (cx > 0.0 && cy > 0.0) ? r - length(vec2(cx, cy)) : min(min(px - x, X1 - px), min(py - y, Y1 - py));
	if (e < 0.0) {
		return -1;
	}
	if (e < 1.0) {
		return 0;
	}
	if (py - y < 2.0) {
		return 1;
	}
	if (Y1 - py < 2.0) {
		return 4;
	}
	if (has_shine) {
		float d = abs(px - (py - y) * 0.6 - shine);
		if (d < 1.3) {
			return 5;
		}
		if (d < 3.0) {
			return 1;
		}
	}
	return py - y < h * 0.45 ? 2 : 3;
}
