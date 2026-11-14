// How the impacts' particles look (colour layer, or the soft layer with `translucent`), drawn as the original draws
// each kind (src/core/sim.js Particles.draw, Bits.draw, impacts/_lib.js rock()): a two-tone spark streak, a mote's
// trail, a grit pixel, a flake, a twinkling star glint, translucent dust discs and smoke puffs, a faceted rock lit
// from the top left, a tumbling shard. Moved by _sim.gdshader, which hands each one its streak and life in CUSTOM.
// The particle's quad (`quad` px, its texture's size) is a canvas the shader draws the kind on, cell by cell.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform sampler2D data : filter_nearest, repeat_disable;
uniform float kind = 0.0;
uniform vec2 quad = vec2(28.0);
// SPARK: the sparks ramp, head (hot) to tail
uniform vec4 s0 : source_color = vec4(1.0);
uniform vec4 s1 : source_color = vec4(1.0);
uniform vec4 s2 : source_color = vec4(1.0);
uniform vec4 s3 : source_color = vec4(1.0);
// CHUNK: stone colours (outline, light, body, shade); SMOKE: its ramp in s0..s3 + smoke4
uniform vec4 outline_c : source_color = vec4(0.1, 0.08, 0.13, 1.0);
uniform vec4 light_c : source_color = vec4(1.0);
uniform vec4 body_c : source_color = vec4(0.5);
uniform vec4 shade_c : source_color = vec4(0.3);
uniform vec4 smoke4 : source_color = vec4(0.1, 0.09, 0.12, 1.0);
uniform float big = 0.0;

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

void fragment() {
	// off: this pixel's centre from the particle; fr: where the particle sits in its own cell; d: this pixel's cell
	// from the particle's (the original draws whole cells: floor(x), floor(y))
	vec2 off = (UV - 0.5) * quad;
	vec2 fr = fract(0.5 - off);
	vec2 d = -floor(0.5 - off);
	int kd = int(kind + 0.5);
	float k = cu.z;
	int idx = int(cu.w + 0.5);
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
	} else if (kd == 5) {
		float r = cu.x * (0.6 + (1.0 - k) * 0.9);
		bool in_disc = r < 0.5 ? all(equal(d, vec2(0.0))) : dot(off, off) <= r * r;
		if (in_disc) {
			c = vec4(pc.rgb, pow(k, 1.3) * 0.7);
		}
	} else if (kd == 8) {
		float age = 1.0 - k;
		float r = cu.x * (0.65 + min(1.0, age * 2.5) * 0.45 + age * (big > 0.5 ? 0.5 : 0.4));
		float a = min(1.0, age * 12.0) * min(1.0, k * 2.4) * (big > 0.5 ? 0.7 : 0.58);
		int ri = int(clamp(floor(age * 5.0), 0.0, 4.0));
		vec3 sr = ri == 0 ? s0.rgb : ri == 1 ? s1.rgb : ri == 2 ? s2.rgb : ri == 3 ? s3.rgb : smoke4.rgb;
		vec3 col = mix(pc.rgb, sr, age);
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
	} else if (kd == 30) {
		// a soft puff: a body thinning to its rim, a lit cap up and to the left
		float r = cu.x;
		float a = cu.y;
		vec4 acc = vec4(0.0);
		float d1 = length(off) / max(r, 1e-3);
		if (d1 <= 1.0) {
			acc = over(acc, pc.rgb, 0.58 * a * (1.0 - d1 * d1 * 0.75));
		}
		float r2 = r * 0.58;
		float d2 = length(off - vec2(-r * 0.22, -r * 0.32)) / max(r2, 1e-3);
		if (d2 <= 1.0) {
			acc = over(acc, mix(pc.rgb, vec3(1.0), 0.55), 0.48 * a * (1.0 - d2 * d2));
		}
		c = acc;
	} else if (kd == 20) {
		vec4 e = texelFetch(data, ivec2(idx, 3), 0);
		vec4 p0 = texelFetch(data, ivec2(idx, 4), 0);
		vec4 p1 = texelFetch(data, ivec2(idx, 5), 0);
		float pts[8] = float[](p0.x, p0.y, p0.z, p0.w, p1.x, p1.y, p1.z, p1.w);
		float n = e.w;
		float rr = 0.75 + e.z * 0.8;
		float ang = cu.x;
		float ca = cos(ang);
		float sa = sin(ang);
		float u = off.x * ca + off.y * sa;
		float v = -off.x * sa + off.y * ca;
		float dd = length(vec2(u, v));
		float g = atan(v, u);
		if (g < 0.0) {
			g += 6.2831853;
		}
		float f = g / 6.2831853 * n;
		int i0 = int(mod(floor(f), n));
		int i1 = int(mod(float(i0 + 1), n));
		float w = f - floor(f);
		float edge = rr * (pts[i0] * (1.0 - w) + pts[i1] * w);
		if (dd <= edge + 0.85) {
			float lit = cos((float(i0) + 0.5) / n * 6.2831853 + ang + 2.3561945);
			vec4 col = dd > edge ? outline_c : dd < edge * 0.42 ? (lit > 0.55 ? light_c : body_c) : (lit > 0.35 ? light_c : lit < -0.4 ? shade_c : body_c);
			c = vec4(col.rgb, cu.y);
		}
	} else if (kd == 21) {
		vec4 e = texelFetch(data, ivec2(idx, 3), 0);
		float s = e.z;
		vec2 dir = vec2(cos(cu.x), sin(cu.x));
		for (float q = -s / 2.0; q <= s / 2.0 + 1e-4; q += 0.5) {
			if (all(equal(floor(fr + dir * q), d))) {
				c = vec4(q > s / 2.0 - 0.6 ? vec3(1.0) : pc.rgb, cu.y);
			}
		}
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
