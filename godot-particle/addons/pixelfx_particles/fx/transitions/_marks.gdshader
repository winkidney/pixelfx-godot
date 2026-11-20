// The transitions' frame-table particles (build/fx/transitions/_transitions.gd marks()): every slot is one of the
// original's small marks (a glint, a sparkle, a flare, a speck, a mote cross, a dash, a block outline, a line) worked
// out at build time from its formulas for each frame it draws, placed on its cell by fx/pickups/_ftp.gdshader from
// the keyed clock and drawn here cell by cell. `data`, 4 rows a frame:
//   row 0: cell x, cell y, alpha (dithered; 1 opaque), kind
//   row 1: colour index, second colour index, light colour index, present
//   row 2: where in its cell (x, y - the cell, worked out in doubles), p0, p1 (glint: L, angle; sparkle: arm; flare: L, k; rect / frame / square: w, h; line: dx, dy)
//   row 3: light x, y, radius, k (for _marks_light.gdshader)
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"

uniform sampler2D data : filter_nearest, repeat_disable;
uniform float quad = 9.0;
uniform vec4 pal[16] : source_color;

varying flat vec4 cu;

void vertex() {
	cu = INSTANCE_CUSTOM;
}

vec4 row(int r) {
	return texelFetch(data, ivec2(int(cu.x + 0.5), int(cu.y + 0.5) * 4 + r), 0);
}

void fragment() {
	vec2 d = floor((UV - 0.5) * quad + 0.5);
	vec2 q = cu.zw + d;
	vec4 r0 = row(0);
	vec4 r1 = row(1);
	vec4 r2 = row(2);
	int kd = int(r0.w + 0.5);
	float a = r0.z;
	float thr = pfx_threshold(FRAGCOORD.xy);
	int c1 = int(r1.x + 0.5);
	int c2 = int(r1.y + 0.5);
	int pick = -1;
	float al = a;
	vec2 ad = abs(d);
	if (kd == 0) {
		// a speck: one cell
		if (ad.x < 0.5 && ad.y < 0.5) {
			pick = c1;
		}
	} else if (kd == 1) {
		// a cross: c1 at the heart, c2 on the four arms
		if (ad.x < 0.5 && ad.y < 0.5) {
			pick = c1;
		} else if (ad.x + ad.y < 1.5) {
			pick = c2;
		}
	} else if (kd == 2) {
		// a filled w x h rect from the cell
		if (d.x >= 0.0 && d.y >= 0.0 && d.x < r2.z && d.y < r2.w) {
			pick = c1;
		}
	} else if (kd == 3) {
		// an outline w x h from the cell, in c1; filled with c2 unless c2 < 0 (r1.y >= 15.5)
		if (d.x >= 0.0 && d.y >= 0.0 && d.x < r2.z && d.y < r2.w) {
			bool rim = d.x < 0.5 || d.y < 0.5 || d.x > r2.z - 1.5 || d.y > r2.w - 1.5;
			if (rim && c1 < 15 && r2.z > 2.5) {
				pick = c1;
			} else if (c2 < 15) {
				pick = c2;
			}
		}
	} else if (kd == 4) {
		int g = tr_glint(d, r2.xy, r2.z, r2.w, a, thr);
		pick = g == 0 ? 8 : g == 1 ? c1 : g == 2 ? c2 : -1;
		al = 1.0;
	} else if (kd == 5) {
		int g = tr_sparkle(d, r2.xy, r2.z);
		pick = g == 0 ? 8 : g == 1 ? c1 : g == 2 ? c2 : -1;
	} else if (kd == 6) {
		int g = tr_flare(d, r2.xy, r2.z, r2.w, thr);
		pick = g == 0 ? 8 : g == 1 ? c1 : g == 2 ? c2 : -1;
		al = 1.0;
	} else if (kd == 7) {
		// a 1 px line from the cell to cell + (dx, dy): c1 then c2 from u > 0.5 when they differ
		float n;
		int i = tr_line_step(d, vec2(0.0), r2.zw, n);
		if (i >= 0) {
			pick = c1;
		}
	}
	if (pick < 0 || !tr_put(al, thr)) {
		discard;
	}
	vec4 c = vec4(tr_pal(pal, pick), 1.0);
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
