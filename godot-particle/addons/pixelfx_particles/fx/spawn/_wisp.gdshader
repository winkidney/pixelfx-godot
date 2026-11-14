// spawn/spawn-portal's wisps: comets arcing up out of the rift, a fading tail of 1 px segments through their last
// positions (white, then pale, then violet, a second strand beside its head), a lit head of two discs and a white
// heart. Colour layer.
//   rows: 0 (x, y, on, life left), 1..6 (the tail's points, two a row, px from the head), 7 (how many points, ..)
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_track.gdshaderinc"

uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);

void vertex() {
	tk_cu = INSTANCE_CUSTOM;
}

vec2 pt(int i) {
	vec4 r = tk_row(1 + i / 2);
	return i % 2 == 0 ? r.xy : r.zw;
}

void fragment() {
	vec2 cell = tk_cell(UV);
	vec2 fr = tk_fr();
	vec2 q = tk_q(UV);
	float th = pfx_threshold(FRAGCOORD.xy);
	int n = int(tk_row(7).x + 0.5);
	vec4 o = vec4(0.0);
	for (int i = 1; i < 12; i++) {
		if (i >= n) {
			break;
		}
		vec2 a = pt(i - 1);
		vec2 b = pt(i);
		float u = float(i) / float(n);
		if (tk_line(cell, floor(fr + a), floor(fr + b)) >= 0.0) {
			float al = 1.15 - u;
			if (al >= 1.0 || al > th) {
				o = u < 0.25 ? white : u < 0.55 ? c6 : c4;
			}
		}
		if (u < 0.35 && tk_line(cell, floor(fr + a + vec2(1.0, 0.0)), floor(fr + b + vec2(1.0, 0.0))) >= 0.0) {
			o = c5;
		}
	}
	if (dot(q, q) <= 4.0) {
		o = c5;
	}
	if (dot(q, q) <= 1.44) {
		o = c6;
	}
	if (all(equal(cell, vec2(0.0)))) {
		o = white;
	}
	if (o.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
