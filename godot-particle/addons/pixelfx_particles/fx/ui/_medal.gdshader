// achievement's medal (src/fx/ui/achievement.js medal()): two ribbon straps up to the toast's top edge, then a gold
// disc with a dark rim, a lit rim inside it, a raised five-point star (dark edge, lit and shaded faces), a shine
// running across it; white all over as it pops. x, y, s (its spring), white and the shine keyed every frame.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/ui/_line.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 G[8] : source_color;
uniform vec4 B[5] : source_color;
uniform float py_top = -16.0;
uniform bool on = false;
// its x as a whole pixel and the (tiny) rest in millionths of a pixel (the keys keep it: they thin values within
// 1e-5 of each other), so a centre a hair off a whole pixel tests as in the original's doubles
uniform vec2 xx = vec2(0.0);
uniform float y = 0.0;
uniform float s = 1.0;
uniform bool white = false;
uniform bool has_shine = false;
uniform float shine = 0.0;
// the shine's white cells row by row from shine_row0 (first, last), worked out in doubles
uniform float shine_row0 = 0.0;
uniform vec2 shine_rows[40];
// the straps' edge lines as whole cells (worked out in doubles at build time: an end a hair off a whole pixel picks
// the cell the original picks): left inner, left outer, right inner, right outer
uniform vec4 ln[4];
// the cells whose centres sit within 4.5 s of its centre (the straps' darker inner side), worked out the same way
uniform vec2 inner = vec2(0.0);
// the straps' fill row by row from row0 (their edges cross pixel centres on the dot): left first, last, right first,
// last cell (first > last: none)
uniform float row0 = 0.0;
uniform vec4 rows[16];

bool in_poly4(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d) {
	vec2 P[4] = vec2[](a, b, c, d);
	bool inside = false;
	for (int i = 0, j = 3; i < 4; j = i++) {
		vec2 pi = P[i];
		vec2 pj = P[j];
		if ((pi.y > p.y) != (pj.y > p.y) && p.x < ((pj.x - pi.x) * (p.y - pi.y)) / (pj.y - pi.y) + pi.x) {
			inside = !inside;
		}
	}
	return inside;
}

// p relative to the medal's centre
bool in_star(vec2 p) {
	bool inside = false;
	for (int i = 0; i < 10; i++) {
		int j = i == 0 ? 9 : i - 1;
		float ai = -PI / 2.0 + float(i) * PI / 5.0;
		float aj = -PI / 2.0 + float(j) * PI / 5.0;
		float ri = (i % 2 == 1) ? 2.8 * s : 6.5 * s;
		float rj = (j % 2 == 1) ? 2.8 * s : 6.5 * s;
		vec2 pi = vec2(cos(ai) * ri, 0.5 + sin(ai) * ri);
		vec2 pj = vec2(cos(aj) * rj, 0.5 + sin(aj) * rj);
		if ((pi.y > p.y) != (pj.y > p.y) && p.x < ((pj.x - pi.x) * (p.y - pi.y)) / (pj.y - pi.y) + pi.x) {
			inside = !inside;
		}
	}
	return inside;
}

bool strap_fill(vec2 cell, int k) {
	int j = int(cell.y - row0);
	if (j < 0 || j >= 16) {
		return false;
	}
	vec2 span = k == 0 ? rows[j].xy : rows[j].zw;
	return cell.x >= span.x && cell.x <= span.y;
}

bool in_shine(vec2 cell) {
	int j = int(cell.y - shine_row0);
	if (j < 0 || j >= 40) {
		return false;
	}
	return cell.x >= shine_rows[j].x && cell.x <= shine_rows[j].y;
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	vec2 pc = cell + 0.5;
	if (!on) {
		discard;
	}
	float r = 10.0 * s;
	float x = xx.x + xx.y * 1e-6;
	vec2 L = vec2((pc.x - xx.x) - xx.y * 1e-6, pc.y - y);
	vec3 c = vec3(0.0);
	bool hit = false;
	float dx = L.x;
	float dy = L.y;
	float d = length(vec2(dx, dy));
	if (cell.x >= floor(x - r - 1.0) && cell.x <= ceil(x + r + 1.0) && cell.y >= floor(y - r - 1.0) && cell.y <= ceil(y + r + 1.0) && d <= r) {
		hit = true;
		if (white) {
			c = r - d < 1.0 ? G[6].rgb : vec3(1.0);
		} else if (r - d < 1.0) {
			c = G[0].rgb;
		} else {
			float l = -(dx * 0.6 + dy * 0.8) / r;
			if (has_shine && in_shine(cell)) {
				c = vec3(1.0);
			} else if (r - d < 2.5) {
				c = l > 0.2 ? G[6].rgb : l > -0.3 ? G[4].rgb : G[3].rgb;
			} else if (in_star(L)) {
				bool rim = !in_star(L + vec2(1.0, 0.0)) || !in_star(L - vec2(1.0, 0.0)) || !in_star(L + vec2(0.0, 1.0)) || !in_star(L - vec2(0.0, 1.0));
				// the faces split on dx + dy = 0, which the medal often sits right on: the whole part first, then its tiny rest
				c = rim ? G[2].rgb : ((pc.x - xx.x) + (pc.y - y)) - xx.y * 1e-6 < 0.0 ? G[7].rgb : G[6].rgb;
			} else {
				c = l > 0.4 ? G[5].rgb : l > -0.2 ? G[4].rgb : G[3].rgb;
			}
		}
	}
	for (int k = 1; k >= 0 && !hit; k--) {
		float sd = k == 0 ? -1.0 : 1.0;
		vec2 a0 = vec2(sd * 2.0 * s, -r + 2.0);
		vec2 a1 = vec2(sd * 7.0 * s, -r + 2.0);
		vec2 b1 = vec2(sd * 9.0 * s, py_top + 1.0 - y);
		vec2 b0 = vec2(sd * 4.0 * s, py_top + 1.0 - y);
		if (on_line(cell, ln[k * 2 + 1].xy, ln[k * 2 + 1].zw) || on_line(cell, ln[k * 2].xy, ln[k * 2].zw)) {
			hit = true;
			c = B[0].rgb;
		} else if (strap_fill(cell, k)) {
			hit = true;
			c = cell.x >= inner.x && cell.x <= inner.y ? B[2].rgb : B[3].rgb;
		}
	}
	if (!hit) {
		discard;
	}
	vec4 o = vec4(c, 1.0);
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
