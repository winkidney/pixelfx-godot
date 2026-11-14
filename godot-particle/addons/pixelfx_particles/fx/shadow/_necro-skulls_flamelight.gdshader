// The necro-skulls' cold flame, light pass: every other pixel (a checkerboard) adds 0.16 * heat of its own colour.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/shadow/_necro-skulls_flame.gdshaderinc"

uniform vec4 pal[8] : source_color;
uniform vec4 white : source_color = vec4(1.0);
uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center + 0.001) + 0.5;
	float heat = nk_flame(p);
	vec2 cell = floor(p);
	if (heat < -0.5 || mod(cell.x + cell.y, 2.0) != 0.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec4 c = heat > 0.82 ? white : heat > 0.66 ? pal[7] : heat > 0.46 ? pal[6] : heat > 0.27 ? pal[5] : heat > 0.12 ? pal[4] : pal[3];
		COLOR = vec4(c.rgb * 0.16 * heat * strength, 1.0);
	}
}
