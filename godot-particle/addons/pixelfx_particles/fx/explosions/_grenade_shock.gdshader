// The grenade's shock (explosions/grenade): a ring of `radius` and `thickness` round the rect's middle, cut off
// below `clip` px under its centre (the floor), dithered by `alpha`. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform float radius = 10.0;
uniform float thickness = 1.0;
uniform float clip = 9.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float alpha = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	float d = length(p);
	if (d > radius || d < max(0.0, radius - thickness) || p.y > clip) {
		discard;
	}
	vec4 c = vec4(color.rgb, alpha);
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
