// Shared by the water shaders (fx/water/_*.gdshader): the water ramp as a uniform (deep to white, the original's
// WATER), value noise like the original's (smooth, in -1..1, seeded) and a tileable version for fields that must
// repeat over the loop. Coordinates are px from a shape's centre, pixel centres at .5 as in the original.
// (no source_color hint: shape() hands colour arrays over as PackedVector4Array, which a hinted array drops)
uniform vec4 pal[8];

float w_hash(float i, float s) {
	return fract(sin(i * 127.1 + s * 311.7 + 0.5) * 43758.5453);
}

float w_hash2(vec2 i, float s) {
	return fract(sin(dot(i, vec2(127.1, 311.7)) + s * 74.7 + 0.5) * 43758.5453);
}

// smooth 1D value noise in -1..1
float w_noise(float x, float s) {
	float i = floor(x);
	float f = x - i;
	float u = f * f * (3.0 - 2.0 * f);
	return mix(w_hash(i, s), w_hash(i + 1.0, s), u) * 2.0 - 1.0;
}

// smooth 2D value noise in -1..1; px: the lattice repeats every px cells across (0: never)
float w_noise2p(vec2 p, float s, float px) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	vec2 i1 = i + 1.0;
	if (px > 0.0) {
		i.x = mod(i.x, px);
		i1.x = mod(i1.x, px);
	}
	float a = w_hash2(vec2(i.x, i.y), s);
	float b = w_hash2(vec2(i1.x, i.y), s);
	float c = w_hash2(vec2(i.x, i1.y), s);
	float d = w_hash2(vec2(i1.x, i1.y), s);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 2.0 - 1.0;
}

float w_noise2(vec2 p, float s) {
	return w_noise2p(p, s, 0.0);
}

// the ramp step for u in 0..1 (no blending: pixel art picks a colour)
vec4 w_at(float u) {
	return pal[clamp(int(floor(u * 8.0)), 0, 7)];
}

// the original's rand(a, b[, c]): its integer hash, exactly (uint arithmetic wraps as Math.imul does)
uint w_mix(uint h, int n) {
	h = (h ^ uint(n)) * 0x85ebca6bu;
	h ^= h >> 13u;
	h *= 0xc2b2ae35u;
	h ^= h >> 16u;
	return h;
}

float js_rand2(int a, int b) {
	return float(w_mix(w_mix(0x9e3779b9u, a), b)) / 4294967296.0;
}

float js_rand3(int a, int b, int c) {
	return float(w_mix(w_mix(w_mix(0x9e3779b9u, a), b), c)) / 4294967296.0;
}

// the original's noise(x, seed) and noise2(x, y, seed), exactly
float js_noise(float x, int s) {
	float i = floor(x);
	float f = x - i;
	float u = f * f * (3.0 - 2.0 * f);
	return mix(js_rand2(int(i), s), js_rand2(int(i) + 1, s), u) * 2.0 - 1.0;
}

float js_noise2(vec2 p, int s) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	int ix = int(i.x);
	int iy = int(i.y);
	float a = js_rand3(ix, iy, s);
	float b = js_rand3(ix + 1, iy, s);
	float c = js_rand3(ix, iy + 1, s);
	float d = js_rand3(ix + 1, iy + 1, s);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 2.0 - 1.0;
}

// the original's tileNoise(x, y, px, py, seed): value noise whose lattice repeats every px cells across and py down
// (0: no repeat), exactly
float js_tile(float x, float y, float px, float py, int s) {
	float ix = floor(x);
	float iy = floor(y);
	float fx = x - ix;
	float fy = y - iy;
	float ux = fx * fx * (3.0 - 2.0 * fx);
	float uy = fy * fy * (3.0 - 2.0 * fy);
	float x0 = px > 0.0 ? mod(ix, px) : ix;
	float x1 = px > 0.0 ? mod(ix + 1.0, px) : ix + 1.0;
	float y0 = py > 0.0 ? mod(iy, py) : iy;
	float y1 = py > 0.0 ? mod(iy + 1.0, py) : iy + 1.0;
	float a = js_rand3(int(x0), int(y0), s);
	float b = js_rand3(int(x1), int(y0), s);
	float c = js_rand3(int(x0), int(y1), s);
	float d = js_rand3(int(x1), int(y1), s);
	return mix(mix(a, b, ux), mix(c, d, ux), uy) * 2.0 - 1.0;
}
