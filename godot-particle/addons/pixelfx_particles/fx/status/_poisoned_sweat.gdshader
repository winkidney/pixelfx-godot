// status/poisoned's toxic sweat at one spot (`spot`: mask x, y; `lag`: its delay), on a rect from a row above the spot
// down to the floor, x centred on the spot's column: a bead gathers and runs, lets go, falls with a short tail and
// hisses on the floor (a green fleck spreading, three sizzle sparks, a wisp of vapour curling up). It moves with the
// body's sway. Keyed: tw. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/status/_poisoned.gdshaderinc"

uniform vec2 size = vec2(24.0, 40.0);
uniform vec2 center = vec2(0.0);
uniform vec2 spot = vec2(0.0);
uniform float lag = 0.0;
// where the rect's top-left cell sits from the feet
uniform vec2 top_left = vec2(0.0);
uniform vec4 c4 : source_color;
uniform vec4 c5 : source_color;
uniform vec4 c6 : source_color;

const float G = 760.0;

bool cell(vec2 q, vec2 p) {
	return floor(q) == floor(p);
}

void fragment() {
	vec2 q = floor(UV * size) + top_left;   // this pixel's cell, from the feet
	float t = tw * PD;
	float age = mod(t - lag, PD / 2.0);
	float x = -12.0 + spot.x + 0.5 + p_off(spot.y);
	float y0 = -38.0 + spot.y;
	vec4 c = vec4(0.0);
	if (age < 0.35) {
		float k = age / 0.35;
		float run = floor(k * 2.0 + 0.5);
		if (cell(q, vec2(x, y0 + run))) {
			c = k > 0.5 ? c6 : c5;
		} else if (k > 0.5 && cell(q, vec2(x, y0 + run - 1.0))) {
			c = c4;
		}
	} else {
		float f = age - 0.35;
		float fall_h = -1.0 - (y0 + 2.0);
		float tf = sqrt(2.0 * max(1.0, fall_h) / G);
		if (f < tf) {
			float y = y0 + 2.0 + 0.5 * G * f * f;
			float tail = min(3.0, G * f * 0.012);
			if (cell(q, vec2(x, y))) {
				c = c6;
			} else if (q.x == floor(x) && q.y >= floor(y - tail) && q.y < floor(y)) {
				c = c4;
			}
		} else {
			float h = f - tf;
			if (h <= 0.4) {
				float k = h / 0.4;
				// the vapour first, then the fleck and the sparks over it
				vec2 v = vec2(x + sin(k * 6.0) * 1.5, -3.0 - k * 6.0);
				if (length(q + 0.5 - v) <= 1.0 + 1.5 * k) {
					c = vec4(c5.rgb, 0.35 * (1.0 - k));
				}
				if (q.y == -1.0 && q.x >= floor(x - 1.0 - k * 2.0) && q.x <= floor(x + 1.0 + k * 2.0)) {
					c = vec4((k < 0.4 ? c6 : c4).rgb, 1.2 - k);
				}
				for (int j = 0; j < 3; j++) {
					float fj = float(j);
					if (cell(q, vec2(x + (fj - 1.0) * (2.0 + 3.0 * k), -2.0 - mod(fj, 2.0) - 5.0 * k * (1.0 - k)))) {
						c = vec4(c6.rgb, 1.0 - k);
					}
				}
			}
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
