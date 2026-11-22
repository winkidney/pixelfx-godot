// Soul drain's funnel (after the original's drawBack()): eleven streamlines drawn once at build time into `data`
// (r, g: the 16-bit u along a line of a pixel where a dash may light; b: the line; a: bit 0 a faint line pixel, bit 1
// it's the brighter C3 (else C2), bit 2 a dash pixel). Dashes run down the lines off the clock `t` (seconds): a pixel
// at u lights where fract(u * 5 - ph * 10 + i * 0.3) < 0.18, ph = the line's phase over the loop. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(208.0, 120.0);
uniform sampler2D data : filter_nearest, repeat_disable;
uniform float t = 0.0;
uniform float period = 3.2;
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 c7 : source_color = vec4(1.0);

void fragment() {
	ivec2 q = ivec2(floor(UV * size));
	vec4 d = texelFetch(data, q, 0);
	int bits = int(round(d.a * 255.0));
	if (bits == 0) {
		discard;
	}
	vec4 c = vec4(0.0);
	if ((bits & 1) != 0) {
		c = (bits & 2) != 0 ? c3 : c2;
	}
	if ((bits & 4) != 0) {
		float u = (round(d.r * 255.0) * 256.0 + round(d.g * 255.0)) / 65535.0;
		float i = round(d.b * 255.0);
		float ph = mod(t + i * 0.37, period) / period;
		float dash = fract(u * 5.0 - ph * 10.0 + i * 0.3);
		if (dash < 0.18) {
			c = u > 0.7 ? c7 : u > 0.35 ? c6 : c5;
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
