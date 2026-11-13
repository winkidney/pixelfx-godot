// A screen covered in ink except for a round hole (iris and spotlight transitions): the hole's `radius` and its lit
// rim are keyed by the effect. Coordinates are px from the effect's origin; the rect covers the whole canvas.
shader_type canvas_item;

#include "pixel.gdshaderinc"

uniform vec2 size = vec2(320.0, 180.0);
uniform vec2 center = vec2(0.0);
// the hole's middle, px from the origin
uniform vec2 focus = vec2(0.0);
uniform float radius = 200.0;
uniform vec4 ink : source_color = vec4(0.03, 0.02, 0.04, 1.0);
// a rim `rim` px wide just outside the hole, from inner colour to outer colour
uniform float rim = 5.0;
uniform vec4 rim_inner : source_color = vec4(1.0, 0.97, 0.91, 1.0);
uniform vec4 rim_outer : source_color = vec4(0.66, 0.53, 0.35, 1.0);
// 0..1: how much of the rim twinkles off (seeded by `grain`, re-rolled when `grain` changes)
uniform float twinkle = 0.0;
uniform float grain = 1.0;

float h(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + grain * 7.13) * 43758.5453);
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float d = length(p - focus);
	vec4 c;
	if (d < radius) {
		discard;
	} else if (d < radius + rim) {
		float u = (d - radius) / max(rim, 0.001);
		c = mix(rim_inner, rim_outer, step(0.5, u));
		if (twinkle > 0.0 && h(floor(p / 2.0)) < twinkle) {
			c = ink;
		}
	} else {
		c = ink;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
