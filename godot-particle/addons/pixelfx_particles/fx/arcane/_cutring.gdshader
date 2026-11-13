// A disc or ring (as shaders/ring.gdshader) whose pixels below `cut_y` (px from the effect's origin: the floor is 0)
// are left out: a burst's rings cut off where they meet the floor. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float radius = 10.0;
uniform float thickness = 0.0;
uniform float squash = 1.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float cut_y = 1e6;
uniform float alpha = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	if (p.y + center.y > cut_y) {
		discard;
	}
	float d = length(vec2(p.x, p.y / max(squash, 0.001)));
	float inner = thickness > 0.0 ? radius - thickness : -1e9;
	if (d > radius || d < inner) {
		discard;
	}
	vec4 c = color;
	c.a *= alpha;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
