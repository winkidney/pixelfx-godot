// status/burning's maths, bit for bit with the original (src/core/math.js, src/fx/status/_lib.js): rand(...ns) as a
// 32-bit hash, the looping value noise wnoise / tnoise, Math.round.
uint b_mix(uint h, int n) {
	h = (h ^ uint(n)) * 0x85ebca6bu;
	h ^= h >> 13u;
	h *= 0xc2b2ae35u;
	h ^= h >> 16u;
	return h;
}

float b_rand2(int a, int b) {
	return float(b_mix(b_mix(0x9e3779b9u, a), b)) / 4294967296.0;
}

float b_rand3(int a, int b, int c) {
	return float(b_mix(b_mix(b_mix(0x9e3779b9u, a), b), c)) / 4294967296.0;
}

float b_round(float x) {
	return floor(x + 0.5);
}

// 1D value noise in [-1, 1] whose lattice wraps every P cells
float b_wnoise(float x, int P, int seed) {
	float fi = floor(x);
	float f = x - fi;
	float u = f * f * (3.0 - 2.0 * f);
	int i = int(fi);
	float a = b_rand2(((i % P) + P) % P, seed);
	float b = b_rand2((((i + 1) % P) + P) % P, seed);
	return (a + (b - a) * u) * 2.0 - 1.0;
}

// noise of time t repeating every D seconds, about f wiggles a second, slid by off
float b_tnoise(float t, float D, float f, int seed, float off) {
	int P = max(2, int(b_round(f * D)));
	return b_wnoise(t / D * float(P) + off, P, seed);
}
