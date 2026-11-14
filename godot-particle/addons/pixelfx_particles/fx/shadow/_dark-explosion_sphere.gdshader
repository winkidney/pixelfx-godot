// The dark explosion's black sphere (after the original's sphere()): a void body with a crescent of reflected light and
// a dull glint, a white rim, and pointed tongues of violet flame that lean up, flicker and crawl round it. mode 0: the
// rim and the flame (colour layer); mode 1: the black body, for a node above the light layer. Key `r`, `heat`, `tt`
// (seconds). Centred on the rect.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(80.0);
uniform float r = 16.0;
uniform float heat = 1.0;
uniform float tt = 0.0;
uniform float mode = 0.0;
uniform vec4 pal[9] : source_color;

float h1(float i, float s) {
	return fract(sin(i * 127.1 + s * 311.7) * 43758.5453);
}

float vnoise(float x, float s) {
	float i = floor(x);
	float f = x - i;
	float u = f * f * (3.0 - 2.0 * f);
	return mix(h1(i, s), h1(i + 1.0, s), u) * 2.0 - 1.0;
}

void fragment() {
	if (r < 0.6) {
		discard;
	}
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	float d = length(p);
	vec4 c;
	if (d < r - 0.5) {
		if (mode < 0.5) {
			discard;
		}
		float e = r - d;
		float ang = atan(p.y, p.x);
		c = pal[0];
		if (e < 1.4 && cos(ang - 0.8) > 0.55) {
			c = pal[2];
		} else if (r > 8.0 && pow(p.x + r * 0.45, 2.0) + pow(p.y + r * 0.45, 2.0) < 1.6) {
			c = pal[3];
		}
	} else {
		if (mode > 0.5) {
			discard;
		}
		float e = d - (r - 0.5);
		if (e < 1.0) {
			c = sin(atan(p.y, p.x) * 7.0 + tt * 9.0) > -0.6 ? pal[8] : pal[7];
		} else {
			float ang = atan(p.y + e * 0.6, p.x);
			float top = max(0.0, -sin(ang));
			float a1 = ang - tt * 0.9;
			float a2 = ang + tt * 1.7;
			float i1 = round(a1 * 9.0 / TAU);
			float i2 = round(a2 * 15.0 / TAU);
			float T1 = pow(0.5 + 0.5 * cos(a1 * 9.0), 3.0) * (0.55 + 0.45 * vnoise(tt * 7.0 + i1 * 3.7, 1.0));
			float T2 = pow(0.5 + 0.5 * cos(a2 * 15.0), 4.0) * (0.5 + 0.5 * vnoise(tt * 11.0 + i2 * 5.1, 2.0));
			float h = heat * (0.3 + 0.95 * top) * (1.5 + 12.0 * max(0.0, T1) + 6.0 * max(0.0, T2));
			if (e > h + 1.0) {
				discard;
			}
			float u = (e - 1.0) / h;
			c = u < 0.18 ? pal[8] : u < 0.4 ? pal[7] : u < 0.62 ? pal[6] : u < 0.84 ? pal[5] : pal[4];
			c.a = u < 0.8 ? 1.0 : (1.0 - u) * 5.0;
		}
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
