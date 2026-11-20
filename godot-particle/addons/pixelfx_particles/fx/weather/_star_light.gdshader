// The glow of the steady stars and glints (_star.gdshader's light twin): steady_glow at k steady_k x twinkle, the
// glint's in `spark` at spark_k x twinkle.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform vec4 steady_glow : source_color = vec4(1.0);
uniform float steady_k = 0.22;
uniform vec4 spark : source_color = vec4(1.0);
uniform float spark_k = 0.3;
uniform float strength = 1.0;

void fragment() {
	vec2 q = wx_cell(UV) + 0.5;
	int kind = int(cu.z + 0.5);
	float tw = cu.w;
	vec3 l = vec3(0.0);
	if (kind == 1) {
		l = steady_glow.rgb * glow_(q, cu.xy + 0.5, 3.0, steady_k * tw);
	} else if (kind == 2) {
		float n = 1.0 + floor(tw * 2.0 + 0.5);
		l = spark.rgb * glow_(q, cu.xy, 4.0 + n * 2.0, spark_k * tw);
	}
	COLOR = vec4(l * strength, 1.0);
}
