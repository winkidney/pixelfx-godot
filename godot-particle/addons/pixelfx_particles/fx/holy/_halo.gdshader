// The halo's ring (holy/halo, colour layer): 92 dots round a flat ellipse, the near side two px thick (bright over
// gold), the far side one thin dithered row, a shimmer running round it and a hot stretch where the glint is.
// `ph` is the loop's phase in radians (keyed); the rect is centred on the ring.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(24.0, 10.0);
uniform float ph = 0.0;
uniform float rx = 9.5;
uniform float ry = 2.6;
uniform vec4 pal[8] : source_color;

float apart(float a, float b) {
	return abs(mod(mod(a - b + PI, TAU) + TAU, TAU) - PI);
}

void fragment() {
	vec2 cell = floor((UV - 0.5) * size);
	float gl = PI / 2.0 + ph;
	vec4 c = vec4(0.0);
	for (int j = 0; j < 92; j++) {
		float g = float(j) / 92.0 * TAU;
		vec2 q = vec2(cos(g) * rx, sin(g) * ry);
		bool near = sin(g) >= 0.0;
		bool shimmer = sin(g * 3.0 - ph * 2.0) > 0.7;
		bool hot = apart(g, gl) < 0.3;
		if (near) {
			if (cell == floor(q)) {
				c = (hot || shimmer) ? vec4(1.0) : pal[6];
			}
			if (cell == floor(q + vec2(0.0, 1.0))) {
				c = hot ? pal[6] : pal[4];
			}
		} else if (cell == floor(q)) {
			c = vec4((hot ? vec4(1.0) : shimmer ? pal[6] : pal[5]).rgb, 0.9);
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
