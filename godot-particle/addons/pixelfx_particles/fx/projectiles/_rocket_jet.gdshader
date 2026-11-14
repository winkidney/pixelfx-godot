// The rocket's jet (projectiles/rocket.js jet()): a cone of flame out of the bell at `x0` in clean bands (a red
// rim, orange, a gold core), white-hot at the nozzle, with a chain of shock diamonds down its middle. Its length J,
// wobble, the diamonds' places and the rim's grain (fr) are keyed every frame, so it flickers. Coordinates are px
// from the parent's origin (build.gd shape() sets size and center).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(40.0, 16.0);
uniform vec2 center = vec2(0.0);
uniform float x0 = -14.0;
uniform float y0 = 0.5;
uniform float J = 22.0;
uniform float wob = 1.0;
uniform vec4 dia = vec4(3.6, 7.9, 12.2, 16.5);
uniform float fr = 0.0;
// F[2], F[3], F[4], F[5], F[7], F[8] of the fire palette
uniform vec4 f2 : source_color;
uniform vec4 f3 : source_color;
uniform vec4 f4 : source_color;
uniform vec4 f5 : source_color;
uniform vec4 f7 : source_color;
uniform vec4 f8 : source_color;

float h(vec2 c) {
	return fract(sin(dot(c, vec2(12.9898, 78.233)) + fr * 3.71) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * size) - size * 0.5 + center;
	vec2 p = cell + 0.5;
	float u = x0 - p.x;
	if (u < 0.0) {
		discard;
	}
	float q = u / J;
	if (q > 1.05) {
		discard;
	}
	float ady = abs(p.y - y0);
	float qq = min(q, 1.0);
	float w = (2.6 + 2.4 * pow(qq, 0.7)) * (1.0 - qq * qq) * wob;
	float m = w - ady + (h(cell) - 0.5) * 0.9 * min(1.0, 0.25 + q * 2.0);
	if (m < -0.5) {
		discard;
	}
	vec4 c;
	bool done = false;
	if (m < 0.5) {
		c = q < 0.45 ? f3 : f2;
		done = true;
	}
	if (!done) {
		for (int i = 0; i < 4; i++) {
			float di = dia[i];
			if (di > J * 0.72) {
				break;
			}
			float d = abs(u - di) / (1.9 - float(i) * 0.15) + ady / (1.7 - float(i) * 0.25);
			if (d < 1.0) {
				c = d < 0.55 && i < 3 ? f8 : f7;
				done = true;
				break;
			}
		}
	}
	if (!done) {
		if (u < 1.6 && ady < 1.6) {
			c = f8;
		} else {
			float lvl = (1.0 - ady / max(0.6, w)) * (1.0 - pow(qq, 1.5));
			c = lvl > 0.62 ? (u < 3.0 ? f7 : f5) : lvl > 0.38 ? f5 : lvl > 0.16 ? f4 : f3;
		}
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
