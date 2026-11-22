// A translucent haze over the canvas rows y0..y1 (the weather loops' dark air: it keeps the sky's stars from reading
// as snow, petals or fireflies). mode 0: one colour, alpha a0 + a1 * smooth(e0, e1, y); mode 1: k = (y - e0) /
// (e1 - e0), colour top -> low by k^pw, alpha a0 + a1 * k. Soft layer (build/fx/weather/_weather.gd sky()).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform vec2 size = vec2(320.0, 180.0);
uniform vec2 center = vec2(0.0);
uniform int mode = 0;
uniform vec4 top : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 low : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float a0 = 0.3;
uniform float a1 = 0.2;
uniform float e0 = -170.0;
uniform float e1 = 0.0;
uniform float pw = 1.0;
uniform float y0 = -170.0;
uniform float y1 = 9.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	if (p.y < y0 || p.y > y1 + 1.0) {
		discard;
	}
	vec4 c;
	if (mode == 0) {
		c = vec4(top.rgb, a0 + a1 * smooth_(e0, e1, p.y));
	} else {
		float k = (p.y - e0) / (e1 - e0);
		c = vec4(mix(top.rgb, low.rgb, pow(max(k, 0.0), pw)), a0 + a1 * k);
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
