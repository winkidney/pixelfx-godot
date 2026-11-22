// Caustic light swimming in a waterfall's pool (see _falls.gdshader), additive: two warped sine nets, light where
// either crosses zero.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform vec2 pool_r = vec2(56.0, 11.0);
uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float T = t * 6.28318530718;
	vec2 q = (p - vec2(0.0, 2.0)) / pool_r;
	float d = dot(q, q);
	if (d > 1.0) {
		discard;
	}
	float cx1 = sin(p.x * 0.11 - T * 2.0);
	float cx2 = sin(T + p.x * 0.05) * 1.4 + p.x * 0.13;
	float u = p.x * 0.2 + 1.8 * sin(p.y * 0.5 + T);
	float w = p.y * 0.55 + 1.8 * cx1;
	float f = (max(0.0, 1.0 - abs(sin(u) + sin(w)) * 2.6) + 0.6 * max(0.0, 1.0 - abs(sin(cx2 + p.y * 0.3)) * 3.0)) * (1.0 - d);
	if (f <= 0.5) {
		discard;
	}
	COLOR = vec4(pal[5].rgb * 0.18 * f * strength, 1.0);
}
