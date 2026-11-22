// The laser grid (src/fx/scifi/laser-grid.js), from the keyed clock `t`:
//   mode 0: haze hanging in the air, thickest low down, seen only near a beam and lit red by it (translucent)
//   mode 1: in the original's order: the scorch the sweepers leave on the floor, cooling; the two steel posts (a lit
//           edge, a groove glinting red where a beam meets it, bolts, the head with its lens, the foot plate, a
//           carriage riding the groove for each sliding beam); the beams (a red body either side of a white-hot core
//           with pale dashes running along it); a glint where two beams cross; the sweepers' hot spots
// Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_scifi.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_jsrand.gdshaderinc"

uniform vec2 size = vec2(128.0, 84.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform int mode = 0;
uniform int seed = 31;
uniform vec4 pal[8] : source_color;
uniform vec4 metal[6] : source_color;

#include "res://addons/pixelfx_particles/fx/scifi/_laser_grid.gdshaderinc"

vec4 haze(vec2 pc, ivec2 P) {
	if (P.y < -60 || P.y >= 0 || float(P.x) < -IN + 1.0 || float(P.x) >= IN) {
		return vec4(0.0);
	}
	float d = 99.0;
	for (int i = 0; i < 5; i++) {
		d = min(d, near_beam(beam(t, i), pc));
	}
	if (d > 11.0) {
		return vec4(0.0);
	}
	float ph = t / D;
	float low = 0.35 + 0.65 * clamp((pc.y - 0.5 + 60.0) / 50.0, 0.0, 1.0);
	float n = 0.5 + 0.5 * tile_fbm(pc.x / 18.0 + ph * 3.0, pc.y / 7.0 + 0.4 * sin(TAU * ph), 3, 0, seed + 7, 2);
	float dens = clamp((n - 0.42) * 2.2, 0.0, 1.0) * low;
	if (dens <= 0.02) {
		return vec4(0.0);
	}
	float lit = exp(-d / 4.5);
	return vec4(lit > 0.5 ? pal[4].rgb : lit > 0.15 ? pal[3].rgb : pal[1].rgb, dens * 0.8 * lit);
}

void post(inout vec4 c, ivec2 P, float s) {
	int x0 = int(s * PX) - 4;
	int i = P.x - x0;
	int top = int(TOP);
	if (P.y >= top + 4 && P.y < 0 && i >= 0 && i < 8) {
		float glint = 0.0;
		for (int b = 0; b < 3; b++) {
			glint = max(glint, exp(-pow((float(P.y) - slide_y(t, b)) / 2.5, 2.0)));
		}
		bool inner = s < 0.0 ? i >= 6 : i <= 1;
		vec4 col = i == 0 || i == 7 ? metal[0] : i == 1 ? metal[4] : i == 2 ? metal[3] : i == 4 ? metal[1] : i == 6 ? metal[2] : metal[3];
		if (inner && i != 0 && i != 7 && glint > 0.35) {
			col = glint > 0.75 ? pal[5] : pal[3];
		}
		c = col;
	}
	// bolts down the post
	if (i == 3 && P.y >= top + 12 && P.y < -4 && (P.y - top - 12) % 9 == 0) {
		c = metal[5];
	}
	// the head
	if (P.y >= top && P.y < top + 10 && i >= -1 && i < 9) {
		c = i == -1 || i == 8 || P.y == top || P.y == top + 9 ? metal[0] : P.y == top + 1 ? metal[5] : i < 3 ? metal[4] : metal[2];
	}
	int lx = int(s * IN);
	if (P.x == lx) {
		if (P.y == top + 6) {
			c = vec4(1.0);
		} else if (P.y == top + 5) {
			c = pal[5];
		} else if (P.y == top + 7) {
			c = pal[4];
		}
	}
	// the foot plate
	if (i >= -3 && i < 11) {
		bool end = i == -3 || i == 10;
		if (P.y == -2) {
			c = end ? metal[0] : metal[4];
		} else if (P.y == -1) {
			c = end ? metal[0] : metal[2];
		} else if (P.y == 0) {
			c = metal[1];
		}
	}
	// a carriage for each sliding beam, riding the groove
	for (int b = 0; b < 3; b++) {
		int y = int(floor(slide_y(t, b) + 0.5));
		int j = P.y - y;
		int ci = s < 0.0 ? P.x - (x0 + 5) : P.x - (x0 - 1);
		if (j >= -2 && j <= 2 && ci >= 0 && ci < 4) {
			c = abs(j) == 2 || ci == (s < 0.0 ? 3 : 0) ? metal[0] : j < 0 ? metal[5] : metal[3];
		}
		if (P.x == lx && P.y == y) {
			c = vec4(1.0);
		}
	}
}

// the original's line() from p0 to p1: whether cell is on it, and how far along (u)
bool line_u(vec2 cell, vec2 p0, vec2 p1, out float u) {
	vec2 a = floor(p0);
	vec2 b = floor(p1);
	if (!cell_on_line(cell, a, b)) {
		return false;
	}
	vec2 e = abs(b - a);
	float n = max(1.0, max(e.x, e.y));
	u = (e.x >= e.y ? abs(cell.x - a.x) : abs(cell.y - a.y)) / n;
	return true;
}

vec4 grid(vec2 pc, ivec2 P, float thr) {
	vec2 cell = vec2(P);
	vec4 c = vec4(0.0);
	// the scorch where the sweepers have just been
	if (P.y == 0 || P.y == 1) {
		for (int si = 0; si < 2; si++) {
			float s = si == 0 ? -1.0 : 1.0;
			for (int k = 0; k < 14; k++) {
				float x = floor(sweep_x(t - float(k) * 0.025, s));
				if (float(P.x) != x) {
					continue;
				}
				float fk = float(k);
				if (P.y == 0 && 1.0 - fk / 14.0 >= thr && 1.0 - fk / 14.0 > 0.0) {
					c = k < 2 ? vec4(1.0) : k < 5 ? pal[6] : k < 9 ? pal[4] : pal[3];
				}
				if (P.y == 1 && 0.6 - fk / 24.0 >= thr && 0.6 - fk / 24.0 > 0.0) {
					c = pal[3];
				}
			}
		}
	}
	post(c, P, -1.0);
	post(c, P, 1.0);
	// the beams: a red body either side, a white-hot core with dashes running along it
	for (int i = 0; i < 5; i++) {
		vec4 b = beam(t, i);
		bool steep = abs(b.w - b.y) > abs(b.z - b.x);
		vec2 o = steep ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
		float u;
		if (line_u(cell, b.xy - o, b.zw - o, u)) {
			c = pal[4];
		}
		if (line_u(cell, b.xy + o, b.zw + o, u)) {
			c = pal[3];
		}
		if (line_u(cell, b.xy, b.zw, u)) {
			c = mod(u * 5.0 - t * 3.0, 1.0) < 0.12 ? pal[6] : vec4(1.0);
		}
	}
	// where beams cross, a glint
	for (int i = 0; i < 5; i++) {
		for (int j = i + 1; j < 5; j++) {
			vec2 x;
			if (cross_at(beam(t, i), beam(t, j), x)) {
				ivec2 d = P - ivec2(floor(x));
				if (d == ivec2(0)) {
					c = vec4(1.0);
				} else if ((d.x == 0 && abs(d.y) <= 2) || (d.y == 0 && abs(d.x) <= 2)) {
					c = max(abs(d.x), abs(d.y)) > 1 ? pal[5] : pal[6];
				}
			}
		}
	}
	// the sweepers' hot spots on the floor
	for (int si = 0; si < 2; si++) {
		float x = floor(sweep_x(t, si == 0 ? -1.0 : 1.0));
		if (P.y == -1 && float(P.x) == x) {
			c = vec4(1.0);
		}
		if (P.y == 0 && (float(P.x) == floor(sweep_x(t, si == 0 ? -1.0 : 1.0) - 1.0) || float(P.x) == floor(sweep_x(t, si == 0 ? -1.0 : 1.0) + 1.0))) {
			c = pal[6];
		}
	}
	return c;
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size + 0.001);
	ivec2 P = ivec2(cell);
	vec2 pc = cell + 0.5;
	float thr = pfx_threshold(FRAGCOORD.xy);
	vec4 c = mode == 0 ? haze(pc, P) : grid(pc, P, thr);
	if (c.a <= 0.0) {
		discard;
	}
	if (px_out(c, FRAGCOORD.xy, mode == 0)) {
		discard;
	}
	COLOR = c;
}
