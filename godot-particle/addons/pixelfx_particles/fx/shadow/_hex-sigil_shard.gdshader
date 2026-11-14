// The hex sigil's burning fragments (the original's Bits shards): the particle's colour along a short sliver, white
// where the texture marks its tip (red). Colour layer, for a GPUParticles2D.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec4 white : source_color = vec4(1.0);
varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec4 tx = texture(TEXTURE, UV);
	if (tx.a < 0.5) {
		discard;
	}
	vec4 c = tx.r > 0.5 ? vec4(white.rgb, vcol.a) : vcol;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
