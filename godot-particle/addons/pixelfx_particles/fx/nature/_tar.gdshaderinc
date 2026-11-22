// nature/toxic-puddle: the tar pool (the original's surf() and pool()), shared by its colour pass (_tar.gdshader),
// its light pass (_tar_light.gdshader) and the bubbles (_tar_bubbles.gdshader). Coordinates are px from the
// origin; `t` is 0 -> 1 over the loop, `period` its length in seconds.
uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float period = 4.0;
uniform float W = 42.0;
uniform float seed = 2.0;
// the palette (8, dark to bright) and the sheen (4)
uniform sampler2D ramp : filter_nearest, repeat_disable;
uniform sampler2D sheen : filter_nearest, repeat_disable;

const float TAR_TAU = 6.2831853;

vec3 tar_C(float i) {
	return texture(ramp, vec2((clamp(i, 0.0, 7.0) + 0.5) / 8.0, 0.5)).rgb;
}

vec3 tar_S(float i) {
	return texture(sheen, vec2((clamp(i, 0.0, 3.0) + 0.5) / 4.0, 0.5)).rgb;
}

float tar_hash(vec2 p, float s) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + s * 17.31) * 43758.5453);
}

// value noise in -1..1, repeating every px in x and py in y (0: no repeat)
float tar_noise(float x, float y, float px, float py, float s) {
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
	float a = tar_hash(vec2(x0, y0), s);
	float b = tar_hash(vec2(x1, y0), s);
	float c = tar_hash(vec2(x0, y1), s);
	float d = tar_hash(vec2(x1, y1), s);
	return mix(mix(a, b, ux), mix(c, d, ux), uy) * 2.0 - 1.0;
}

// the surface height above the floor at x (negative: up): a heavy lens of tar, slow swells rolling through it
float tar_surf(float x) {
	float d = min(1.0, abs(x) / W);
	float ph = TAR_TAU * t;
	float lens = sqrt(1.0 - d * d) * 6.6 + (d > 0.8 ? 1.6 * smoothstep(0.8, 0.9, d) : 0.0);
	float swell = pow(max(0.0, sin(x * 0.09 - ph)), 6.0) * 1.2 + pow(max(0.0, sin(x * 0.06 + ph * 2.0 + 1.0)), 8.0) * 0.9;
	return -floor(lens + swell * (1.0 - d) + 0.5);
}

// the pool at pixel (x, y): false where there's none; col its colour, a its alpha; lc / lk the light it gives
bool tar_pool(float x, float y, out vec3 col, out float a, out vec3 lc, out float lk) {
	col = vec3(0.0);
	a = 1.0;
	lc = vec3(0.0);
	lk = 0.0;
	float d = abs(x + 0.5) / W;
	float T = t * period;
	if (y == 0.0 && abs(x + 0.5) > W && abs(x + 0.5) < W + 7.0) {
		// the glow bleeding out onto the floor at both lips
		float k = x >= 0.0 ? x - floor(W) : -x - floor(W);
		if (k >= 1.0 && k <= 6.0) {
			col = k < 3.0 ? tar_C(6.0) : tar_C(5.0);
			a = 1.0 - k / 7.0;
			return true;
		}
	}
	if (d > 1.03) {
		return false;
	}
	float top = tar_surf(x + 0.5);
	if (y == top - 1.0 && d > 0.9) {
		col = tar_C(1.0);
		return true;
	}
	if (y < top || y > 2.0 || (y == 2.0 && d > 0.75) || (y == 1.0 && d > 0.9)) {
		return false;
	}
	float ph = t;
	float oil = 0.6 * tar_noise(x * 0.08, ph * 4.0, 0.0, 4.0, seed) + 0.6 * tar_noise(x * 0.11 - ph * 4.0, 1.0, 4.0, 0.0, seed + 1.0);
	float hue = tar_noise(x * 0.05, ph * 2.0 + 7.0, 0.0, 2.0, seed + 3.0);
	if (d > 0.93 && y <= 0.0) {
		col = y == top ? tar_C(7.0) : tar_C(6.0);
	} else if (y == top) {
		// the skin catches light along its top: a lit edge, the sheen sliding over it, glints running along
		bool glint = abs(fract(x * 0.07 - ph * 3.0) - 0.5) < 0.012 || tar_hash(vec2(x, floor(T * 10.0)), seed + 5.0) < 0.015;
		col = glint ? vec3(1.0) : oil > 0.55 ? (hue > 0.0 ? tar_S(3.0) : tar_S(2.0)) : oil > 0.15 ? (hue > 0.0 ? tar_S(1.0) : tar_C(5.0)) : tar_C(5.0);
		if (glint) {
			lc = tar_C(7.0);
			lk = 0.5;
		}
	} else if (y == top + 1.0) {
		col = oil > 0.4 ? tar_S(0.0) : tar_C(3.0);
	} else if (y >= 1.0) {
		col = tar_C(0.0);
	} else {
		// cracks of light under the crust, writhing slowly, swelling brighter and dimmer in a slow pulse
		float pulse = 0.5 + 0.5 * sin(TAR_TAU * T / period + x * 0.03);
		float v = abs(tar_noise(x * 0.09, y * 0.75 + ph * 4.0, 0.0, 4.0, seed + 7.0) + 0.2 * sin(TAR_TAU * T * 2.0 / period + x * 0.15));
		float w = 0.6 + 0.6 * pulse;
		col = v < 0.035 * w ? tar_C(7.0) : v < 0.08 * w ? tar_C(6.0) : v < 0.14 * w ? tar_C(4.0) : tar_C(1.0);
		if (v < 0.08 * w) {
			lc = tar_C(6.0);
			lk = 0.25 + 0.3 * pulse;
		}
	}
	return true;
}
