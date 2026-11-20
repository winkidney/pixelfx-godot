// diamond-wipe's light: every lit diamond's rim light and its glow.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_diamond.gdshaderinc"

uniform float strength = 1.0;

void fragment() {
	vec2 px = floor(UV * vec2(TR_W, TR_H));
	vec2 pc = px + 0.5;
	vec3 l = vec3(0.0);
	for (int n = 0; n < count; n++) {
		vec4 d = texelFetch(lat, ivec2(n, 0), 0);
		float hd;
		float heat;
		dw_state(d, hd, heat);
		if (hd < 0.5 || heat <= 0.0) {
			continue;
		}
		if (heat > 0.15 && dw_in(px, d, hd)) {
			float dy = pc.y - d.y;
			float dx = pc.x - d.x;
			if (hd - abs(dx) - abs(dy) < 1.0) {
				int q = (dy < 0.0 ? 0 : 2) + (dx < 0.0 ? 0 : 1);
				l += lt_add(C[5].rgb, 0.4 * heat * (q == 0 ? 1.0 : 0.6));
			}
		}
		l += lt_glow(pc, d.xy, hd + 6.0, C[4].rgb, 0.22 * heat);
	}
	COLOR = vec4(l * strength, 1.0);
}
