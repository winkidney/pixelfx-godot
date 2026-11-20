// Up to four of the original's p.glow() lights over the canvas, keyed: glow i at pos[i], radius rad[i], strength
// k[i], colour col[i] (painter.js glow(): (1 - d)^2 falloff, added to the light layer).
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform vec2 size = vec2(320.0, 180.0);
uniform vec2 center = vec2(0.0);
uniform vec2 pos[4];
uniform float rad[4];
uniform float k[4];
uniform vec4 col[4] : source_color;
uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec3 l = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		l += col[i].rgb * glow_(p, pos[i], rad[i], k[i]);
	}
	COLOR = vec4(l * strength, 1.0);
}
