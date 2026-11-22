// A 1 px line of whole cells placed by _vstreak.gdshader (its cell count in CUSTOM.x): the original's p.line with a
// colour along it, `head` over the first `split` of its length (from the top), `tail` after; its alpha (the
// particle's colour alpha) dithered as the original's dot(). Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec4 head : source_color = vec4(1.0);
uniform vec4 tail : source_color = vec4(1.0);
uniform float split = 0.3;

varying flat vec4 cu;

void vertex() {
	cu = INSTANCE_CUSTOM;
}

void fragment() {
	float n = max(1.0, cu.x);
	float j = clamp(floor(UV.y * n), 0.0, n - 1.0);
	float u = j / max(1.0, n - 1.0);
	vec4 c = u < split ? head : tail;
	c.a = COLOR.a;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
