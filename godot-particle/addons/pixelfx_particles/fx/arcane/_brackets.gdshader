// The missiles' lock on the target (after arcane-missiles.js lock()): four bracket arcs of `radius`, each 0.76 rad
// long, turned by `spin`. Centred on the rect. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(48.0);
uniform float radius = 19.0;
uniform float spin = 0.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float alpha = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	float d = length(p);
	if (abs(d - radius) > 0.55) {
		discard;
	}
	float a = atan(p.y, p.x) - spin + 0.38;
	float m = mod(mod(a, TAU / 4.0) + TAU, TAU / 4.0);
	if (m > 0.76) {
		discard;
	}
	vec4 c = color;
	c.a *= alpha;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
