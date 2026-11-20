// glitch-wipe's light: each moving edge's glow, the light on its line and ghosts, its slivers and broken tiles.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_glitch.gdshaderinc"

uniform float strength = 1.0;

vec3 gl_pick_l(float u) {
	return gl_pick(u);
}

void fragment() {
	vec2 q = floor(UV * vec2(TR_W, TR_H));
	vec2 pc = q + 0.5;
	vec3 l = vec3(0.0);
	int fi = int(fr + 0.5);
	for (int n = 0; n < nb; n++) {
		vec4 b;
		float k, e;
		bool moving, behind;
		gl_band(n, b, k, moving, e, behind);
		if (!gl_shown(k) || !moving) {
			continue;
		}
		int bi = int(b.x + 0.5);
		float h = b.z;
		float exc = clamp(gl_round(e), 0.0, TR_W);
		float open = behind ? 1.0 : -1.0;
		if (q.y >= b.y && q.y < b.y + h) {
			int yi = int(q.y);
			float jag = gl_round((gl_r(fi, yi, 14) - 0.5) * 6.0 + (gl_r(fi >> 1, bi, 15) - 0.5) * 6.0);
			float ex = clamp(gl_round(e + jag), 0.0, TR_W);
			float e1 = behind ? ex - 1.0 : ex;
			float side = behind ? 1.0 : -1.0;
			float sp = 2.0 + float((bi + fi) % 3);
			if (q.x == e1) {
				l += lt_add(vec3(1.0), 0.45);
			}
			if (q.x == e1 + side * (sp + 1.0)) {
				l += lt_add(red.rgb, 0.5);
			}
			if (q.x == e1 + side * (sp + 3.0)) {
				l += lt_add(red.rgb, 0.22);
			}
			if (q.x == e1 - side * (sp + 1.0)) {
				l += lt_add(C[5].rgb, 0.45);
			}
			if (q.x == e1 - side * (sp + 3.0)) {
				l += lt_add(C[5].rgb, 0.22);
			}
			for (int s = 0; s < 4; s++) {
				if (gl_r(fi, bi, 20 + s) > 0.5) {
					continue;
				}
				float len = 2.0 + floor(pow(gl_r(fi, bi, 30 + s), 2.0) * 60.0);
				bool ahead = gl_r(fi, bi, 40 + s) < 0.6;
				float d = floor(pow(gl_r(fi, bi, 50 + s), 1.5) * 70.0) + 4.0;
				float y = b.y + floor(gl_r(fi, bi, 60 + s) * h);
				float x = ahead ? (open > 0.0 ? exc + d : exc - d - len) : (open > 0.0 ? exc - d - len : exc + d);
				if (q.y == y && q.x >= x && q.x < x + len && mod(q.x - x, 3.0) < 0.5) {
					l += lt_add(gl_pick(gl_r(fi, bi, 70 + s)), 0.35);
				}
			}
			if (h >= 8.0 && gl_r(fi, bi, 80) < 0.35) {
				float bw = 6.0 + floor(gl_r(fi, bi, 81) * 10.0);
				float bh = 3.0 + floor(gl_r(fi, bi, 82) * min(6.0, h - 3.0));
				float x = exc + open * floor(gl_r(fi, bi, 83) * 24.0 - 4.0) - (open < 0.0 ? bw : 0.0);
				float y = b.y + floor(gl_r(fi, bi, 84) * (h - bh));
				if (q.y == y && q.x >= x && q.x < x + bw && mod(q.x - x, 2.0) < 0.5) {
					l += lt_add(gl_r(fi, bi, 85) < 0.5 ? C[5].rgb : red.rgb, 0.25);
				}
			}
		}
		l += lt_glow(pc, vec2(exc, b.y + h / 2.0), h * 0.7 + 7.0, (bi % 2 == 1) ? red.rgb : C[5].rgb, 0.28);
	}
	COLOR = vec4(l * strength, 1.0);
}
