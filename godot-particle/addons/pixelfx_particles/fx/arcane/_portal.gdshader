// The portal's rift, colour pass (see _portal.gdshaderinc): the rim's lines and the inside in the original's dithered
// ramp steps (tone with sharp 0.65). Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/arcane/_portal.gdshaderinc"

uniform vec4 c0 : source_color = vec4(1.0);
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 c7 : source_color = vec4(1.0);

vec4 pal(int i) {
	return i <= 0 ? c0 : i == 1 ? c1 : i == 2 ? c2 : i == 3 ? c3 : i == 4 ? c4 : i == 5 ? c5 : i == 6 ? c6 : c7;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center + 0.001) + 0.5;
	int col;
	float level;
	float lk;
	int kind = p_rift(p, col, level, lk);
	if (kind == 0) {
		discard;
	}
	vec4 c;
	if (kind == 1) {
		c = pal(col);
		if (col == 3) {
			c.a = 0.5;
		}
	} else {
		// the original's tone(): a ramp step, dithering only near the step's edge
		float b = pfx_threshold(FRAGCOORD.xy);
		float f = clamp(level, 0.0, 1.0) * 7.0;
		float i = floor(f);
		float q = clamp((f - i - 0.5) / (1.0 - 0.65) + 0.5, 0.0, 1.0);
		if (q > b) {
			i = min(7.0, i + 1.0);
		}
		c = pal(int(i));
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
