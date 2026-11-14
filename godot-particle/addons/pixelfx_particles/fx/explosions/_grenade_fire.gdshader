// A fire puff for particles (explosions/grenade; the original's fireBall): on a square quad (dot4), a ball of flame
// in the particle's colour with a rim a step or two darker (the colour times `rim`, snapped to the palette), a lit
// core set up and left, and a tongue on top, so a mass of them reads as separate balls. The ball fills `ball` of the
// quad's half-width (room for the tongue). Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec4 rim : source_color = vec4(0.8, 0.5, 0.3, 1.0);
uniform float ball = 0.76;

void fragment() {
	vec2 q = (UV - 0.5) * 2.0 / ball;
	vec4 c = COLOR;
	if (length(q - vec2(-0.16, -0.22)) < 0.78 || length(q - vec2(0.0, -0.9)) < 0.42) {
		// the core and the tongue: the puff's own colour
	} else if (length(q) < 1.0) {
		c.rgb *= rim.rgb;
	} else {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
