// A geyser (water/geyser), shared by _geyser.gdshader and _geyser_light.gdshader: the original's clock, all of it a
// function of `now` (seconds since it started; key it): a pool that heaves and burbles, spurts while it builds, the
// blast at `erupt`, a column `hmax` px tall holding with a churning head, falling apart at `fall` and gone at `gone`.
uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float now = 0.0;
uniform float hmax = 100.0;
uniform float seed = 4.0;
uniform float sy = 0.22;

const float G_TAU = 6.28318530718;
const float G_PI = 3.14159265359;
const float GG = 820.0;
const float ERUPT = 1.15;
const float FALL = 2.6;
const float GONE = 3.3;

float g_out_cubic(float x) {
	x = clamp(x, 0.0, 1.0);
	return 1.0 - (1.0 - x) * (1.0 - x) * (1.0 - x);
}

float g_in_quad(float x) {
	x = clamp(x, 0.0, 1.0);
	return x * x;
}

float pool_r(float t) {
	return (12.0 + 7.0 * smoothstep(0.0, 1.0, t) + 15.0 * g_out_cubic((t - ERUPT) / 1.2)) * (1.0 - 0.25 * smoothstep(GONE, 4.6, t));
}

float pool_k(float t) {
	return smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(4.0, 4.85, t));
}

float top_h(float t) {
	if (t < ERUPT || t > GONE) {
		return 0.0;
	}
	return hmax * g_out_cubic((t - ERUPT) / 0.3) * (0.93 + 0.07 * js_noise(t * 2.2, int(seed))) * (1.0 - g_in_quad((t - FALL) / (GONE - FALL)));
}

float head_k(float t) {
	return smoothstep(ERUPT + 0.08, ERUPT + 0.3, t) * (1.0 - smoothstep(FALL + 0.1, FALL + 0.45, t));
}

float thin_k(float t) {
	return smoothstep(ERUPT, ERUPT + 0.12, t) * (1.0 - 0.55 * smoothstep(FALL, GONE, t));
}

float spurt_h(float t) {
	float s0[6] = float[](0.46, 0.72, 0.92, 1.04, GONE + 0.15, GONE + 0.55);
	float hs[6] = float[](7.0, 12.0, 9.0, 15.0, 15.0, 8.0);
	float h = 0.0;
	for (int i = 0; i < 6; i++) {
		h = max(h, hs[i] * sin(G_PI * clamp((t - s0[i]) / 0.2, 0.0, 1.0)));
	}
	return h;
}

// the soft light round a point and along a segment (the original's glow and glowLine)
float g_glow(vec2 p, vec2 c, float r) {
	float d = distance(p, c) / max(r, 1e-3);
	return d < 1.0 ? (1.0 - d) * (1.0 - d) : 0.0;
}

float g_glow_line(vec2 p, vec2 a, vec2 b, float r) {
	vec2 d = b - a;
	float u = clamp(dot(p - a, d) / max(dot(d, d), 1e-9), 0.0, 1.0);
	float e = distance(a + d * u, p) / max(r, 1e-3);
	return e < 1.0 ? (1.0 - e) * (1.0 - e) : 0.0;
}
