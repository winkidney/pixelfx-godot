// status/poisoned's ring pulsing out across the floor on each tick: the original's band() on a plane squashed by
// `squash`, `thickness` px deep inward from `radius`, brightest at its rim (c6, c5, c4, c3 inward), fading by `alpha`;
// `side` 1 keeps the far half (behind the character), -1 the near half. A pixel is lit when the band crosses its cell
// (so the squashed top and bottom stay a solid pixel line). Keyed: radius, thickness, alpha. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0, 16.0);
uniform vec2 center = vec2(0.0);
uniform float radius = 5.0;
uniform float thickness = 2.5;
uniform float squash = 0.18;
uniform float side = 0.0;
uniform float alpha = 1.0;
uniform vec4 c3 : source_color;
uniform vec4 c4 : source_color;
uniform vec4 c5 : source_color;
uniform vec4 c6 : source_color;

float dist(vec2 p) {
	return length(vec2(p.x, p.y / squash));
}

void fragment() {
	vec2 cellp = floor((UV - 0.5) * size);   // the cell's corner, from the centre
	if ((side > 0.5 && cellp.y + 0.5 >= 0.0) || (side < -0.5 && cellp.y + 0.5 < 0.0)) {
		discard;
	}
	float a = dist(cellp);
	float b = dist(cellp + vec2(1.0, 0.0));
	float d = dist(cellp + vec2(0.0, 1.0));
	float e = dist(cellp + vec2(1.0, 1.0));
	float lo = min(min(a, b), min(d, e));
	float hi = max(max(a, b), max(d, e));
	// a cell straddling the axis holds the ellipse's nearest point inside it
	if (cellp.x < 0.0 && cellp.x + 1.0 > 0.0) {
		lo = min(lo, abs(cellp.y + 0.5) / squash);
	}
	if (cellp.y < 0.0 && cellp.y + 1.0 > 0.0) {
		lo = min(lo, abs(cellp.x + 0.5));
	}
	if (lo > radius || hi < radius - thickness) {
		discard;
	}
	float u = clamp((radius - dist(cellp + 0.5)) / max(thickness, 0.001), 0.0, 1.0);
	vec4 c = u < 0.15 ? c6 : (u < 0.4 ? c5 : (u < 0.7 ? c4 : c3));
	c.a = alpha * (u < 0.4 ? 1.2 : 1.15 - u);
	c *= COLOR;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
