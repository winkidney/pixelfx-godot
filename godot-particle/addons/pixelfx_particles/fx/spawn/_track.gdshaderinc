// Shared by the canvas shaders of the spawn effects' tracked particles (_track.gdshader moves them): the particle's
// header and rows of `data` for this sample, and where this fragment's pixel is. CUSTOM: (index, sample, exact x, y).
//   tk_cell: this pixel's cell from the particle's cell (whole px); tk_abs: in the effect's coordinates; tk_q: this
//   pixel's centre from the particle's exact position (the original tests pixel centres); tk_fr: where the particle
//   sits inside its cell.
uniform sampler2D data : filter_nearest, repeat_disable;
uniform float rows = 1.0;
uniform float head = 1.0;
uniform float width = 2048.0;
uniform vec2 quad = vec2(9.0);

varying flat vec4 tk_cu;

vec4 tk_fetch(int l) {
	int w = int(width + 0.5);
	return texelFetch(data, ivec2(l % w, l / w), 0);
}

vec4 tk_head(int h) {
	return tk_fetch(int(tk_cu.x + 0.5) * int(head + 0.5) + h);
}

vec4 tk_row(int r) {
	vec4 h = tk_head(0);
	return tk_fetch(int(h.z + 0.5) + (int(tk_cu.y + 0.5) - int(h.x + 0.5)) * int(rows + 0.5) + r);
}

vec2 tk_pos() {
	return tk_cu.zw;
}

vec2 tk_cell(vec2 uv) {
	return floor((uv - 0.5) * quad + 0.5);
}

vec2 tk_fr() {
	return tk_cu.zw - floor(tk_cu.zw);
}

// this pixel's cell in the effect's coordinates (the particle's exact position is row 0's xy)
vec2 tk_abs(vec2 uv) {
	return floor(tk_cu.zw) + tk_cell(uv);
}

vec2 tk_q(vec2 uv) {
	return tk_cell(uv) + 0.5 - tk_fr();
}

// the original's disc(): pixel centres within r of c (px from the particle); under half a pixel, just c's cell
bool tk_disc(vec2 uv, vec2 c, float r) {
	if (r < 0.5) {
		return all(equal(tk_cell(uv), floor(tk_fr() + c)));
	}
	vec2 d = tk_q(uv) - c;
	return dot(d, d) <= r * r;
}

vec4 tk_over(vec4 dst, vec3 c, float a) {
	if (a <= 0.004) {
		return dst;
	}
	float oa = a + dst.a * (1.0 - a);
	float k = a / oa;
	return vec4(c * k + dst.rgb * (1.0 - k), oa);
}

// the original's line() between cells a and b (px from the particle's cell), Bresenham-like: -1 when this cell isn't
// on it, else u (0 at a .. 1 at b)
float tk_line(vec2 d, vec2 a, vec2 b) {
	vec2 e = b - a;
	float n = max(abs(e.x), abs(e.y));
	if (n < 0.5) {
		return all(equal(d, a)) ? 0.0 : -1.0;
	}
	if (abs(e.x) >= abs(e.y)) {
		if (d.x < min(a.x, b.x) - 0.1 || d.x > max(a.x, b.x) + 0.1) {
			return -1.0;
		}
		float y = a.y + e.y * (d.x - a.x) / e.x;
		return abs(d.y - floor(y + 0.5)) < 0.1 ? abs(d.x - a.x) / n : -1.0;
	}
	if (d.y < min(a.y, b.y) - 0.1 || d.y > max(a.y, b.y) + 0.1) {
		return -1.0;
	}
	float x = a.x + e.x * (d.y - a.y) / e.y;
	return abs(d.x - floor(x + 0.5)) < 0.1 ? abs(d.y - a.y) / n : -1.0;
}

// the original's glow(): (1 - d / r)^2 at pixel centres
float tk_glow(vec2 q, vec2 c, float r) {
	if (r < 1.0) {
		return 0.0;
	}
	float f = 1.0 - length(q - c) / r;
	return f > 0.0 ? f * f : 0.0;
}

// the original's glowLine(): (1 - d / r)^2 round the segment a..b
float tk_glow_line(vec2 q, vec2 a, vec2 b, float r) {
	if (r < 1.0) {
		return 0.0;
	}
	vec2 e = b - a;
	float u = clamp(dot(q - a, e) / max(dot(e, e), 1e-9), 0.0, 1.0);
	float f = 1.0 - length(a + e * u - q) / r;
	return f > 0.0 ? f * f : 0.0;
}

