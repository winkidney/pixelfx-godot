// nature/toxic-puddle: the tar pool, colour pass (see _tar.gdshaderinc). Key `t` 0 -> 1 over the loop.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "_tar.gdshaderinc"

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec3 col;
	float a;
	vec3 lc;
	float lk;
	if (!tar_pool(floor(p.x), floor(p.y), col, a, lc, lk)) {
		discard;
	}
	vec4 c = vec4(col, a);
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
