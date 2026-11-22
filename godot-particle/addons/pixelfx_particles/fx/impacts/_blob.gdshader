// blunt-hit's blob (src/fx/impacts/blunt-hit.js): a lumpy disc, radius r0 * (1 + 0.15 sin(5a + ph) + 0.08 sin(9a +
// 2.3 ph)), squashed by sy, banded from a white heart out to its rim: look 0 white / hi / mid, look 1 white / hi /
// mid / lo. Key r0, sy, ph, look on the original's frames.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform float r0 = 11.5;
uniform float sy = 1.1;
uniform float ph = 0.0;
uniform float look = 0.0;
uniform vec4 white : source_color = vec4(1.0);
uniform vec4 hi : source_color = vec4(1.0);
uniform vec4 mid : source_color = vec4(1.0);
uniform vec4 lo : source_color = vec4(1.0);

void fragment() {
	vec4 tint = COLOR;
	vec2 q = floor((UV - 0.5) * size) + 0.5;
	float dx = q.x;
	float dy = q.y * sy;
	float d = length(vec2(dx, dy));
	float a = atan(dy, dx);
	float ro = r0 * (1.0 + 0.15 * sin(5.0 * a + ph) + 0.08 * sin(9.0 * a + ph * 2.3));
	if (d > ro) {
		discard;
	}
	float f = d / ro;
	vec4 c = look < 0.5 ? (f < 0.55 ? white : f < 0.86 ? hi : mid) : (f < 0.3 ? white : f < 0.72 ? hi : f < 0.9 ? mid : lo);
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
