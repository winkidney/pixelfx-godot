// A word as the ui originals draw theirs (src/fx/ui/_lib.js drawWord), pixel for pixel: letters in the original's
// pixel font (`glyphs`: letter k's bitmap at x = 8k), each placed and scaled on its own (its layout in `lay`; it1:
// alpha, flash, slant, present), filled with a ramp down the letter, bevelled (lit top, shaded underside, lit left)
// on flat edges, outlined (ow 1 or 2) and shadowed, a diagonal shine and a white flash. The last letter on a pixel
// wins, as in the original. Items and the shine are keyed every frame; `box` bounds the pixels it can touch.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D glyphs : filter_nearest, repeat_disable;
uniform int n = 0;
uniform float gh = 7.0;
uniform float gw[16];
uniform vec4 it0[16];
uniform vec4 it1[16];
uniform sampler2D lay : filter_nearest, repeat_disable;
uniform float frame = 0.0;
uniform vec4 box = vec4(0.0, 0.0, -1.0, -1.0);
uniform vec4 fill[4] : source_color;
uniform int nfill = 1;
uniform vec4 edge : source_color = vec4(1.0);
uniform bool has_edge = false;
uniform vec4 under : source_color = vec4(1.0);
uniform bool has_under = false;
uniform vec4 outline : source_color = vec4(1.0);
uniform bool has_outline = false;
uniform int ow = 1;
uniform vec4 shadow : source_color = vec4(1.0);
uniform bool has_shadow = false;
uniform bool has_shine = false;
uniform float shine = 0.0;
uniform float shine_y = 0.0;
uniform vec4 glint : source_color = vec4(1.0);

bool ink(int k, int gx, int gy) {
	if (gx < 0 || gy < 0 || float(gx) >= gw[k] || float(gy) >= gh) {
		return false;
	}
	return texelFetch(glyphs, ivec2(k * 8 + gx, gy), 0).r > 0.5;
}

// the font row gy is open above / below column gx (no ink there or diagonally next to it)
bool open_row(int k, int gx, int gy) {
	if (gy < 0 || float(gy) >= gh) {
		return true;
	}
	return !ink(k, gx, gy) && !ink(k, gx - 1, gy) && !ink(k, gx + 1, gy);
}

// which letter (1-based, 0 none) inks cell P, with its bevel bits, its fill step and whether it is in the letter's
// lower half: read from the layout the build script worked out in doubles (lay, 8 bits: per frame and letter, a
// texel per pixel row: font row + 1 (0: none), italic shift + 128, edge bits, fill step; then a texel per pixel
// column: font column + 1, left-edge bit; it0: the letter's first pixel row, first column, rows, columns)
int at(vec2 P, out int e, out int fi, out bool low) {
	int id = 0;
	e = 0;
	fi = 0;
	low = false;
	if (P.x < box.x || P.y < box.y || P.x >= box.z || P.y >= box.w) {
		return 0;
	}
	int fr = int(frame + 0.5);
	for (int k = 0; k < 16; k++) {
		if (k >= n) {
			break;
		}
		if (it1[k].w < 0.5) {
			continue;
		}
		vec4 a = it0[k];
		int j = int(P.y - a.x);
		if (j < 0 || float(j) >= a.z) {
			continue;
		}
		int r0 = (fr * n + k) * 2;
		vec4 R = floor(texelFetch(lay, ivec2(j, r0), 0) * 255.0 + 0.5);
		if (R.x < 0.5) {
			continue;
		}
		int i = int(P.x - (R.y - 128.0) - a.y);
		if (i < 0 || float(i) >= a.w) {
			continue;
		}
		vec4 Q = floor(texelFetch(lay, ivec2(i, r0 + 1), 0) * 255.0 + 0.5);
		if (Q.x < 0.5) {
			continue;
		}
		Q.x -= 1.0;
		R.x -= 1.0;
		int gx = int(Q.x + 0.5);
		int gy = int(R.x + 0.5);
		if (!ink(k, gx, gy)) {
			continue;
		}
		id = k + 1;
		int fl = int(R.z + 0.5);
		e = 0;
		if ((fl & 1) != 0 && open_row(k, gx, gy - 1)) {
			e |= 1;
		}
		if ((fl & 2) != 0 && open_row(k, gx, gy + 1)) {
			e |= 2;
		}
		if (Q.y > 0.5 && !ink(k, gx - 1, gy)) {
			e |= 4;
		}
		fi = int(R.w + 0.5);
		low = (fl & 4) != 0;
	}
	return id;
}

int at0(vec2 P) {
	int e;
	int fi;
	bool low;
	return at(P, e, fi, low);
}

void fragment() {
	vec2 P = floor(center + (UV - 0.5) * size);
	if (P.x < box.x - 4.0 || P.y < box.y - 4.0 || P.x >= box.z + 4.0 || P.y >= box.w + 4.0) {
		discard;
	}
	int e;
	int i;
	bool low;
	int id = at(P, e, i, low);
	vec4 c = vec4(0.0);
	if (id > 0) {
		vec4 b = it1[id - 1];
		vec3 col = fill[i].rgb;
		if ((e & 1) != 0) {
			col = has_edge ? edge.rgb : fill[nfill - 1].rgb;
		} else if ((e & 2) != 0) {
			col = has_under ? under.rgb : fill[0].rgb;
		} else if ((e & 4) != 0 && i < nfill - 1) {
			col = fill[i + 1].rgb;
		}
		if (has_shine) {
			float dd = abs(P.x + 0.5 - (P.y + 0.5 - shine_y) * 0.6 - shine);
			if (dd < 1.1) {
				col = vec3(1.0);
			} else if (dd < 2.4) {
				col = glint.rgb;
			}
		}
		if (b.y > 0.6 || (b.y > 0.25 && low)) {
			col = vec3(1.0);
		}
		c = vec4(col, b.x);
	} else {
		int nb = 0;
		for (int dy = -2; dy <= 2; dy++) {
			for (int dx = -2; dx <= 2; dx++) {
				if (nb != 0 || abs(dx) > ow || abs(dy) > ow || (ow >= 2 && abs(dx) + abs(dy) >= 4)) {
					continue;
				}
				nb = at0(P + vec2(float(dx), float(dy)));
			}
		}
		if (nb > 0) {
			if (!has_outline) {
				discard;
			}
			c = vec4(outline.rgb, it1[nb - 1].x);
		} else if (has_shadow) {
			float o = float(ow);
			int s = at0(P + vec2(-o, -1.0 - o));
			if (s == 0) {
				s = at0(P + vec2(1.0 - o, -1.0 - o));
			}
			if (s == 0) {
				s = at0(P + vec2(-o, -o));
			}
			if (s > 0) {
				c = vec4(shadow.rgb, it1[s - 1].x * 0.9);
			}
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	// painter.js put(): below full alpha it draws only above its Bayer cell's threshold (at it: not)
	float a = c.a * alpha_scale;
	if (!(a >= 1.0 || a > pfx_threshold(FRAGCOORD.xy))) {
		discard;
	}
	COLOR = vec4(pfx_snap(c.rgb), 1.0);
}
