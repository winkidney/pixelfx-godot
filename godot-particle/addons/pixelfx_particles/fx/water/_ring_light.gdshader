// The light a ripple's outer crest catches (the original's p.light along ring()), additive: put it over a
// _ring.gdshader node with the same keys.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_ring.gdshaderinc"

uniform float strength = 1.0;
uniform float amount = 0.3;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 - offset;
	vec4 c;
	float lit;
	int crest;
	if (!ring_px(p, c, lit, crest) || crest != 0) {
		discard;
	}
	COLOR = vec4(pal[4].rgb * amount * lit * strength, 1.0);
}
