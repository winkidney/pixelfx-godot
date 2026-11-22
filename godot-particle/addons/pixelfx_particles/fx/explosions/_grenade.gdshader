// The grenade (explosions/grenade): a pineapple grenade turned by `a` (about 11 x 15 px) at `g` (px from the origin):
// an oval body cut into knobbly segments by grooves, lit from the top left, an outline, a metal cap with a ring pin, a
// lever down its side, and the fuse's tip in `tip`. The original's drawGrenade, pixel for pixel. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec2 g = vec2(0.0);
uniform float a = 0.0;
uniform vec4 tip : source_color = vec4(1.0);
uniform vec4 b0 : source_color;
uniform vec4 b1 : source_color;
uniform vec4 b2 : source_color;
uniform vec4 b3 : source_color;
uniform vec4 b4 : source_color;
uniform vec4 m0 : source_color;
uniform vec4 m1 : source_color;
uniform vec4 m2 : source_color;
uniform vec4 m3 : source_color;
uniform vec4 outline : source_color;

vec4 body(int i) {
	return i <= 0 ? b0 : i == 1 ? b1 : i == 2 ? b2 : i == 3 ? b3 : b4;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float ca = cos(a);
	float sa = sin(a);
	vec2 ft = g + vec2(sa * 10.4, -ca * 10.4);
	vec4 c = vec4(0.0);
	float dx = p.x - g.x;
	float dy = p.y - g.y;
	float u = dx * ca + dy * sa;
	float v = -dx * sa + dy * ca;
	float e = (u / 5.1) * (u / 5.1) + ((v - 0.6) / 6.4) * ((v - 0.6) / 6.4);
	if (floor(p) == floor(ft)) {
		c = tip;
	} else if (abs(dx) > 13.5 || abs(dy) > 13.5) {
		discard;
	} else if (v < -5.0 && v > -10.2 && abs(u) < 2.4) {
		c = (v < -9.4 || abs(u) > 1.7) ? m0 : (u < -0.6 ? m3 : m2);
	} else if (length(vec2(u + 3.4, v + 8.0)) < 1.9 && length(vec2(u + 3.4, v + 8.0)) > 0.9) {
		c = m2;
	} else if (u > 2.2 && u < 3.6 && v > -8.6 && v < 2.0) {
		c = u > 3.0 ? m0 : m1;
	} else if (e > 1.2) {
		discard;
	} else if (e > 1.0) {
		c = outline;
	} else {
		float lit = -(dx * 0.6 + dy * 0.8) / 6.0;
		bool gv = abs(mod(v + 30.0, 3.1) - 1.55) < 0.45;
		bool gu = abs(mod(u + 30.0, 3.4) - 1.7) < 0.45;
		float k = 2.0 + lit * 1.7 - ((gv || gu) ? 1.0 : 0.0) + ((e < 0.3 && lit > 0.3) ? 1.0 : 0.0);
		c = body(clamp(int(floor(k + 0.5)), 0, 4));
	}
	c.a = 1.0;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
