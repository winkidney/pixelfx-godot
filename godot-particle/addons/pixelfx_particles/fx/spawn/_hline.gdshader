// A 1 px line across from -len to len on one row (the original's p.line with a colour along it): `mid` within `split`
// of its middle, `ends` beyond. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0, 3.0);
uniform vec2 center = vec2(0.0);
uniform float len = 0.0;
uniform float row = 0.0;
uniform float split = 0.3;
uniform vec4 mid : source_color = vec4(1.0);
uniform vec4 ends : source_color = vec4(1.0);

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	float a = floor(-len);
	float b = floor(len);
	if (len < 0.0 || cell.y != floor(row) || cell.x < a || cell.x > b) {
		discard;
	}
	float u = b > a ? (cell.x - a) / (b - a) : 0.0;
	vec4 c = abs(u - 0.5) < split ? mid : ends;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
