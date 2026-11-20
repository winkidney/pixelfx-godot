// exclamation's mark (src/fx/ui/exclamation.js bang()): a bar tapering to its foot and a round dot, a dark outline,
// lit down its left side, scaled by sx / sy and turned by ang about its foot (x, y); white all over on the pop.
// Keyed every frame from the original's spring. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform bool on = false;
uniform float x = 0.0;
uniform float y = 0.0;
uniform float sx = 1.0;
uniform float sy = 1.0;
uniform float ang = 0.0;
uniform bool white = false;

float hw(float V) {
	return 2.3 + (-V - 10.0) * 0.09;
}

bool in_bar(float U, float V) {
	return V > -24.0 && V < -9.5 && abs(U) < hw(V);
}

bool in_dot(float U, float V) {
	return length(vec2(U, V + 3.6)) < 3.3;
}

bool inside(float U, float V) {
	return in_bar(U, V) || in_dot(U, V);
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	if (!on || cell.x < floor(x - 16.0) || cell.x > ceil(x + 16.0) || cell.y < floor(y - 34.0) || cell.y > ceil(y + 6.0)) {
		discard;
	}
	vec2 pc = cell + 0.5;
	float ca = cos(ang);
	float sa = sin(ang);
	float dx = pc.x - x;
	float dy = pc.y - y;
	float u = (dx * ca + dy * sa) / sx;
	float v = (-dx * sa + dy * ca) / sy;
	float ex = 1.0 / sx;
	float ey = 1.0 / sy;
	vec3 c;
	if (!inside(u, v)) {
		if (inside(u - ex, v) || inside(u + ex, v) || inside(u, v - ey) || inside(u, v + ey)) {
			c = C[0].rgb;
		} else {
			discard;
		}
	} else if (white) {
		c = vec3(1.0);
	} else if (in_dot(u, v)) {
		c = length(vec2(u + 1.2, v + 4.8)) < 1.2 ? vec3(1.0) : u + v + 3.6 < -0.5 ? C[6].rgb : u + v + 3.6 < 1.5 ? C[5].rgb : C[4].rgb;
	} else {
		float w = hw(v);
		float q = (u + w) / (2.0 * w);
		if (q < 0.28) {
			c = v < -20.0 ? vec3(1.0) : C[7].rgb;
		} else if (q > 0.74) {
			c = C[4].rgb;
		} else {
			c = v < -18.0 ? C[6].rgb : C[5].rgb;
		}
	}
	vec4 o = vec4(c, 1.0);
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
