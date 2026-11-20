// weather/clouds' moon (clouds.js moon()): a pale disc with darker seas and a bright limb on the lit side.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(320.0, 180.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform vec4 white : source_color = vec4(1.0);
uniform vec2 moon = vec2(92.0, -128.0);
uniform float radius = 12.0;
uniform float t = 0.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float dx = p.x - moon.x;
	float dy = p.y - moon.y;
	float d = length(vec2(dx, dy)) / radius;
	if (d > 1.0) {
		discard;
	}
	bool sea = (dx + 4.0) * (dx + 4.0) + (dy + 2.0) * (dy + 2.0) < 14.0 || (dx - 3.0) * (dx - 3.0) + (dy - 4.0) * (dy - 4.0) < 9.0
		|| (dx - 5.0) * (dx - 5.0) + (dy + 5.0) * (dy + 5.0) < 4.0;
	vec4 c = d > 0.86 ? (dx + dy < 0.0 ? C[6] : white) : sea ? C[5] : (d < 0.5 && dx + dy < 0.0) ? white : C[7];
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
