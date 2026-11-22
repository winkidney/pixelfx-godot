// The originals' noise, bit for bit where it matters: math.js hash / rand (Math.imul as uint maths) and tileNoise,
// and _lib.js lnoise (smooth noise in -1..1 repeating every D seconds, F bumps a loop).

uint js_hash_step(uint h, int n) {
	h = (h ^ uint(n)) * 0x85ebca6bu;
	h ^= h >> 13u;
	h *= 0xc2b2ae35u;
	h ^= h >> 16u;
	return h;
}

float js_rand3(int a, int b, int c) {
	uint h = js_hash_step(js_hash_step(js_hash_step(0x9e3779b9u, a), b), c);
	return float(h >> 8u) / 16777216.0;
}

int js_wrapi(int a, int m) {
	return a - m * int(floor(float(a) / float(m)));
}

// math.js tileNoise(x, y, px, 0, seed) (repeating every px cells in x; seed truncated as JS `| 0` does)
float js_tile_noise(float x, float y, int px, float seed) {
	float ix = floor(x);
	float iy = floor(y);
	float fx = x - ix;
	float fy = y - iy;
	float ux = fx * fx * (3.0 - 2.0 * fx);
	float uy = fy * fy * (3.0 - 2.0 * fy);
	int x0 = px > 0 ? js_wrapi(int(ix), px) : int(ix);
	int x1 = px > 0 ? js_wrapi(int(ix) + 1, px) : int(ix) + 1;
	int y0 = int(iy);
	int y1 = y0 + 1;
	int s = int(seed);
	float a = js_rand3(x0, y0, s);
	float b = js_rand3(x1, y0, s);
	float c = js_rand3(x0, y1, s);
	float d = js_rand3(x1, y1, s);
	return mix(mix(a, b, ux), mix(c, d, ux), uy) * 2.0 - 1.0;
}

float js_lnoise(float t, float D, float F, float off, float seed) {
	return js_tile_noise((t / D) * F + off, 0.5, int(F + 0.5), seed);
}
