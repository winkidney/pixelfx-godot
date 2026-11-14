// A standing crescent shock front on the floor (src/fx/impacts/_lib.js frontCrescent()): it leans back from a leading
// edge low at x = pos, dir 1 racing right, -1 left; h tall, w thick at its widest, a point at the top; edge / body /
// back colours bright to dark; alpha dithers it out. Key pos, h, w, alpha and the colours.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float pos = 0.0;
uniform float dir = 1.0;
uniform float h = 20.0;
uniform float w = 4.0;
uniform vec4 edge_c : source_color = vec4(1.0);
uniform vec4 body_c : source_color = vec4(1.0);
uniform vec4 back_c : source_color = vec4(1.0);
uniform float alpha = 1.0;

void fragment() {
	vec4 tint = COLOR;
	vec2 p = floor(center + (UV - 0.5) * size) + 0.5;
	if (h < 1.0 || w < 0.3 || p.y > 0.0 || p.y < -h - 1.0) {
		discard;
	}
	float ry = h * 0.8;
	float cy = -h * 0.2;
	float rx = max(2.0, h * 0.55);
	float ey = (p.y - cy) / ry;
	if (ey <= -1.0 || ey >= 1.0) {
		discard;
	}
	float e2 = 1.0 - ey * ey;
	float edge = rx * sqrt(e2) - rx;
	float wt = w * pow(e2, 0.45);
	float q = (edge - (p.x - pos) * dir) / max(0.5, wt);
	if (q < 0.0 || q > 1.0) {
		discard;
	}
	vec4 c = q < 0.28 ? edge_c : q < 0.62 ? body_c : back_c;
	c.a = alpha * (ey < -0.8 ? 0.7 : 1.0) * (q > 0.7 ? 1.25 - q * 0.8 : 1.0);
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
