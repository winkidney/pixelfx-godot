// Frost on the floor (the floor is y = 0, coordinates are px from the effect's origin): a crust along the floor, rime
// tufts standing on it, a dithered bloom under the surface, column by column with the originals' integer hash, so
// each column's tufts are the original's. Every dot is dithered by its own alpha and the last one drawn wins, as the
// original paints them. Colour layer; `ramp` is the ice ramp (dark to bright).
//   kind 0  ice/frost-nova: from -`x1` to `x1`, fading out past `a` of `reach`, fresh white along the running `edge`
//   kind 1  ice/ice-spikes: a frost line racing out to `edge` (from 0 to `reach`), each column growing as it's reached
//           (at `start` + `run` (1 - (1 - x / reach)^(1 / 1.7))), melting oldest first from `melt`, a white-hot head
//           while it runs; `t` is the effect's time
//   kind 2  ice/icicle-fall: frost splashed across the floor where it struck, `x1` px either side, grown to `spread_k`
//           (0..1), its tufts leaning outward, fading by `a`
//   kind 3  ice/freeze: frost lines racing in from `x1` px either side to the feet by `start` s, rime ferns
//           standing up from the crust, fading by `a`; `t` is the effect's time
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float kind = 0.0;
uniform float t = 0.0;
uniform float x1 = 12.0;
uniform float reach = 100.0;
uniform float a = 1.0;
uniform float edge = 0.0;
uniform float start = 0.04;
uniform float run = 0.44;
uniform float melt = 1.75;
uniform float spread_k = 1.0;
uniform sampler2D ramp : filter_nearest, repeat_disable;

vec4 C(int i) {
	return texture(ramp, vec2((float(i) + 0.5) / 8.0, 0.5));
}

uint mix32(uint h, int n) {
	h = (h ^ uint(n)) * 0x85ebca6bu;
	h ^= h >> 13u;
	h *= 0xc2b2ae35u;
	h ^= h >> 16u;
	return h;
}

// the originals' rand(a, b)
float jrand(int p, int q) {
	return float(mix32(mix32(0x9e3779b9u, p), q)) / 4294967296.0;
}

float smooth01(float lo, float hi, float x) {
	float u = clamp((x - lo) / (hi - lo), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

// draw dot (colour c, alpha k) if it lands: the last one drawn wins
void dot_(inout vec4 o, inout bool hit, vec4 c, float k, float th) {
	if (k > 0.0 && k >= th) {
		o = c;
		hit = true;
	}
}

// column x's frost as the nova draws it; P is the pixel, returns whether anything landed on it
void nova(int x, ivec2 P, inout vec4 o, inout bool hit, float th, bool side_only) {
	float d = abs(float(x) + 0.5);
	float q = d / reach;
	float k = clamp((a * 1.15 - q) / 0.15, 0.0, 1.0);
	if (k <= 0.0 || float(x) < floor(-x1) || float(x) > ceil(x1)) {
		return;
	}
	float h = jrand(x, 17);
	bool fresh = edge > 0.0 && d > edge - 3.0;
	int tuft = h < 0.45 ? int(round((1.0 + jrand(x, 5) * 3.0) * (1.0 - q * 0.6))) : 0;
	if (!side_only) {
		if (P.y == 0) {
			dot_(o, hit, (fresh || h < 0.25) ? vec4(1.0) : C(6), k, th);
		} else if (P.y < 0 && -P.y <= tuft) {
			dot_(o, hit, -P.y == tuft ? vec4(1.0) : C(5), k, th);
		}
	}
	if (tuft > 1 && jrand(x, 9) < 0.5) {
		int sx = x + (jrand(x, 3) < 0.5 ? -1 : 1);
		if (P.x == sx && P.y == -tuft + 1) {
			dot_(o, hit, C(6), k, th);
		}
	}
	if (!side_only && P.y > 0) {
		float D = (4.0 + jrand(x, 11) * 4.0) * (1.0 - q * 0.5);
		float j = float(P.y);
		if (j <= D) {
			float v = j / D;
			vec4 c = jrand(x * 31 + P.y, 7) < 0.06 ? vec4(1.0) : (v < 0.25 ? C(6) : (v < 0.55 ? C(5) : C(4)));
			dot_(o, hit, c, k * (1.1 - v) * (fresh ? 1.3 : 1.0), th);
		}
	}
}

float reached_at(float x) {
	return start + run * (1.0 - pow(1.0 - clamp(x / reach, 0.0, 1.0), 1.0 / 1.7));
}

// column x's frost as the spikes' frost line draws it
void line_frost(int x, ivec2 P, inout vec4 o, inout bool hit, float th, bool side_only) {
	float fx = float(x);
	if (fx < -3.0 || fx > min(edge, reach + 6.0)) {
		return;
	}
	float q = clamp(fx / reach, 0.0, 1.0);
	float age = t - reached_at(max(0.0, fx));
	float k = 1.0 - smooth01(melt + q * 0.35, melt + q * 0.35 + 0.6, t);
	if (k <= 0.0 || age < 0.0) {
		return;
	}
	float h = jrand(x, 17);
	float grow = smooth01(0.0, 0.3, age);
	bool head = edge - fx < 3.0 && edge < reach;
	int L = h < 0.45 ? int(round(grow * (1.0 + jrand(x, 5) * 2.6))) : 0;
	if (!side_only) {
		if (P.y == 0) {
			dot_(o, hit, (head || age < 0.06 || h < 0.3) ? vec4(1.0) : C(6), k, th);
		} else if (P.y < 0 && -P.y <= L) {
			dot_(o, hit, -P.y == L ? vec4(1.0) : C(5), k, th);
		}
	}
	if (L > 1 && jrand(x, 9) < 0.5 && P.x == x + 1 && P.y == -L + 1) {
		dot_(o, hit, C(6), k, th);
	}
	if (!side_only && P.y > 0) {
		float D = grow * (2.0 + jrand(x, 11) * 4.0) * (1.0 - q * 0.3);
		float j = float(P.y);
		if (j <= D) {
			vec4 c = jrand(x * 31 + P.y, 7) < 0.06 ? vec4(1.0) : (P.y < 2 ? C(5) : (P.y < 4 ? C(4) : C(3)));
			dot_(o, hit, c, k * (1.1 - j / (D + 1.0)), th);
		}
	}
	if (!side_only && head && P.y == -1) {
		dot_(o, hit, vec4(1.0), 1.0, th);
	}
}

// column x's frost as the icicle's splash draws it
void splash(int x, ivec2 P, inout vec4 o, inout bool hit, float th, bool side_only) {
	if (float(x) < -x1 || float(x) > x1) {
		return;
	}
	float d = abs(float(x) + 0.5) / x1;
	float h = jrand(x, 23);
	float k = a * clamp((spread_k * 1.15 - d) / 0.15, 0.0, 1.0);
	if (k <= 0.0) {
		return;
	}
	if (!side_only && P.y == 0) {
		dot_(o, hit, (h < 0.35 || d > spread_k - 0.12) ? vec4(1.0) : C(6), k, th);
	}
	if (h < 0.4 && P.y < 0) {
		int n = int(round((1.0 + jrand(x, 3) * 2.5) * (1.0 - d)));
		int j = -P.y;
		int lean = x > 0 ? 1 : (x < 0 ? -1 : 0);
		if (j <= n && P.x == x + (j > 1 ? lean : 0)) {
			dot_(o, hit, j > 1 ? vec4(1.0) : C(5), k, th);
		}
	}
	if (!side_only && P.y > 0) {
		int n = int(round((2.0 + jrand(x, 7) * 3.0) * (1.0 - d * 0.6)));
		if (P.y <= n) {
			dot_(o, hit, P.y < 2 ? C(5) : C(4), k * (1.1 - float(P.y) / 6.0), th);
		}
	}
}

// column x's frost as the freeze draws it
void ferns(int x, ivec2 P, inout vec4 o, inout bool hit, float th, bool side_only) {
	float fx = float(x);
	if (fx < -x1 || fx > x1) {
		return;
	}
	float d = abs(fx + 0.5) / x1;
	float age = t - start * (1.0 - d);
	if (age < 0.0) {
		return;
	}
	float k = a * clamp((1.12 - d) / 0.2, 0.0, 1.0);
	if (k <= 0.0) {
		return;
	}
	float g = smooth01(0.0, 0.4, age);
	float h = jrand(x, 31);
	int s = x < 0 ? -1 : 1;
	if (!side_only && P.y == 0) {
		dot_(o, hit, (age < 0.05 || h < 0.3) ? vec4(1.0) : C(6), k, th);
	}
	if (h < 0.55) {
		int L = int(round(g * (1.0 + jrand(x, 7) * 3.4) * (1.0 - d * 0.55)));
		if (!side_only && P.x == x && P.y < 0 && -P.y <= L) {
			dot_(o, hit, -P.y == L ? vec4(1.0) : C(5), k, th);
		}
		if (L >= 2 && P.x == x + s && P.y == -L + 1) {
			dot_(o, hit, C(6), k, th);
		}
		if (L >= 4 && P.x == x - s && P.y == -L + 2) {
			dot_(o, hit, C(5), k, th);
		}
	}
	if (!side_only && P.y > 0) {
		float D = g * (2.0 + jrand(x, 11) * 4.0) * (1.0 - d * 0.5);
		float j = float(P.y);
		if (j <= D) {
			vec4 c = jrand(x * 13 + P.y, 5) < 0.07 ? vec4(1.0) : (P.y < 2 ? C(5) : (P.y < 4 ? C(4) : C(3)));
			dot_(o, hit, c, k * (1.05 - j / (D + 1.0)), th);
		}
	}
}

void fragment() {
	vec4 tint = COLOR;   // the node's modulate: fade a group, tint a copy
	ivec2 P = ivec2(floor((UV - 0.5) * size + center));
	float th = pfx_threshold(FRAGCOORD.xy);
	vec4 o = vec4(0.0);
	bool hit = false;
	// columns are drawn left to right: the one to the left may reach over with a side tuft, then this one, then the
	// one to the right
	if (kind < 0.5) {
		nova(P.x - 1, P, o, hit, th, true);
		nova(P.x, P, o, hit, th, false);
		nova(P.x + 1, P, o, hit, th, true);
	} else if (kind < 1.5) {
		line_frost(P.x - 1, P, o, hit, th, true);
		line_frost(P.x, P, o, hit, th, false);
	} else if (kind < 2.5) {
		splash(P.x - 1, P, o, hit, th, true);
		splash(P.x, P, o, hit, th, false);
		splash(P.x + 1, P, o, hit, th, true);
	} else {
		ferns(P.x - 1, P, o, hit, th, true);
		ferns(P.x, P, o, hit, th, false);
		ferns(P.x + 1, P, o, hit, th, true);
	}
	if (!hit) {
		discard;
	}
	o.a = 1.0;
	o *= tint;
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
