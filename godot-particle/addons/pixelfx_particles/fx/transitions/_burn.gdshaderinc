// burn-away.js draw(): the screen burning in behind a ragged ember line (field A), then the black smouldering and
// burning open (field B). Per pixel, worked out at build time from the original's fields and noise: fa (A's value,
// its 1 / gradient, B's value, its 1 / gradient), fb (heat, flicker phase 0..63, fleck, char jitter), fc (crack vein).
// Keyed every frame: t, mode (0 nothing, 1 all ink, 2 the fields), inp (burning in), k (the front's level), fade,
// sk / sr / blo (the smoulder: strength, reach, B's lowest value), hi (the level beyond which a pixel is deep in the
// cover).
uniform sampler2D fa : filter_nearest, repeat_disable;
uniform sampler2D fb : filter_nearest, repeat_disable;
uniform sampler2D fc : filter_nearest, repeat_disable;
uniform float t = 0.0;
uniform float mode = 0.0;
uniform float inp = 1.0;
uniform float k = 0.0;
uniform float fade = 1.0;
uniform float sk = 0.0;
uniform float sr = 5.0;
uniform float blo = 0.0;
uniform float hi = 0.0;
uniform vec4 F[9] : source_color;
uniform vec4 ink : source_color;
uniform vec4 charc : source_color;
uniform vec4 scorch : source_color;
uniform vec4 warm : source_color;

const float HALO = 24.0;
const float POOL = 48.0;

// what the original's shadeAt() does to pixel q: kind 0 nothing, 1 a colour (col), 2 the scorch blended at alpha sa;
// lk: the warm light it adds (summed as the original adds it, each add whole bytes: la, lb, lc)
void bn_shade(ivec2 q, out int kind, out vec3 col, out float sa, out float l1, out float l2) {
	kind = 0;
	col = vec3(0.0);
	sa = 0.0;
	l1 = 0.0;
	l2 = 0.0;
	if (mode < 1.5) {
		if (mode > 0.5) {
			kind = 1;
			col = ink.rgb;
		}
		return;
	}
	vec4 a = texelFetch(fa, q, 0);
	vec4 b = texelFetch(fb, q, 0);
	bool in_ = inp > 0.5;
	float f = in_ ? a.x : a.z;
	float g = in_ ? a.y : a.w;
	bool deep;
	if (in_) {
		if (f < k - 33.0) {
			deep = true;
		} else if (f < hi) {
			deep = false;
		} else {
			return;
		}
	} else {
		if (f >= hi) {
			deep = true;
		} else if (f >= k - POOL) {
			deep = false;
		} else {
			return;
		}
	}
	float fleck = b.z;
	if (deep && fleck <= 0.0) {
		kind = 1;
		col = ink.rgb;
		return;
	}
	float ph = b.y;
	float qp = ph / 63.0;
	float FL = 0.75 + 0.25 * sin(t * 7.0 + qp * 9.0);
	float HV = 0.3 * sin(t * 5.5 + qp * 11.0);
	float ph5 = mod(ph * 5.0, 64.0) / 63.0;
	bool TW = sin(t * 13.0 + ph5 * 40.0) > -0.5;
	float e = in_ ? k - f : f - k;
	float s = e * g;
	if (e < 0.0) {
		if (in_ && s > -2.5) {
			kind = 2;
			sa = 0.5 * (1.0 + s / 2.5);
		}
		float u = max(0.0, 1.0 + e / HALO);
		float v = 1.0 + e / POOL;
		l1 = (0.3 * u * u + 0.12 * v * v) * FL;
		return;
	}
	float hv = clamp(b.x + HV, 0.0, 1.0);
	float th = 0.6 + 0.6 * hv;
	float u = s / th;
	kind = 1;
	if (u < 6.4) {
		col = u < 0.9 ? (hv > 0.6 ? F[8].rgb : F[7].rgb) : u < 1.7 ? F[6].rgb : u < 2.4 ? F[5].rgb : u < 3.1 ? F[4].rgb : u < 3.8 ? F[3].rgb : u < 4.6 ? F[2].rgb : u < 5.5 ? F[1].rgb : F[0].rgb;
		if (u < 4.6) {
			l1 = 0.45 * (1.0 - u / 4.6) * (0.7 + 0.3 * hv);
		}
		return;
	}
	if (sk > 0.0 && f < blo + sr) {
		float hm = (1.0 - (f - blo) / sr) * sk * (0.7 + 0.6 * hv);
		if (texelFetch(fc, q, 0).x < 0.04 + 0.08 * hm) {
			col = hm > 0.95 ? F[6].rgb : hm > 0.75 ? F[5].rgb : hm > 0.55 ? F[4].rgb : hm > 0.38 ? F[3].rgb : hm > 0.22 ? F[2].rgb : F[1].rgb;
			l1 = 0.4 * hm;
			return;
		}
		l1 = 0.2 * hm * hm;
	}
	float L = fleck * (0.8 + 0.4 * hv);
	float jit = b.w;
	if (L > 0.0 && s < L) {
		float v = (s - 6.4 * th) / max(1.0, L - 6.4 * th);
		if (v < 1.0 && TW && !(fade < 1.0 && fade <= jit / 1.5 + 0.5)) {
			col = v < 0.3 ? F[4].rgb : v < 0.55 ? F[3].rgb : v < 0.8 ? F[2].rgb : F[1].rgb;
			l2 = 0.3 * (1.0 - v);
			return;
		}
	}
	if (e < 22.0) {
		l2 = 0.2 * pow(1.0 - e / 22.0, 2.0);
	}
	col = u - 6.4 < 1.6 * th + jit ? charc.rgb : ink.rgb;
}
