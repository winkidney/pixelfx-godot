// Shared by the weather shaders (build/fx/weather/_weather.gd): the originals' randomness (src/core/math.js hash /
// rand, exact on uints), their whole-loop helpers (src/fx/weather/_lib.js trips(), field() sampling, the local
// Bayer threshold) and math.js smooth(). Every weather loop is a pure function of the effect's clock `t` (seconds),
// keyed by the animation, so a particle or a pixel is placed from t alone and the loop has no seam.

// the effect's clock (seconds), keyed by the animation
uniform float t = 0.0;

uint wx_mix(uint h, uint n) {
	h = (h ^ n) * 0x85ebca6bu;
	h ^= h >> 13u;
	h *= 0xc2b2ae35u;
	h ^= h >> 16u;
	return h;
}

float wx_u(uint h) {
	return float(h >> 8u) / 16777216.0;
}

float rand2(int a, int b) {
	return wx_u(wx_mix(wx_mix(0x9e3779b9u, uint(a)), uint(b)));
}

float rand3(int a, int b, int c) {
	return wx_u(wx_mix(wx_mix(wx_mix(0x9e3779b9u, uint(a)), uint(b)), uint(c)));
}

uint hash4(int a, int b, int c, int d) {
	return wx_mix(wx_mix(wx_mix(wx_mix(0x9e3779b9u, uint(a)), uint(b)), uint(c)), uint(d));
}

float rand4(int a, int b, int c, int d) {
	return wx_u(wx_mix(wx_mix(wx_mix(wx_mix(0x9e3779b9u, uint(a)), uint(b)), uint(c)), uint(d)));
}

int imod(int a, int b) {
	return a - b * int(floor(float(a) / float(b)));
}

float smooth_(float e0, float e1, float x) {
	float u = clamp((x - e0) / (e1 - e0), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

// _lib.js trips(): slot i of n falls m times a loop (m0..m1); u is how far through its fall, k which fall (wrap it by m)
void trip(float tt, float D, int i, int sd, int m0, int m1, out float u, out int k, out int m) {
	m = m0 + int(floor(rand3(sd, i, 72) * float(m1 - m0 + 1)));
	float s = (tt / D) * float(m) + rand3(sd, i, 71);
	k = int(floor(s));
	u = s - floor(s);
}

const float WX_BAYER[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);

// _lib.js bayer(x, y) on the effect's local coordinates
float bayer_(float x, float y) {
	int ix = int(floor(x)) & 3;
	int iy = int(floor(y)) & 3;
	return (WX_BAYER[iy * 4 + ix] + 0.5) / 16.0;
}

// _lib.js sample(F, u, v): a baked field (an R float texture, w x h, powers of two), wrapping, bilinear between cells
float fsample(sampler2D F, float u, float v) {
	ivec2 sz = textureSize(F, 0);
	float x = floor(u);
	float y = floor(v);
	float fx = u - x;
	float fy = v - y;
	int xi = int(x);
	int yi = int(y);
	int m = sz.x - 1;
	int n = sz.y - 1;
	int x0 = xi & m;
	int x1 = (xi + 1) & m;
	int y0 = yi & n;
	int y1 = (yi + 1) & n;
	float a = texelFetch(F, ivec2(x0, y0), 0).r;
	float b = texelFetch(F, ivec2(x1, y0), 0).r;
	float c = texelFetch(F, ivec2(x0, y1), 0).r;
	float e = texelFetch(F, ivec2(x1, y1), 0).r;
	return a + (b - a) * fx + (c - a + (a - b - c + e) * fx) * fy;
}

// painter.js glow(): the light at a pixel centre p from a glow at c, radius r, strength k
float glow_(vec2 p, vec2 c, float r, float k) {
	if (r < 1.0 || k <= 0.004) {
		return 0.0;
	}
	vec2 d = (p - c) / r;
	float q = dot(d, d);
	if (q >= 1.0) {
		return 0.0;
	}
	float f = 1.0 - sqrt(q);
	return f * f * k;
}
