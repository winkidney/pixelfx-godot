// A 1 px ring of radius `radius` tilted in depth (`squash` in its own y) and rolled `rot` radians, centred on the
// rect; pixels below `cut_y` (px from the effect's origin: the floor is 0) are left out. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float radius = 10.0;
uniform float squash = 1.0;
uniform float rot = 0.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float cut_y = 1e6;
uniform float alpha = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	if (p.y + center.y > cut_y) {
		discard;
	}
	float c = cos(rot);
	float s = sin(rot);
	vec2 l = vec2(p.x * c + p.y * s, -p.x * s + p.y * c);
	float ry = max(0.3, radius * squash);
	vec2 n = vec2(l.x / radius, l.y / ry);
	float d = length(n);
	if (d < 1e-6) {
		discard;
	}
	float g = length(vec2(n.x / radius, n.y / ry)) / d;
	if (abs(d - 1.0) / g > 0.5) {
		discard;
	}
	vec4 col = color;
	col.a *= alpha;
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
