// nature/toxic-puddle: the tar pool's light pass (see _tar.gdshaderinc): the veins and glints light up, additively.
shader_type canvas_item;
render_mode blend_add;

#include "_tar.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec3 col;
	float a;
	vec3 lc;
	float lk;
	if (!tar_pool(floor(p.x), floor(p.y), col, a, lc, lk) || lk <= 0.0) {
		discard;
	}
	COLOR = vec4(lc * lk * strength, 1.0);
}
