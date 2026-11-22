// The magic missile's motes and sparks (core/sim.js Particles.draw) for particles moved by
// _magic-missile_sim.gdshader. COLOR: the particle's colour and its life left; UV.y runs tail (0) to head (1).
// A mote (kind 0): its colour on the front 40%, the same at 55% brightness behind, fading in its last 35%. A spark
// (kind 2): the front 45% in the head's colour (s0 while young, s1, then s2), the back in it too while young, then s3.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform int kind = 0;
uniform vec4 s0 : source_color = vec4(1.0);
uniform vec4 s1 : source_color = vec4(1.0);
uniform vec4 s2 : source_color = vec4(1.0);
uniform vec4 s3 : source_color = vec4(1.0);

varying vec4 state;

void vertex() {
	state = COLOR;
}

void fragment() {
	float k = state.a;
	vec4 c;
	if (kind == 0) {
		c = UV.y > 0.6 ? vec4(state.rgb, 1.0) : vec4(state.rgb * 0.55, 1.0);
		c.a = k < 0.35 ? k / 0.35 : 1.0;
	} else {
		vec4 head = k > 0.6 ? s0 : k > 0.3 ? s1 : s2;
		c = UV.y > 0.55 ? head : (k > 0.5 ? head : s3);
		c.a = 1.0;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
