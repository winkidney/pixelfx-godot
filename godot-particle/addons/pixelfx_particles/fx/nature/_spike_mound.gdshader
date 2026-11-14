// The floor heaving into a trembling mound before the spike breaks through (nature/earth-spike): a half ellipse
// 15 px across each way and `hm` px tall, shifted `jx` px, lit on top and to the left, a dark rim. Key hm and jx.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D stone : filter_nearest, repeat_disable;
uniform float hm = 0.0;
uniform float jx = 0.0;

vec4 S(int i) {
	return texture(stone, vec2((float(i) + 0.5) / 8.0, 0.5));
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center) + 0.5;
	float dx = (p.x - jx) / 15.0;
	float dy = p.y / max(hm, 0.01);
	float d = dx * dx + dy * dy;
	if (hm <= 0.6 || p.y > 0.5 || p.y < -hm - 1.0 || abs(p.x) > 16.0 || d > 1.18) {
		discard;
	}
	vec4 c = d > 1.0 ? S(0) : dy < -0.72 ? S(6) : dx < -0.3 ? S(5) : dx > 0.35 ? S(3) : S(4);
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
