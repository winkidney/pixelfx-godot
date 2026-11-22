// spawn/egg-hatch's soft contact shadow under the egg, shifting as it rocks (`sx`), fading (`k`). Soft layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(21.0, 3.0);
uniform vec2 center = vec2(0.0);
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float sx = 0.0;
uniform float k = 1.0;

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	float d = pow((cell.x + 0.5 - sx) / 9.5, 2.0) + pow((cell.y + 0.5) / 1.8, 2.0);
	if (d >= 1.0) {
		discard;
	}
	vec4 c = vec4(color.rgb, 0.5 * k * (1.0 - d));
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
