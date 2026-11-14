// The necro-skulls' cold flame, colour pass: white low in its heart, cooling outward and upward through the ghost
// greens (pal: the effect's palette). Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/shadow/_necro-skulls_flame.gdshaderinc"

uniform vec4 pal[8] : source_color;
uniform vec4 white : source_color = vec4(1.0);

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center + 0.001) + 0.5;
	float heat = nk_flame(p);
	if (heat < -0.5) {
		discard;
	}
	vec4 c = heat > 0.82 ? white : heat > 0.66 ? pal[7] : heat > 0.46 ? pal[6] : heat > 0.27 ? pal[5] : heat > 0.12 ? pal[4] : pal[3];
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
