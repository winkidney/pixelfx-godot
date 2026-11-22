// _lib.js blobShadow(p, x, rx, k, y): dithered darkness on the floor line, fuller in the middle, with a shorter second
// row under it; key x, rx and k (k 0 or rx under 0.8: none). Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0, 4.0);
uniform vec2 center = vec2(0.0);
uniform float x = 0.0;
uniform float rx = 8.0;
uniform float k = 1.0;
uniform float y = 0.0;
uniform vec4 ink : source_color = vec4(0.043, 0.031, 0.078, 1.0);

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	vec2 cell = floor(pc);
	if (rx < 0.8 || k <= 0.0 || cell.x < floor(x - rx) || cell.x > ceil(x + rx)) {
		discard;
	}
	float u = abs(cell.x + 0.5 - x) / rx;
	if (u > 1.0) {
		discard;
	}
	float a = k * (1.0 - u * u);
	vec4 c;
	if (cell.y == y) {
		c = vec4(ink.rgb, a * 1.1);
	} else if (cell.y == y + 1.0 && u < 0.6) {
		c = vec4(ink.rgb, a * 0.6);
	} else {
		discard;
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
