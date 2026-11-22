// The flower of nature/healing-bloom, after the original's stem(), petal() and draw(), all from `t` (seconds, keyed
// by the animation): a lit floor line, a 2 px shoot swaying in a gentle S, two leaves unfurling off it, a bud that
// swells, six petals splaying open round a golden heart (the far ones behind it) and letting go one by one, the
// whole plant wilting back into the floor. Coordinates are px from the effect's origin.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

const float STEM = 0.42;
const float BUD = 0.75;
const float OPEN = 1.05;
const float LIFT = 1.7;
const float WILT = 2.4;
const float H = 36.0;

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
// C: the plant ramp (8, dark to bright); P: the petal ramp (4); G: the heart ramp (4)
uniform vec4 c1 : source_color;
uniform vec4 c3 : source_color;
uniform vec4 c4 : source_color;
uniform vec4 c5 : source_color;
uniform vec4 c6 : source_color;
uniform vec4 p0 : source_color;
uniform vec4 p1 : source_color;
uniform vec4 p2 : source_color;
uniform vec4 p3 : source_color;
uniform vec4 g1 : source_color;
uniform vec4 g2 : source_color;
uniform vec4 g3 : source_color;

float smooth_(float a, float b, float x) {
	float u = clamp((x - a) / (b - a), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

float out_back(float x, float s) {
	if (x <= 0.0) return 0.0;
	if (x >= 1.0) return 1.0;
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0);
}

float grow_() {
	float a = clamp(t / STEM, 0.0, 1.0);
	float b = clamp((t - WILT) / 0.6, 0.0, 1.0);
	return (1.0 - pow(1.0 - a, 3.0)) * (1.0 - b * b * b);
}

vec2 stem_pt(int i, float g) {
	float s = float(i) / 12.0;
	float sway = sin(t * 2.6) * 1.4 * smooth_(0.2, 0.6, t);
	return vec2(sin(s * 3.2) * 2.2 * s + sway * s * s, (1.0 - g) * H * 1.1 - s * H);
}

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

int leaf_in(vec2 ij, float len, float w, float ca, float sa) {
	float u = (ij.x + 0.5) * ca + (ij.y + 0.5) * sa + len / 2.0;
	float v = -(ij.x + 0.5) * sa + (ij.y + 0.5) * ca;
	if (u < 0.0 || u > len) return 0;
	float half_w = w * pow(sin(PI * u / len), 0.75);
	return abs(v) <= half_w ? (v < 0.0 ? 1 : 2) : 0;
}

// drawLeaf: centred on (x, y), len long, wid across, turned by ang, flipped by fl; pal dark..bright
bool leaf(vec2 cell, vec2 at, float len, float wid, float ang, float fl, vec4 q0, vec4 q1, vec4 q2, vec4 q3, inout vec4 col) {
	float ca = cos(ang);
	float sa = sin(ang);
	float sq = cos(fl);
	float w = max(0.55, abs(sq) * wid);
	bool under = sq < 0.0;
	vec2 X = floor(at + 0.5);
	vec2 ij = cell - X;
	bool hit = false;
	int s = leaf_in(ij, len, w, ca, sa);
	if (s == 0) {
		if (leaf_in(ij + vec2(-1, 0), len, w, ca, sa) > 0 || leaf_in(ij + vec2(1, 0), len, w, ca, sa) > 0 || leaf_in(ij + vec2(0, -1), len, w, ca, sa) > 0 || leaf_in(ij + vec2(0, 1), len, w, ca, sa) > 0) {
			col = q0;
			hit = true;
		}
	} else {
		float u = (ij.x + 0.5) * ca + (ij.y + 0.5) * sa + len / 2.0;
		float v = -(ij.x + 0.5) * sa + (ij.y + 0.5) * ca;
		bool rib = abs(v) < 0.5 && u > len * 0.12 && u < len * 0.88 && w > 1.2;
		col = rib ? q1 : ((s == 1) != under ? q3 : q2);
		hit = true;
	}
	if (all(equal(cell, floor(X - vec2(ca, sa) * (len / 2.0 + 1.0))))) {
		col = q1;
		hit = true;
	}
	return hit;
}

bool petal(vec2 cell, int i, vec2 top, bool far_side, inout vec4 col) {
	float az = float(i) / 6.0 * 2.0 * PI + 0.3;
	if ((sin(az) < 0.0) != far_side) return false;
	float at_ = LIFT + mod(float(i) * 0.37, 1.0) * 0.55;
	if (t >= at_ || t <= BUD - 0.05) return false;
	float op = out_back(clamp((t - BUD) / (OPEN - BUD), 0.0, 1.0), 1.4);
	float e = mix(0.15, PI / 2.0 - 0.2, op);
	float dx = sin(e) * cos(az);
	float dz = sin(e) * sin(az);
	float dy = -cos(e);
	float L = mix(8.0, 12.0, op);
	float len = L * length(vec2(dx, dy));
	float ang = atan(dy, dx);
	bool back = dz < 0.0;
	if (len < 1.5) return false;
	vec2 at = vec2(top.x + dx * L * 0.5, top.y - 3.0 + dy * L * 0.5);
	if (back) {
		return leaf(cell, at, len + 1.0, 3.0 + (1.0 - abs(dz)) * 0.8, ang, 0.9, p0, p0, p1, p2, col);
	}
	return leaf(cell, at, len + 1.0, 3.0 + (1.0 - abs(dz)) * 0.8, ang, 0.2, p0, p1, p2, p3, col);
}

void fragment() {
	vec2 cell = floor((UV - 0.5) * size + center + vec2(0.001));
	vec2 q = cell + 0.5;
	vec4 col = vec4(0.0);
	float a = 1.0;
	bool any = false;
	float g = grow_();
	vec2 top = stem_pt(12, g);
	// the lit floor line
	if (cell.y == 0.0) {
		float fw = 6.0 + 16.0 * smooth_(0.0, 0.8, t);
		if (cell.x >= floor(-fw) && cell.x <= fw) {
			float u = abs(cell.x) / fw;
			a = sqrt(max(0.0, 1.0 - u)) * smooth_(0.0, 0.4, t) * (1.0 - smooth_(WILT, WILT + 0.6, t));
			col = u < 0.3 ? c6 : (u < 0.65 ? c5 : c4);
			any = a > 0.0;
		}
	}
	// the far petals behind everything
	for (int i = 0; i < 6; i++) {
		if (petal(cell, i, top, true, col)) { any = true; a = 1.0; }
	}
	if (g > 0.02) {
		// the shoot, lit down its left side
		for (int i = 1; i <= 12; i++) {
			vec2 s0 = stem_pt(i - 1, g);
			vec2 s1 = stem_pt(i, g);
			if (s1.y > 0.0) continue;
			if (on_line(q, s0, s1)) { col = c5; any = true; a = 1.0; }
			if (on_line(q, s0 + vec2(1, 0), s1 + vec2(1, 0))) { col = c3; any = true; a = 1.0; }
		}
		// leaves unfurling off it
		for (int n = 0; n < 2; n++) {
			int i = n == 0 ? 4 : 7;
			float sd = n == 0 ? -1.0 : 1.0;
			float d = n == 0 ? 0.1 : 0.22;
			float lk = out_back(clamp((t - d - 0.12) / 0.3, 0.0, 1.0), 1.6) * (1.0 - smooth_(WILT, WILT + 0.5, t) * 0.4);
			vec2 p = stem_pt(i, g);
			if (lk <= 0.0 || p.y > -1.0) continue;
			float la = sd < 0.0 ? -2.6 + 0.4 * (1.0 - lk) : -0.55 - 0.4 * (1.0 - lk);
			if (leaf(cell, p + vec2(cos(la), sin(la)) * 6.0 * lk, 12.0 * lk, 3.4, la, 0.25, c1, c3, c5, c6, col)) { any = true; a = 1.0; }
		}
		// the bud
		if (t > STEM - 0.1 && t < OPEN - 0.1) {
			float b = clamp((t - STEM + 0.1) / (BUD - STEM), 0.0, 1.0);
			float w = 2.0 + 2.5 * b;
			float h = 3.5 + 5.0 * b;
			vec2 bc = vec2(top.x, top.y - h * 0.6);
			vec2 dd = (q - bc) / vec2(w, h);
			float d2 = dot(dd, dd);
			if (d2 <= 1.0) {
				float an = atan(dd.y, dd.x);
				col = cos(an) < -0.2 ? p2 : (sqrt(d2) > 0.7 ? p0 : p1);
				any = true;
				a = 1.0;
			}
		}
	}
	for (int i = 0; i < 6; i++) {
		if (petal(cell, i, top, false, col)) { any = true; a = 1.0; }
	}
	// the golden heart
	if (t > OPEN - 0.12 && t < WILT + 0.3) {
		float k = 1.0 - smooth_(WILT - 0.3, WILT + 0.3, t);
		float cy = top.y - 4.0;
		float r1 = 3.3 * k;
		float r2 = 2.2 * k;
		if ((r1 >= 0.6 && length(q - vec2(top.x, cy)) <= r1) || (r1 < 0.6 && r1 > 0.0 && all(equal(cell, floor(vec2(top.x, cy)))))) { col = g1; any = true; a = 1.0; }
		if ((r2 >= 0.6 && length(q - vec2(top.x - 0.5, cy - 0.5)) <= r2) || (r2 < 0.6 && r2 > 0.0 && all(equal(cell, floor(vec2(top.x - 0.5, cy - 0.5)))))) { col = g2; any = true; a = 1.0; }
		if (all(equal(cell, floor(vec2(top.x - 1.0, cy - 1.0))))) { col = g3; any = true; a = 1.0; }
	}
	if (!any) {
		discard;
	}
	vec4 c = vec4(col.rgb, a);
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
