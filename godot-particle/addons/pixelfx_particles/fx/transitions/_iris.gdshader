// iris's cover (colour layer): ink round the hole and the rim's bevel, white-hot as it pops open.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_iris.gdshaderinc"

void fragment() {
	vec2 px = floor(UV * vec2(TR_W, TR_H));
	vec3 col = vec3(-1.0);
	if (mode > 1.5) {
		col = ink.rgb;
	} else if (mode > 0.5) {
		float a0, b1, g;
		if (!ir_span(px, a0, b1, g) || px.x < a0 || px.x >= b1) {
			col = ink.rgb;
		} else {
			float dx = px.x + 0.5 - focus.x;
			float dy = px.y + 0.5 - focus.y;
			float d = length(vec2(dx, dy)) - r;
			if (abs(dx) >= g && d >= 0.0) {
				float q = d / rw;
				float lit = 0.5 - 0.5 * (dx * 0.7 + dy * 0.7) / (r + d + 0.01);
				float h = hot * (0.55 + 0.6 * lit);
				col = q >= 1.0 ? ink.rgb : q < 0.2 ? (h > 0.5 ? vec3(1.0) : h > 0.3 ? C[6].rgb : C[5].rgb) : q < 0.4 ? (h > 0.38 ? C[6].rgb : C[5].rgb) : q < 0.65 ? (h > 0.3 ? C[5].rgb : C[4].rgb) : q < 0.85 ? C[3].rgb : C[2].rgb;
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
