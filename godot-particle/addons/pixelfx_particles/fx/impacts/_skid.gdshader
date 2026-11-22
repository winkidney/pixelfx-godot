// ricochet's skid (src/fx/impacts/ricochet.js drawBack): a gouge along the floor's top rows from x = -3 to `len`,
// glowing where the round dragged (white, hi, mid, lo, low, soot as `heat` falls, cooler toward its far end), every
// other cell of the row under it lit or sooty. Key heat, len, fade.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float heat = 1.0;
uniform float len = 12.0;
uniform float fade = 1.0;
uniform vec4 white : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 soot : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec4 tint = COLOR;
	vec2 cell = floor(center + (UV - 0.5) * size);
	float x = cell.x;
	if (x < -3.0 || x > len) {
		discard;
	}
	float h = heat * (1.15 - (x + 3.0) / 15.0 * 0.6);
	vec4 c;
	if (cell.y == 0.0) {
		c = h > 0.8 ? white : h > 0.55 ? c5 : h > 0.35 ? c4 : h > 0.18 ? c3 : h > 0.08 ? c2 : soot;
		c.a = fade;
	} else if (cell.y == 1.0 && x > -2.0 && x < len - 2.0 && mod(x, 2.0) == 0.0) {
		c = h > 0.4 ? c3 : soot;
		c.a = fade * 0.7;
	} else {
		discard;
	}
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
