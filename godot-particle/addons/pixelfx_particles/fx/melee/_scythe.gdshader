// The scythe's crescent (scythe-reap.js blade()) along a swing, colour layer: the band from u = 0 to U, W px in from
// the rim, thickest behind the edge: a pale ghostly rim, a dark body deepening inward (ramp, darkest first, 8
// colours; a step darker at the rim once it hangs, `late`), dissolving at its tail; then torn away from the tail as
// `tear` runs 0 -> 1, a ragged front of per-pixel thresholds. Key U, tear, late.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/melee/_swing.gdshaderinc"

uniform float U = 0.0;
uniform float W = 21.0;
uniform float span = 3.5;
uniform float tear = 0.0;
uniform float late = 0.0;
uniform vec4 ramp[8];

float h2(vec2 x) {
	return fract(sin(dot(x, vec2(127.1, 311.7)) + 7.0 * 74.7) * 43758.5453);
}

void fragment() {
	vec4 tint = COLOR;
	if (U < 0.02 || tear >= 1.0) {
		discard;
	}
	vec2 p = sw_px(UV);
	vec2 ra = sw_plane(p);
	float r = ra.x;
	if (r > R + 1.0 || r < R - W - 1.0 || !sw_keep(ra.y, side)) {
		discard;
	}
	float u = sw_u(ra.y, 0.0, U);
	if (u < 0.0) {
		discard;
	}
	float v = u / U;
	float w = W * pow(max(0.0, sin(3.14159265 * pow(v, 1.7))), 0.55);
	if (w < 0.5) {
		discard;
	}
	float q = (R - r) / w;
	if (q < 0.0 || q > 1.0) {
		discard;
	}
	float nz = h2(vec2(floor(u * 40.0), floor(r)));
	if (tear > 0.0 && (u / span) < tear * 1.2 - nz * 0.2) {
		discard;
	}
	int ci = q < 0.08 ? 7 : q < 0.16 ? 6 : q < 0.25 ? 5 : q < 0.4 ? 4 : q < 0.62 ? 3 : 2;
	vec4 c = ramp[(late > 0.5 && q < 0.2) ? ci - 1 : ci];
	c.a = min(1.0, v / 0.25);
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
