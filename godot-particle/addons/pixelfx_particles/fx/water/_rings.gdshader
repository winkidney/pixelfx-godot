// Many ripple rings (the original's water ring()) at fixed places, each spreading and fading `rate` times a loop on
// its own phase: where a fountain's arcs come down, where rain lands. pts: the rings' middles (px from the rect's
// centre), phase: when each starts (0..1 of its cycle). r goes r0 -> r1 as it ages, k kmax * (1 - age)^kpow.
// Key `t` 0 -> 1 over the loop.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_ringfn.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform float t = 0.0;
uniform vec2 pts[16];
uniform float phase[16];
uniform float count = 0.0;
uniform float rate = 1.0;
uniform float r0 = 2.0;
uniform float r1 = 10.0;
uniform float kmax = 0.8;
uniform float kpow = 1.3;
uniform float sy = 0.34;
uniform float side = 0.0;
uniform float n = 1.0;
uniform float gap = 3.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	vec4 c = vec4(0.0);
	bool any = false;
	for (int i = 0; i < 16; i++) {
		if (float(i) >= count) {
			break;
		}
		float f = fract(t * rate + phase[i]);
		vec4 ci;
		float lit;
		int crest;
		if (ring_hit(p - pts[i], r0 + f * (r1 - r0), sy, kmax * pow(1.0 - f, kpow), n, gap, side, false, 0.0, float(i), 0.0, ci, lit, crest)) {
			c = ci;
			any = true;
		}
	}
	if (!any || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
