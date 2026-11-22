// A mote of light or ash flying off a body (spawn/disintegrate's motes): a dot in its colour of the moment, with a
// short tail behind it when it's quick (the original's scale(c, 0.6) and scale(c, 0.4) dots). Colour layer: on/off
// alpha through the Bayer matrix; the colours are the original's mixes of the body's own, kept as they are.
//   rows: 0 (x, y, 1 + alpha, glow), 1 (vx, vy, colour index, kind: 0 tailed, 1 plain, 2 ash)
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_track.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_track_px.gdshaderinc"

uniform vec4 cols[128] : source_color;

void vertex() {
	tk_cu = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 r0 = tk_row(0);
	vec4 r1 = tk_row(1);
	vec2 p = tk_pos();
	float a = r0.z - 1.0;
	vec2 cell = tk_abs(UV);
	vec3 col = cols[int(r1.z + 0.5)].rgb;
	int kind = int(r1.w + 0.5);
	float th = pfx_threshold(FRAGCOORD.xy);
	vec4 c = vec4(0.0);
	if (all(equal(cell, floor(p))) && (a >= 1.0 || a > th)) {
		c = vec4(col, 1.0);
	} else if (kind == 0) {
		float sp = length(r1.xy);
		vec2 u = r1.xy / max(sp, 1e-6);
		if (sp > 85.0 && all(equal(cell, floor(p - u * 2.4))) && a * 0.6 > th) {
			c = vec4(tk_scale(col, 0.4), 1.0);
		} else if (sp > 30.0 && all(equal(cell, floor(p - u * 1.2))) && a * 0.85 > th) {
			c = vec4(tk_scale(col, 0.6), 1.0);
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	COLOR = c;
}
