// A jet of light leaping out of the floor (the original's p.beam: a capsule from (x, bot) up to (x, top), `r` px
// round): white down its middle, c6 at its edges, c5 at its head (colour layer). Key top, bot and r.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(16.0, 80.0);
uniform vec2 center = vec2(0.0);
uniform float top = 0.0;
uniform float bot = 0.0;
uniform float r = 0.0;
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	if (r <= 0.0 || bot - top <= 2.0) {
		discard;
	}
	float L = bot - top;
	float u = clamp((bot - p.y) / L, 0.0, 1.0);
	vec2 q = vec2(0.0, bot - u * L) - p;
	float v = length(q) / r;
	if (v > 1.0) {
		discard;
	}
	vec4 c = v < 0.45 ? vec4(1.0) : u > 0.8 ? c5 : c6;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
