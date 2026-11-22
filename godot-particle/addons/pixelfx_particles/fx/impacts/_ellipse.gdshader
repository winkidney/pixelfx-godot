// A flat banded ellipse (the originals' p.ellipse with a colour by depth): rx, ry; `inner` out to d < t1, `mid` to
// d < t2, `outer` to the rim (d: 0 centre .. 1 rim).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec2 mid_at = vec2(0.0);
uniform float rx = 10.0;
uniform float ry = 3.0;
uniform float t1 = 0.5;
uniform float t2 = 0.8;
uniform vec4 inner : source_color = vec4(1.0);
uniform vec4 mid : source_color = vec4(1.0);
uniform vec4 outer : source_color = vec4(1.0);

void fragment() {
	vec4 tint = COLOR;
	vec2 p = floor(center + (UV - 0.5) * size) + 0.5 - mid_at;
	float d = length(vec2(p.x / rx, p.y / ry));
	if (d > 1.0) {
		discard;
	}
	vec4 c = d > t2 ? outer : d > t1 ? mid : inner;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
