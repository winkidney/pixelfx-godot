// The light the whirlpool's brightest foam gives off (see _whirlpool.gdshaderinc), additive.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_whirlpool.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	vec4 c = whirl(p, 2);
	if (c.a <= 0.0) {
		discard;
	}
	COLOR = vec4(c.rgb * strength, 1.0);
}
