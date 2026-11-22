// A particle drawn as the original's p.disc() (dust, smoke, vapour: melee/_kinds.gdshader), on the soft layer: a
// translucent disc over the particle's quad (2 r across), blended in 8 steps and snapped to the palette.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

void fragment() {
	if (length(UV - 0.5) * 2.0 > 1.0) {
		discard;
	}
	vec4 c = COLOR;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
