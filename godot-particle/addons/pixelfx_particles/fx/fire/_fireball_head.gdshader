// The fireball's head (the original's head()): a ball whose outline churns and whose heat swirls in a spiral, white
// at the heart, swept back into an egg behind, with a crisp hot rim on its leading edge. Coordinates are px from the
// ball's centre (`center` from shape(), plus `offset` keyed for its bob); key `t` 0 -> 1 over the loop.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(24.0);
uniform vec2 offset = vec2(0.0);
uniform float t = 0.0;
uniform float radius = 5.0;
uniform float seed = 5.0;
uniform vec4 h0 : source_color = vec4(1.0);
uniform vec4 h1 : source_color = vec4(1.0);
uniform vec4 h2 : source_color = vec4(1.0);
uniform vec4 h3 : source_color = vec4(1.0);
uniform vec4 h4 : source_color = vec4(1.0);
uniform vec4 h5 : source_color = vec4(1.0);
uniform vec4 h6 : source_color = vec4(1.0);

float hsh(float i, float s) {
	return fract(sin(i * 127.1 + s * 311.7) * 43758.5453);
}

// smooth value noise in [-1, 1] repeating every `period` cells
float pnoise(float x, float period, float s) {
	float i = floor(x);
	float f = x - i;
	float u = f * f * (3.0 - 2.0 * f);
	float a = hsh(mod(i, period), s);
	float b = hsh(mod(i + 1.0, period), s);
	return (a + (b - a) * u) * 2.0 - 1.0;
}

void fragment() {
	vec2 p = floor(UV * size) + 0.5 - size * 0.5 - offset;
	float d = length(p);
	float th = atan(p.y, p.x);
	float back = max(0.0, -cos(th));
	float a = th / 6.28318530718;
	float bump = 0.55 * pnoise(a * 9.0 + t * 9.0, 9.0, seed) + 0.35 * pnoise(a * 5.0 - t * 10.0, 5.0, seed + 1.0);
	float rim = radius * (1.0 + 0.55 * back * back) + bump;
	if (d > rim) {
		discard;
	}
	float swirl = pnoise(a * 5.0 - t * 10.0 + d * 0.45, 5.0, seed + 2.0);
	float h = 1.0 - d / rim + 0.26 * swirl + 0.1 * (1.0 - back);
	vec4 c;
	if (rim - d < 1.0 && back < 0.3) {
		c = h > 0.3 ? h3 : h5;
	} else {
		c = h > 0.74 ? h0 : h > 0.58 ? h1 : h > 0.42 ? h2 : h > 0.27 ? h4 : h > 0.13 ? h5 : h6;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
