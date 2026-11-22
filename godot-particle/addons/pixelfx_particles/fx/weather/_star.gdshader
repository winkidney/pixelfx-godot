// A star (placed by _stars.gdshader): a dim twinkling speck in `dim`, a steady point in steady[0 or 1], or a little
// glint (sim.js sparkle(): spark, tipped with spark_tip).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_sparkle.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform vec4 dim : source_color = vec4(1.0);
uniform vec4 steady[2] : source_color;
uniform vec4 spark : source_color = vec4(1.0);
uniform vec4 spark_tip : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);

void fragment() {
	vec2 d = wx_cell(UV);
	int kind = int(cu.z + 0.5);
	float tw = cu.w;
	vec4 c = vec4(0.0);
	if (kind == 0) {
		if (d == vec2(0.0)) c = vec4(dim.rgb, 0.35 + 0.5 * tw);
	} else if (kind == 1) {
		if (d == vec2(0.0)) c = steady[int(pc.x + 0.5)];
	} else {
		c = sparkle_px(d, cu.xy, 1.0 + floor(tw * 2.0 + 0.5), spark, spark_tip, white);
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
