// A puff of dust (explosions/dirt-explosion, the original's SMOKE particle): a see-through body and a denser core
// sitting a little low, drawn crisp on the pixel grid at any size from the particle's colour and alpha (the
// texture only sizes the quad). Soft layer: real translucency in 8 steps, snapped to the palette.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform float body = 0.45;
uniform float core = 0.62;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 q = UV - 0.5;
	if (length(q) > 0.5) {
		discard;
	}
	vec4 c = tint;
	float a = c.a * body;
	if (length(q - vec2(0.025, 0.03)) < 0.37) {
		a = 1.0 - (1.0 - a) * (1.0 - c.a * core);
	}
	c.a = a;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
