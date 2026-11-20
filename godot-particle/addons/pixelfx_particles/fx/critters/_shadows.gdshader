// A row of _lib.js shadow() ellipses blended over the floor one after another (a snake's length): sh[j] = x, rx, k
// (keyed every frame), all on row y with height ry, in ink; where they overlap their alphas build up as the
// original's blends do. Soft layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(128.0, 8.0);
uniform vec2 center = vec2(0.0);
uniform float y = 0.0;
uniform float ry = 1.2;
uniform vec4 sh[40];
uniform int count = 0;
uniform vec4 ink : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	vec2 cell = floor(pc);
	float keep = 1.0;
	for (int j = 0; j < 40; j++) {
		if (j >= count) {
			break;
		}
		vec4 s = sh[j];
		if (s.y <= 0.0 || s.z <= 0.0 || cell.x < floor(s.x - s.y) || cell.x > ceil(s.x + s.y) || cell.y < floor(y - ry) || cell.y > ceil(y + ry)) {
			continue;
		}
		float d = pow((pc.x - s.x) / s.y, 2.0) + pow((pc.y - y) / ry, 2.0);
		if (d < 1.0) {
			keep *= 1.0 - s.z * pow(1.0 - d, 0.7);
		}
	}
	vec4 c = vec4(ink.rgb, 1.0 - keep);
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
