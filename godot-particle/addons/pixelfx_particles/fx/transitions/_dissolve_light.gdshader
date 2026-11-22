// pixel-dissolve's light: each block's glow as it winks in and out.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_dissolve.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 q = floor(UV * vec2(TR_W, TR_H));
	vec2 pc = q + 0.5;
	vec3 l = vec3(0.0);
	ivec2 cq = ivec2(floor(q / CELL));
	for (int gy = -1; gy <= 1; gy++) {
		for (int gx = -1; gx <= 1; gx++) {
			ivec2 c = cq + ivec2(gx, gy);
			if (c.x < 0 || c.y < 0 || c.x >= 16 || c.y >= 9) {
				continue;
			}
			vec4 ce = texelFetch(cells, c, 0);
			for (int k = 0; k < int(ce.y + 0.5); k++) {
				int bi = int(ce.x + 0.5) + k;
				vec4 b0 = texelFetch(blocks, ivec2(bi, 0), 0);
				vec4 b1 = texelFetch(blocks, ivec2(bi, 1), 0);
				float s = b0.z;
				vec2 cc = b0.xy + s / 2.0;
				float ki = (t - b1.x) / P;
				float ko = (t - b1.y) / P;
				if (ki < 0.0 || ko >= 1.6) {
					continue;
				}
				if (ko < 0.0) {
					if (ki < 1.0) {
						l += lt_glow(pc, cc, s * 0.8 + 4.0, C[5].rgb, 0.45 * (1.0 - ki));
					}
				} else if (ko < 0.35) {
					l += lt_glow(pc, cc, s * 0.8 + 3.0, C[4].rgb, 0.35 * ko / 0.35);
				} else if (ko < 0.75) {
					l += lt_glow(pc, cc, s * 0.8 + 4.0, C[5].rgb, 0.45 * (1.0 - (ko - 0.35) / 0.4 * 0.5));
				} else if (ko < 1.0) {
					l += lt_glow(pc, cc, s * 0.5 + 3.0, C[5].rgb, 0.35 * (1.0 - (ko - 0.75) / 0.25));
				}
			}
		}
	}
	COLOR = vec4(l * strength, 1.0);
}
