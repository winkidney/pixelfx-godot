// A faceted stone spike standing on the floor (after src/fx/nature/_lib.js drawSpike), for nature/earth-spike: a
// ridge splits a lit left face from a shaded right face, strata step across both, notches chip the edges, a dark
// rim goes round it; cracks spread over it (glowing with `heat`); a white flash; a glint sweeping up its lit face.
// split = 1: it has broken into two halves that part by `gap` and tip out by `tip`, crumble from the top (`clip`,
// ragged) and sink by `sink` below the floor. Key the uniforms frame by frame (the build script follows the
// original's curves); coordinates are px from the effect's origin (`center` is the rect's middle).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
// the stone ramp (8 steps, dark to bright) and the crack glow ramp (5 steps)
uniform sampler2D stone : filter_nearest, repeat_disable;
uniform sampler2D glow_ramp : filter_nearest, repeat_disable;
uniform float x0 = 0.0;
uniform float h = 10.0;
uniform float w = 10.0;
uniform float lean = 0.0;
uniform float white = 0.0;
uniform float glint = -1.0;
uniform float clip = 1.0;
uniform float split = 0.0;
uniform float gap = 0.0;
uniform float tip = 0.0;
uniform float sink = 0.0;
uniform float crack = 0.0;
uniform float heat = 0.0;
// the look: notches (u, side, depth), strata (u), the strata's slope, a seed for their jog
uniform vec3 notches[5];
uniform float notch_count = 0.0;
uniform float strata[4];
uniform float strata_count = 0.0;
uniform float slope = 0.0;
uniform float look_seed = 1.0;
// three cracks of up to 10 points [u, v] each (v: -1 left edge .. 1 right edge), their lengths in crack_len
uniform vec2 crack_pts[30];
uniform vec3 crack_len = vec3(0.0);
uniform float alpha = 1.0;

vec4 S(int i) {
	return texture(stone, vec2((float(clamp(i, 0, 7)) + 0.5) / 8.0, 0.5));
}

vec4 GL(int i) {
	return texture(glow_ramp, vec2((float(clamp(i, 0, 4)) + 0.5) / 5.0, 0.5));
}

float rnd(float a, float b) {
	return fract(sin(a * 12.9898 + b * 78.233 + look_seed * 0.137) * 43758.5453);
}

float hw(float u, float side) {
	float v = (w / 2.0) * pow(max(0.0, 1.0 - u), 0.85) + 0.3;
	for (int i = 0; i < 5; i++) {
		if (float(i) >= notch_count) {
			break;
		}
		vec3 n = notches[i];
		if (abs(n.y - side) < 0.5 && u > n.x && u < n.x + 0.07) {
			v -= n.z * (1.0 - u * 0.5);
		}
	}
	return max(0.0, v);
}

// the spike's frame for one draw: base x, lean, half (-1, 0, 1), base y, floor y
bool inside(vec2 q, float xs, float ln, float half, float base, float fl) {
	float py = q.y + 0.5;
	float u = (base - py) / h;
	if (u < 0.0 || u > 1.0 || py > fl) {
		return false;
	}
	float l = xs + ln * u - hw(u, -1.0);
	float r = xs + ln * u + hw(u, 1.0);
	float fx = q.x + 0.5;
	if (fx < l || fx > r) {
		return false;
	}
	if (clip < 1.0 && u > clip + (rnd(q.x, 77.0) - 0.5) * 0.07) {
		return false;
	}
	if (half == 0.0) {
		return true;
	}
	float qq = (fx - l) / max(0.5, r - l) * 2.0 - 1.0;
	return half < 0.0 ? qq < -0.18 : qq >= -0.18;
}

vec2 crack_at(vec2 uv, float xs, float ln, float base) {
	return vec2(xs + ln * uv.x + uv.y * hw(uv.x, uv.y < 0.0 ? -1.0 : 1.0), base - uv.x * h);
}

// is pixel q on the line from cell a to cell b (as the original's Bresenham draws it)
bool on_line(vec2 q, vec2 a, vec2 b) {
	vec2 A = floor(a);
	vec2 B = floor(b);
	vec2 d = B - A;
	if (abs(d.x) >= abs(d.y)) {
		if (q.x < min(A.x, B.x) || q.x > max(A.x, B.x)) {
			return false;
		}
		float y = d.x == 0.0 ? A.y : A.y + (q.x - A.x) * d.y / d.x;
		return q.y == floor(y + 0.5);
	}
	if (q.y < min(A.y, B.y) || q.y > max(A.y, B.y)) {
		return false;
	}
	float x = A.x + (q.y - A.y) * d.x / d.y;
	return q.x == floor(x + 0.5);
}

// one draw of drawSpike: the colour at q (alpha 0: nothing)
vec4 spike(vec2 q, float xs, float ln, float half, float base, float fl) {
	vec4 c = vec4(0.0);
	if (!inside(q, xs, ln, half, base, fl)) {
		if (q.y + 0.5 <= fl && (inside(q - vec2(1.0, 0.0), xs, ln, half, base, fl) || inside(q + vec2(1.0, 0.0), xs, ln, half, base, fl)
				|| inside(q + vec2(0.0, 1.0), xs, ln, half, base, fl) || (inside(q - vec2(0.0, 1.0), xs, ln, half, base, fl) && q.y < base - 1.0))) {
			c = S(0);
		}
	} else if (white > 0.5) {
		c = vec4(1.0);
	} else {
		float py = q.y + 0.5;
		float u = (base - py) / h;
		float cx = xs + ln * u;
		float l = cx - hw(u, -1.0);
		float r = cx + hw(u, 1.0);
		float fx = q.x + 0.5;
		float band = 0.0;
		bool st = false;
		for (int i = 0; i < 4; i++) {
			if (float(i) >= strata_count) {
				break;
			}
			float d = u * h - strata[i] * h - slope * (fx - cx);
			if (d > 0.0) {
				band += 1.0;
			}
			if (abs(d) < 0.5) {
				st = true;
			}
		}
		float jog = (rnd(band, look_seed) - 0.5) * 0.3;
		float qq = (fx - l) / max(0.5, r - l) * 2.0 - 1.0;
		float qr = -0.18 + jog;
		int i;
		if (u > 0.93) {
			i = qq < qr + 0.3 ? 7 : 5;
		} else if (abs(qq - qr) < max(0.09, 0.55 / max(1.0, r - l))) {
			i = 7;
		} else if (qq < qr) {
			i = fx - l < 1.0 ? 7 : (qq < -0.5 + jog ? 6 : 5);
		} else {
			i = r - fx < 1.0 ? 3 : (qq < 0.38 + jog ? 4 : 2);
		}
		if (st && i < 7) {
			i -= 1;
		}
		float fleck = rnd(q.x * 7.0 + 3.0, q.y * 13.0 + 5.0);
		if (fleck < 0.035) {
			i = qq < qr ? 7 : i - 1;
		} else if (fleck > 0.965) {
			i -= 1;
		}
		if (glint >= 0.0 && qq < qr + 0.1) {
			float g = abs(u - glint);
			if (g < 0.035) {
				i = 8;
			} else if (g < 0.07) {
				i = max(i, 7);
			}
		}
		c = i >= 8 ? vec4(1.0) : S(i);
	}
	// cracks spreading over it, a lit lip on one side of each (or a glowing seam while it's hot)
	if (crack > 0.0) {
		for (int j = 0; j < 3; j++) {
			float n = crack_len[j];
			float m = max(1.0, floor(n * crack));
			for (int k = 1; k < 10; k++) {
				if (float(k) >= m) {
					break;
				}
				vec2 p0 = crack_pts[j * 10 + k - 1];
				vec2 p1 = crack_pts[j * 10 + k];
				if (p1.x > clip) {
					break;
				}
				vec2 a = crack_at(p0, xs, ln, base);
				vec2 b = crack_at(p1, xs, ln, base);
				if (!inside(floor(a), xs, ln, half, base, fl) || !inside(floor(b), xs, ln, half, base, fl)) {
					continue;
				}
				if (heat > 0.05) {
					if (on_line(q, a + vec2(1.0, 0.0), b + vec2(1.0, 0.0))) {
						c = S(0);
					}
					if (on_line(q, a, b)) {
						c = heat > 0.7 ? GL(4) : heat > 0.4 ? GL(3) : heat > 0.2 ? GL(2) : GL(1);
					}
				} else {
					if (on_line(q, a, b)) {
						c = S(0);
					}
					if (q == floor(b + vec2(1.0, -1.0)) && rnd(q.x, q.y) < 0.7) {
						c = S(6);
					}
				}
			}
		}
	}
	return c;
}

void fragment() {
	vec2 q = floor((UV - 0.5) * size + center);
	vec4 c;
	if (split < 0.5) {
		c = spike(q, x0, lean, 0.0, 0.0, 1e6);
	} else {
		vec4 a = spike(q, x0 - gap / 2.0, lean - tip, -1.0, sink, 0.0);
		vec4 b = spike(q, x0 + gap / 2.0, lean + tip, 1.0, sink, 0.0);
		c = b.a > 0.0 ? b : a;
	}
	if (c.a <= 0.0) {
		discard;
	}
	c.a *= alpha;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
