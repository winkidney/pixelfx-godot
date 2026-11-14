// The lightning-strike's sigil on the floor: a ring of dashes turning slowly, crosshair ticks, an inner ring and a
// heart, drawn in from the front as it appears, brighter as `k` (the charge) climbs, white-hot the moment the bolt
// lands, then gone. `near` draws the front half (with a dark underside), else the far half. Key `t` and `k`. The
// heart is the pixel just right of and below the rect's middle (an odd-sized rect centred half a pixel off).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(75.0, 25.0);
uniform float t = 0.0;
uniform float k = 0.0;
uniform bool near = true;
uniform float strike = 0.76;
uniform float rx = 28.0;
uniform float sy = 0.22;
uniform vec4 c2 : source_color;
uniform vec4 c3 : source_color;
uniform vec4 c4 : source_color;
uniform vec4 c5 : source_color;
uniform vec4 c6 : source_color;

bool on_side(float a) {
	return (sin(a) >= 0.0) == near;
}

float from_front(float a) {
	return abs(mod(mod(a - PI / 2.0, TAU) + TAU + PI, TAU) - PI) / PI;
}

void fragment() {
	vec2 q = floor((UV - 0.5) * size);
	float reveal = clamp(t / 0.22, 0.0, 1.0);
	float spin = t * 0.8;
	float burnt = t > strike ? t - strike : -1.0;
	if (burnt > 0.45) {
		discard;
	}
	float a0 = burnt < 0.07 ? 1.0 : 1.0 - (burnt - 0.07) / 0.38;
	bool hot = burnt >= 0.0 && burnt < 0.07;
	vec4 white = vec4(1.0);
	vec4 c = vec4(0.0);
	bool hit = false;
	// the heart
	if (near && burnt < 0.0) {
		if (q == vec2(0.0)) {
			c = k > 0.5 ? white : c6;
			hit = true;
		} else if (q == vec2(1.0, 0.0) || q == vec2(-1.0, 0.0) || q == vec2(0.0, -1.0)) {
			c = c5;
			hit = true;
		}
	}
	// the inner ring
	if (!hit && t > 0.3) {
		for (int i = 0; i < 70; i++) {
			float a = float(i) * 0.09;
			if (a >= TAU || !on_side(a)) {
				continue;
			}
			if (floor(vec2(cos(a) * 14.0, sin(a) * 14.0 * sy)) == q) {
				c = hot ? white : (near ? c4 : c2);
				c.a = clamp((t - 0.3) / 0.12, 0.0, 1.0);
				hit = true;
			}
		}
	}
	// the crosshair ticks
	if (!hit && reveal >= 1.0) {
		for (int j = 0; j < 4; j++) {
			float a = spin * -0.5 + float(j) * TAU / 4.0 + PI / 4.0;
			if (!on_side(a)) {
				continue;
			}
			vec2 p0 = vec2(cos(a) * (rx - 5.0), sin(a) * (rx - 5.0) * sy);
			vec2 p1 = vec2(cos(a) * (rx + 5.0), sin(a) * (rx + 5.0) * sy);
			vec2 d = p1 - p0;
			for (int s = 0; s <= 20; s++) {
				if (floor(p0 + d * float(s) / 20.0) == q) {
					c = hot ? white : (near ? c6 : c4);
					hit = true;
				}
			}
		}
	}
	// the ring of dashes
	if (!hit) {
		for (int i = 0; i < 22; i++) {
			float a = float(i) / 22.0 * TAU + spin;
			if (!on_side(a) || from_front(a) > reveal) {
				continue;
			}
			for (int j = 0; j < 3; j++) {
				float da = float(j) * 0.06;
				vec2 p = floor(vec2(cos(a + da) * rx, sin(a + da) * rx * sy));
				if (p == q) {
					c = hot ? white : (near ? (k > 0.7 ? c6 : c5) : (k > 0.7 ? c4 : c3));
					hit = true;
				} else if (near && p + vec2(0.0, 1.0) == q && !hit) {
					c = hot ? c6 : c2;
					hit = true;
				}
			}
		}
	}
	if (!hit) {
		discard;
	}
	c.a = (c.a > 0.0 ? c.a : 1.0) * a0;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
