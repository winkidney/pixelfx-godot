// _lib.js shadow(p, cx, cy, rx, ry, c, a): an ellipse blended over the floor, a at its centre fading as (1 - d)^0.7
// to nothing at its rim. Key x (and rx, k). Soft layer (translucent: the original blends it).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0, 8.0);
uniform vec2 center = vec2(0.0);
uniform float x = 0.0;
uniform float y = 0.0;
uniform float rx = 10.0;
uniform float ry = 1.5;
uniform float k = 0.5;
uniform vec4 ink : source_color = vec4(0.05, 0.04, 0.07, 1.0);

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	vec2 cell = floor(pc);
	if (rx <= 0.0 || ry <= 0.0 || k <= 0.0 || cell.x < floor(x - rx) || cell.x > ceil(x + rx) || cell.y < floor(y - ry) || cell.y > ceil(y + ry)) {
		discard;
	}
	float d = pow((pc.x - x) / rx, 2.0) + pow((pc.y - y) / ry, 2.0);
	if (d >= 1.0) {
		discard;
	}
	vec4 c = vec4(ink.rgb, k * pow(1.0 - d, 0.7));
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
