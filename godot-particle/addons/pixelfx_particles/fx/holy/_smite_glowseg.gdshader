// Light along a segment (holy/smite and holy-pillar, light layer): the original's glowLine(a, b, r, c, k),
// (1 - distance to the segment / r)^2 * k, and a glow(at, r2, c2, k2) on top. Coordinates are px from the origin.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/holy/_smite_lib.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec2 a = vec2(0.0);
uniform vec2 b = vec2(0.0);
uniform float radius = 8.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float k = 0.0;
uniform vec2 at = vec2(0.0);
uniform float radius2 = 8.0;
uniform vec4 color2 : source_color = vec4(1.0);
uniform float k2 = 0.0;
uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec3 l = vec3(0.0);
	if (k > 0.0) {
		l += color.rgb * smite_glow_seg(p, a, b, radius) * k;
	}
	if (k2 > 0.0) {
		l += color2.rgb * smite_glow(p, at, radius2) * k2;
	}
	COLOR = vec4(min(l, vec3(1.0)) * strength, 1.0);
}
