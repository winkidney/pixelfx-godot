// chest-open's poof (src/fx/pickups/chest-open.js): the emptied chest, painted once as the original paints it (tex),
// dissolves from the lid down: each pixel goes at its own time (tdt, seconds), flashing gold (C6) for its last
// 0.04 s (the original meant C3 for the dark outline, but its test never matches). t: the effect's clock, keyed every frame. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(40.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D tex : filter_nearest, repeat_disable;
uniform sampler2D tdt : filter_nearest, repeat_disable;
uniform vec4 c6 : source_color;
uniform float t = 0.0;

void fragment() {
	ivec2 q = ivec2(floor(UV * size));
	vec4 c = texelFetch(tex, q, 0);
	float td = texelFetch(tdt, q, 0).r;
	if (c.a < 0.5 || t >= td) {
		discard;
	}
	if (td - t < 0.04) {
		c = c6;
	}
	c.a = 1.0;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
