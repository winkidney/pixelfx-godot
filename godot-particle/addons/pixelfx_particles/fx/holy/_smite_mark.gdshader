// The smite's mark (holy/smite, colour layer): a 1 px oval closing on the spot, white and gold dashes turning round
// it, a gold shadow under its near half, and a four-armed glint spinning over it. Key rr, spin, k, ka, arm.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/holy/_smite_lib.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float rr = 26.0;
uniform float sy = 0.38;
uniform float spin = 0.0;
uniform float k = 0.0;
uniform float ka = 0.0;
uniform float arm = 0.0;
uniform vec4 c3 : source_color;
uniform vec4 c5 : source_color;

void put(inout vec4 c, vec4 cc, float a, vec2 fc) {
	if (a > 0.0 && (a >= 1.0 || a > pfx_threshold(fc))) {
		c = vec4(cc.rgb, 1.0);
	}
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 cell = floor(p);
	vec4 c = vec4(0.0);
	if (k <= 0.0) {
		discard;
	}
	int n = int(ceil(rr * TAU * 1.5)) + 6;
	// the oval, then its shadow under the near half
	for (int j = 0; j < 400; j++) {
		if (j >= n) {
			break;
		}
		float g = float(j) / float(n) * TAU;
		if (floor(vec2(cos(g) * rr, sin(g) * rr * sy)) == cell) {
			put(c, sin(g * 4.0 + spin) > 0.0 ? vec4(1.0) : c5, ka, FRAGCOORD.xy);
		}
	}
	for (int j = 0; j < 400; j++) {
		if (j >= n) {
			break;
		}
		float g = float(j) / float(n) * TAU;
		if (sin(g) > 0.0 && floor(vec2(cos(g) * rr, 1.0 + sin(g) * rr * sy)) == cell) {
			put(c, c3, k * 0.6, FRAGCOORD.xy);
		}
	}
	// the glint's arms
	for (int i = 0; i < 4; i++) {
		float a = spin * 0.3 + float(i) * PI / 2.0;
		float len = i % 2 == 1 ? arm * 0.6 : arm;
		float u;
		if (smite_on_line(cell, vec2(0.0, -2.0), vec2(cos(a) * len, -2.0 + sin(a) * len), u)) {
			put(c, u < 0.4 ? vec4(1.0) : c5, 1.2 - u, FRAGCOORD.xy);
		}
	}
	if (cell == vec2(0.0, -2.0)) {
		c = vec4(1.0);
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
