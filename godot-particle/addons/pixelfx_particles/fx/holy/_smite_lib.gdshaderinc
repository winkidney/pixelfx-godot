// Shared by the smite and holy-pillar shaders: the originals' 1 px lines (a DDA between the cells of the two ends),
// 1 px ovals (dots stepped round an ellipse), capsule beams and glows.

// true when `cell` (a pixel's floor) is on the 1 px line from a to b; u: 0 at a .. 1 at b
bool smite_on_line(vec2 cell, vec2 a, vec2 b, out float u) {
	vec2 ca = floor(a);
	vec2 cb = floor(b);
	vec2 d = cb - ca;
	u = 0.0;
	if (abs(d.x) < 0.5 && abs(d.y) < 0.5) {
		return cell == ca;
	}
	if (abs(d.x) >= abs(d.y)) {
		float s = (cell.x - ca.x) / d.x;
		if (s < -1e-4 || s > 1.0 + 1e-4) {
			return false;
		}
		u = s;
		return floor(ca.y + d.y * s + 0.5) == cell.y;
	}
	float s = (cell.y - ca.y) / d.y;
	if (s < -1e-4 || s > 1.0 + 1e-4) {
		return false;
	}
	u = s;
	return floor(ca.x + d.x * s + 0.5) == cell.x;
}

// the original's glow(x, y, r): k (1 - d / r)^2, measured from the pixel's centre
float smite_glow(vec2 p, vec2 at, float r) {
	float f = 1.0 - length(p - at) / max(r, 0.001);
	return f > 0.0 ? f * f : 0.0;
}

// the original's glowLine(a, b, r): (1 - distance to the segment / r)^2
float smite_glow_seg(vec2 p, vec2 a, vec2 b, float r) {
	vec2 ab = b - a;
	float u = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
	float f = 1.0 - length(a + ab * u - p) / max(r, 0.001);
	return f > 0.0 ? f * f : 0.0;
}
