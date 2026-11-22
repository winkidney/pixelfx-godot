// The light the transitions' marks give off (the light twin of _marks.gdshader: same data, same slots): a glint's two
// lights, a sparkle's glow, or the glow in row 3 (radius < 1: light added to the mark's own cell only).
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"

uniform sampler2D data : filter_nearest, repeat_disable;
uniform float quad = 9.0;
uniform vec4 pal[16] : source_color;
uniform float strength = 1.0;

varying flat vec4 cu;

void vertex() {
	cu = INSTANCE_CUSTOM;
}

void fragment() {
	int i = int(cu.x + 0.5);
	int f = int(cu.y + 0.5);
	vec4 r0 = texelFetch(data, ivec2(i, f * 4), 0);
	vec4 r1 = texelFetch(data, ivec2(i, f * 4 + 1), 0);
	vec4 r2 = texelFetch(data, ivec2(i, f * 4 + 2), 0);
	vec4 r3 = texelFetch(data, ivec2(i, f * 4 + 3), 0);
	vec2 d = floor((UV - 0.5) * quad + 0.5);
	vec2 q = cu.zw + d;
	vec2 pc = q + 0.5;
	int kd = int(r0.w + 0.5);
	vec3 l = vec3(0.0);
	if (kd == 4) {
		l += tr_glint_light(pc, cu.zw + r2.xy, r2.z, r0.z, tr_pal(pal, int(r1.x + 0.5)));
	}
	vec3 lc = tr_pal(pal, int(r1.z + 0.5));
	if (r3.w > 0.004) {
		if (r3.z < 1.0) {
			if (all(equal(q, floor(r3.xy)))) {
				l += lt_add(lc, r3.w);
			}
		} else {
			l += lt_glow(pc, r3.xy, r3.z, lc, r3.w);
		}
	}
	COLOR = vec4(l * strength * COLOR.a, 1.0);
}
