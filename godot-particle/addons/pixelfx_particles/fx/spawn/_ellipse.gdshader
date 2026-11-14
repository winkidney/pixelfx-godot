// An ellipse flat on the floor (the original's p.ellipse with colour and alpha by depth): `inner` out to d < t1, `mid`
// to d < t2, `outer` to the rim; alpha k * (1 - d^2), dithered. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec2 mid_at = vec2(0.0);
uniform float rx = 10.0;
uniform float ry = 3.0;
uniform float t1 = 0.4;
uniform float t2 = 0.7;
uniform float k = 1.0;
uniform vec4 inner : source_color = vec4(1.0);
uniform vec4 mid : source_color = vec4(1.0);
uniform vec4 outer : source_color = vec4(1.0);

void fragment() {
	vec2 p = floor(center + (UV - 0.5) * size) + 0.5 - mid_at;
	if (rx <= 0.0 || ry <= 0.0) {
		discard;
	}
	float d = length(vec2(p.x / rx, p.y / ry));
	if (d > 1.0) {
		discard;
	}
	vec4 c = d < t1 ? inner : d < t2 ? mid : outer;
	c.a = k * (1.0 - d * d);
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
