// A ring of dots as the original paints its bursts (uppercut.js, whip-crack.js, thrust.js), colour layer: dots every
// `astep` radians (0: 0.6 / r) round an ellipse of radius (r - o) across and (r - o) * ry_k down, for o = 0, 0.5, 1 ...
// while o < th, centred `off` px from the rect's centre pixel (frac_: where that centre sits in its pixel); each dot is
// the pixel cell holding it, dithered by alpha. Key r, th, off, color, alpha.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(65.0);
uniform vec2 frac_ = vec2(0.5);
uniform vec2 off = vec2(0.0);
uniform float r = 10.0;
uniform float rx_k = 1.0;
uniform float ry_k = 1.0;
uniform float th = 1.0;
uniform float astep = 0.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float alpha = 1.0;

void fragment() {
	vec4 tint = COLOR;
	if (alpha <= 0.0 || r <= 0.0) {
		discard;
	}
	vec2 cell = floor((UV - 0.5) * size);
	vec2 c0 = frac_ + off;
	vec2 pc = cell + 0.5 - c0;
	float st = astep > 0.0 ? astep : 0.6 / r;
	float ang = atan(pc.y / ry_k, pc.x / rx_k);
	if (ang < 0.0) {
		ang += 6.2831853;
	}
	bool hit = false;
	for (int m = 0; m < 8; m++) {
		float o = float(m) * 0.5;
		if (o >= th && m > 0) {
			break;
		}
		float rr = r - o;
		float j0 = floor(ang / st);
		for (int j = -2; j <= 3; j++) {
			float a = (j0 + float(j)) * st;
			if (a < 0.0 || a >= 6.2831853) {
				continue;
			}
			vec2 p = c0 + vec2(cos(a) * rr * rx_k, sin(a) * rr * ry_k);
			if (floor(p) == cell) {
				hit = true;
			}
		}
	}
	if (!hit) {
		discard;
	}
	vec4 c = color;
	c.a *= alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
