// spawn/spawn-portal's rift (_rift.gdshaderinc): colour layer, its colours the effect's own.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_rift.gdshaderinc"

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	vec4 o = rift_px(cell, pfx_threshold(FRAGCOORD.xy));
	if (o.a <= 0.0) {
		discard;
	}
	o.a = 1.0;
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
