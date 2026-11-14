// A Lichtenberg fern of burn marks (zap-hit): `data` holds, per pixel of the fern, its distance along the branches
// from the hit (r * 64 px) and whether it's the thick side line of a main frond (g). The burn races out at `speed`
// px/s from `snap`, glows white and cools down the palette, then dithers away. Key `t` with the effect's time.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform sampler2D data : filter_nearest;
uniform float t = 0.0;
uniform float snap = 0.05;
uniform float speed = 260.0;
uniform vec4 c1 : source_color;
uniform vec4 c2 : source_color;
uniform vec4 c4 : source_color;
uniform vec4 c5 : source_color;
uniform vec4 c6 : source_color;
uniform vec4 c7 : source_color;

void fragment() {
	vec4 d = texelFetch(data, ivec2(floor(UV * size)), 0);
	if (d.a < 0.5) {
		discard;
	}
	float age = t - snap - d.r * 64.0 / speed;
	if (age < 0.0) {
		discard;
	}
	float k = exp(-age / 0.22) - smoothstep(0.45, 0.85, t) * 0.3;
	vec4 c;
	if (d.g > 0.5) {
		c = k > 0.45 ? c5 : c2;
	} else {
		c = k > 0.75 ? c7 : k > 0.45 ? c6 : k > 0.25 ? c5 : k > 0.1 ? c4 : k > -0.05 ? c2 : c1;
	}
	c.a = 1.0 - smoothstep(0.78, 0.88, t);
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
