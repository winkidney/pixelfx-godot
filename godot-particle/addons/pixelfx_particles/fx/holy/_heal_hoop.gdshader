// The heal's hoop of light (holy/heal, colour layer): a 1 px oval of radius `r` lying flat, white on its nearest
// stretch; the far half (back) a little thinner, the near half with a gold line under it. Centred on the rect.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(48.0, 20.0);
uniform float r = 16.0;
uniform bool back = false;
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);

const float SY = 0.3;

bool on_oval(vec2 p, float rr) {
	float e = length(vec2(p.x, p.y / SY));
	return e > 0.0 && abs(e - rr) / (length(vec2(p.x, p.y / (SY * SY))) / e) < 0.5;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	if (r < 0.5 || (back && p.y > 0.0) || (!back && p.y < 0.0)) {
		discard;
	}
	vec4 c = vec4(0.0);
	if (!back && on_oval(p - vec2(0.0, 1.0), r - 0.5)) {
		c = c4;
	}
	if (on_oval(p, r)) {
		c = p.y / (r * SY) > 0.5 ? vec4(1.0) : c6;
		c.a = back ? 0.8 : 1.0;
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
