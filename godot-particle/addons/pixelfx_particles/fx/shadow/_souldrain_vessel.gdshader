// Soul drain's vessel (after the original's vessel()): a black crystal, its two left facets lit violet from inside, a
// hard ridge, a heart of stolen light that swells and whitens with `f` (the landings), its edge flaring at f > 0.5.
// `y0` is its centre (it bobs). Coordinates: px from the effect's origin. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(24.0, 32.0);
uniform vec2 center = vec2(0.0);
uniform float y0 = -50.0;
uniform float f = 0.0;
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 c7 : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center + 0.001) + 0.5;
	float W = 9.0;
	float UP = 14.0;
	float DN = 12.0;
	float x = p.x;
	float dy = p.y - y0;
	if (dy < -UP - 1.0 || dy > DN + 1.0) {
		discard;
	}
	float half_ = dy < 0.0 ? W * (1.0 + dy / UP) : W * (1.0 - dy / DN);
	if (half_ <= 0.0 || abs(x) > half_ + 0.6) {
		discard;
	}
	vec4 c;
	bool ridge = abs(x + dy * 0.12) < 0.6;
	bool heart = abs(x) + abs(dy - 1.0) < 2.6 + f * 1.5;
	if (abs(x) > half_ - 0.4) {
		c = f > 0.5 ? c6 : c1;
	} else if (heart) {
		c = f > 0.4 ? white : c6;
	} else if (ridge) {
		c = f > 0.3 ? c7 : c5;
	} else if (x < 0.0) {
		c = dy < 0.0 ? (f > 0.2 ? c5 : c4) : c3;
	} else {
		c = dy < 0.0 ? c2 : c1;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
