// The magic missile's twinkling stars (core/sim.js sparkle()) for particles moved by _magic-missile_sim.gdshader,
// on a 9 x 9 quad snapped to the pixel grid: COLOR.rgb the colour, COLOR.a * 16 - 0.5 the arm n (0: one pixel of
// the colour). Arms n px along the axes, their outer 40% in the colour at 75%, diagonals from 3 px (and longer ones
// from 6), a white heart.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

varying vec4 state;

void vertex() {
	state = COLOR;
}

void fragment() {
	ivec2 q = ivec2(floor(UV * 9.0)) - ivec2(4);
	int n = int(round(state.a * 16.0 - 0.5));
	vec4 c0 = vec4(state.rgb, 1.0);
	vec4 tip = vec4(state.rgb * 0.75, 1.0);
	int ax = abs(q.x);
	int ay = abs(q.y);
	vec4 col;
	if (n <= 0) {
		if (q.x != 0 || q.y != 0) {
			discard;
		}
		col = c0;
	} else if (q.x == 0 && q.y == 0) {
		col = vec4(1.0);
	} else if ((q.x == 0 && ay <= n) || (q.y == 0 && ax <= n)) {
		col = float(max(ax, ay)) > float(n) * 0.6 ? tip : c0;
	} else if (n >= 3 && ax == 1 && ay == 1) {
		col = c0;
	} else if (n >= 6 && ax == 2 && ay == 2) {
		col = tip;
	} else {
		discard;
	}
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
