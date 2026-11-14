// The sigil the holy pillar burns on the floor (holy/holy-pillar, colour layer): two flat rings and twelve marks
// turning slowly between them. It burns in round from the front both ways (`u` 0..1), white-hot, then gold, then
// cooling with `heat`, flickering white while hot, and dithers out with `out_k`. `back`: the far half.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(60.0, 18.0);
uniform float t = 0.0;
uniform float u = 0.0;
uniform float heat = 1.0;
uniform float out_k = 0.0;
uniform bool first = false;
uniform bool back = false;
uniform vec4 pal[8] : source_color;

const float SY = 0.24;
const float RX = 26.0;

float hash(vec2 q) {
	return fract(sin(dot(q, vec2(12.9898, 78.233))) * 43758.5453);
}

bool on_oval(vec2 p, float rr) {
	float e = length(vec2(p.x, p.y / SY));
	return e > 0.0 && abs(e - rr) / (length(vec2(p.x, p.y / (SY * SY))) / e) < 0.5;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	if (out_k <= 0.0 || (back && p.y > 0.0) || (!back && p.y < 0.0)) {
		discard;
	}
	float g = atan(p.y / SY, p.x);
	if (abs(mod(mod(g - PI / 2.0 + PI, TAU) + TAU, TAU) - PI) > u * PI + 0.01) {
		discard;
	}
	bool hot = false;
	bool on = false;
	if (on_oval(p, RX)) {
		on = true;
		hot = true;
	} else if (on_oval(p, RX * 0.72)) {
		on = true;
	} else {
		float e = length(vec2(p.x, p.y / SY));
		for (int j = 0; j < 12; j++) {
			float a = t * 0.35 + float(j) * TAU / 12.0;
			vec2 dir = vec2(cos(a), sin(a) * SY);
			float r1 = RX * (j % 3 == 0 ? 0.95 : 0.88);
			vec2 a0 = dir * RX * 0.78;
			vec2 ab = dir * r1 - a0;
			float s = clamp(dot(p - a0, ab) / dot(ab, ab), 0.0, 1.0);
			if (length(p - a0 - ab * s) < 0.6 && e >= RX * 0.76 && e <= r1 + 0.6) {
				on = true;
				hot = j % 2 == 0;
			}
		}
	}
	if (!on) {
		discard;
	}
	bool flick = hash(vec2(round(g * 40.0), floor(t * 20.0))) < 0.18;
	vec4 c = (first || (flick && heat > 0.4)) ? vec4(1.0) : heat > 0.6 ? (hot ? pal[6] : pal[5]) : heat > 0.3 ? pal[4] : heat > 0.1 ? pal[3] : pal[2];
	c.a = out_k;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
