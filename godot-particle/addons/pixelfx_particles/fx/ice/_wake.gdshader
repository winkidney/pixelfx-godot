// ice/ice-lance's wake: a ribbon of frost narrowing behind the spear from x = `start` back `reach` px, its width
// rippling with the loop (`t` 0..1), pale down its heart near the spear, cooler to its edges, translucent. Coordinates
// are px from the rect's middle (put it at the effect's origin). Soft colour layer (translucent).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float start = -36.0;
uniform float reach = 104.0;
uniform float t = 0.0;
uniform vec4 heart : source_color = vec4(1.0);
uniform vec4 body : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(1.0);
uniform float alpha = 0.7;

void fragment() {
	vec4 tint = COLOR;   // the node's modulate: fade a group, tint a copy
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float u = (start - p.x) / reach;
	if (u < 0.0 || u > 1.0) {
		discard;
	}
	float w = 4.5 * pow(1.0 - u, 0.7) + 0.5 + 1.5 * sin(u * 9.0 - t * 6.2831853 * 2.0) * u;
	float v = abs(p.y) / w;
	if (v >= 1.0) {
		discard;
	}
	float a = (1.0 - v * v) * pow(1.0 - u, 1.4);
	if (a < 0.04) {
		discard;
	}
	vec4 c = (v < 0.25 && u < 0.4) ? heart : (v < 0.6 ? body : edge);
	c.a = a * alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
