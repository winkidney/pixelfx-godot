// The rune circle on the floor (after the original's circle()): three 1 px rings in perspective, lit by two sparks
// of light chasing round the outer one; studs round its outside turning a quarter a loop, a square turning the other
// way inside the inner ring, and twelve runes riding round the band, bobbing, bright at the front, dim behind and
// flaring as the light passes. `far` 1 draws the half behind the character (drawBack), 0 the half in front. `t` runs
// 0..1 over the loop. Coordinates: px from the effect's origin, the circle's centre. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(110.0, 40.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float far = 0.0;
uniform float R = 46.0;
uniform float RR = 39.0;
uniform float RI = 23.0;
uniform float RC = 7.0;
uniform float SY = 0.3;
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);

// glyphs 0, 3 and 5 of the original's rune alphabet, 3 x 5, bit (row * 3 + col)
const int G0 = 2 | (5 << 3) | (2 << 6) | (2 << 9) | (5 << 12);
const int G3 = 1 | (5 << 3) | (7 << 6) | (5 << 9) | (4 << 12);
const int G5 = 7 | (2 << 3) | (7 << 6) | (2 << 9) | (2 << 12);

float gap(float a, float b) {
	return abs(atan(sin(a - b), cos(a - b)));
}

bool keep(float g) {
	return far > 0.5 ? sin(g) < 0.0 : sin(g) >= 0.0;
}

// the original's floorRing(): is the pixel centre p on the 1 px ellipse of radius r? (angle out in g)
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

vec2 at(float g, float r) {
	return vec2(cos(g) * r, sin(g) * r * SY);
}

bool glyph_px(int gl, ivec2 q) {
	if (q.x < 0 || q.x > 2 || q.y < 0 || q.y > 4) {
		return false;
	}
	return ((gl >> (q.y * 3 + q.x)) & 1) == 1;
}

// is the pixel on the segment a-b, drawn as the original's Bresenham line?
bool on_line(vec2 cell, vec2 a, vec2 b) {
	vec2 fa = floor(a);
	vec2 fb = floor(b);
	vec2 d = fb - fa;
	if (abs(d.x) >= abs(d.y)) {
		if (cell.x < min(fa.x, fb.x) || cell.x > max(fa.x, fb.x)) {
			return false;
		}
		float u = abs(d.x) < 0.5 ? 0.0 : (cell.x - fa.x) / d.x;
		return cell.y == floor(fa.y + d.y * u + 0.5);
	}
	if (cell.y < min(fa.y, fb.y) || cell.y > max(fa.y, fb.y)) {
		return false;
	}
	float u = (cell.y - fa.y) / d.y;
	return cell.x == floor(fa.x + d.x * u + 0.5);
}

void fragment() {
	vec2 cell = floor((UV - 0.5) * size + center + 0.001);
	vec2 p = cell + 0.5;
	float spin = t * TAU / 4.0;
	float chase = t * TAU * 2.0;
	bool is_far = far > 0.5;
	vec4 c = vec4(0.0);
	float g;
	// the rings
	if (on_ring(p, R, g) && keep(g)) {
		float l = min(gap(g, chase), gap(g, chase + PI));
		c = l < 0.22 ? white : l < 0.5 ? c6 : (sin(g) < 0.0 ? c5 : c6);
	}
	if (on_ring(p, RI, g) && keep(g)) {
		c = sin(g) < 0.0 ? c4 : c5;
	}
	if (on_ring(p, RC, g) && keep(g)) {
		c = sin(g) < 0.0 ? c5 : c6;
	}
	// studs round the outside
	for (int j = 0; j < 16; j++) {
		float gs = spin + (float(j) + 0.5) * TAU / 16.0;
		if ((sin(gs) < 0.0) != is_far) {
			continue;
		}
		vec2 s = floor(at(gs, R + 3.5));
		bool hot = min(gap(gs, chase), gap(gs, chase + PI)) < 0.3;
		if (cell == s) {
			c = hot ? white : (sin(gs) < 0.0 ? c4 : (j % 2 == 1 ? c5 : c6));
		} else if (j % 2 == 0 && cell.y == s.y && abs(cell.x - s.x) == 1.0) {
			c = hot ? c6 : (sin(gs) < 0.0 ? c3 : c4);
		}
	}
	// the square, turning the other way, cut where it crosses the ring's middle line
	for (int k = 0; k < 4; k++) {
		vec2 a = at(-spin + float(k) * TAU / 4.0 + PI / 4.0, RI);
		vec2 b = at(-spin + float(k + 1) * TAU / 4.0 + PI / 4.0, RI);
		if ((a.y < 0.0) != (b.y < 0.0)) {
			float u = a.y / (a.y - b.y);
			float mx = a.x + (b.x - a.x) * u;
			if ((a.y < 0.0) == is_far) {
				b = vec2(mx, 0.0);
			} else {
				a = vec2(mx, 0.0);
			}
		} else if ((a.y < 0.0) != is_far) {
			continue;
		}
		if (on_line(cell, a, b)) {
			c = is_far ? c4 : c5;
		}
	}
	// the runes, nearest drawn last
	float best = -2.0;
	for (int k = 0; k < 12; k++) {
		float gr = spin + (float(k) + 0.5) * TAU / 12.0;
		if ((sin(gr) < 0.0) != is_far || sin(gr) < best) {
			continue;
		}
		vec2 xy = at(gr, RR);
		bool hot = min(gap(gr, chase), gap(gr, chase + PI)) < 0.2;
		float bob = sin(t * TAU * 4.0 + 4.0 * gr) * 0.5;
		ivec2 o = ivec2(int(round(xy.x)) - 1, int(round(xy.y - 1.0 + bob)) - 4);
		int gl = k % 3 == 0 ? G0 : k % 3 == 1 ? G3 : G5;
		ivec2 q = ivec2(cell) - o;
		if (glyph_px(gl, q)) {
			c = hot ? white : (is_far ? c5 : c6);
			best = sin(gr);
		} else if (glyph_px(gl, q - ivec2(0, 1))) {
			c = hot ? c5 : (is_far ? c2 : c3);
			best = sin(gr);
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
