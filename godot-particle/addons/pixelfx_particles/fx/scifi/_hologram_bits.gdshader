// The hologram's data bits (src/fx/scifi/hologram.js cycle()): each slot one of the original's 18, born and living
// as its rng(seed, i, 911) says (`bits`: born, life, x share, white), rising from the lens up through the cone as it
// widens, fading out; a flicker drops the odd rows. Placed from the keyed clock `t`; colour layer (dot1 texture).
shader_type particles;
render_mode disable_velocity, disable_force;

uniform float t = 0.0;
uniform sampler2D data : filter_nearest, repeat_disable;
uniform sampler2D bits : filter_nearest, repeat_disable;
uniform vec4 hi : source_color = vec4(1.0);
uniform vec4 lo : source_color = vec4(1.0);

#include "res://addons/pixelfx_particles/fx/scifi/_hologram.gdshaderinc"

void place(int i, inout mat4 tr, inout vec4 col) {
	vec4 b = texelFetch(bits, ivec2(i, 0), 0);
	float age = mod(t - b.x, D);
	tr = mat4(vec4(0.0), vec4(0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	if (age >= b.y) {
		return;
	}
	float ph = t / D;
	float cy = OY + 1.5 * sin(TAU * ph * 2.0);
	float top = cy + RAD * 1.3;
	float k = age / b.y;
	vec2 p = vec2(b.z * mix(4.0, RAD + 2.0, k), mix(LENS - 2.0, top, k));
	bool flick = F(0).y > 0.5;
	if (flick && (int(floor(p.y)) & 1) == 1) {
		return;
	}
	tr = mat4(vec4(1.0, 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(floor(p) + 0.5, 0.0, 1.0));
	col = vec4(b.w > 0.5 ? hi.rgb : lo.rgb, min(1.0, (1.0 - k) * 2.0));
}

void start() {
	VELOCITY = vec3(0.0);
	place(int(INDEX), TRANSFORM, COLOR);
}

void process() {
	VELOCITY = vec3(0.0);
	place(int(INDEX), TRANSFORM, COLOR);
}
