// weather/shooting-stars' milky band (shooting-stars.js sky()'s rows pass): a faint band of light across the sky,
// dim specks scattered thickest along its middle. light: its light (the light layer) instead of its specks.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform vec2 size = vec2(320.0, 180.0);
uniform vec2 center = vec2(0.0);
uniform vec4 K[5] : source_color;
uniform int seed = 4;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float d = abs((p.y + 110.0) - (p.x * -0.32)) / 36.0;
	if (d >= 1.0 || p.y > 0.0) {
		discard;
	}
	float k = (1.0 - d) * (1.0 - d);
	if (rand4(int(p.x + 159.5), int(floor(p.y)), seed, 5) >= 0.05 * k) {
		discard;
	}
	vec4 c = vec4(K[2].rgb, 0.7);
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
