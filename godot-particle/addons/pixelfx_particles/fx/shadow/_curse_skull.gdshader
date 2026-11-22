// Curse's skull (after the original's skull()): the hand-drawn 17 x 18 skull from `tex` (R: which pixel, 1 outline,
// 2..5 bone dark to bright, 6 sockets, 7 nose, 8 teeth, 9 gaps; G: when a crack splits it, 0 never) at scale s,
// squashed by sq, shaken to (ox, oy) about (0, sy); white (the stamp's first frames) paints it white with violet
// sockets; crack 0..1 splits it from the crown, light leaking out of the splits. no_sockets 1 leaves the sockets out
// (the copy lifted above the light: bone keeps its colours under the glow). Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(40.0, 44.0);
uniform vec2 center = vec2(0.0, -60.0);
uniform sampler2D tex : filter_nearest;
uniform float sy = -60.0;
uniform float s = 1.0;
uniform float sq = 1.0;
uniform float ox = 0.0;
uniform float oy = 0.0;
uniform float white_on = 0.0;
uniform float crack = 0.0;
uniform float no_sockets = 0.0;
uniform vec4 k0 : source_color = vec4(1.0);
uniform vec4 k1 : source_color = vec4(1.0);
uniform vec4 k2 : source_color = vec4(1.0);
uniform vec4 k3 : source_color = vec4(1.0);
uniform vec4 k4 : source_color = vec4(1.0);
uniform vec4 c0 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center + 0.001) + 0.5;
	float cx = ox;
	float cy = sy + oy;
	int u = int(floor((p.x - cx) / s + 8.5));
	int v = int(floor((p.y - cy) / (s * sq) + 9.0));
	if (u < 0 || v < 0 || u >= 17 || v >= 18) {
		discard;
	}
	vec4 cell = texelFetch(tex, ivec2(u, v), 0);
	int ch = int(round(cell.r * 255.0));
	if (ch == 0 || (no_sockets > 0.5 && ch == 6)) {
		discard;
	}
	vec4 c;
	if (white_on > 0.5) {
		c = (ch == 6 || ch == 7) ? c5 : white;
	} else {
		c = ch == 1 ? k0 : ch == 2 ? k1 : ch == 3 ? k2 : ch == 4 ? k3 : ch == 5 ? k4 : ch == 6 ? c0 : ch == 7 ? c0 : ch == 8 ? k3 : k0;
		float ck = round(cell.g * 255.0);
		if (ck > 0.0 && (ck - 1.0) / 250.0 < crack) {
			c = (crack > 0.55 && (u + v) % 2 == 1) ? c6 : k0;
		}
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
