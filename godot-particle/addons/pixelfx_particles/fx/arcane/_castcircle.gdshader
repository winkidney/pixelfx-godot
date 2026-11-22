// The magic circle (after magic-circle-cast.js circle() and runes()): drawn on the floor by pens (the two outer rings
// from the front round both sides to the back, the inner ring from the back all the way round, ticks between the
// outer rings, a hexagram edge by edge), every line fresh-white as it's written and burning at the circle's level;
// two sparks chase round the outer ring as the runes light; eight runes stand on it, dim until lit one by one, rise,
// bob, and go out one by one. `far` 1 draws the half behind (drawBack), 0 the near half. `t` runs 0..1 over the
// effect (`dur` s). Coordinates: px from the effect's origin, the circle's centre. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/arcane/_glyphs.gdshaderinc"

uniform vec2 size = vec2(100.0, 40.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float dur = 3.9;
uniform float far = 0.0;
uniform vec4 c3 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);

const float R = 40.0;
const float R2 = 35.0;
const float RI = 24.0;
const float RR = 30.0;
const float SY = 0.3;
const vec2 PEN = vec2(0.04, 0.42);
const vec2 PEN2 = vec2(0.1, 0.48);
const vec2 INNER = vec2(0.3, 0.6);
const vec2 STAR = vec2(0.52, 0.88);
const vec2 RUNES = vec2(0.9, 1.3);
const float FLASH = 1.52;
const float BREAK = 2.42;
const float GONE = 3.45;

float sm(float a, float b, float x) {
	return smoothstep(a, b, x);
}

float level(float s) {
	if (s < RUNES.x) return 0.55;
	if (s < FLASH) return 0.55 + 0.4 * sm(RUNES.x, FLASH, s);
	if (s < FLASH + 0.07) return 1.2;
	if (s < BREAK) return 0.92;
	return 0.92 * (1.0 - sm(BREAK, GONE, s));
}

vec4 line_col(float lvl, float age) {
	return age < 0.05 ? white : age < 0.16 ? c6 : lvl > 1.0 ? white : lvl > 0.8 ? c6 : lvl > 0.45 ? c5 : lvl > 0.28 ? c4 : c3;
}

float wrap_tau(float a) {
	return mod(mod(a, TAU) + TAU, TAU);
}

float from_front(float g) {
	return abs(atan(sin(g - PI * 0.5), cos(g - PI * 0.5)));
}

float outer_at(float g, vec2 w) {
	return w.x + from_front(g) / PI * (w.y - w.x);
}

float inner_at(float g) {
	return INNER.x + wrap_tau(g + PI * 0.5) / TAU * (INNER.y - INNER.x);
}

bool keep(float g) {
	return far > 0.5 ? sin(g) < 0.0 : sin(g) >= 0.0;
}

bool on_ring(vec2 p, float r, out float g) {
	float ry = r * SY;
	vec2 n = vec2(p.x / r, p.y / max(0.3, ry));
	float d = length(n);
	g = atan(n.y, n.x);
	if (d < 1e-6) {
		return false;
	}
	float gr = length(vec2(n.x / r, n.y / max(0.3, ry))) / d;
	return abs(d - 1.0) / gr <= 0.5;
}

// the Bresenham line a-b through cell? u out: how far along (0..1)
bool on_line(vec2 cell, vec2 a, vec2 b, out float u) {
	vec2 fa = floor(a);
	vec2 fb = floor(b);
	vec2 d = fb - fa;
	u = 0.0;
	if (abs(d.x) >= abs(d.y)) {
		if (cell.x < min(fa.x, fb.x) || cell.x > max(fa.x, fb.x)) {
			return false;
		}
		u = abs(d.x) < 0.5 ? 0.0 : (cell.x - fa.x) / d.x;
		return cell.y == floor(fa.y + d.y * u + 0.5);
	}
	if (cell.y < min(fa.y, fb.y) || cell.y > max(fa.y, fb.y)) {
		return false;
	}
	u = (cell.y - fa.y) / d.y;
	return cell.x == floor(fa.x + d.x * u + 0.5);
}

vec2 tri(float a0, int k) {
	float a = a0 + float(k) * TAU / 3.0;
	return vec2(cos(a), sin(a)) * RI;
}

void fragment() {
	float s = t * dur;
	if (s >= GONE + 0.25 && s >= BREAK + 0.2 + 7.0 * 0.08 + 0.25) {
		discard;
	}
	vec2 cell = floor((UV - 0.5) * size + center + 0.001);
	vec2 p = cell + 0.5;
	bool is_far = far > 0.5;
	float lvl = level(s);
	float la = clamp(lvl / 0.3, 0.0, 1.0);
	vec4 c = vec4(0.0);
	float g;
	if (s < GONE) {
		// the rings, each pixel lit once its pen has passed
		if (on_ring(p, R, g) && keep(g)) {
			float when = outer_at(g, PEN);
			if (s >= when) {
				c = vec4(line_col(lvl, s - when).rgb, la);
				if (s > RUNES.x && s < BREAK) {
					float run = (s - RUNES.x) * 5.0 + pow(s - RUNES.x, 2.0) * 4.0;
					if (abs(atan(sin(g - run), cos(g - run))) < 0.22 || abs(atan(sin(g - run - PI), cos(g - run - PI))) < 0.22) {
						c = vec4(white.rgb, la);
					}
				}
			}
		}
		if (on_ring(p, R2, g) && keep(g)) {
			float when = outer_at(g, PEN2);
			if (s >= when) {
				c = vec4(line_col(lvl, s - when).rgb, la);
			}
		}
		if (on_ring(p, RI, g) && keep(g)) {
			float when = inner_at(g);
			if (s >= when) {
				c = vec4(line_col(lvl, s - when).rgb, la);
			}
		}
		// ticks across the band between the two outer rings
		for (int j = 0; j < 32; j++) {
			float gt = (float(j) + 0.5) * TAU / 32.0;
			if ((sin(gt) < 0.0) != is_far) {
				continue;
			}
			float when = outer_at(gt, PEN2) + 0.03;
			float u;
			if (s >= when && on_line(cell, vec2(cos(gt) * R2, sin(gt) * R2 * SY), vec2(cos(gt) * R, sin(gt) * R * SY), u)) {
				c = vec4(line_col(lvl, s - when).rgb, la * (j % 2 == 1 ? 0.6 : 1.0));
			}
		}
		// the hexagram, edge by edge (both triangles at once), cut where it crosses the middle line
		for (int k = 0; k < 3; k++) {
			float t0 = STAR.x + float(k) * (STAR.y - STAR.x) / 3.0;
			float edur = (STAR.y - STAR.x) / 3.0;
			float sp = clamp((s - t0) / edur, 0.0, 1.0);
			if (sp <= 0.0) {
				continue;
			}
			for (int tr = 0; tr < 2; tr++) {
				float a0 = tr == 0 ? -PI * 0.5 : PI * 0.5;
				vec2 p0 = tri(a0, k);
				vec2 p1 = tri(a0, k + 1);
				float u0 = 0.0;
				float u1 = sp;
				if ((p0.y < 0.0) != (p1.y < 0.0)) {
					float uc = p0.y / (p0.y - p1.y);
					if ((p0.y < 0.0) == is_far) {
						u1 = min(u1, uc);
					} else {
						u0 = uc;
					}
				} else if ((p0.y < 0.0) != is_far) {
					continue;
				}
				if (u1 <= u0) {
					continue;
				}
				vec2 a = vec2(p0.x + (p1.x - p0.x) * u0, (p0.y + (p1.y - p0.y) * u0) * SY);
				vec2 b = vec2(p0.x + (p1.x - p0.x) * u1, (p0.y + (p1.y - p0.y) * u1) * SY);
				float u;
				if (on_line(cell, a, b, u)) {
					float age = s - (t0 + (u0 + (u1 - u0) * u) * edur);
					c = vec4(line_col(lvl, age).rgb, la);
				}
			}
		}
	}
	// the runes
	for (int k = 0; k < 8; k++) {
		float gr = -PI * 0.5 + (float(k) + 0.5) * TAU / 8.0;
		if ((sin(gr) < 0.0) != is_far) {
			continue;
		}
		float x = cos(gr) * RR;
		float y0 = sin(gr) * RR * SY;
		float lit = s - (RUNES.x + float(k) * (RUNES.y - RUNES.x) / 7.0);
		float gone = clamp((s - (BREAK + 0.2 + float(k) * 0.08)) / 0.25, 0.0, 1.0);
		if (s < inner_at(gr) || gone >= 1.0) {
			continue;
		}
		float y = y0 - 1.0;
		vec4 body = c3;
		vec4 under = vec4(0.0);
		float a = 1.0;
		if (lit >= 0.0) {
			float q = clamp(lit / 0.2, 0.0, 1.0);
			float s2 = 2.4;
			float rise = q <= 0.0 ? 0.0 : q >= 1.0 ? 3.0 : 3.0 * (1.0 + (s2 + 1.0) * pow(q - 1.0, 3.0) + s2 * pow(q - 1.0, 2.0));
			float bob = lit > 0.2 ? sin(s * 5.0 + float(k)) * 0.5 : 0.0;
			y = y0 - 1.0 - rise + bob;
			bool hot = lit < 0.07 || (s > FLASH && s < FLASH + 0.07);
			body = hot ? white : lvl > 0.8 ? white : c6;
			under = hot ? c6 : c4;
			a = 1.0 - gone;
		}
		ivec2 o = ivec2(int(round(x)) - 1, int(round(y)) - 4);
		ivec2 q = ivec2(cell) - o;
		if (pfx_glyph(k, q)) {
			c = vec4(body.rgb, a);
		} else if (under.a > 0.0 && pfx_glyph(k, q - ivec2(0, 1))) {
			c = vec4(under.rgb, a);
		}
		// a glint as it lights
		if (lit >= 0.0 && lit < 0.1) {
			int n = int(round(4.0 * (1.0 - lit / 0.1) + 1.0));
			ivec2 sq = ivec2(cell) - ivec2(int(floor(x)), int(floor(y - 2.0)));
			int ax = abs(sq.x);
			int ay = abs(sq.y);
			if (sq == ivec2(0)) {
				c = white;
			} else if ((sq.x == 0 && ay <= n) || (sq.y == 0 && ax <= n)) {
				c = float(max(ax, ay)) > float(n) * 0.6 ? c5 : c6;
			} else if (n >= 3 && ax == 1 && ay == 1) {
				c = c6;
			}
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
