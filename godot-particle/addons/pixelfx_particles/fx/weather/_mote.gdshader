// A dust mote or a spark of light (weather/god-rays): one pixel in its colour (CUSTOM.z: 0..2 of `tone`), with two
// more beside and below it when CUSTOM.w says it's big.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform vec4 tone[3] : source_color;
uniform vec4 side : source_color = vec4(1.0);

void fragment() {
	vec2 d = wx_cell(UV);
	vec4 c = vec4(0.0);
	if (d == vec2(0.0)) {
		c = tone[int(cu.z + 0.5)];
	} else if (cu.w > 0.5 && (d == vec2(1.0, 0.0) || d == vec2(0.0, 1.0))) {
		c = side;
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
