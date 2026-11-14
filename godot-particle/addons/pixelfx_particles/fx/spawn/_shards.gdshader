// The original's Bits (src/core/sim.js Bits.draw), tracked: a shard (a short line of dots, its far tip white), a
// shaded chunk (lit top-left, dark bottom-right, a dark rim, in `ramp`), a drip; each fading as its life runs out.
// Colour layer: dithered on and off as the original's dot().
//   head 1 (kind: 0 shard, 1 chunk, 2 drip, colour index, size, ..); rows 0 (x, y, on, alpha), 1 (angle, ..)
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_track.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_track_px.gdshaderinc"

uniform vec4 cols[16] : source_color;
uniform vec4 ramp[5] : source_color;
uniform vec4 white : source_color = vec4(1.0);

void vertex() {
	tk_cu = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 h1 = tk_head(1);
	vec4 r0 = tk_row(0);
	vec4 r1 = tk_row(1);
	int kind = int(h1.x + 0.5);
	vec3 col = cols[int(h1.y + 0.5)].rgb;
	float s = h1.z;
	float a = r0.w;
	float ca = cos(r1.x);
	float sa = sin(r1.x);
	vec2 cell = tk_cell(UV);
	vec2 fr = tk_fr();
	float th = pfx_threshold(FRAGCOORD.xy);
	if (!(a >= 1.0 || a > th)) {
		discard;
	}
	vec4 o = vec4(0.0);
	if (kind == 0) {
		// the last dot drawn on a cell is on top: step down from the far end
		int n = int(floor(s / 0.5 + 1e-4));
		for (int k = n; k >= 0; k--) {
			float d = -s / 2.0 + 0.5 * float(k);
			if (all(equal(cell, floor(fr + vec2(ca, sa) * d)))) {
				o = vec4(d > s / 2.0 - 0.6 ? white.rgb : col, 1.0);
				break;
			}
		}
	} else if (kind == 1) {
		// cells round the rounded position
		vec2 pc = cell - floor(fr + 0.5);
		float r = ceil(s) + 1.0;
		if (abs(pc.x) <= r && abs(pc.y) <= r) {
			float u = (pc.x + 0.5) * ca + (pc.y + 0.5) * sa;
			float v = -(pc.x + 0.5) * sa + (pc.y + 0.5) * ca;
			float d = abs(u) / s + abs(v) / (s * 0.62);
			if (d <= 1.3) {
				o = d > 1.0 ? ramp[0] : v < 0.0 ? (u < 0.0 ? ramp[4] : ramp[3]) : u < 0.0 ? ramp[2] : ramp[1];
			}
		}
	} else {
		if (all(equal(cell, vec2(0.0)))) {
			o = vec4(col, 1.0);
		} else if (all(equal(cell, floor(fr + vec2(0.0, -1.0)))) && a * 0.5 > th) {
			o = vec4(col, 1.0);
		}
	}
	if (o.a <= 0.0) {
		discard;
	}
	COLOR = vec4(o.rgb, 1.0);
}
