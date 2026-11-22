// The light round spawn/coin-drop's coins (_coin.gdshader): a warm glow round a coin in the air; on the floor its
// gleam, a glow on its face and the light of its glint; the light of the last star as it winks out. Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/spawn/_track.gdshaderinc"

uniform vec4 pal[8] : source_color;
uniform vec4 white : source_color = vec4(1.0);
uniform float strength = 1.0;

void vertex() {
	tk_cu = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 r0 = tk_row(0);
	vec4 r1 = tk_row(1);
	vec2 p = tk_pos();
	vec2 q = tk_abs(UV) + 0.5;
	int mode = int(r0.w + 0.5);
	vec3 l = vec3(0.0);
	if (mode == 1) {
		l = pal[4].rgb * tk_glow(q, p, 8.0) * 0.3;
	} else if (mode == 2) {
		l = pal[4].rgb * tk_glow(q, vec2(p.x, -1.0), 7.0) * 0.18 + pal[5].rgb * tk_glow(q, vec2(p.x, -2.0), 6.0) * 0.25;
		if (r1.x >= 1.0) {
			l += white.rgb * tk_glow(q, vec2(p.x - 1.0, -3.0), 4.0 + 2.0 * r1.x) * 0.4;
		}
	} else if (mode == 3 && r1.x >= 1.0) {
		l = white.rgb * tk_glow(q, vec2(p.x, -2.0), 4.0 + 2.0 * r1.x) * 0.5;
	}
	COLOR = vec4(l * strength * COLOR.a, 1.0);
}
