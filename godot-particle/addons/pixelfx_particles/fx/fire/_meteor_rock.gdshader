// The meteor's rock (fire/meteor): a lumpy dark stone, white-hot on its leading face (the side facing `dir`), cracks
// glowing over its dark back, an outline. `cool` 0..1 cools it to a smouldering lump. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(20.0);
uniform vec2 center = vec2(0.0);
uniform float radius = 6.5;
uniform vec2 dir = vec2(0.6, 0.8);
uniform float cool = 0.0;
uniform float alpha = 1.0;
uniform float seed = 99.0;
uniform vec4 h0 : source_color = vec4(1.0);
uniform vec4 h1 : source_color = vec4(1.0);
uniform vec4 h2 : source_color = vec4(1.0);
uniform vec4 h4 : source_color = vec4(1.0);
uniform vec4 h6 : source_color = vec4(1.0);
uniform vec4 rk0 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 rk1 : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 rk2 : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform vec4 outline : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float hh(float x, float s) {
	return fract(sin(x * 12.9898 + s * 78.233) * 43758.5453);
}

float vnoise(float x, float s) {
	float i = floor(x);
	float f = x - i;
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hh(i, s), hh(i + 1.0, s), u) * 2.0 - 1.0;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	float d = length(p);
	float a = atan(p.y, p.x);
	float rr = radius * (1.0 + 0.18 * vnoise(a * 2.2 + 3.0, seed) + 0.1 * vnoise(a * 5.0, seed + 1.0));
	if (d > rr + 1.0) {
		discard;
	}
	vec4 c;
	if (d > rr) {
		c = outline;
	} else {
		float face = dot(p, dir) / max(1.0, d);
		float heat = (1.0 - cool) * (face * 0.6 + 0.5 - (d / rr) * 0.25);
		if (heat > 0.62) {
			c = heat > 0.85 ? h0 : heat > 0.74 ? h1 : h2;
		} else if (heat > 0.42) {
			c = h4;
		} else {
			float h = fract(sin(dot(floor(p), vec2(12.9898, 78.233)) + seed * 3.1) * 43758.5453);
			if (h < 0.22 * (1.0 - cool * 0.7)) {
				c = (1.0 - cool) > 0.5 ? h4 : h6;
			} else {
				c = (p.x * -0.6 + p.y * -0.8 > 0.0) ? rk2 : (d / rr > 0.6 ? rk0 : rk1);
			}
		}
	}
	c.a = alpha;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
