// How the tractor beam's cycle() particles look (placed by _tractor_bits.gdshader): mode 0 a translucent disc
// (radius in CUSTOM.x, alpha in the colour), mode 1 a 1 px streak (its quad stretched along it) in its head colour
// over its front half and its tail colour (CUSTOM.yzw) behind, mode 2 a pixel, mode 3 a twinkle (the original's
// sparkle(): arms CUSTOM.x px in c, tips in tip, a white heart). Colour layer, translucent in mode 0.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_scifi.gdshaderinc"

uniform int mode = 0;
uniform vec2 quad = vec2(10.0);
uniform vec4 c : source_color = vec4(1.0);
uniform vec4 tip : source_color = vec4(1.0);

varying flat vec4 cu;

void vertex() {
	cu = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 o = vec4(0.0);
	if (mode == 0) {
		vec2 off = (UV - 0.5) * quad;
		float r = cu.x;
		if (r < 0.5 ? all(equal(-floor(0.5 - off), vec2(0.0))) : dot(off, off) <= r * r) {
			o = COLOR;
		}
	} else if (mode == 1) {
		o = UV.x > 0.5 ? vec4(COLOR.rgb, 1.0) : vec4(cu.yzw, 1.0);
	} else if (mode == 2) {
		o = COLOR;
	} else {
		ivec2 q = ivec2(floor(UV * quad)) - ivec2(floor(quad * 0.5));
		int n = int(cu.x + 0.5);
		int ax = abs(q.x);
		int ay = abs(q.y);
		if (q == ivec2(0)) {
			o = vec4(1.0);
		} else if ((q.x == 0 && ay <= n) || (q.y == 0 && ax <= n)) {
			o = float(max(ax, ay)) > float(n) * 0.6 ? tip : c;
		}
	}
	if (o.a <= 0.0) {
		discard;
	}
	if (px_out(o, FRAGCOORD.xy, mode == 0)) {
		discard;
	}
	COLOR = o;
}
