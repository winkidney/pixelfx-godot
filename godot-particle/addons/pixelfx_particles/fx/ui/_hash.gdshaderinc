// src/core/math.js hash(), rand(), noise(), noise2(): the original's integer hash (Math.imul wraps as uint products do)
// and its value noise, for shaders that re-roll what the original re-rolls every frame.
uint js_hash_step(uint h, int n) {
	h = (h ^ uint(n)) * 0x85ebca6bu;
	h ^= h >> 13u;
	h *= 0xc2b2ae35u;
	h ^= h >> 16u;
	return h;
}

float js_rand2(int a, int b) {
	return float(js_hash_step(js_hash_step(0x9e3779b9u, a), b)) / 4294967296.0;
}

float js_rand3(int a, int b, int c) {
	return float(js_hash_step(js_hash_step(js_hash_step(0x9e3779b9u, a), b), c)) / 4294967296.0;
}

float js_noise(float x, int seed) {
	float i = floor(x);
	float f = x - i;
	float u = f * f * (3.0 - 2.0 * f);
	return mix(js_rand2(int(i), seed), js_rand2(int(i) + 1, seed), u) * 2.0 - 1.0;
}

float js_noise2(float x, float y, int seed) {
	float ix = floor(x);
	float iy = floor(y);
	float fx = x - ix;
	float fy = y - iy;
	float ux = fx * fx * (3.0 - 2.0 * fx);
	float uy = fy * fy * (3.0 - 2.0 * fy);
	float a = js_rand3(int(ix), int(iy), seed);
	float b = js_rand3(int(ix) + 1, int(iy), seed);
	float c = js_rand3(int(ix), int(iy) + 1, seed);
	float d = js_rand3(int(ix) + 1, int(iy) + 1, seed);
	return mix(mix(a, b, ux), mix(c, d, ux), uy) * 2.0 - 1.0;
}
