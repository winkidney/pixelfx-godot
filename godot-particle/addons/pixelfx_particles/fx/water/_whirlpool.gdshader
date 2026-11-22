// A whirlpool seen from above (see _whirlpool.gdshaderinc). mode 0: the dark see-through water (put it on the soft,
// translucent layer); mode 1: the foam arms, the lip and the eye (colour layer).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_whirlpool.gdshaderinc"

uniform float mode = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	vec4 c = whirl(p, int(mode + 0.5));
	if (c.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
