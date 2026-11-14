// The tractor beam (src/fx/scifi/tractor-beam.js), from the keyed clock `t`, in the original's order:
//   mode 0: the pool of light where the beam meets the floor (translucent)
//   mode 1: the far half of the beam's rim on the floor; the rocks on the far side of the beam, seen through it
//   mode 2: the beam: a glassy cone, white-hot under the lens, hard bright edges with a dithered fringe, light
//           drifting in it (curtains, pulses climbing it; translucent inside)
//   mode 3: rings of light climbing the beam, quickening and narrowing with it (far half dim, near half bright)
//   mode 4: the near rocks and those still on the floor (a faint trail of their rush up, tumbling, lit from above by
//           the lens), a glint at the lens as each is swallowed
//   mode 5: the beam's rim on the floor in front; the hovering pod: a glassy cockpit on a wide hull, running lights
//           chasing round its rim, the lens underneath
// Colour layer (translucent where the original blends).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_scifi.gdshaderinc"

uniform vec2 size = vec2(120.0, 132.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform int mode = 0;
uniform vec4 pal[8] : source_color;
uniform vec4 hull[6] : source_color;
uniform vec4 stone[5] : source_color;
// the curtains' places across the beam (the original's rand(seed, s, 7))
uniform float curtain[4];
// the rocks: (born, r0, th0, dir), (size, a0, va, 0), their outline's six radii (rand(id, i)) in two vec4s
uniform vec4 rock_a[7];
uniform vec4 rock_b[7];
uniform vec4 rock_r0[7];
uniform vec4 rock_r1[7];

#include "res://addons/pixelfx_particles/fx/scifi/_tractor.gdshaderinc"

const float LIFE = POP + HOVER + RISE;

// a ring round the beam at height y: its far half (back) or near half
bool hoop_at(ivec2 P, float y, float rx, bool back) {
	if (abs(float(P.y) - y) > rx * 0.17 + 2.0) {
		return false;
	}
	float ry = rx * 0.17;
	int n = int(ceil(rx * 7.0));
	for (int i = 0; i < 300; i++) {
		if (i >= n) {
			break;
		}
		float g = float(i) / float(n) * TAU;
		float s = sin(g);
		if ((s >= 0.0) == back) {
			continue;
		}
		if (all(equal(floor(vec2(cos(g) * rx, y + s * ry)), vec2(P)))) {
			return true;
		}
	}
	return false;
}

float rad_of(int i, float ang, float R) {
	float n = 6.0;
	float f = mod((ang / TAU) * n, n);
	int j = int(floor(f));
	float kk = f - float(j);
	vec4 r0 = rock_r0[i];
	vec4 r1 = rock_r1[i];
	float v[6] = float[](r0.x, r0.y, r0.z, r0.w, r1.x, r1.y);
	return R * (0.75 + 0.35 * mix(v[j % 6], v[(j + 1) % 6], kk));
}

// rock i's own pixels at pixel centre pc (shaded), or alpha 0
vec4 rock_px(int i, Rock q, vec2 pc, bool back) {
	float R = max(0.9, q.size);
	vec2 d = pc - q.p;
	if (abs(d.x) > R + 2.5 || abs(d.y) > R + 2.5) {
		return vec4(0.0);
	}
	float ca = cos(q.a);
	float sa = sin(q.a);
	float u = d.x * ca + d.y * sa;
	float v = -d.x * sa + d.y * ca;
	float dd = length(vec2(u, v));
	float e = rad_of(i, atan(v, u), R);
	if (dd > e + 0.8) {
		return vec4(0.0);
	}
	if (dd > e) {
		return stone[0];
	}
	if (back) {
		return d.y < -0.3 * R ? stone[3] : stone[1];
	}
	vec3 lit = mix(stone[4].rgb, pal[6].rgb, 0.3 + 0.6 * q.lift);
	if (d.y < -0.45 * R) {
		return q.lift > 0.35 && dd > e - 1.0 ? pal[6] : vec4(lit, 1.0);
	}
	if (d.y < -0.1 * R) {
		return d.x < 0.0 ? stone[4] : stone[3];
	}
	return d.y > 0.35 * R ? stone[1] : stone[2];
}

vec4 rocks(ivec2 P, vec2 pc, bool back, float thr) {
	vec4 c = vec4(0.0);
	for (int i = 0; i < 7; i++) {
		float age = mod(t - rock_a[i].x, D);
		if (age >= LIFE) {
			continue;
		}
		Rock q = rock_at(rock_a[i], rock_b[i], age);
		if (back) {
			if (q.z < 0.0 && q.lift > 0.0) {
				vec4 rc = rock_px(i, q, pc, true);
				if (rc.a > 0.0) {
					c = rc;
				}
			}
			continue;
		}
		if (q.z >= 0.0 || q.lift <= 0.0) {
			float R = max(0.9, q.size);
			if (q.lift > 0.15) {
				// a faint trail of its rush up the beam, and soft puffs along it
				vec2 a = floor(q.prev);
				vec2 b = floor(q.p);
				if (cell_on_line(vec2(P), a, b)) {
					vec2 e = abs(b - a);
					float n = max(1.0, max(e.x, e.y));
					float u = (e.x >= e.y ? abs(float(P.x) - a.x) : abs(float(P.y) - a.y)) / n;
					if (0.7 * u >= thr && u > 0.0) {
						c = u > 0.6 ? pal[5] : pal[3];
					}
				}
				for (int j = 1; j <= 3; j++) {
					vec2 dc = mix(q.p, q.prev, float(j) / 3.0) + vec2(0.0, 1.0);
					float r = R * (0.5 + 0.25 * float(j));
					if (length(pc - dc) <= r) {
						c = blend_over(c, mix(stone[3].rgb, pal[5].rgb, 0.4), 0.22 * (1.0 - float(j) / 4.0) * q.lift);
					}
				}
			}
			vec4 rc = rock_px(i, q, pc, false);
			if (rc.a > 0.0) {
				c = rc;
			}
		}
		// swallowed: a glint at the lens
		if (age > LIFE - 0.1) {
			ivec2 s = ivec2(floor(vec2(q.p.x, LENS + 3.0)));
			ivec2 d = P - s;
			if (d == ivec2(0)) {
				c = vec4(1.0);
			} else if ((d.x == 0 && abs(d.y) <= 5) || (d.y == 0 && abs(d.x) <= 5)) {
				c = max(abs(d.x), abs(d.y)) > 3 ? pal[5] : pal[6];
			} else if (abs(d.x) == 1 && abs(d.y) == 1) {
				c = pal[6];
			}
		}
	}
	return c;
}

vec4 beam(ivec2 P, vec2 pc, float thr) {
	float y = float(P.y);
	if (y < ceil(LENS + 3.0) || y >= 0.0) {
		return vec4(0.0);
	}
	float ph = t / D;
	float w = half_w(y);
	float v = (y - LENS) / -LENS;
	bool pulse = mod(v * 3.2 + ph * 6.0, 1.0) < 0.08;
	float x = float(P.x);
	if (x < floor(-w) - 1.0 || x > ceil(w)) {
		return vec4(0.0);
	}
	float q = abs(x + 0.5) / w;
	if (q > 1.0 + 1.2 / w) {
		return vec4(0.0);
	}
	if (q > 1.0) {
		return 0.6 - 0.3 * v >= thr ? pal[4] : vec4(0.0);
	}
	if (q > 1.0 - 1.0 / w) {
		return v < 0.2 ? vec4(1.0) : v < 0.45 ? pal[6] : pal[5];
	}
	bool cur = false;
	for (int s = 0; s < 4; s++) {
		if (abs((x + 0.5) / w - (curtain[s] - 0.5) * 1.4 - 0.12 * sin(TAU * ph + float(s) * 1.7)) < 0.045) {
			cur = true;
		}
	}
	float core = pow(1.0 - q, 2.0) * pow(1.0 - v, 1.6);
	float a = 0.08 + 0.22 * pow(q, 4.0) + 0.6 * core + (pulse ? 0.12 : 0.0) + (cur ? 0.18 : 0.0);
	vec3 col = core > 0.45 ? vec3(1.0) : (cur || pulse || v < 0.35) ? pal[5].rgb : pal[4].rgb;
	return vec4(col, clamp(a, 0.0, 1.0));
}

vec4 pod(ivec2 P, vec2 pc) {
	float ph = t / D;
	float y = floor(LENS - 5.0 + 1.5 * sin(TAU * 2.0 * ph) + 0.5);
	vec4 c = vec4(0.0);
	float x = pc.x;
	float dy = pc.y - y;
	if (x >= -20.5 && x <= 21.5 && dy >= -11.5 && dy <= 6.5) {
		float cx = x / 8.5;
		float cy = (dy + 5.0) / 6.0;
		float hx = x / 20.0;
		float hy = (dy + 0.5) / 4.5;
		float wd = 19.5 - dy * 2.4;
		if (cy < 0.0 && cx * cx + cy * cy <= 1.0) {
			float d = cx * cx + cy * cy;
			float l = -cx * 0.6 - cy * 0.8;
			c = d > 0.8 ? hull[0] : l > 0.85 ? vec4(1.0) : l > 0.6 ? pal[6] : l > 0.2 ? pal[4] : pal[3];
		} else if (dy <= 0.0 && hx * hx + hy * hy <= 1.0) {
			float d = hx * hx + hy * hy;
			float l = -hx * 0.55 - hy * 0.7;
			c = d > 0.88 ? hull[0] : l > 0.55 ? hull[5] : l > 0.25 ? hull[4] : l > -0.1 ? hull[3] : hull[2];
		} else if (dy > 0.0 && dy <= 5.0 && abs(x) <= wd) {
			c = abs(x) > wd - 1.0 ? hull[0] : dy >= 4.0 && abs(x) < 9.0 ? pal[3] : hull[1];
		}
	}
	if (float(P.y) == y + 1.0) {
		for (int i = 0; i < 6; i++) {
			if (P.x == -15 + i * 6) {
				float k = 0.5 + 0.5 * cos(TAU * (4.0 * ph - float(i) / 6.0));
				c = k > 0.7 ? vec4(1.0) : k > 0.35 ? pal[5] : pal[2];
			}
		}
	}
	// the lens: a white-hot eye in a ring of light
	vec2 e = (pc - vec2(0.0, y + 5.5)) / vec2(7.5, 2.2);
	float d = length(e);
	if (d <= 1.0) {
		c = d < 0.45 ? vec4(1.0) : d < 0.75 ? pal[6] : d < 0.9 ? pal[5] : pal[3];
	}
	return c;
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size + 0.001);
	ivec2 P = ivec2(cell);
	vec2 pc = cell + 0.5;
	float thr = pfx_threshold(FRAGCOORD.xy);
	vec4 c = vec4(0.0);
	if (mode == 0) {
		if (P.y >= -6 && P.y <= 6 && abs(pc.x) <= BOTW + 1.0) {
			float d = length(vec2(pc.x / BOTW, pc.y / 5.5));
			if (d <= 1.0) {
				c = vec4(d < 0.35 ? pal[6].rgb : pal[5].rgb, 0.2 + 0.55 * pow(1.0 - d, 1.5));
			}
		}
	} else if (mode == 1) {
		if (hoop_at(P, 0.0, BOTW + 1.0, true)) {
			c = pal[5];
		}
		vec4 r = rocks(P, pc, true, thr);
		if (r.a > 0.0) {
			c = r;
		}
	} else if (mode == 2) {
		c = beam(P, pc, thr);
	} else if (mode == 3) {
		for (int i = 0; i < 5; i++) {
			float k = mod(t - float(i) / 5.0 * D, D) / 1.1;
			if (k >= 1.0) {
				continue;
			}
			float y = mix(0.0, LENS + 5.0, k * k);
			float w = half_w(y) + 1.0;
			if (hoop_at(P, y, w, true)) {
				c = pal[3];
			}
			if (hoop_at(P, y, w, false)) {
				c = k < 0.12 ? vec4(1.0) : pal[6];
			}
		}
	} else if (mode == 4) {
		c = rocks(P, pc, false, thr);
	} else {
		if (hoop_at(P, 0.0, BOTW + 1.0, false)) {
			c = vec4(1.0);
		}
		if (hoop_at(P, 1.0, BOTW, false)) {
			c = pal[5];
		}
		vec4 pd = pod(P, pc);
		if (pd.a > 0.0) {
			c = pd;
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (px_out(c, FRAGCOORD.xy, c.a < 0.999)) {
		discard;
	}
	COLOR = c;
}
