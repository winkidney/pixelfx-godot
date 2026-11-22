// ice/freeze's block: thirteen glassy panes (`facets`: which pane each pixel is in, r = index / 255, b = 1 inside),
// each setting at its time `at[i]`: a pale flash, then glass in its own tint and opacity (`tints`, `opacity`),
// brighter while fresh; two sweeps of light (`sweeps`) slide across it, every pane flashing whole as the light passes
// (`delay`, `lit`); `white` turns the whole block white. The rect's top-left is pixel (x0, y0) of the effect.
// Soft colour layer (translucent). _glass_light.gdshader is the sweeps' light.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(36.0, 53.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D facets : filter_nearest;
uniform float at[13];
uniform vec4 tints[13];
uniform float opacity[13];
uniform float delay[13];
uniform float lit[13];
uniform vec2 sweeps = vec2(1.12, 1.82);
uniform float t = 0.0;
uniform float white = 0.0;
uniform vec4 c6 : source_color = vec4(0.86, 0.98, 1.0, 1.0);
uniform vec4 c7 : source_color = vec4(1.0);
uniform float alpha = 1.0;

float sweep(int i) {
	float g = max(sin(PI * clamp((t - sweeps.x - delay[i] * 0.32) / 0.13, 0.0, 1.0)), sin(PI * clamp((t - sweeps.y - delay[i] * 0.32) / 0.13, 0.0, 1.0)));
	return g * (0.35 + 0.65 * lit[i]);
}

void fragment() {
	vec4 tint = COLOR;
	ivec2 P = ivec2(floor(UV * size));
	vec4 m = texelFetch(facets, P, 0);
	if (m.b < 0.5) {
		discard;
	}
	int i = int(floor(m.r * 255.0 + 0.5));
	float age = t - at[i];
	if (age < 0.0) {
		discard;
	}
	vec4 c;
	if (white > 0.5) {
		c = vec4(1.0);
	} else if (age < 0.03) {
		c = vec4(c7.rgb, 0.55);
	} else {
		float fresh = 1.0 - clamp((age - 0.03) / 0.1, 0.0, 1.0);
		float g = sweep(i);
		c = (fresh > 0.5 || g > 0.5) ? c6 : tints[i];
		c.a = opacity[i] + 0.25 * fresh + 0.15 * g;
	}
	c.a *= alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
