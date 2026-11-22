// A ring on a tilted plane (src/core/sim.js band()): radius, th px thick inward, squashed by squash onto the floor,
// banded through its thickness: rim (white when hot), then c2, c1, c0 inward, the inner part dithering out. side 1
// draws the far half (rows above the centre), -1 the near half. Key radius / th / alpha / the colours.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
// the ring's centre, in the effect's coordinates
uniform vec2 mid = vec2(0.0, 0.5);
uniform float radius = 10.0;
uniform float th = 2.0;
uniform float squash = 0.16;
uniform float side = 0.0;
uniform vec4 c0 : source_color = vec4(1.0);
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);
uniform float alpha = 1.0;

void fragment() {
	vec4 tint = COLOR;
	vec2 cell = floor(center + (UV - 0.5) * size);
	if ((side > 0.5 && cell.y + 0.5 > mid.y) || (side < -0.5 && cell.y + 0.5 < mid.y)) {
		discard;
	}
	// the cell as a box on the unsquashed plane: does the band r - th .. r cross it, and how near its rim
	vec2 lo = vec2(cell.x - mid.x, (cell.y - mid.y) / squash);
	vec2 hi = vec2(cell.x + 1.0 - mid.x, (cell.y + 1.0 - mid.y) / squash);
	vec2 nearest = clamp(vec2(0.0), lo, hi);
	vec2 far = max(abs(lo), abs(hi));
	float rmin = length(nearest);
	float rmax = length(far);
	if (radius <= 0.0 || rmin > radius || rmax < radius - th) {
		discard;
	}
	// the original samples the thickness every 0.5 px from th down: the outermost sample in this cell colours it
	float o = radius - min(rmax, radius);
	float first = th - 0.5 * floor(th / 0.5);
	o = first + 0.5 * ceil(max(0.0, o - first) / 0.5 - 1e-4);
	if (o > th + 1e-3 || radius - o < rmin) {
		discard;
	}
	float u = o / max(th, 1e-3);
	vec4 c = u < 0.15 ? c3 : u < 0.4 ? c2 : u < 0.7 ? c1 : c0;
	c.a = alpha * (u < 0.4 ? 1.2 : 1.15 - u);
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
