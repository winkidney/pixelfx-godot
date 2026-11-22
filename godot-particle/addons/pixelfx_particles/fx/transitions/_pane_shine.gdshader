// shatter-wipe's pane reflections (soft layer): three slanted bands of pale light blended over the dark glass,
// fading once it settles.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_pane.gdshaderinc"

void fragment() {
	vec2 q = floor(UV * vec2(TR_W, TR_H));
	float a = 0.0;
	if (r1 > 0.0 && shine > 0.0 && q.y < r1) {
		for (int b = 0; b < 3; b++) {
			float off = b == 0 ? 0.0 : b == 1 ? 22.0 : 30.0;
			float w = b == 0 ? 16.0 : b == 1 ? 3.0 : 1.0;
			float ba = b == 0 ? 0.05 : b == 1 ? 0.1 : 0.12;
			float xc = TR_W * 0.18 + off + (TR_H - (q.y - y0)) * 0.7;
			if (q.x >= max(0.0, floor(xc - w / 2.0)) && q.x < min(TR_W, ceil(xc + w / 2.0))) {
				a = ba * shine;
			}
		}
	}
	if (a <= 0.0) {
		discard;
	}
	vec4 o = vec4(C[6].rgb, a);
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
