// status/burning's scorch mark spreading over the clothes from one tick (over the stand-in, pixel for pixel: the rect
// is its mask, `mask`): body pixels within `radius` of `spot` (feet coords, squashed 1.2 in y, a grain of rand added)
// char to ch0 (the inner half) and ch1, the rim ember-edged c3 / c4 re-rolled 20 times a second (`f20`), all fading by
// `fade` (dithered). The rect's top-left is the mask's (`top_left`, feet coords). Keyed: radius, fade, f20. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/status/_burning.gdshaderinc"

uniform vec2 size = vec2(24.0, 38.0);
uniform vec2 center = vec2(0.0);
uniform vec2 top_left = vec2(-12.0, -38.0);
uniform sampler2D mask : filter_nearest;
uniform vec2 spot = vec2(0.0);
uniform float radius = 0.0;
uniform float fade = 0.0;
uniform float f20 = 0.0;
uniform vec4 c3 : source_color;
uniform vec4 c4 : source_color;
uniform vec4 ch0 : source_color;
uniform vec4 ch1 : source_color;

void fragment() {
	ivec2 m = ivec2(floor(UV * size));
	if (fade <= 0.0 || texelFetch(mask, m, 0).a < 0.5) {
		discard;
	}
	vec2 p = vec2(m) + top_left + 0.5;
	float d = length(vec2(p.x - spot.x, (p.y - spot.y) * 1.2)) + b_rand3(m.x, m.y, 7) * 0.9;
	if (d > radius) {
		discard;
	}
	vec4 c;
	if (d > radius - 1.0) {
		c = b_rand3(m.x, m.y, int(f20)) < 0.5 ? c3 : c4;
		c.a = fade * 1.2;
	} else {
		c = d < radius * 0.5 ? ch0 : ch1;
		c.a = fade * 1.1;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
