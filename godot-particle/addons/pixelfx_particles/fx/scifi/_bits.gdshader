// How the scifi effects' simulated particles look (colour layer, or the soft layer with `translucent`), drawn as the
// original draws each kind (src/core/sim.js Particles.draw; after fx/impacts/_bits.gdshader): a two-tone spark
// streak, a mote's trail, a gathering streak, a flake, vapour, dust and smoke puffs, a twinkling star glint, an
// ember, a fire puff cooling down the fire ramp, a grit pixel, a dead pixel. Moved by _ghost.gdshader, which hands
// each one its streak and life in CUSTOM. The particle's quad (`quad` px) is a canvas the kind is drawn on, cell by
// cell.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_scifi.gdshaderinc"

uniform sampler2D data : filter_nearest, repeat_disable;
uniform float kind = 0.0;
uniform vec2 quad = vec2(28.0);
// SPARK / EMBER: the sparks ramp, head (hot) to tail; SMOKE: the smoke ramp in s0..s3 + smoke4
uniform vec4 s0 : source_color = vec4(1.0);
uniform vec4 s1 : source_color = vec4(1.0);
uniform vec4 s2 : source_color = vec4(1.0);
uniform vec4 s3 : source_color = vec4(1.0);
uniform vec4 smoke4 : source_color = vec4(0.1, 0.09, 0.12, 1.0);
// FIRE: the fire ramp, white-hot to smouldering
uniform vec4 fire[9] : source_color;
uniform float big = 0.0;
// SMOKE without a colour of its own: it walks down the smoke ramp alone
uniform bool plain = false;

varying flat vec4 cu;
varying flat vec4 pc;

void vertex() {
	cu = INSTANCE_CUSTOM;
	pc = COLOR;
}

// a 1 px line from cell a to cell b, as Bresenham steps it (one pixel per step along the longer axis)
bool on_line(vec2 d, vec2 a, vec2 b) {
	vec2 e = b - a;
	if (abs(e.x) >= abs(e.y)) {
		if (abs(e.x) < 0.5) {
			return all(equal(d, a));
		}
		if (d.x < min(a.x, b.x) - 0.1 || d.x > max(a.x, b.x) + 0.1) {
			return false;
		}
		float y = a.y + e.y * (d.x - a.x) / e.x;
		return abs(d.y - floor(y + 0.5)) < 0.1;
	}
	if (d.y < min(a.y, b.y) - 0.1 || d.y > max(a.y, b.y) + 0.1) {
		return false;
	}
	float x = a.x + e.x * (d.y - a.y) / e.y;
	return abs(d.x - floor(x + 0.5)) < 0.1;
}

vec4 over(vec4 dst, vec3 c, float a) {
	if (a <= 0.004) {
		return dst;
	}
	float oa = a + dst.a * (1.0 - a);
	float k = a / oa;
	return vec4(c * k + dst.rgb * (1.0 - k), oa);
}

// painter.js circle(): every pixel whose centre is within r of the centre; a lone dot under 0.6 px
bool in_circle(vec2 off, vec2 d, vec2 fr, vec2 c, float r) {
	if (r < 0.6) {
		return all(equal(d, floor(fr + c)));
	}
	vec2 q = off - c;
	return dot(q, q) <= r * r;
}

void fragment() {
	// off: this pixel's centre from the particle; fr: where the particle sits in its own cell; d: this pixel's cell
	// from the particle's (the original draws whole cells: floor(x), floor(y))
	vec2 off = (UV - 0.5) * quad;
	vec2 fr = fract(0.5 - off);
	vec2 d = -floor(0.5 - off);
	int kd = int(kind + 0.5);
	float k = cu.z;
	vec4 c = vec4(0.0);
	if (kd == 0) {
		vec2 dir = cu.xy;
		vec4 head = k > 0.6 ? s0 : k > 0.3 ? s1 : s2;
		vec4 tail = k > 0.5 ? head : s3;
		if (on_line(d, floor(fr - dir * 0.45), vec2(0.0))) {
			c = head;
		} else if (on_line(d, floor(fr - dir), floor(fr - dir * 0.4))) {
			c = tail;
		}
	} else if (kd == 1) {
		vec2 dir = cu.xy;
		float a = k < 0.35 ? k / 0.35 : 1.0;
		if (on_line(d, floor(fr - dir * 0.4), vec2(0.0))) {
			c = vec4(pc.rgb, a);
		} else if (on_line(d, floor(fr - dir), floor(fr - dir * 0.35))) {
			c = vec4(pc.rgb * 0.55, a);
		}
	} else if (kd == 2) {
		// dots from the head back along the streak; the one nearest the head wins a cell
		float L = length(cu.xy);
		vec2 u = cu.xy / max(L, 1e-4);
		for (float q = 0.0; q <= 7.01; q += 0.5) {
			if (q > L + 1e-4) {
				break;
			}
			if (all(equal(floor(fr - u * q), d))) {
				vec3 cc = q < 1.0 ? vec3(1.0) : q < L * 0.5 ? pc.rgb : pc.rgb * 0.6;
				c = vec4(cc, q < L * 0.5 ? 1.0 : 1.2 - q / L);
				break;
			}
		}
	} else if (kd == 11) {
		if (k > 0.125) {
			if (all(equal(d, vec2(0.0)))) {
				c = vec4(pc.rgb, 1.0);
			} else if (cu.x >= 2.0) {
				if (all(equal(d, vec2(1.0, 0.0)))) {
					c = vec4(pc.rgb, 1.0);
				} else if (all(equal(d, vec2(0.0, 1.0)))) {
					c = vec4(pc.rgb * 0.8, 1.0);
				} else if (all(equal(d, vec2(1.0, 1.0)))) {
					c = vec4(pc.rgb * 0.7, 1.0);
				}
			}
		}
	} else if (kd == 14) {
		// a body bit on its way up: one in three a streak, longer the faster it goes, cooling as it climbs; the rest
		// a spark (s0..s2: white, C6, C5; s3: C3)
		float j = texelFetch(data, ivec2(int(cu.w + 0.5), 3), 0).w;
		float u = cu.z;
		vec4 head = u > 0.75 ? s0 : u > 0.4 ? s1 : s2;
		float L = cu.y;
		if (L >= 1.0 && j < 0.33) {
			vec2 b = floor(fr + vec2(cu.x, L));
			if (cell_on_line(d, vec2(0.0), b)) {
				vec2 e = abs(b);
				float n = max(1.0, max(e.x, e.y));
				float sv = (e.x >= e.y ? abs(d.x) : abs(d.y)) / n;
				c = sv < 0.25 ? head : sv < 0.6 ? s2 : s3;
			}
		} else if ((j < 0.75 || u > 0.6) && all(equal(d, vec2(0.0)))) {
			c = j > 0.9 ? s0 : head;
		}
	} else if (kd == 13) {
		// a dead pixel: an s x s rect at its rounded place, its own colour until it cools to s0
		vec2 r0 = floor(fr + 0.5);
		vec2 q = d - r0;
		if (cu.y > 0.5 && q.x >= 0.0 && q.y >= 0.0 && q.x < cu.x && q.y < cu.x) {
			c = cu.z > 0.5 ? vec4(pc.rgb, 1.0) : s0;
		}
	} else if (kd == 12) {
		if (cu.y > 0.5 && all(equal(d, vec2(0.0)))) {
			c = vec4(pc.rgb, 1.0);
		}
	} else if (kd == 3) {
		float a = min(1.0, k * 3.0);
		if (all(equal(d, vec2(0.0)))) {
			c = vec4(pc.rgb, a);
		} else if (cu.x > 1.3 && abs(d.x) + abs(d.y) < 1.5) {
			c = vec4(pc.rgb * 0.8, a * 0.8);
		}
	} else if (kd == 6) {
		float tw = cu.x;
		float size = cu.y;
		if (size < 1.0) {
			if (tw * k > 0.25 && all(equal(d, vec2(0.0)))) {
				c = tw > 0.8 ? vec4(1.0) : vec4(pc.rgb, 1.0);
			}
		} else {
			float n = floor(size * tw * min(1.0, k * 3.0) + 0.5);
			if (n >= 1.0) {
				vec3 tip = pc.rgb * 0.75;
				vec2 ad = abs(d);
				if (all(equal(d, vec2(0.0)))) {
					c = vec4(1.0);
				} else if ((ad.x < 0.5 || ad.y < 0.5) && max(ad.x, ad.y) <= n + 0.1) {
					c = vec4(max(ad.x, ad.y) > n * 0.6 ? tip : pc.rgb, 1.0);
				} else if (n >= 3.0 && ad.x > 0.5 && ad.x < 1.5 && ad.y > 0.5 && ad.y < 1.5) {
					c = vec4(pc.rgb, 1.0);
				} else if (n >= 6.0 && ad.x > 1.5 && ad.x < 2.5 && ad.y > 1.5 && ad.y < 2.5) {
					c = vec4(tip, 1.0);
				}
			}
		}
	} else if (kd == 7) {
		if (cu.x > 0.5) {
			vec4 hc = k > 0.6 ? s0 : k > 0.3 ? s1 : s2;
			if (all(equal(d, vec2(0.0)))) {
				c = hc;
			} else if (cu.y > 1.5 && all(equal(d, vec2(0.0, 1.0)))) {
				c = s3;
			}
		}
	} else if (kd == 9) {
		float r = cu.x;
		int idx = int(cu.y + 0.5);
		vec4 fc = fire[idx];
		if (idx >= 7) {
			if (in_circle(off, d, fr, vec2(0.0), r)) {
				c = vec4(fc.rgb, min(1.0, k * 3.0) * 0.85);
			}
		} else {
			if (idx <= 3 && r > 1.8 && in_circle(off, d, fr, vec2(-r * 0.28, -r * 0.34), r * 0.36)) {
				c = fire[max(0, idx - 1)];
			} else if (r > 1.6 && in_circle(off, d, fr, vec2(0.0, -r * 0.9), r * 0.42)) {
				c = fc;
			} else if (in_circle(off, d, fr, vec2(-r * 0.16, -r * 0.22), r * 0.78)) {
				c = fc;
			} else if (in_circle(off, d, fr, vec2(0.0), r)) {
				c = fire[min(8, idx + 2)];
			}
		}
	} else if (kd == 4 || kd == 5) {
		float r = cu.x * (0.6 + (1.0 - k) * 0.9);
		bool in_disc = r < 0.5 ? all(equal(d, vec2(0.0))) : dot(off, off) <= r * r;
		if (in_disc) {
			c = vec4(pc.rgb, pow(k, 1.3) * (kd == 4 ? 0.45 : 0.7));
		}
	} else if (kd == 8) {
		float age = 1.0 - k;
		float r = cu.x * (0.65 + min(1.0, age * 2.5) * 0.45 + age * (big > 0.5 ? 0.5 : 0.4));
		float a = min(1.0, age * 12.0) * min(1.0, k * 2.4) * (big > 0.5 ? 0.7 : 0.58);
		// a colourless puff walks down the smoke ramp; a coloured one fades into it
		float ra = plain ? age * 1.05 : age;
		int ri = int(clamp(floor(ra * 5.0), 0.0, 4.0));
		vec3 sr = ri == 0 ? s0.rgb : ri == 1 ? s1.rgb : ri == 2 ? s2.rgb : ri == 3 ? s3.rgb : smoke4.rgb;
		vec3 col = plain ? sr : mix(pc.rgb, sr, age);
		vec4 acc = vec4(0.0);
		if (dot(off, off) <= r * r) {
			acc = over(acc, col, a * 0.45);
		}
		vec2 o2 = off - vec2(r * 0.05, r * 0.06);
		if (dot(o2, o2) <= r * r * 0.74 * 0.74) {
			acc = over(acc, col, a * 0.62);
		}
		vec2 o3 = off - vec2(-r * 0.22, -r * 0.3);
		if (age < 0.5 && dot(o3, o3) <= r * r * 0.25) {
			acc = over(acc, mix(col, vec3(1.0), 0.12), a * 0.4 * (1.0 - age * 2.0));
		}
		c = acc;
	}
	if (c.a <= 0.0) {
		discard;
	}
	c.a *= COLOR.a;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
