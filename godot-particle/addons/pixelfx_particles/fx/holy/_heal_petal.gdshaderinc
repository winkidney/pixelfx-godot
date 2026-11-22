// Shared by the heal's petal shaders: petal k of the lotus round the feet at time t: rooted on a ring on the floor,
// leaning out as it opens (bloom b, keyed per petal), foreshortened as it turns away.
const float SY = 0.3;
const int NP = 8;
uniform float t = 0.0;
// per petal: its angle on the ring at t = 0, its width, its bloom now (0..1.2)
uniform float pa[8];
uniform float pw[8];
uniform float pb[8];

// base (xy) and tip (zw) of petal k; near: on the near side of the ring
vec4 petal_at(int k, out float b, out bool near) {
	float g = pa[k] + t * 0.4;
	b = pb[k];
	near = sin(g) >= 0.0;
	float rb = 6.0;
	float rt = rb + 9.0 * min(1.2, b);
	float h = (k % 2 == 1 ? 7.0 : 9.0) * b;
	return vec4(cos(g) * rb, sin(g) * rb * SY, cos(g) * rt, sin(g) * rt * SY - h);
}
