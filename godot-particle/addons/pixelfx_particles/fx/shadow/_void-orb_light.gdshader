// The void orb, light layer (see _void-orb.gdshaderinc): light on the vortex's filaments, and a glow on each lensed
// image of the specks behind.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/shadow/_jsrand.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/shadow/_void-orb.gdshaderinc"

uniform vec4 pal[9] : source_color;
uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center + 0.001) + 0.5;
	float g = vo_gulp();
	vec3 sum = vec3(0.0);
	int col;
	float a;
	float k;
	if (vo_vortex(p, g, col, a, k) == 1) {
		sum += pal[col].rgb * k;
	}
	for (int s = 0; s < 7; s++) {
		for (int w = 0; w < 2; w++) {
			float r;
			float a0;
			float hw;
			float mag;
			if (!vo_image(s, w, r, a0, hw, mag)) {
				continue;
			}
			vec2 c = vec2(cos(a0) * r, VO_Y + sin(a0) * r);
			float rad = 4.0 + min(10.0, hw * r);
			float d = length(p - c) / rad;
			if (d < 1.0) {
				sum += pal[6].rgb * (1.0 - d) * (1.0 - d) * min(0.5, 0.18 * mag);
			}
		}
	}
	COLOR = vec4(sum * strength, 1.0);
}
