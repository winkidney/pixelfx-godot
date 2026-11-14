// status/frozen's icicle, hanging from its root (the rect's top-left cell) down to the floor: `len` px long, white
// at the tip, pale at the root, a blue shadow down the right of its upper half; then its drop: `drop_mode` 1 swells
// a pixel at the tip (row `drop`), 2 falls as a pale pair (rows `drop` - 1 and `drop`). Keyed: len, drop, drop_mode.
// Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(2.0, 30.0);
uniform vec2 center = vec2(0.0);
uniform float len = 4.0;
uniform float drop = 0.0;
uniform int drop_mode = 0;
uniform vec4 c4 : source_color;
uniform vec4 c5 : source_color;
uniform vec4 c6 : source_color;
uniform vec4 c7 : source_color;

void fragment() {
	ivec2 P = ivec2(floor(UV * size));
	float j = float(P.y);
	vec4 c = vec4(0.0);
	if (j < len) {
		float v = j / len;
		if (P.x == 0) {
			c = v > 0.75 ? vec4(1.0) : (v < 0.3 ? c7 : c6);
		} else if (P.x == 1 && v < 0.5) {
			c = c4;
		}
	}
	if (P.x == 0 && drop_mode == 1 && P.y == int(floor(drop))) {
		c = c6;
	}
	if (P.x == 0 && drop_mode == 2) {
		if (P.y == int(floor(drop))) {
			c = c6;
		} else if (P.y == int(floor(drop - 1.0))) {
			c = c5;
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	c *= COLOR;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
