// status/charmed's hearts, drawn as the original draws them (_lib.js icon() of shaped(heartShape, s)): every pixel
// cell (dx, dy) from the rect's middle whose centre falls inside the heart at scale `s` px, lit on its top and left
// edges (c3), shaded on its bottom and right (c1), filled with c2 and ringed by the outline c0, with a glint (`glint`
// at (-round(0.55 s), -round(0.45 s)), `glint2` right of it and under it). With `inner` > 0 it is instead the ring
// between the heart at `s` and the heart at `inner`, all in c2 (the ring thrown off on each beat). Key s, inner, c2,
// alpha. Colour layer (alpha dithers).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(40.0);
uniform vec2 center = vec2(0.0);
uniform float s = 5.6;
uniform float inner = 0.0;
uniform vec4 c0 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 c1 : source_color = vec4(0.5, 0.0, 0.2, 1.0);
uniform vec4 c2 : source_color = vec4(0.8, 0.2, 0.4, 1.0);
uniform vec4 c3 : source_color = vec4(1.0, 0.5, 0.7, 1.0);
uniform vec4 glint : source_color = vec4(1.0);
uniform vec4 glint2 : source_color = vec4(1.0);
uniform bool show_glint = true;
uniform float alpha = 1.0;

bool heart(vec2 q) {
	float u = q.x;
	float v = q.y;
	if ((u + 0.5) * (u + 0.5) + (v + 0.32) * (v + 0.32) <= 0.3025) {
		return true;
	}
	if ((u - 0.5) * (u - 0.5) + (v + 0.32) * (v + 0.32) <= 0.3025) {
		return true;
	}
	return v >= -0.32 && v <= 1.0 && abs(u) <= 1.04 * pow(max(0.0, 1.0 - (v + 0.32) / 1.32), 0.75);
}

bool ins(vec2 d, float sc) {
	return heart((d + 0.5) / sc);
}

void fragment() {
	vec4 tint = COLOR;
	vec2 d = floor(UV * size) - floor(size / 2.0);
	vec4 c;
	if (inner > 0.0) {
		if (!(ins(d, s) && !ins(d, inner))) {
			discard;
		}
		c = c2;
	} else {
		vec2 g = -floor(vec2(0.55, 0.45) * s + 0.5);
		if (show_glint && d == g) {
			c = glint;
		} else if (show_glint && (d == g + vec2(1.0, 0.0) || d == g + vec2(0.0, 1.0))) {
			c = glint2;
		} else if (ins(d, s)) {
			bool top = !ins(d + vec2(0.0, -1.0), s);
			bool left = !ins(d + vec2(-1.0, 0.0), s);
			bool bottom = !ins(d + vec2(0.0, 1.0), s);
			bool right = !ins(d + vec2(1.0, 0.0), s);
			c = (top || left) ? c3 : ((bottom || right) ? c1 : c2);
		} else if (ins(d + vec2(-1.0, 0.0), s) || ins(d + vec2(1.0, 0.0), s) || ins(d + vec2(0.0, -1.0), s) || ins(d + vec2(0.0, 1.0), s)) {
			c = c0;
		} else {
			discard;
		}
	}
	c.a *= alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
