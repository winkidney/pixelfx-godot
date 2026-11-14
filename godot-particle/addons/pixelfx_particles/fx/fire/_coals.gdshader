// A heap of coals breathing in the heat (the brazier's and campfire's beds): lumps that pulse from red to yellow-white
// on their own phase with dark gaps between them, highest in the middle. Optionally a lit rim row and rivets under
// it (the brazier's bowl). Coordinates are px from the effect's origin; key `t` 0 -> 1 over the loop.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(32.0, 10.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
// the bed: half-width, the row its base sits on, how high the mound rises in the middle
uniform float half_w = 15.0;
uniform float base = -25.0;
uniform float mound = 4.0;
uniform float pulses = 2.0;
uniform float seed = 20.0;
uniform vec4 c0 : source_color = vec4(0.0);
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 gap : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// the brazier's bowl: a lit rim row at `base` and rivets two rows under it (alpha 0: none)
uniform vec4 rim : source_color = vec4(0.0);
uniform vec4 rim_edge : source_color = vec4(0.0);
uniform vec4 rivet : source_color = vec4(0.0);
uniform float rim_half = 14.0;

float h2(vec2 p, float s) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + s * 17.17) * 43758.5453);
}

void fragment() {
	vec2 p = floor(UV * size) + 0.5 + center - size * 0.5;
	vec4 c = vec4(0.0);
	if (rim.a > 0.0 && p.y >= base && p.y < base + 3.0) {
		float hw = rim_half;
		if (abs(p.x) > hw + 0.5) {
			discard;
		}
		if (abs(p.x) > hw - 0.5) {
			c = rim_edge;
		} else if (p.y < base + 1.0) {
			c = rim;
		} else if (p.y < base + 2.0) {
			discard;
		} else {
			c = mod(floor(p.x + 0.5), 4.0) == 0.0 ? rivet : vec4(0.0);
			if (c.a <= 0.0) {
				discard;
			}
		}
	} else {
		float top = base - 1.0 - mound * max(0.0, 1.0 - pow(p.x / (half_w - 1.0), 2.0));
		if (p.y < top || p.y > base + 0.5 || abs(p.x) > half_w - 0.5) {
			discard;
		}
		float lump = h2(vec2(floor((p.x + floor(p.y) * 1.5) / 3.0), floor(p.y / 2.0)), seed);
		bool edge = p.y < top + 1.0;
		if (h2(floor(p), seed + 1.0) < 0.16 || (edge && lump < 0.3)) {
			c = gap;
		} else {
			float g = (0.5 + 0.5 * sin(t * 3.14159265 * 2.0 * pulses + lump * 40.0)) * (edge ? 0.7 : 1.0);
			c = g > 0.72 ? c1 : g > 0.5 ? c2 : g > 0.3 ? c3 : g > 0.15 ? c4 : c0;
		}
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
