// The light of spawn/egg-hatch's egg (_egg.gdshaderinc): its open cracks and its burning rim. Light layer.
shader_type canvas_item;
render_mode blend_add;

uniform float strength = 1.0;

#include "res://addons/pixelfx_particles/fx/spawn/_egg.gdshaderinc"

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	vec3 l;
	vec4 o = egg_px(cell, l);
	COLOR = vec4(l * strength * COLOR.a, 1.0);
}
