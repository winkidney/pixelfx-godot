// A spark streak (projectiles/_lib.js spark()) for particles moved by _energy-disc_wake.gdshader: the front 45% in
// the head's colour (s0 while young, s1, then s2 as it cools), the back in the head's colour while it's young and s3
// once it's past half its life. COLOR.r is the life left (1 -> 0); UV.y runs tail (0) to head (1). Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec4 s0 : source_color = vec4(1.0);
uniform vec4 s1 : source_color = vec4(1.0);
uniform vec4 s2 : source_color = vec4(1.0);
uniform vec4 s3 : source_color = vec4(1.0);
// the head's colour steps (life left above th0: s0, above th1: s1), where the head colour starts (UV.y), when the
// back turns s3, and a fade over the far 35% of a speed line (drawn ahead of its point)
uniform float th0 = 0.6;
uniform float th1 = 0.3;
uniform float head_from = 0.55;
uniform float tail_k = 0.5;
uniform float fade_tail = 0.0;

varying vec4 state;

void vertex() {
	state = COLOR;
}

void fragment() {
	float k = state.r;
	vec4 head = k > th0 ? s0 : k > th1 ? s1 : s2;
	vec4 c = UV.y > head_from ? head : (k > tail_k ? head : s3);
	// speed lines run ahead of their point: the front end (UV.y 1) is their far end, and it fades
	float u = UV.y;
	c.a = fade_tail > 0.5 && u > 0.65 ? (1.0 - u) / 0.35 : 1.0;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
