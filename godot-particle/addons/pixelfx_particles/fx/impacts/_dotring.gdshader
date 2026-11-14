// A thin ring of dots (the originals' `for angles: p.dot(x + cos g * r, y + sin g * r)`), every cell the circle
// passes through, only where cos(angle - dir) > open (the side of it that's drawn: -1 for all of it). Key radius,
// color, alpha.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform float radius = 5.0;
uniform float squash = 1.0;
uniform float dir = 3.14159265;
uniform float open = -1.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float alpha = 1.0;

void fragment() {
	vec4 tint = COLOR;
	vec2 q = floor((UV - 0.5) * size) + 0.5;
	vec2 p = vec2(q.x, q.y / max(squash, 0.001));
	float rho = length(p);
	float g = atan(p.y, p.x);
	if (cos(g - dir) <= open) {
		discard;
	}
	vec2 n = rho > 0.0 ? p / rho : vec2(1.0, 0.0);
	float reach = 0.5 * (abs(n.x) + abs(n.y) * max(squash, 0.001) / max(squash, 0.001));
	if (abs(rho - radius) > reach * 0.85) {
		discard;
	}
	vec4 c = color;
	c.a *= alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
