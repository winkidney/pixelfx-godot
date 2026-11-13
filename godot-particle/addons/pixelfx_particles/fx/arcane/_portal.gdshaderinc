// The portal's rift (after the original's rift()), shared by its colour pass (_portal.gdshader) and its light pass
// (_portal_light.gdshader): an upright oval rx x ry whose rim wobbles on rolling noise, lit where two hot spots chase
// round it; inside, depth bands fall away to a dark well, three bright arms and three faint ones wind down a log
// spiral with knots running down them, tunnel rings shrink away. `t` runs 0..1 over the loop. Coordinates: px from the
// effect's origin; the oval is centred on (0, cy).
uniform vec2 size = vec2(48.0, 72.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float rx = 17.0;
uniform float ry = 29.0;
uniform float cy = -34.0;
uniform float grain = 4.0;

float p_hash(vec2 q) {
	return fract(sin(dot(q, vec2(127.1, 311.7)) + grain * 17.17) * 43758.5453);
}

// value noise repeating every per.x cells across and per.y down
float p_tile_noise(vec2 q, vec2 per) {
	vec2 i = floor(q);
	vec2 f = q - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	vec2 i0 = mod(i, per);
	vec2 i1 = mod(i + 1.0, per);
	float a = p_hash(i0);
	float b = p_hash(vec2(i1.x, i0.y));
	float c = p_hash(vec2(i0.x, i1.y));
	float d = p_hash(i1);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 2.0 - 1.0;
}

float p_wrap_pi(float a) {
	return a - TAU * floor((a + PI) / TAU);
}

float p_rim(float th) {
	return 1.0 + 0.05 * p_tile_noise(vec2(th / TAU * 10.0 + t * 10.0, t * 4.0), vec2(10.0, 4.0)) + 0.018 * sin(th * 3.0 - t * TAU * 2.0);
}

float p_hot(float th) {
	float s0 = t * TAU * 2.0 - 0.6;
	float s1 = s0 + PI;
	float a = p_wrap_pi(th - s0);
	float b = p_wrap_pi(th - s1);
	return max(exp(-(a * a) / 0.12), 0.85 * exp(-(b * b) / 0.08)) + 0.35 * max(0.0, cos(th + 2.3));
}

float p_smooth(float a, float b, float x) {
	return smoothstep(a, b, x);
}

// out: colour index into the ramp as a float level (st / 7 for tone) or a fixed colour; returns 0 nothing, 1 the
// rim pixels (col set), 2 the inside (level set)
int p_rift(vec2 p, out int col, out float level, out float lit_k) {
	float u = p.x / rx;
	float v = (p.y - cy) / ry;
	float r = max(length(vec2(u, v)), 1e-6);
	float th = atan(v, u);
	float R0 = p_rim(th);
	float g = length(vec2(u / rx, v / ry)) / r;
	float e = (r - R0) / g;
	float h = p_hot(th);
	lit_k = 0.0;
	col = -1;
	level = 0.0;
	if (e > 2.5) {
		return 0;
	}
	if (e > 1.5) {
		if (h > 0.6) {
			col = 3; // C3 at half alpha
			return 1;
		}
		return 0;
	}
	if (e > 0.5) {
		col = h > 0.5 ? 4 : 2;
		return 1;
	}
	if (e > -0.5) {
		col = h > 0.42 ? 7 : 6;
		lit_k = 0.25 + 0.4 * h;
		return 1;
	}
	float d = r / R0;
	float z = -log(max(0.02, d));
	float phi = 3.0 * th + 6.5 * z - TAU * 3.0 * t;
	float k1 = 0.5 + 0.5 * cos(phi);
	float k2 = 0.5 + 0.5 * cos(phi + PI + 0.6 * z);
	float lit = pow(d, 1.5);
	float sink = p_smooth(0.2, 0.62, d);
	float knot = pow(max(0.0, cos(4.0 * z - phi / 3.0 + TAU * 5.0 * t)), 6.0);
	float st = p_smooth(0.4, 0.7, d) + 0.6 * p_smooth(0.8, 0.95, d);
	float crest = pow(k1, 16.0) * (0.6 + 5.6 * lit) * (1.0 + 0.5 * knot) * sink;
	st += crest + pow(k1, 5.0) * 1.1 * lit;
	st += pow(k2, 18.0) * (0.3 + 1.8 * lit) * sink;
	st += pow(0.5 + 0.5 * cos(TAU * (z * 1.5 - t * 2.0)), 20.0) * 1.3 * sink * (1.0 - 0.5 * k1);
	st += pow(0.5 + 0.5 * cos(3.0 * phi + 2.0 * z + 1.3), 10.0) * 1.1 * lit * sink;
	st += 2.2 * pow(p_smooth(0.8, 1.0, d), 2.0) * (0.75 + 0.45 * h);
	level = st / 7.0;
	if (crest > 2.2) {
		lit_k = 0.12 + 0.05 * crest;
	}
	return 2;
}
