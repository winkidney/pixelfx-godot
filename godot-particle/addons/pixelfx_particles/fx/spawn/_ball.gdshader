// A soft, top-lit smoke ball (spawn/poof, spawn/coin-drop: the original's drawBall), one layer of it: 0 the shade
// disc (down and right), 1 the body, 2 the lit cap and its white highlight. Three emitters share one track and draw
// the layers in the original's order (every shade, then every body, then every cap), so neighbouring balls merge into
// one lumpy cloud. Soft layer: the original blends these discs.
//   rows: 0 (x, y, on, r), 1 (shade colour, body colour, cap colour (-1: none), alpha), 2 (highlight alpha, ..)
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_track.gdshaderinc"

uniform int layer = 0;
uniform vec4 pal[8] : source_color;
// the discs' offsets and sizes against r: shade (dx, dy, r), body, cap, highlight; and their alphas
uniform vec3 shade_d = vec3(0.16, 0.2, 1.0);
uniform vec3 body_d = vec3(-0.06, -0.08, 0.86);
uniform vec3 cap_d = vec3(-0.28, -0.34, 0.42);
uniform vec3 hl_d = vec3(-0.3, -0.38, 0.2);
uniform vec3 alphas = vec3(0.8, 0.88, 0.85);
uniform vec4 hl_color : source_color = vec4(1.0);
uniform float hl_alpha = 0.9;

void vertex() {
	tk_cu = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 r0 = tk_row(0);
	vec4 r1 = tk_row(1);
	float r = r0.w;
	float a = r1.w;
	vec4 c = vec4(0.0);
	if (layer == 0) {
		if (tk_disc(UV, shade_d.xy * r, r * shade_d.z)) {
			c = vec4(pal[int(r1.x + 0.5)].rgb, alphas.x * a);
		}
	} else if (layer == 1) {
		if (tk_disc(UV, body_d.xy * r, r * body_d.z)) {
			c = vec4(pal[int(r1.y + 0.5)].rgb, alphas.y * a);
		}
	} else if (r1.z > -0.5) {
		if (tk_disc(UV, cap_d.xy * r, r * cap_d.z)) {
			c = tk_over(c, pal[int(r1.z + 0.5)].rgb, alphas.z * a);
		}
		float ha = tk_row(2).x;
		if (ha > 0.0 && tk_disc(UV, hl_d.xy * r, r * hl_d.z)) {
			c = tk_over(c, hl_color.rgb, ha);
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
