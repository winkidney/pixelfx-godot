// The scanner's HUD over the stand-in (src/fx/scifi/scanner.js), from the keyed clock `t` (s): four L brackets
// snapping in round the body with a hot corner each, the box that flashes out on lock, the body's outline lit row by
// row as the scan line passes and cooling behind it (a white pulse when the scan is done), the scan line itself with
// a translucent slice of light over the rows just above it and a glint at each end of the body, the readout's leader
// and its ten-cell bar. The readout's words are text nodes; the light is _scanner_light.gdshader. Colour layer
// (the slices translucent).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_scifi.gdshaderinc"

uniform vec2 size = vec2(112.0, 78.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D tex : filter_nearest;
uniform float t = 0.0;
uniform float period = 3.2;
uniform vec4 pal[8] : source_color;

const float LOCK = 0.3;
const float SCAN0 = 0.42;
const float SCAN1 = 1.6;
const float DONE = 1.75;
const float LET = 2.5;

// the stand-in (2: 24 x 38, feet at the origin)
const int AX = -12;
const int AY = -38;
const int AW = 24;
const int AH = 38;

bool on(ivec2 p) {
	ivec2 q = p - ivec2(AX, AY);
	if (q.x < 0 || q.y < 0 || q.x >= AW || q.y >= AH) {
		return false;
	}
	return texelFetch(tex, q, 0).a > 0.5;
}

bool row_of(int y, out int r0, out int r1) {
	r0 = 1000;
	r1 = -1000;
	if (y < AY || y >= AY + AH) {
		return false;
	}
	for (int i = 0; i < 64; i++) {
		if (i >= AW) {
			break;
		}
		if (on(ivec2(AX + i, y))) {
			r0 = min(r0, AX + i);
			r1 = max(r1, AX + i);
		}
	}
	return r1 >= r0;
}

float scan_t(float y) {
	return SCAN0 + (SCAN1 - SCAN0) * acos(1.0 - 2.0 * clamp((y + 0.5 - float(AY - 3)) / float(4 - AY), 0.0, 1.0)) / PI;
}

float scan_y(float tt) {
	return mix(float(AY - 3), 1.0, e_in_out_sine((tt - SCAN0) / (SCAN1 - SCAN0)));
}

// a sparkle(arm 2) centred on cell s: arms C6 then C5 at their tips, a white heart
bool sparkle2(ivec2 P, ivec2 s, out vec4 c) {
	ivec2 d = P - s;
	int ax = abs(d.x);
	int ay = abs(d.y);
	if (d == ivec2(0)) {
		c = vec4(1.0);
		return true;
	}
	if ((d.x == 0 && ay <= 2) || (d.y == 0 && ax <= 2)) {
		c = max(ax, ay) > 1 ? pal[5] : pal[6];
		return true;
	}
	return false;
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size + 0.001);
	ivec2 P = ivec2(cell);
	vec4 W = vec4(1.0);
	vec4 c = vec4(0.0);
	float bx0 = float(AX - 4);
	float bx1 = float(AX + AW + 3);
	float by0 = float(AY - 4);
	float by1 = 3.0;
	float lock = e_out_back(t / LOCK, 2.2);
	float outk = e_in_cubic((t - LET) / 0.45);
	float spread = (1.0 - lock) * 14.0 + outk * 12.0;
	bool gone = t > LET + 0.45 || (t > LET + 0.25 && int(floor((t - LET) * 20.0)) % 2 == 1);
	bool flash = (t > LOCK && t < LOCK + 0.07) || (t > DONE && t < DONE + 0.05) || (t > DONE + 0.12 && t < DONE + 0.17);
	vec4 bc = flash ? W : pal[5];
	float thr = pfx_threshold(FRAGCOORD.xy);
	// the brackets: two arms from a corner, a short inner tick (dithered), a hot corner
	if (!gone) {
		for (int i = 0; i < 4; i++) {
			float x = (i % 2 == 0) ? bx0 - spread : bx1 + spread;
			float y = (i < 2) ? by0 - spread : by1 + spread;
			int sx = (i % 2 == 0) ? 1 : -1;
			int sy = (i < 2) ? 1 : -1;
			ivec2 X = ivec2(floor(vec2(x, y)));
			ivec2 d = (P - X) * ivec2(sx, sy);
			if (d.y == 0 && d.x >= 0 && d.x <= 7) {
				c = bc;
			}
			if (d.x == 0 && d.y >= 0 && d.y <= 7) {
				c = bc;
			}
			if (d.y == 1 && d.x >= 1 && d.x <= 3 && 0.6 >= thr) {
				c = bc;
			}
			if (d == ivec2(0)) {
				c = W;
			}
		}
	}
	// on lock: a box flashes out from the brackets
	float lk = (t - LOCK) / 0.3;
	if (lk >= 0.0 && lk < 1.0) {
		float e = 3.0 + 10.0 * e_out_cubic(lk);
		vec4 lc = lk < 0.25 ? W : lk < 0.5 ? pal[6] : lk < 0.75 ? pal[5] : pal[3];
		int x0 = int(floor(bx0 - e));
		int x1 = int(floor(bx1 + e));
		int y0 = int(floor(by0 - e));
		int y1 = int(floor(by1 + e));
		if (((P.y == y0 || P.y == y1) && P.x >= x0 && P.x <= x1) || ((P.x == x0 || P.x == x1) && P.y >= y0 && P.y <= y1)) {
			c = lc;
		}
	}
	// the outline, lit row by row as the line passes and cooling behind it
	float since_done = mod(t - DONE, period);
	float pulse = since_done < 0.3 ? 1.0 - since_done / 0.3 : 0.0;
	float off_y = mix(float(AY - 2), 2.0, clamp((t - LET) / 0.4, 0.0, 1.0));
	if (t > SCAN0 && !on(P) && (on(P + ivec2(1, 0)) || on(P - ivec2(1, 0)) || on(P + ivec2(0, 1)) || on(P - ivec2(0, 1)))) {
		float a = t - scan_t(float(P.y));
		if (a >= 0.0 && !(t > LET && float(P.y) < off_y)) {
			c = pulse > 0.4 ? W : a < 0.07 ? W : a < 0.25 ? pal[6] : a < 0.6 ? pal[5] : t > LET - 0.3 ? pal[3] : pal[4];
		}
	}
	// the scan line and the slice of light just above it
	if (t > SCAN0 && t < SCAN1) {
		int y = int(floor(scan_y(t)));
		int k = y - P.y;
		if (k >= 1 && k <= 5 && on(P)) {
			c = blend_over(c, k < 2 ? pal[6].rgb : pal[5].rgb, 0.55 - float(k) * 0.09);
		}
		int r0;
		int r1;
		bool has = row_of(y, r0, r1);
		if (P.x >= int(bx0) - 2 && P.x <= int(bx1) + 2) {
			if (P.y == y) {
				c = has && P.x >= r0 && P.x <= r1 ? W : pal[6];
			} else if (P.y == y - 1) {
				c = blend_over(c, pal[5].rgb, 0.35);
			}
		}
		if (has) {
			vec4 sc;
			if (sparkle2(P, ivec2(r0 - 1, y), sc) || sparkle2(P, ivec2(r1 + 1, y), sc)) {
				c = sc;
			}
		}
	}
	// the readout: a leader from the top-right bracket to a panel, then its bar of ten cells
	float lead = clamp((t - LOCK) / 0.1, 0.0, 1.0);
	if (!gone && lead > 0.0) {
		float px = bx1 + spread + 6.0;
		float py = by0 - spread + 2.0;
		vec2 a0 = vec2(bx1 + spread, by0 - spread);
		vec2 a1 = vec2(mix(bx1 + spread, px - 1.0, lead), mix(by0 - spread, py + 4.0, lead));
		if (on_seg(cell, a0, a1)) {
			c = pal[3];
		}
		if (lead >= 1.0) {
			if (on_seg(cell, vec2(px - 1.0, py + 4.0), vec2(px + 1.0, py + 4.0))) {
				c = pal[3];
			}
			float del = clamp((t - LET) / 0.25, 0.0, 1.0);
			float k = clamp((t - SCAN0) / (SCAN1 - SCAN0), 0.0, 1.0);
			bool ok = t > DONE;
			for (int i = 0; i < 10; i++) {
				if (float(i) >= 10.0 * (1.0 - del)) {
					break;
				}
				bool lit = float(i + 1) / 10.0 <= k + 1e-6 || ok;
				ivec2 r = ivec2(int(floor(px + 2.5 + float(i) * 3.0)), int(floor(py + 13.5)));
				if (P.x >= r.x && P.x < r.x + 2 && P.y >= r.y && P.y < r.y + 3) {
					c = lit ? (ok ? pal[6] : pal[5]) : pal[2];
				}
			}
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
