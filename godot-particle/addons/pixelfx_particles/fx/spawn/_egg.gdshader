// spawn/egg-hatch's egg (_egg.gdshaderinc): colour layer, its colours (the shell's own shading and its warm mixes)
// kept as they are.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_egg.gdshaderinc"

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	vec3 l;
	vec4 o = egg_px(cell, l);
	if (o.a < 0.5) {
		discard;
	}
	COLOR = vec4(o.rgb, 1.0);
}
