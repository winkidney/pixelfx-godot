// The original's band() (core/sim.js): a ring lying on the floor (y squashed to `sy`), `th` px thick inward from
// radius r, coloured by depth through it (c0 at the rim, then c1, c2, c3), dithered by k (rim 1.2 k, fading inward).
// side 1: only the far half (behind), -1: only the near half. The rect is centred on the ring's centre. Key r, th, k.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 frac_ = vec2(0.0);
uniform float r = 10.0;
uniform float th = 2.0;
uniform float k = 0.0;
uniform float sy = 0.16;
uniform float side = 0.0;
uniform vec4 c0 : source_color = vec4(1.0);
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);

void fragment() {
	vec4 tint = COLOR;
	if (k <= 0.0 || r <= 0.0) {
		discard;
	}
	vec2 p = floor((UV - 0.5) * size) + 0.5 - frac_;
	if ((side > 0.5 && p.y >= 0.0) || (side < -0.5 && p.y < 0.0)) {
		discard;
	}
	float d = length(vec2(p.x, p.y / sy));
	float o = r - d;
	// a dot lands in a cell when the ring passes within about half a pixel of its centre (2.5 px of plane radius down)
	float slack = 0.5 + 2.2 * abs(p.y / sy) / max(d, 1.0);
	if (o < -slack || o > th + slack) {
		discard;
	}
	float u = clamp(o / max(th, 0.01), 0.0, 1.0);
	vec4 c = u < 0.15 ? c0 : u < 0.4 ? c1 : u < 0.7 ? c2 : c3;
	c.a = k * (u < 0.4 ? 1.2 : 1.15 - u);
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
