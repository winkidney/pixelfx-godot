// The dome of force (hammer-smash.js), colour layer: the upper half of a shell of radius r round the rect's bottom
// middle, th px thick, in solid steps (a white rim, then c6, c5, c4 inside; all white and c6 at first), dissolving
// as a whole (alpha). `d` is how far through its life it is. Key r, th, d, alpha.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform float cx = 0.0;
uniform float r = 0.0;
uniform float th = 1.0;
uniform float d = 0.0;
uniform float alpha = 0.0;
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);

void fragment() {
	vec4 tint = COLOR;
	if (alpha <= 0.0) {
		discard;
	}
	vec2 p = vec2(floor((UV.x - 0.5) * size.x) + 0.5 - cx, floor(UV.y * size.y) + 0.5 - size.y);
	float e = r - length(p);
	if (e < 0.0 || e > th || p.y > -0.5) {
		discard;
	}
	float v = e / th;
	vec4 c = d < 0.1 ? (v < 0.6 ? vec4(1.0) : c6) : v < 0.34 ? (d < 0.45 ? vec4(1.0) : c6) : v < 0.67 ? c5 : c4;
	c.a = alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
