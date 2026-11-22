// A UI plate (src/fx/ui/_lib.js panel()) on its own: rect (x, y, w, h), corner r, alpha a (dithered), an optional
// diagonal shine; ink: outline, rim, top, body, low. Keyed every frame. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/ui/_panel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 ink[5] : source_color;
uniform bool on = false;
uniform vec4 rc = vec4(0.0);
uniform float r = 3.0;
uniform float a = 1.0;
uniform bool has_shine = false;
uniform float shine = 0.0;

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	int k = on ? panel_px(pc, rc, r, has_shine, shine) : -1;
	if (k < 0) {
		discard;
	}
	vec4 c = vec4(k == 5 ? vec3(1.0) : ink[k].rgb, a);
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
