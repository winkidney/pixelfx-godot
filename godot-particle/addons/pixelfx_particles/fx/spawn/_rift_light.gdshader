// The light of spawn/spawn-portal's rift (_rift.gdshaderinc). Light layer.
shader_type canvas_item;
render_mode blend_add;

uniform float strength = 1.0;

#include "res://addons/pixelfx_particles/fx/spawn/_rift.gdshaderinc"

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	COLOR = vec4(rift_light(cell) * strength * COLOR.a, 1.0);
}
