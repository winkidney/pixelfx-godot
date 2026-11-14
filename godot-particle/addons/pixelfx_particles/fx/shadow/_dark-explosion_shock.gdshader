// A shock ring in the air (the lib's ringFast() as the dark explosion uses it): a band `thickness` px inside `radius`,
// banded hot (white / c6 / c5) or cool (c5 / c4) from its outer edge in, stopped by the floor (y > 0.5 from the
// effect's origin). `center` is the ring's middle, px from the origin.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float radius = 10.0;
uniform float thickness = 2.0;
uniform float hot = 1.0;
uniform float alpha = 1.0;
uniform vec4 pal[9] : source_color;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	float d = length(p);
	float r0 = max(0.0, radius - thickness);
	if (d >= radius || d < r0 || radius <= 0.0) {
		discard;
	}
	// the original tests the floor at the ring's own radius along this pixel's angle
	if (center.y + p.y / max(d, 0.001) * radius > 0.5) {
		discard;
	}
	float v = (d - r0) / max(radius - r0, 0.001);
	vec4 c = hot > 0.5 ? (v > 0.6 ? pal[8] : v > 0.3 ? pal[6] : pal[5]) : (v > 0.5 ? pal[5] : pal[4]);
	c.a = alpha;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
