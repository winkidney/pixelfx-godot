// The light down a water stream's white core (see _jet.gdshaderinc), additive.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_jet.gdshaderinc"

uniform float strength = 1.0;
uniform float amount = 0.12;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 - offset;
	if (jet_level(p) != 0) {
		discard;
	}
	COLOR = vec4(pal[5].rgb * amount * strength, 1.0);
}
