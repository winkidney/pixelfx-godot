// The originals' deterministic randomness (src/core/math.js) on the GPU, exact: hash(a, b[, c]) and the mulberry32
// generator rng(...) seeds (uint arithmetic wraps like Math.imul). For particle process shaders that place every
// particle where the original's cycle() / burst() puts it.
uint js_mix(uint h, uint n) {
	h = (h ^ n) * 0x85ebca6bu;
	h ^= h >> 13u;
	h *= 0xc2b2ae35u;
	h ^= h >> 16u;
	return h;
}

uint js_hash2(int a, int b) {
	return js_mix(js_mix(0x9e3779b9u, uint(a)), uint(b));
}

uint js_hash3(int a, int b, int c) {
	return js_mix(js_mix(js_mix(0x9e3779b9u, uint(a)), uint(b)), uint(c));
}

float js_next(inout uint s) {
	s += 0x6d2b79f5u;
	uint q = s;
	q = (q ^ (q >> 15u)) * (q | 1u);
	q ^= q + (q ^ (q >> 7u)) * (q | 61u);
	return float(q ^ (q >> 14u)) / 4294967296.0;
}

float js_range(inout uint s, float a, float b) {
	return a + (b - a) * js_next(s);
}

// the original's cycle(t, period, count, seed, life range): particle i's age at time T (s), or -1 while it is unborn
// or dead; L gets its life
float js_cycle(int seed, int i, float T, float period, float l0, float l1, out float L) {
	uint g = js_hash3(seed, i, 911);
	float born = js_next(g) * period;
	L = js_range(g, l0, l1);
	float age = mod(T - born, period);
	return age < L ? age : -1.0;
}
