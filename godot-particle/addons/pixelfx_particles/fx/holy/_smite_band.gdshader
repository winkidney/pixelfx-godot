// (holy: a copy of lightning/_band.gdshader) A band round an ellipse (the originals' band() and ring()): `thickness` px inward from `radius`, y squashed by
// `squash` (0.18 lies on the floor), coloured by depth from its outer edge (c0 the rim, then c1, c2, c3 inward)
// and dithered out by `k` the way the original fades it (or evenly with `even`). side 1 keeps the far (upper) half,
// -1 the near half; pixels more than `clip` px below the centre are dropped (a ring in the air meeting the floor).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform float radius = 10.0;
uniform float thickness = 2.0;
uniform float squash = 1.0;
uniform vec4 c0 : source_color = vec4(1.0);
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);
uniform float k = 1.0;
uniform bool even = false;
uniform float side = 0.0;
uniform float clip = 1e9;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	if ((side > 0.5 && p.y > 0.0) || (side < -0.5 && p.y < 0.0) || p.y > clip || radius <= 0.0) {
		discard;
	}
	float d = length(vec2(p.x, p.y / max(squash, 0.001)));
	float o = radius - d;
	if (o < -0.25 || o > thickness + 0.25) {
		discard;
	}
	float u = clamp(o / max(thickness, 0.001), 0.0, 1.0);
	vec4 c = u < 0.15 ? c0 : u < 0.4 ? c1 : u < 0.7 ? c2 : c3;
	c.a = even ? k : k * (u < 0.4 ? 1.2 : 1.15 - u);
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
