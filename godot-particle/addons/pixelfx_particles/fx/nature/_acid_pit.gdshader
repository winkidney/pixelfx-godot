// nature/acid-splash: the pit the acid eats into the floor and the acid boiling down into it (the original's
// drawBack): an etched bowl `pw` wide and `pit` deep with a ragged floor, its bottom and lip glowing while `heat` is
// up and cooling to a burnt lip; the acid in it a bright shimmering skin, darker as it deepens, its surface at
// `level` (negative: domed above the floor) sinking as it boils off. The build keys pw, pit, level, heat, fade,
// acid (1 while there's acid) and `t` (seconds, for the shimmer) every frame. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float pw = 0.0;
uniform float pit = 0.0;
uniform float level = 0.0;
uniform float heat = 0.0;
uniform float fade = 1.0;
uniform float acid = 1.0;
uniform float seed = 6.0;
uniform sampler2D ramp : filter_nearest, repeat_disable;
uniform vec4 scorch : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 burnt : source_color = vec4(0.1, 0.1, 0.1, 1.0);

vec3 C(float i) {
	return texture(ramp, vec2((clamp(i, 0.0, 7.0) + 0.5) / 8.0, 0.5)).rgb;
}

float hash(float x, float s) {
	return fract(sin(x * 127.1 + s * 311.7) * 43758.5453);
}

float noise1(float x, float s) {
	float i = floor(x);
	float f = x - i;
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash(i, s), hash(i + 1.0, s), u) * 2.0 - 1.0;
}

float depth(float x) {
	float d = abs(x) / max(1.0, pw);
	return d >= 1.0 ? -1.0 : pit * sqrt(1.0 - d * d) + (hash(floor(x + 0.5), seed) - 0.5) * 0.9;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float x = floor(p.x);
	float y = floor(p.y);
	if (pw <= 1.0) {
		discard;
	}
	vec4 c = vec4(0.0);
	float dp = depth(x + 0.5);
	if (dp >= 0.0) {
		float bottom = max(0.0, floor(dp + 0.5));
		bool edge = abs(x + 0.5) / pw > 0.88;
		if (y >= 0.0 && y <= bottom) {
			c = vec4(y == bottom ? (heat > 0.5 ? C(6.0) : heat > 0.15 ? C(4.0) : burnt.rgb) : scorch.rgb, fade);
		} else if (y == bottom + 1.0) {
			c = vec4(heat > 0.5 ? C(5.0) : heat > 0.15 ? C(3.0) : scorch.rgb, fade * 0.8);
		} else if (y == -1.0 && edge) {
			c = vec4(heat > 0.4 ? C(7.0) : heat > 0.1 ? C(5.0) : burnt.rgb, fade);
		}
		// the acid in it
		if (acid > 0.5) {
			float d = abs(x + 0.5) / pw;
			float dome = level < 0.0 ? floor(level * sqrt(max(0.0, 1.0 - d * d)) + 0.5) : floor(level + 0.5);
			float bot = floor(dp + 0.5);
			if (dome <= bot && y >= dome && y <= bot) {
				float n = noise1(x * 0.25 - t * 2.4, 3.0) + noise1(x * 0.1 + t * 1.4, 5.0) * 0.6;
				vec3 a = y == dome ? (n > 0.7 ? C(7.0) : C(6.0)) : y == dome + 1.0 ? (n > 0.2 ? C(5.0) : C(4.0)) : y >= bot ? C(3.0) : C(4.0);
				c = vec4(a, 1.0);
			}
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
