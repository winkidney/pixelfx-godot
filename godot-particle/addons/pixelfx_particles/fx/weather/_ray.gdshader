// An aurora ray as a fine strand of light up from the hem, green into violet, fading as it rises, a pale point at
// its foot (aurora.js draw()). Soft layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform vec4 low : source_color = vec4(1.0);
uniform vec4 mid : source_color = vec4(1.0);
uniform vec4 high : source_color = vec4(1.0);
uniform vec4 foot : source_color = vec4(1.0);

void fragment() {
	vec2 d = wx_cell(UV);
	float n = floor(cu.z + 0.5);
	float j = -d.y;
	vec4 c = vec4(0.0);
	if (d.x == 0.0) {
		if (j == 0.0) {
			c = foot;
		} else if (j >= 1.0 && j <= n - 1.0) {
			float u = j / n;
			c = vec4((u < 0.35 ? low : u < 0.6 ? mid : high).rgb, cu.w * pow(1.0 - u, 1.3));
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
