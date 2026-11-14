// Floor cracks (src/fx/impacts/_lib.js makeCracks / drawCracks). `map` holds the original's jagged lines baked cell by
// cell at build time: r = distance along the crack, g = which crack, b = 1 the crack itself / 2 its lit lower lip.
// Each grows to grown(t) = len * outCubic((t - t0) / grow) and is lit from the hot ramp by heat * clamp(1.2 - d / 40)
// before it cools to `dark`. t is the effect's time (keyed), heat and fade keyed from the original's curves.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform sampler2D map : filter_nearest, repeat_disable;
uniform vec4 crack[16];   // (t0, len, 0, 0)
uniform float t = 0.0;
uniform float grow = 0.1;
uniform float heat = 0.0;
uniform float fade = 1.0;
uniform vec4 hot0 : source_color = vec4(1.0);
uniform vec4 hot1 : source_color = vec4(1.0);
uniform vec4 hot2 : source_color = vec4(1.0);
uniform vec4 hot3 : source_color = vec4(1.0);
uniform vec4 dark : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 lip : source_color = vec4(1.0);

void fragment() {
	vec4 tint = COLOR;
	vec4 m = texelFetch(map, ivec2(floor(UV * size)), 0);
	if (m.a < 0.5) {
		discard;
	}
	vec4 ck = crack[int(m.g + 0.5)];
	float g = ck.y * (1.0 - pow(1.0 - clamp((t - ck.x) / grow, 0.0, 1.0), 3.0));
	if (g <= 0.0 || m.r >= g) {
		discard;
	}
	vec4 c;
	if (m.b > 1.5) {
		c = vec4(lip.rgb, fade * 0.8);
	} else {
		float h = heat * clamp(1.2 - m.r / 40.0, 0.0, 1.0);
		c = h > 0.75 ? hot0 : h > 0.5 ? hot1 : h > 0.3 ? hot2 : h > 0.12 ? hot3 : dark;
		c.a = fade;
	}
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
