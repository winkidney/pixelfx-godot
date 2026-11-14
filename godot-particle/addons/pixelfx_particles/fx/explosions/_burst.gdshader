// A comic-book burst star (explosions/cartoon-pow): 2N spikes, long and short in turn, its edge at each angle running
// straight from spike tip to notch; an ink edge, a yellow body with halftone dots on its shaded side, an inked orange
// heart and a yellow core. Key `outer` (its size), `rot`, `shake` (px) and `boil` (a whole number: the spikes jitter
// each time it changes). Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(150.0);
uniform vec2 center = vec2(0.0);
uniform float outer = 50.0;
uniform float rot = -0.1;
uniform vec2 shake = vec2(0.0);
uniform float boil = 0.0;
uniform float squash = 0.82;
uniform float spikes[28];
uniform int count = 28;
uniform vec4 ink : source_color = vec4(0.1, 0.05, 0.08, 1.0);
uniform vec4 heart : source_color = vec4(0.95, 0.48, 0.14, 1.0);
uniform vec4 body : source_color = vec4(1.0, 0.76, 0.24, 1.0);
uniform vec4 light : source_color = vec4(1.0, 0.94, 0.48, 1.0);
uniform float alpha = 1.0;

float h(float i, float b) {
	return fract(sin(i * 12.9898 + b * 78.233 + 7.0) * 43758.5453);
}

float rad(int i) {
	int j = i % count;
	return spikes[j] * (1.0 + (h(float(j), boil) - 0.5) * 0.08);
}

void fragment() {
	if (outer < 0.5) {
		discard;
	}
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float dx = p.x - shake.x;
	float dy = (p.y - shake.y) / squash;
	float d = length(vec2(dx, dy));
	float M = float(count);
	float a = atan(dy, dx) - rot;
	float u = fract(a / 6.2831853) * M;
	int i = int(floor(u)) % count;
	float f = u - floor(u);
	float r = mix(rad(i), rad(i + 1), f);
	float e = d / r;
	vec4 c;
	if (e > outer + 2.5) {
		discard;
	} else if (e > outer) {
		c = ink;
	} else if (e > outer * 0.66 + 2.0) {
		vec2 q = floor(p);
		bool dot = dx * 0.6 + dy * 0.8 > outer * 0.25 && mod(q.x + q.y * 2.0, 4.0) < 0.5 && mod(q.y, 2.0) < 0.5;
		c = dot ? body : light;
	} else if (e > outer * 0.66) {
		c = ink;
	} else {
		c = e > outer * 0.44 ? heart : body;
	}
	c.a = alpha;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
