// Shared by the laser grid's shaders (src/fx/scifi/laser-grid.js): the beams at the clock `t` (three sliding between
// the posts, two sweepers from the posts' heads to the floor), the distance from a point to one, where two cross,
// and the original's tileNoise / tileFbm (needs _jsrand.gdshaderinc). Declare `t` first.

const float D = 3.0;
const float PX = 48.0;
const float TOP = -64.0;
const float IN = 44.0;

float sweep_x(float tt, float s) {
	return s * (34.0 - 68.0 * (0.5 - 0.5 * cos(TAU * (tt / D) + (s > 0.0 ? 0.0 : 1.9))));
}

float slide_y(float tt, int i) {
	vec4 b = i == 0 ? vec4(-14.0, 8.0, 1.0, 0.0) : i == 1 ? vec4(-31.0, 12.0, 2.0, 1.3) : vec4(-48.0, 9.0, 1.0, 3.6);
	return b.x + b.y * sin(TAU * b.z * (tt / D) + b.w);
}

// beam i (0..4) at time tt: x0, y0, x1, y1
vec4 beam(float tt, int i) {
	if (i < 3) {
		float y = slide_y(tt, i);
		return vec4(-IN, y, IN, y);
	}
	float s = i == 3 ? -1.0 : 1.0;
	return vec4(s * IN, TOP + 6.0, sweep_x(tt, s), 0.0);
}

float near_beam(vec4 b, vec2 p) {
	vec2 a = b.xy;
	vec2 e = b.zw - b.xy;
	float u = clamp(dot(p - a, e) / dot(e, e), 0.0, 1.0);
	return length(a + e * u - p);
}

bool cross_at(vec4 a, vec4 b, out vec2 c) {
	float d = (a.x - a.z) * (b.y - b.w) - (a.y - a.w) * (b.x - b.z);
	if (abs(d) < 1e-6) {
		return false;
	}
	float u = ((a.x - b.x) * (b.y - b.w) - (a.y - b.y) * (b.x - b.z)) / d;
	float v = -((a.x - a.z) * (a.y - b.y) - (a.y - a.w) * (a.x - b.x)) / d;
	c = vec2(a.x + u * (a.z - a.x), a.y + u * (a.w - a.y));
	return u >= 0.0 && u <= 1.0 && v >= 0.0 && v <= 1.0;
}

int wrapi(int i, int p) {
	return p > 0 ? imod(i, p) : i;
}

float tile_noise(float x, float y, int px, int py, int sd) {
	float ix = floor(x);
	float iy = floor(y);
	float fx = x - ix;
	float fy = y - iy;
	float ux = fx * fx * (3.0 - 2.0 * fx);
	float uy = fy * fy * (3.0 - 2.0 * fy);
	int x0 = wrapi(int(ix), px);
	int x1 = wrapi(int(ix) + 1, px);
	int y0 = wrapi(int(iy), py);
	int y1 = wrapi(int(iy) + 1, py);
	float a = float(js_hash3(x0, y0, sd)) / 4294967296.0;
	float b = float(js_hash3(x1, y0, sd)) / 4294967296.0;
	float c = float(js_hash3(x0, y1, sd)) / 4294967296.0;
	float d = float(js_hash3(x1, y1, sd)) / 4294967296.0;
	return mix(mix(a, b, ux), mix(c, d, ux), uy) * 2.0 - 1.0;
}

float tile_fbm(float x, float y, int px, int py, int sd, int oct) {
	float s = 0.0;
	float a = 0.5;
	float n = 0.0;
	int k = 1;
	for (int o = 0; o < 4; o++) {
		if (o >= oct) {
			break;
		}
		s += tile_noise(x * float(k), y * float(k), px * k, py * k, sd + o * 101) * a;
		n += a;
		a *= 0.5;
		k *= 2;
	}
	return s / n;
}
