// ice/ice-lance's spear seen from the side, pointing right with its tip at the rect's `center`: a hexagonal shaft
// `span` px long shaded row by row (a white top edge, a lit upper facet, a bright ridge, a cool lower facet, a deep
// keel, a dark rim), a long cutting point, a light pulse running through the ridge (`pulse`, x px) and a glint
// sliding along the top (`glint`). Colour layer; the ramp is the ice ramp, dark to bright.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float span = 40.0;
uniform float pulse = -100.0;
uniform float glint = -100.0;
uniform float alpha = 1.0;
uniform sampler2D ramp : filter_nearest, repeat_disable;

vec4 K(float i) {
	return texture(ramp, vec2((i + 0.5) / 8.0, 0.5));
}

void fragment() {
	vec4 tint = COLOR;   // the node's modulate: fade a group, tint a copy
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	float x = p.x;
	float y = p.y;
	float T = 16.0;
	float H = 3.5;
	float L = span;
	if (x > 0.0 || x < -L) {
		discard;
	}
	float h = x > -T ? H * (-x / T) + 0.3 : (x < -L + 3.0 ? H * (0.7 + 0.3 * ((x + L) / 3.0)) : H);
	vec4 c;
	if (abs(y) > h + 0.5) {
		if (abs(y) < h + 1.5) {
			c = K(1.0);
		} else {
			discard;
		}
	} else {
		float v = y / max(0.5, h);
		if (x > -1.5) {
			c = vec4(1.0);
		} else if (v > -0.3 && v < 0.35 && abs(x - pulse) < 2.5) {
			c = vec4(1.0);
		} else if (v < -0.3 && abs(x - glint) < 1.0) {
			c = vec4(1.0);
		} else {
			c = v < -0.72 ? vec4(1.0) : v < -0.36 ? K(6.0) : v < -0.18 ? K(7.0) : v < 0.38 ? K(4.0) : v < 0.78 ? K(2.0) : K(1.0);
		}
	}
	c.a = alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
