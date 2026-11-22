// The homing missile's blast ring (projectiles/homing-missile.js): a ring `width` px thick inside `radius`, centred on
// the rect's centre, cut off below the floor (`cut`: px below the centre). Colour layer; key radius, width, alpha.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(80.0);
uniform float radius = 8.0;
uniform float width = 2.5;
uniform float cut = 6.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float alpha = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	float d2 = dot(p, p);
	float r0 = max(0.0, radius - width);
	if (d2 > radius * radius || d2 < r0 * r0 || p.y > cut) {
		discard;
	}
	vec4 c = color;
	c.a *= alpha;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
