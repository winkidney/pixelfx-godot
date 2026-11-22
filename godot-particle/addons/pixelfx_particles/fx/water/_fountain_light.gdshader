// Caustic light swimming in a fountain's basin water (see _fountain.gdshader), additive.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float by = -12.24;
uniform float level = 8.8;
uniform float pool_r = 29.5;
uniform float sy = 0.34;
uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float T = t * 6.28318530718;
	float ry = pool_r * sy;
	float cy = by - level;
	float dx = p.x / pool_r;
	float dy = (p.y - cy) / ry;
	float d = dx * dx + dy * dy;
	if (d > 1.0) {
		discard;
	}
	float u = p.x * 0.25 + 1.6 * sin(p.y * 0.6 + T);
	float w = p.y * 0.7 + 1.6 * sin(p.x * 0.14 - T * 2.0);
	float f = max(0.0, 1.0 - abs(sin(u) + sin(w)) * 2.6) * (1.0 - d);
	if (f <= 0.35) {
		discard;
	}
	COLOR = vec4(pal[5].rgb * 0.3 * f * strength, 1.0);
}
