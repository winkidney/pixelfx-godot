// The thorny vine of nature/vine-whip, after the original's vine() and thorns(): a stroke through 25 points (keyed
// by the animation), thick at the root and thin at the tip, lit on whichever side faces the top left with a bright
// edge, dark beneath, bark notches; hooked thorns on alternate sides raking back toward the root; three leaves on
// short stalks that sway with `t` (seconds). Coordinates are px from the effect's origin; nothing below the floor.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

const int N = 24;
const float LS = 3.3;

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec2 pts[25];
uniform float t = 0.0;
// C: the vine ramp (8, dark to bright); T: the thorn ramp (4)
uniform vec4 c0 : source_color;
uniform vec4 c1 : source_color;
uniform vec4 c2 : source_color;
uniform vec4 c3 : source_color;
uniform vec4 c4 : source_color;
uniform vec4 c5 : source_color;
uniform vec4 c6 : source_color;
uniform vec4 t1 : source_color;
uniform vec4 t2 : source_color;
uniform vec4 t3 : source_color;
uniform float alpha = 1.0;

float width_at(float s) {
	return 1.2 + 4.8 * pow(1.0 - s, 0.7);
}

float jsmod(float a, float b) {
	return a - b * trunc(a / b);
}

// Bresenham-like: is the pixel centre q on the line between the pixels of a and b?
bool on_line(vec2 q, vec2 a, vec2 b) {
	vec2 A = floor(a) + 0.5;
	vec2 B = floor(b) + 0.5;
	vec2 d = B - A;
	if (abs(d.x) >= abs(d.y)) {
		if (abs(d.x) < 0.5) {
			return all(equal(floor(q), floor(A)));
		}
		float s = (q.x - A.x) / d.x;
		if (s < -0.01 || s > 1.01) return false;
		return abs(q.y - (A.y + s * d.y)) <= 0.5;
	}
	float s = (q.y - A.y) / d.y;
	if (s < -0.01 || s > 1.01) return false;
	return abs(q.x - (A.x + s * d.x)) <= 0.5;
}

bool in_tri(vec2 p, vec2 a, vec2 b, vec2 c) {
	float d1 = (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y);
	float d2 = (p.x - c.x) * (b.y - c.y) - (b.x - c.x) * (p.y - c.y);
	float d3 = (p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y);
	bool neg = d1 < 0.0 || d2 < 0.0 || d3 < 0.0;
	bool pos = d1 > 0.0 || d2 > 0.0 || d3 > 0.0;
	return !(neg && pos);
}

// drawLeaf's inside test: 0 outside, 1 the lit half, 2 the other
int leaf_in(vec2 ij, float len, float w, float ca, float sa) {
	float u = (ij.x + 0.5) * ca + (ij.y + 0.5) * sa + len / 2.0;
	float v = -(ij.x + 0.5) * sa + (ij.y + 0.5) * ca;
	if (u < 0.0 || u > len) return 0;
	float half_w = w * pow(sin(3.14159265 * u / len), 0.75);
	return abs(v) <= half_w ? (v < 0.0 ? 1 : 2) : 0;
}

void fragment() {
	vec2 cell = floor((UV - 0.5) * size + center + vec2(0.001));
	vec2 q = cell + 0.5;
	vec4 col = vec4(0.0);
	bool any = false;
	if (cell.y <= 0.0) {
		// the stroke, segment by segment (later ones over earlier ones)
		for (int i = 0; i < N; i++) {
			vec2 a = pts[i];
			vec2 b = pts[i + 1];
			vec2 dd = b - a;
			float L = max(length(dd), 1e-4);
			vec2 nn = vec2(-dd.y / L, dd.x / L);
			vec2 pp = q - a;
			float u = dot(pp, dd) / (L * L);
			if (u < -0.15 || u > 1.15) continue;
			float d = dot(pp, nn);
			float w = mix(width_at(float(i) / float(N)) / 2.0, width_at(float(i + 1) / float(N)) / 2.0, clamp(u, 0.0, 1.0)) + 0.35;
			if (abs(d) > w) continue;
			float up = nn.x * -0.6 + nn.y * -0.8 > 0.0 ? 1.0 : -1.0;
			float side = sign(d) * up;
			float qq = abs(d) / w;
			float arc = (float(i) + u) * LS;
			vec4 c = qq > 0.8 ? (side > 0.0 ? c5 : c1) : side > 0.0 ? (qq > 0.35 ? c4 : c3) : (qq > 0.4 ? c2 : c3);
			if (w > 1.6 && abs(jsmod(arc + d * 0.8, 5.0) - 2.5) < 0.45 && qq < 0.8) c = c2;
			col = c;
			any = true;
		}
	}
	// thorns, alternating sides, hooked back toward the root
	for (int i = 2; i < N - 1; i += 2) {
		vec2 a = pts[i];
		vec2 b = pts[i + 1];
		vec2 dd = b - a;
		float L = max(length(dd), 1e-4);
		float side = (i / 2) % 2 == 1 ? 1.0 : -1.0;
		vec2 nn = vec2(-dd.y / L, dd.x / L) * side;
		float w = width_at(float(i) / float(N)) / 2.0;
		float len = 1.8 + 2.4 * (1.0 - float(i) / float(N));
		vec2 tt = dd / L;
		vec2 p0 = a + nn * (w - 0.5);
		if (p0.y > 0.0) continue;
		vec2 tip = p0 + nn * len - tt * len * 0.7;
		if (in_tri(q, p0 - tt * 1.6, p0 + tt * 1.4, tip)) { col = t1; any = true; }
		if (on_line(q, p0 + tt * 0.8, tip)) { col = t2; any = true; }
		if (all(equal(cell, floor(tip)))) { col = t3; any = true; }
	}
	// leaves on short stalks
	for (int n = 0; n < 3; n++) {
		int k = n == 0 ? 7 : (n == 1 ? 13 : 18);
		vec2 a = pts[k];
		vec2 b = pts[k + 1];
		if (a.y > -2.0) continue;
		float ang = atan(b.y - a.y, b.x - a.x);
		float side = k % 2 == 1 ? 1.0 : -1.0;
		float la = ang + side * 1.1 + sin(t * 9.0 + float(k)) * 0.2;
		vec2 lc = a + vec2(cos(la), sin(la)) * 4.0;
		float fl = 0.3 + sin(t * 5.0 + float(k)) * 0.4;
		float len = 7.0;
		float ca = cos(la);
		float sa = sin(la);
		float sq = cos(fl);
		float w = max(0.55, abs(sq) * 2.2);
		bool under = sq < 0.0;
		vec2 X = floor(lc + 0.5);
		vec2 ij = cell - X;
		int s = leaf_in(ij, len, w, ca, sa);
		if (s == 0) {
			if (leaf_in(ij + vec2(-1, 0), len, w, ca, sa) > 0 || leaf_in(ij + vec2(1, 0), len, w, ca, sa) > 0 || leaf_in(ij + vec2(0, -1), len, w, ca, sa) > 0 || leaf_in(ij + vec2(0, 1), len, w, ca, sa) > 0) {
				col = c1;
				any = true;
			}
		} else {
			float u = (ij.x + 0.5) * ca + (ij.y + 0.5) * sa + len / 2.0;
			float v = -(ij.x + 0.5) * sa + (ij.y + 0.5) * ca;
			bool rib = abs(v) < 0.5 && u > len * 0.12 && u < len * 0.88 && w > 1.2;
			col = rib ? c3 : ((s == 1) != under ? c6 : c5);
			any = true;
		}
		vec2 stem = floor(X - vec2(ca, sa) * (len / 2.0 + 1.0));
		if (all(equal(cell, stem))) { col = c3; any = true; }
	}
	if (!any) {
		discard;
	}
	vec4 c = vec4(col.rgb, alpha);
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
