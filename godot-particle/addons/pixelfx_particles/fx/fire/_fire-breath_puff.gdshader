// A ball of flame drawn inside a particle's quad (use a solid square texture such as dot4), after the original's
// firePuff: the particle's colour (its ramp) as the body, a darker rim (mixed toward `rim`), a lit spot up and to the
// left (mixed toward `heart`). Colour layer: dithered alpha, palette snap.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec4 rim : source_color = vec4(0.54, 0.12, 0.09, 1.0);
uniform float rim_mix = 0.55;
uniform float rim_width = 0.14;
uniform vec4 heart : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float heart_mix = 0.5;

void fragment() {
	vec2 q = UV - 0.5;
	float r = length(q);
	if (r > 0.5) {
		discard;
	}
	vec4 c = COLOR;
	if (length(q - vec2(-0.08, -0.11)) > 0.39 && r > 0.5 - rim_width) {
		c.rgb = mix(c.rgb, rim.rgb, rim_mix);
	} else if (length(q - vec2(-0.14, -0.17)) < 0.17) {
		c.rgb = mix(c.rgb, heart.rgb, heart_mix);
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
