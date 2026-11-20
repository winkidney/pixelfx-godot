// shatter-wipe's pane (colour layer). pass 0: the dark glass; pass 1 (over the reflections): the lit bevel, the glint
// along the falling edge, the cracks (white at their tips, cooling to ice, each with its shadow) and their white flare.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_pane.gdshaderinc"

void fragment() {
	vec2 q = floor(UV * vec2(TR_W, TR_H));
	vec3 col = vec3(-1.0);
	if (pass < 0.5) {
		if (r1 > 0.0 && q.y < r1) {
			col = ink.rgb;
		}
	} else {
		if (r1 > 0.0 && shine > 0.0) {
			float st = shine > 0.66 ? 0.0 : shine > 0.33 ? 1.0 : 2.0;
			if (q.y == r1 - 1.0) {
				col = C[int(6.0 - st * 2.0)].rgb;
			} else if (q.y == r1 - 2.0) {
				col = C[int(4.0 - st)].rgb;
			} else if (q.y == r1 - 3.0) {
				col = C[int(max(1.0, 2.0 - st))].rgb;
			}
			float k = max(0.0, 1.0 - abs(q.x - gx) / 28.0);
			if (k > 0.0 && q.y == r1 - 1.0 && r1 - 1.0 < TR_H) {
				col = k > 0.5 ? vec3(1.0) : C[6].rgb;
			}
		}
		if (cracks_on > 0.5) {
			vec4 cp = texelFetch(cpix, ivec2(q), 0);
			int s0 = int(cp.x + 0.5);
			int n = int(cp.y + 0.5);
			for (int i = 0; i < 256; i++) {
				if (i >= n) {
					break;
				}
				float e = pn_entry(s0 + i);
				float t0 = abs(e);
				if (t0 > t) {
					break;
				}
				if (e < 0.0) {
					col = C[1].rgb;
				} else {
					float age = t - t0;
					col = age < 0.04 ? vec3(1.0) : age < 0.18 ? C[6].rgb : C[5].rgb;
				}
			}
			if (wbeat > 0.0) {
				for (int i = 0; i < 256; i++) {
					if (i >= n) {
						break;
					}
					if (pn_entry(s0 + i) > 0.0) {
						col = vec3(1.0);
					}
				}
			}
		}
	}
	if (col.r < 0.0) {
		discard;
	}
	vec4 o = vec4(col, 1.0);
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
