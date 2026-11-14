// Shared by the scifi effects' canvas shaders, light ones included: the original's easings (src/core/math.js
// ease), its 1 px lines on whole cells, its glow falloff (painter.js glow / glowLine).

float e_out_cubic(float x) {
	x = clamp(x, 0.0, 1.0);
	return 1.0 - pow(1.0 - x, 3.0);
}

float e_in_cubic(float x) {
	x = clamp(x, 0.0, 1.0);
	return x * x * x;
}

float e_in_quad(float x) {
	x = clamp(x, 0.0, 1.0);
	return x * x;
}

float e_out_quad(float x) {
	x = clamp(x, 0.0, 1.0);
	return 1.0 - (1.0 - x) * (1.0 - x);
}

float e_in_out_sine(float x) {
	x = clamp(x, 0.0, 1.0);
	return -(cos(PI * x) - 1.0) / 2.0;
}

float e_out_back(float x, float s) {
	if (x <= 0.0) {
		return 0.0;
	}
	if (x >= 1.0) {
		return 1.0;
	}
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0);
}

float e_out_expo(float x) {
	return x >= 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * x);
}

float e_smooth(float a, float b, float x) {
	float u = clamp((x - a) / (b - a), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

// whether cell d is on the 1 px line from cell a to cell b (one pixel per step along the longer axis)
bool cell_on_line(vec2 d, vec2 a, vec2 b) {
	vec2 e = b - a;
	if (abs(e.x) >= abs(e.y)) {
		if (abs(e.x) < 0.5) {
			return all(equal(d, a));
		}
		if (d.x < min(a.x, b.x) - 0.1 || d.x > max(a.x, b.x) + 0.1) {
			return false;
		}
		float y = a.y + e.y * (d.x - a.x) / e.x;
		return abs(d.y - floor(y + 0.5)) < 0.1;
	}
	if (d.y < min(a.y, b.y) - 0.1 || d.y > max(a.y, b.y) + 0.1) {
		return false;
	}
	float x = a.x + e.x * (d.y - a.y) / e.y;
	return abs(d.x - floor(x + 0.5)) < 0.1;
}

// the original's line(x0, y0, x1, y1): from the cell under the first point to the cell under the second
bool on_seg(vec2 cell, vec2 p0, vec2 p1) {
	return cell_on_line(cell, floor(p0), floor(p1));
}

// painter.js glow(): (1 - d / r)^2 at a pixel centre `pc` from a light at `at`
float glow_at(vec2 pc, vec2 at, float r) {
	if (r < 1.0) {
		return 0.0;
	}
	float f = 1.0 - length(pc - at) / r;
	return f > 0.0 ? f * f : 0.0;
}

// painter.js glowLine()
float glow_seg(vec2 pc, vec2 a, vec2 b, float r) {
	if (r < 1.0) {
		return 0.0;
	}
	vec2 e = b - a;
	float u = clamp(dot(pc - a, e) / max(dot(e, e), 1e-9), 0.0, 1.0);
	float f = 1.0 - length(a + e * u - pc) / r;
	return f > 0.0 ? f * f : 0.0;
}

// a modulo that is never negative (the GPU's % on a negative int isn't the original's: it reads it unsigned)
int imod(int a, int b) {
	return a - b * int(floor(float(a) / float(b)));
}
