// The plasma ball of explosions/plasma-explosion: a white heart, cyan and blue bands swirling round it with bright
// filaments twisting through, a violet rim boiling at the edge; it swells and hollows out. Key `radius`, `u` (0..1
// over its life), `boil` (whole steps) and `clock` (the effect's time, for the filaments' twist). Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(96.0);
uniform float radius = 5.0;
uniform float u = 0.0;
uniform float boil = 0.0;
uniform float clock = 0.0;
uniform vec4 white : source_color = vec4(1.0);
uniform vec4 c3 : source_color;
uniform vec4 c4 : source_color;
uniform vec4 c5 : source_color;
uniform vec4 v2 : source_color;
uniform vec4 v3 : source_color;

float h(float i, float s) {
	return fract(sin(i * 127.1 + s * 311.7) * 43758.5453);
}

float noise1(float x, float s) {
	float i = floor(x);
	float f = x - i;
	float k = f * f * (3.0 - 2.0 * f);
	return mix(h(i, s), h(i + 1.0, s), k) * 2.0 - 1.0;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	float d = length(p);
	float a = atan(p.y, p.x);
	float edge = radius * (1.0 + 0.1 * noise1(a * 3.0 + boil * 0.7, 3.0));
	if (d > edge || radius < 0.5) {
		discard;
	}
	float v = d / edge;
	float hollow = smoothstep(0.35, 1.0, u);
	if (v < hollow * 0.92) {
		discard;
	}
	float n = noise1(a * 4.0 + d * 0.25 + boil * 0.5, 5.0);
	float w = v + n * 0.14;
	bool fil = abs(sin(a * 5.0 + d * 0.32 - clock * 14.0 + n * 2.5)) < 0.1;
	vec4 c;
	if (v > 0.9) {
		c = v2;
	} else if (fil && v > 0.3) {
		c = u < 0.5 ? white : c5;
	} else if (w < 0.32 - u * 0.25) {
		c = white;
	} else if (w < 0.52) {
		c = c5;
	} else if (w < 0.72) {
		c = c4;
	} else if (w < 0.86) {
		c = u < 0.5 ? c3 : v3;
	} else {
		c = v2;
	}
	c.a = 1.0;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
