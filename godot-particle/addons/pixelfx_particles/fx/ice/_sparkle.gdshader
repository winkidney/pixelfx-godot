// The original's sparkle(): a pixel cross with arms `arm` px long (rounded), the inner 60% in `color`, the rest in
// `tip`, diagonals once it's 3 px, longer diagonals at 6, a white heart. Centred on the rect's middle pixel (give
// it an odd size). Key `arm` (0 hides it) and the rect's position. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(25.0);
uniform vec2 center = vec2(0.0);
uniform float arm = 0.0;
uniform vec4 color : source_color = vec4(0.86, 0.98, 1.0, 1.0);
uniform vec4 tip : source_color = vec4(0.38, 0.78, 0.96, 1.0);
uniform vec4 heart : source_color = vec4(1.0);
uniform float alpha = 1.0;

void fragment() {
	vec4 tint = COLOR;   // the node's modulate: fade a group, tint a copy
	float n = floor(arm + 0.5);
	if (n < 1.0) {
		discard;
	}
	vec2 q = floor(UV * size) - floor(size / 2.0);
	vec2 a = abs(q);
	vec4 c;
	if (a.x < 0.5 && a.y < 0.5) {
		c = heart;
	} else if (a.x < 0.5 || a.y < 0.5) {
		float d = max(a.x, a.y);
		if (d > n) {
			discard;
		}
		c = d > n * 0.6 ? tip : color;
	} else if (a.x == a.y && a.x < 1.5 && n >= 3.0) {
		c = color;
	} else if (a.x == a.y && a.x > 1.5 && a.x < 2.5 && n >= 6.0) {
		c = tip;
	} else {
		discard;
	}
	c.a *= alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
