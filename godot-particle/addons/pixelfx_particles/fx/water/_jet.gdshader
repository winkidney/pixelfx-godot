// A pressurised water stream (see _jet.gdshaderinc), colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_jet.gdshaderinc"

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 - offset;
	int lvl = jet_level(p);
	if (lvl < 0) {
		discard;
	}
	vec4 c = lvl == 0 ? pal[7] : lvl == 1 ? pal[6] : lvl == 2 ? pal[5] : pal[4];
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
