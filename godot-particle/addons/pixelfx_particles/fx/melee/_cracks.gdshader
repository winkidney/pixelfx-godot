// Cracks splitting the floor (melee/_lib.js cracks(), heavy-cleave.js, hammer-smash.js), colour layer. `segs` holds a
// column per piece of crack: row 0 (x0, y0, x1, y1) px from the effect's origin, row 1 (distance along its crack,
// the crack's `at`, fork 0/1). `q` is the time since the blow (keyed): each crack races out to `reach` px over
// `ramp_t` s (forks 30%), starting at * at_k late. mode 0 (cleave): white hot, cooling down `ramp` to `dark` with
// `heat` and along the crack, a dark line beside it below the floor's edge. mode 1 (hammer): 2 px down, a white
// flash, then c_mid, then soot, with a shade line under it from 0.12 s. `fade` dithers it all out.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D segs : filter_nearest, repeat_disable;
uniform float count = 0.0;
uniform float q = -1.0;
uniform float reach = 40.0;
uniform float ramp_t = 0.13;
uniform float at_k = 0.1;
uniform float mode = 0.0;
uniform float heat = 1.0;
uniform float fade = 1.0;
uniform vec4 ramp[8];
uniform vec4 dark : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 shade : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 c_mid : source_color = vec4(1.0);

// how far along segment a -> b (cell to cell) the cell sits, or -1 when the line misses it
float on_seg(vec2 cell, vec2 a, vec2 b) {
	vec2 pa = floor(a) + 0.5;
	vec2 pb = floor(b) + 0.5;
	vec2 ab = pb - pa;
	float l2 = dot(ab, ab);
	vec2 pc = cell + 0.5;
	float u = l2 > 0.0 ? clamp(dot(pc - pa, ab) / l2, 0.0, 1.0) : 0.0;
	vec2 d = abs(pa + ab * u - pc);
	return max(d.x, d.y) < 0.5 ? u : -1.0;
}

void fragment() {
	vec4 tint = COLOR;
	if (q < 0.0 || fade <= 0.0) {
		discard;
	}
	vec2 cell = floor((UV - 0.5) * size) + center;
	vec4 col = vec4(0.0);
	int n = int(count);
	for (int i = 0; i < n; i++) {
		vec4 s = texelFetch(segs, ivec2(i, 0), 0);
		vec4 m = texelFetch(segs, ivec2(i, 1), 0);
		float e = clamp((q - m.y * at_k) / ramp_t, 0.0, 1.0);
		float rch = reach * (1.0 - pow(1.0 - e, 3.0)) * (m.z > 0.5 ? 0.3 : 1.0);
		float l = length(s.zw - s.xy);
		if (rch <= m.x) {
			continue;
		}
		float fpart = min(1.0, (rch - m.x) / max(l, 1e-3));
		vec2 b = s.xy + (s.zw - s.xy) * fpart;
		if (mode < 0.5) {
			if (b.y > 0.5 && on_seg(cell, s.xy + vec2(1.0, 0.0), b + vec2(1.0, 0.0)) >= 0.0) {
				col = dark;
			}
			if (on_seg(cell, s.xy, b) >= 0.0) {
				float h = heat * (1.0 - m.x / 46.0) - (m.z > 0.5 ? 0.12 : 0.0);
				col = h > 0.72 ? vec4(1.0) : h > 0.08 ? ramp[int(clamp(floor(h * 8.0 + 0.5), 1.0, 6.0))] : dark;
			}
		} else {
			if (q >= 0.12 && on_seg(cell, s.xy + vec2(0.0, 3.0), b + vec2(0.0, 3.0)) >= 0.0) {
				col = shade;
			}
			if (on_seg(cell, s.xy + vec2(0.0, 2.0), b + vec2(0.0, 2.0)) >= 0.0) {
				col = q < 0.05 ? vec4(1.0) : q < 0.12 ? c_mid : dark;
			}
		}
	}
	if (col.a <= 0.0) {
		discard;
	}
	col.a = fade;
	col *= tint;
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
