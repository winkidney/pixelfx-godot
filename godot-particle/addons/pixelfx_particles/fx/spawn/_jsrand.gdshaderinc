// The original's hash() / rand() (src/core/math.js), bit for bit on 32-bit unsigned ints.
uint js_hash_step(uint h, int n) {
	h = (h ^ uint(n)) * 2246822507u;
	h ^= h >> 13u;
	h *= 3266489909u;
	h ^= h >> 16u;
	return h;
}

float js_rand2(int a, int b) {
	uint h = js_hash_step(js_hash_step(2654435769u, a), b);
	return float(h >> 8u) / 16777216.0;
}

float js_rand3(int a, int b, int c) {
	uint h = js_hash_step(js_hash_step(js_hash_step(2654435769u, a), b), c);
	return float(h >> 8u) / 16777216.0;
}

// math.js noise(x, seed): smooth 1D value noise in [-1, 1]
float js_noise(float x, int sd) {
	float i = floor(x);
	float f = x - i;
	float u = f * f * (3.0 - 2.0 * f);
	return mix(js_rand2(int(i), sd), js_rand2(int(i) + 1, sd), u) * 2.0 - 1.0;
}
