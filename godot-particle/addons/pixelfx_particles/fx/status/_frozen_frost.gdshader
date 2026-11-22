// status/frozen's frost on the floor round the feet (rows -1 .. 3 from the floor, x centred on the feet): a white
// crust with a pale bloom under it, a broken edge out to `reach` that creeps out and back, twinkling crystals.
// `noise`: r = the original's rand(x, 17) (how ragged the edge is there), g = rand(x, 3) (its twinkle's phase), for
// x = -24 .. 23 (texel x + 24). Keyed: reach, t (0..1 over the loop). Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(48.0, 5.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D noise : filter_nearest;
uniform float reach = 13.0;
uniform float t = 0.0;
uniform vec4 c4 : source_color;
uniform vec4 c5 : source_color;
uniform vec4 c6 : source_color;
uniform vec4 c7 : source_color;

void fragment() {
	ivec2 P = ivec2(floor(UV * size));
	int x = P.x - int(size.x) / 2;
	int y = P.y - 1;
	vec4 n = texelFetch(noise, ivec2(clamp(x + 24, 0, 47), 0), 0);
	float h = n.r;
	float q = abs(float(x) + 0.5) / reach;
	float k = 1.0 - q * q;
	if (q > 1.0 + h * 0.15) {
		discard;
	}
	vec4 c = vec4(0.0);
	if (y == 0) {
		bool tw = sin(t * TAU * 2.0 + n.g * TAU) > 0.94;
		c = (tw || h < 0.3) ? c7 : (q > 0.85 ? c5 : c6);
	} else if (y == -1) {
		if (h < 0.3 * k) {
			c = c6;
		}
	} else {
		float rows = 1.0 + floor(2.0 * k + 0.5);
		if (float(y) <= rows) {
			c = y == 1 ? c5 : c4;
			c.a = (1.05 - float(y) / 4.0) * 0.85;
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	c *= COLOR;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
