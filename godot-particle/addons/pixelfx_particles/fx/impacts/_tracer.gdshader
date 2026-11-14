// A tracer round (src/fx/impacts/ricochet.js tracer()): a white head, a hot body cooling to a dim tail, `len` px back
// from `head` (the effect's coordinates) along `angle`; the tail dithers out with k. Key head, len, k.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec2 head = vec2(0.0);
uniform float angle = 0.0;
uniform float len = 22.0;
uniform float k = 1.0;
uniform vec4 c0 : source_color = vec4(1.0);
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);

void fragment() {
	vec4 tint = COLOR;
	vec2 cell = floor(center + (UV - 0.5) * size);
	vec2 u = vec2(cos(angle), sin(angle));
	vec4 c = vec4(0.0);
	// the original's dots, every 0.5 px from the head back: the last one on a cell wins
	for (int i = 0; i <= 160; i++) {
		float d = float(i) * 0.5;
		if (d > len) {
			break;
		}
		vec2 p = head - u * d;
		if (all(equal(floor(p), cell))) {
			float f = d / max(len, 1e-3);
			c = vec4((f < 0.12 ? c0 : f < 0.45 ? c1 : f < 0.75 ? c2 : c3).rgb, f < 0.45 ? 1.0 : k * (1.25 - f));
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
