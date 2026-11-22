// How projectiles/_muzzle_bits.gdshader's particles look (colour layer): the particle colour carries (life left k,
// kind / 4 (4: a big ember), shown). A spark: a streak along its motion, its front 45% the head colour (hot, warm, cool as k falls)
// and the back the tail colour once it's past half its life; a grain or an ember: a pixel (an ember with a cooler
// one under it when it's big); a pellet: white at the head, then gold, then orange, thinning at the tail.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec4 s0 : source_color = vec4(1.0);
uniform vec4 s1 : source_color = vec4(1.0);
uniform vec4 s2 : source_color = vec4(1.0);
uniform vec4 s3 : source_color = vec4(1.0);
// a grain's colours (young, old)
uniform vec4 g0 : source_color = vec4(1.0);
uniform vec4 g1 : source_color = vec4(1.0);
// a pellet's, head to tail
uniform vec4 p0 : source_color = vec4(1.0);
uniform vec4 p1 : source_color = vec4(1.0);
uniform vec4 p2 : source_color = vec4(1.0);

varying vec4 st;

void vertex() {
	st = COLOR;
}

void fragment() {
	if (st.b < 0.5 || st.a < 0.5) {
		discard;
	}
	float k = st.r;
	int kind = int(st.g * 4.0 + 0.5);
	vec4 head = k > 0.6 ? s0 : k > 0.3 ? s1 : s2;
	vec4 c;
	// streaks (sparks, pellets) are quads centred on their heads, twice as long: the back half is the streak
	float uu = UV.y * 2.0;
	if ((kind == 0 || kind == 2) && uu > 1.0) {
		discard;
	}
	if (kind == 0) {
		c = uu > 0.55 ? head : (k > 0.5 ? head : s3);
	} else if (kind == 1) {
		c = k > 0.5 ? g0 : g1;
	} else if (kind == 2) {
		float u = uu;
		c = u > 0.85 ? p0 : u > 0.5 ? p1 : p2;
		c.a = u > 0.3 ? 1.0 : u / 0.3;
	} else if (kind == 3) {
		c = head;
	} else {
		c = UV.y > 0.5 ? s3 : head;
	}
	c.a *= COLOR.a;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
