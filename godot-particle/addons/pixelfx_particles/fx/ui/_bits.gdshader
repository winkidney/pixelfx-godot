// How the ui effects' particles look (colour layer), drawn cell by cell as the original's painter draws each thing
// (src/core/painter.js, sim.js). Placed by _ftp.gdshader on its cell; `data` holds, per slot and frame:
//   row 0: cell x, cell y, kind, alpha (dithered; above 1 opaque)
//   row 1: colours c1, c2, c3 (packed 0xRRGGBB), the quad's size
//   rows 2..4: the kind's numbers (p0..p11)
// Kinds: 2 dot, 3 line (Bresenham, colour runs and a two-piece alpha ramp along it), 4 sparkle (sim.js), 5 circle / disc,
// 6 ring (colour bands across it), 7 an ellipse's rim, 8 beam (thick segment, colour bands along it), 9 shard
// (sim.js Bits), 11 rect, 20 coin (coin-collect), 21 paper (confetti), 22 plate of light (level-up), 23 one angle of a floor band.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform sampler2D data : filter_nearest, repeat_disable;
// the palette ramp's steps, for the coin
uniform vec4 pal[8] : source_color;
// translucent in its own colours (smoke): 32 dithered alpha steps, no palette snap
uniform bool raw = false;

varying flat vec4 cu;

const int ROWS = 5;

void vertex() {
	cu = INSTANCE_CUSTOM;
}

// this entry's texel r (cu.xy: the column and row its 5 texels start at, packed 1024 a row)
vec4 row(int r) {
	int k = int(cu.y + 0.5) * 1024 + int(cu.x + 0.5) + r;
	return texelFetch(data, ivec2(k % 1024, k / 1024), 0);
}

// painter.js line() from cell (0, 0) to cell e: the step index of cell d along it, or -1 off it
int line_step(vec2 d, vec2 e) {
	int sx = 0;
	int sy = 0;
	int ex = int(e.x);
	int ey = int(e.y);
	int dx = abs(ex);
	int dy = -abs(ey);
	int stx = ex > 0 ? 1 : -1;
	int sty = ey > 0 ? 1 : -1;
	int err = dx + dy;
	ivec2 q = ivec2(d);
	int hit = -1;
	for (int i = 0; i < 200; i++) {
		if (sx == q.x && sy == q.y) {
			hit = i;
		}
		if (sx == ex && sy == ey) {
			break;
		}
		int e2 = 2 * err;
		if (e2 >= dy) {
			err += dy;
			sx += stx;
		}
		if (e2 <= dx) {
			err += dx;
			sy += sty;
		}
	}
	return hit;
}

// three colour bands by u: below t1 (or at it, le), below t2, the rest
vec3 band3(float u, float t1, float t2, bool le, vec3 a, vec3 b, vec3 c) {
	bool in1 = le ? u <= t1 : u < t1;
	bool in2 = le ? u <= t2 : u < t2;
	return in1 ? a : in2 ? b : c;
}

// _ui coin(): a coin of radius r turned so its face is w wide, centred at off within cell (0, 0) (coin-collect)
int coin_px(vec2 d, vec2 off, float r, float w, bool white) {
	float rx = max(0.7, r * w);
	float ry = r;
	vec2 q = d + 0.5 - off;
	float u = q.x / rx;
	float v = q.y / ry;
	float dd = length(vec2(u, v));
	if (dd > 1.0) {
		return -1;
	}
	float e = (1.0 - dd) * min(rx * 1.6, ry);
	if (white) {
		return e < 1.0 ? 6 : 8;
	}
	if (e < 1.0) {
		return 1;
	}
	if (rx < 2.0) {
		return v < -0.2 ? 6 : v < 0.4 ? 4 : 3;
	}
	if (e < 2.0) {
		return u + v < -0.2 ? 6 : 3;
	}
	if (abs(q.x) < 0.55 && abs(v) < 0.5) {
		return 3;
	}
	if (q.x >= 0.55 && q.x < 1.55 && abs(v) < 0.5) {
		return 7;
	}
	float l = -(u * 0.6 + v * 0.8);
	return l > 0.4 ? 7 : l > 0.05 ? 6 : l > -0.35 ? 5 : 4;
}

vec3 unpack(float v) {
	// an exact whole number up to 2^24 (adding 0.5 up there would round it up)
	int i = int(v);
	return vec3(float((i >> 16) & 255), float((i >> 8) & 255), float(i & 255)) / 255.0;
}

void fragment() {
	vec4 r0 = row(0);
	vec4 r1 = row(1);
	vec4 r2 = row(2);
	vec4 r3 = row(3);
	vec4 r4 = row(4);
	float q = r1.w;
	vec2 d = floor((UV - 0.5) * q + 0.5);
	int kd = int(r0.z + 0.5);
	float a = r0.w;
	vec3 c1 = unpack(r1.x);
	vec3 c2 = unpack(r1.y);
	vec3 c3 = unpack(r1.z);
	vec4 c = vec4(0.0);
	vec2 ad = abs(d);
	if (kd == 2) {
		if (ad.x < 0.5 && ad.y < 0.5) {
			c = vec4(c1, a);
		}
	} else if (kd == 3) {
		// r2: end cell, the steps where the colour moves to c2 and to c3; r3: the step where the alpha changes piece,
		// whether step 0 takes the first piece, A0, A1; r4: B0, B1, reversed
		int i = line_step(d, r2.xy);
		if (i >= 0) {
			float fi = float(i);
			float n = max(1.0, max(abs(r2.x), abs(r2.y)));
			float u = fi / n;
			if (r4.z > 0.5) {
				u = 1.0 - u;
			}
			vec3 lc = fi < r2.z ? c1 : fi < r2.w ? c2 : c3;
			bool first = (fi < r3.x) == (r3.y > 0.5);
			float au = first ? r3.z + r3.w * u : r4.x + r4.y * u;
			c = vec4(lc, a * au);
		}
	} else if (kd == 4) {
		// sim.js sparkle(): arms of n px (past 60% the tip colour), diagonals from 3, longer from 6, a white heart
		float n = r2.x;
		float m = max(ad.x, ad.y);
		if (ad.x < 0.5 && ad.y < 0.5) {
			c = vec4(1.0);
		} else if ((ad.x < 0.5 || ad.y < 0.5) && m <= n + 0.1) {
			c = vec4(m > n * 0.6 ? c2 : c1, 1.0);
		} else if (n >= 3.0 && abs(ad.x - 1.0) < 0.1 && abs(ad.y - 1.0) < 0.1) {
			c = vec4(c1, 1.0);
		} else if (n >= 6.0 && abs(ad.x - 2.0) < 0.1 && abs(ad.y - 2.0) < 0.1) {
			c = vec4(c2, 1.0);
		}
	} else if (kd == 5) {
		vec2 p = d + 0.5 - r2.xy;
		if (dot(p, p) <= r2.z * r2.z) {
			c = vec4(c1, a);
		}
	} else if (kd == 6) {
		vec2 p = d + 0.5 - r2.xy;
		float d2 = dot(p, p);
		float r = r2.z;
		float w = r2.w;
		float r0_ = max(0.0, r - w);
		if (d2 <= r * r && d2 >= r0_ * r0_) {
			float den = r - r0_;
			float v = w > 0.0 ? (sqrt(d2) - r0_) / (den == 0.0 ? 1.0 : den) : 1.0;
			c = vec4(band3(v, r3.x, r3.y, int(r3.z + 0.5) == 1, c1, c2, c3), a);
		}
	} else if (kd == 7) {
		vec2 p = (d + 0.5 - r2.xy) / r2.zw;
		float d2 = dot(p, p);
		if (d2 <= 1.0 && sqrt(d2) > r3.x) {
			c = vec4(c1, a);
		}
	} else if (kd == 8) {
		vec2 pc = d + 0.5;
		vec2 A = r2.xy;
		vec2 e = r2.zw - A;
		float L2 = dot(e, e);
		if (L2 == 0.0) {
			L2 = 1e-9;
		}
		float u = clamp(dot(pc - A, e) / L2, 0.0, 1.0);
		vec2 p = A + e * u - pc;
		float r = r3.x;
		if (dot(p, p) <= r * r) {
			c = vec4(band3(u, r3.y, r3.z, int(r3.w + 0.5) == 1, c1, c2, c3), a);
		}
	} else if (kd == 9) {
		// sim.js Bits SHARD: dots every half px along its length, the far tip white; the last one on a cell wins
		float s = r3.x;
		bool hit = false;
		bool tip = false;
		for (int k = 0; k < 40; k++) {
			float dd = -s / 2.0 + 0.5 * float(k);
			if (dd > s / 2.0) {
				break;
			}
			vec2 cell = floor(r2.xy + r2.zw * dd);
			if (cell == d) {
				hit = true;
				tip = dd > s / 2.0 - 0.6;
			}
		}
		if (hit) {
			c = vec4(tip ? vec3(1.0) : c1, a);
		}
	} else if (kd == 11) {
		if (d.x >= 0.0 && d.y >= 0.0 && d.x < r2.x && d.y < r2.y) {
			c = vec4(c1, a);
		}
	} else if (kd == 20) {
		// r2: centre offset in the cell, radius, face width; r3.x: white
		int k = coin_px(d, r2.xy, r2.z, r2.w, r3.x > 0.5);
		if (k >= 0) {
			c = vec4(k == 8 ? vec3(1.0) : pal[k].rgb, a);
		}
	} else if (kd == 22) {
		// level-up's plate of light: an ellipse (rx, ry) round the origin, white at its heart, fading at its rim by k
		vec2 p = d + 0.5;
		float rx = r2.x;
		float ry = r2.y;
		float k = r2.z;
		if (d.x >= floor(-rx) && d.x <= ceil(rx) && d.y >= floor(-ry) && d.y <= ceil(ry)) {
			float dd = length(vec2(p.x / rx, p.y / ry));
			if (dd <= 1.0) {
				float u = dd / max(0.05, k);
				c = vec4(u < 0.3 ? vec3(1.0) : u < 0.55 ? c1 : u < 0.8 ? c2 : c3, dd < 0.6 * k ? 1.0 : k * (1.0 - dd) * 2.2);
			}
		}
	} else if (kd == 23) {
		// sim.js band(), one angle of it: its dots from th in to the rim, every half px (r2: the centre's offset in its
		// own cell, cos, sin; r3: r, sy, th, k; r4: hot, the fourth colour, the centre's cell from this one); the last
		// one drawn on a cell (past its dither) wins. Worked from the centre's own cell, so a dot a hair off a pixel
		// edge (a ring's flat ends) lands where the original's lands.
		// r4.x packs hot (bit 0) and the steps where the colour moves to the rim's (u < 0.7, 0.4, 0.15), decided at
		// build time as the original's doubles decide them (u lands on them exactly more often than not)
		float th_ = pfx_threshold(FRAGCOORD.xy);
		float th = r3.z;
		int pk = int(r4.x + 0.5);
		bool hot = (pk & 1) != 0;
		int s1 = (pk >> 1) & 31;
		int s2 = (pk >> 6) & 31;
		int s3 = (pk >> 11) & 31;
		int n = int(floor(th / 0.5 + 1e-4));
		for (int i = n; i >= 0; i--) {
			float o = th - 0.5 * float(i);
			float u = o / th;
			vec2 cell = floor(vec2(r2.x + r2.z * (r3.x - o), r2.y + r2.w * (r3.x - o) * r3.y)) + r4.zw;
			if (cell != d) {
				continue;
			}
			int b = i >= s3 ? 0 : i >= s2 ? 1 : i >= s1 ? 2 : 3;
			float aa = r3.w * (b <= 1 ? 1.2 : 1.15 - u);
			if (!(aa >= 1.0 || aa > th_)) {
				continue;
			}
			c = vec4(b == 0 ? (hot ? vec3(1.0) : c1) : b == 1 ? c2 : b == 2 ? c3 : unpack(r4.y), 1.0);
			break;
		}
	} else if (kd == 21) {
		// confetti's paper: a little card (w x h) turned by ang, its width by its flip; a white top edge face-on
		vec2 p = d + 0.5 - r2.xy;
		float ca = r3.x;
		float sa = r3.y;
		float u = p.x * ca + p.y * sa;
		float v = -p.x * sa + p.y * ca;
		float w = r2.z;
		float h = r2.w;
		if (!(abs(u) > w / 2.0 + 0.2 || abs(v) > h / 2.0)) {
			c = vec4(r3.z > 0.92 && v < -h / 2.0 + 1.0 ? vec3(1.0) : c1, a);
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (raw) {
		float q = floor(c.a * alpha_scale * 32.0 + pfx_threshold(FRAGCOORD.xy)) / 32.0;
		if (q <= 0.0) {
			discard;
		}
		c = vec4(c.rgb, min(q, 1.0));
	} else if (translucent) {
		if (pfx_pixel(c, FRAGCOORD.xy)) {
			discard;
		}
	} else {
		// painter.js put(): a dot below full alpha draws only when it is above its Bayer cell's threshold (at it: not)
		float a = c.a * alpha_scale;
		if (!(a >= 1.0 || a > pfx_threshold(FRAGCOORD.xy))) {
			discard;
		}
		c = vec4(pfx_snap(c.rgb), 1.0);
	}
	COLOR = c;
}
