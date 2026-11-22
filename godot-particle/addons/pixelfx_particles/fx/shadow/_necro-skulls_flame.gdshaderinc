// The necro-skulls' cold flame (after the original's flame()): a body swelling off its base at fb and tapering over
// fh px into licking tongues, its width and sway off two octaves of tiling noise scrolling up once a loop (t 0..1).
// Shared by the colour pass and the light pass. Coordinates: px from the effect's origin.
uniform vec2 size = vec2(32.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float fb = -32.0;
uniform float fh = 34.0;
uniform float w0 = 10.0;

float nk_rand(vec2 q, float s) {
	return fract(sin(dot(q, vec2(127.1, 311.7)) + s * 17.17) * 43758.5453);
}

// value noise wrapping every py cells down (py 0: no wrap), -1..1
float nk_tile(vec2 q, float py, float s) {
	vec2 i = floor(q);
	vec2 f = q - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float y0 = py > 0.0 ? mod(i.y, py) : i.y;
	float y1 = py > 0.0 ? mod(i.y + 1.0, py) : i.y + 1.0;
	float a = nk_rand(vec2(i.x, y0), s);
	float b = nk_rand(vec2(i.x + 1.0, y0), s);
	float c = nk_rand(vec2(i.x, y1), s);
	float d = nk_rand(vec2(i.x + 1.0, y1), s);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 2.0 - 1.0;
}

// heat 0..1 inside the flame, < 0 outside
float nk_flame(vec2 p) {
	float u = (fb - p.y) / fh;
	if (u < -0.04 || u >= 1.0) {
		return -1.0;
	}
	float n1 = nk_tile(vec2(p.x * 0.3, p.y * 0.2 + t * 8.0), 8.0, 3.0);
	float n2 = nk_tile(vec2(p.x * 0.6, p.y * 0.45 + t * 16.0), 16.0, 5.0);
	float prof = u < 0.22 ? 0.35 + 0.65 * sqrt(max(0.0, u) / 0.22) : pow(1.0 - (u - 0.22) / 0.78, 0.85);
	float w = w0 * prof * (1.0 + 0.3 * n1) + n2 * 2.2 * u;
	float sway = n1 * 3.0 * u * u;
	float d = abs(p.x - sway) / max(0.6, w);
	if (d > 1.0) {
		return -1.0;
	}
	return pow(1.0 - d, 0.7) * pow(max(0.0, 1.0 - u), 0.55) + n2 * 0.12;
}
