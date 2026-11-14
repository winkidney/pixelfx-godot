// ice/icicle-fall's icicle: a rippled taper `span` px long and `width` px wide at its root, hanging from the rect's
// middle top (the rect's centre is the root: draw it `span` + 2 px down), lit down its left side with a bright core
// streak, rings of light at the ripples, deep on the right, a white tip, a dark rim. `white` flashes it, `glint`
// (0..1 or -1) runs a highlight down its lit side. Colour layer; the ramp is the ice ramp, dark to bright.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(32.0, 80.0);
uniform vec2 center = vec2(0.0);
uniform float span = 36.0;
uniform float width = 12.0;
// the root's x within its pixel (the original's 0.5) and the trembling offset
uniform float x0 = 0.5;
uniform float white = 0.0;
uniform float glint = -1.0;
uniform float alpha = 1.0;
uniform sampler2D ramp : filter_nearest, repeat_disable;

vec4 K(float i) {
	return texture(ramp, vec2((i + 0.5) / 8.0, 0.5));
}

void fragment() {
	vec4 tint = COLOR;   // the node's modulate: fade a group, tint a copy
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	float u = p.y / span;
	if (u < 0.0 || u > 1.0) {
		discard;
	}
	float cx = x0 + 0.7 * sin(u * 6.0 + 1.0);
	float s = p.x - cx;
	float h = (width / 2.0) * pow(1.0 - u, 0.75) * (1.0 + 0.14 * sin(u * 13.0 + 0.5)) * (u < 0.08 ? 1.15 : 1.0) + 0.3;
	if (abs(s) > h + 1.0) {
		discard;
	}
	vec4 c;
	if (abs(s) > h) {
		c = K(1.0);
	} else if (white > 0.5) {
		c = vec4(1.0);
	} else {
		float q = s / h;
		bool ring = sin(u * 13.0 + 0.5) > 0.7;
		if (u > 0.88) {
			c = vec4(1.0);
		} else if (q < -0.72) {
			c = K(6.0);
		} else if (q < -0.2) {
			c = ring ? K(7.0) : K(5.0);
		} else if (q < 0.18) {
			c = u < 0.72 ? K(7.0) : K(6.0);
		} else if (q > 0.8) {
			c = K(2.0);
		} else if (abs(q - 0.45) < 0.1 && u > 0.15 && u < 0.6) {
			c = K(5.0);
		} else {
			c = q < 0.6 ? K(4.0) : K(3.0);
		}
		if (glint >= 0.0 && q < 0.25 && abs(u - glint) < 0.06) {
			c = vec4(1.0);
		}
	}
	c.a = alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
