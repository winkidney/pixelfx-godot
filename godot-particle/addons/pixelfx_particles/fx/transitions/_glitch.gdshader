// glitch-wipe's bands (colour layer): ink behind each torn, ragged edge, its white line and magenta / cyan ghosts,
// specks, data slivers and broken tiles round it, and the signal's spits while it's all black.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_glitch.gdshaderinc"

void fragment() {
	vec2 q = floor(UV * vec2(TR_W, TR_H));
	vec3 col = vec3(-1.0);
	int fi = int(fr + 0.5);
	for (int n = 0; n < nb; n++) {
		vec4 b;
		float k, e;
		bool moving, behind;
		gl_band(n, b, k, moving, e, behind);
		if (q.y < b.y || q.y >= b.y + b.z) {
			continue;
		}
		if (!gl_shown(k)) {
			break;
		}
		int bi = int(b.x + 0.5);
		float h = b.z;
		int yi = int(q.y);
		float jag = moving ? gl_round((gl_r(fi, yi, 14) - 0.5) * 6.0 + (gl_r(fi >> 1, bi, 15) - 0.5) * 6.0) : 0.0;
		float ex = clamp(gl_round(e + jag), 0.0, TR_W);
		if (behind ? q.x < ex : q.x >= ex) {
			col = ink.rgb;
		}
		if (!moving) {
			break;
		}
		float e1 = behind ? ex - 1.0 : ex;
		float side = behind ? 1.0 : -1.0;
		float sp = 2.0 + float((bi + fi) % 3);
		if (q.x == e1) {
			col = vec3(1.0);
		}
		if (q.x == e1 + side * sp || q.x == e1 + side * (sp + 1.0)) {
			col = red.rgb;
		}
		if (q.x == e1 - side * (sp + 1.0)) {
			col = C[5].rgb;
		}
		if (q.x == e1 - side * (sp + 2.0)) {
			col = C[4].rgb;
		}
		float exc = clamp(gl_round(e), 0.0, TR_W);
		float open = behind ? 1.0 : -1.0;
		// specks crackling round the edge
		for (int s = 0; s < 32; s++) {
			if (float(s) >= h) {
				break;
			}
			if (gl_r(fi, bi, 100 + s) > 0.55) {
				continue;
			}
			float x = exc + open * gl_round(pow(gl_r(fi, bi, 200 + s), 2.0) * 22.0 - 4.0);
			float y = b.y + floor(gl_r(fi, bi, 300 + s) * h);
			if (q.x == x && q.y == y) {
				col = gl_pick(gl_r(fi, bi, 400 + s));
			}
		}
		// data slivers
		for (int s = 0; s < 4; s++) {
			if (gl_r(fi, bi, 20 + s) > 0.5) {
				continue;
			}
			float len = 2.0 + floor(pow(gl_r(fi, bi, 30 + s), 2.0) * 60.0);
			bool ahead = gl_r(fi, bi, 40 + s) < 0.6;
			float d = floor(pow(gl_r(fi, bi, 50 + s), 1.5) * 70.0) + 4.0;
			float y = b.y + floor(gl_r(fi, bi, 60 + s) * h);
			float x = ahead ? (open > 0.0 ? exc + d : exc - d - len) : (open > 0.0 ? exc - d - len : exc + d);
			if (q.y == y && q.x >= x && q.x < x + len) {
				col = gl_pick(gl_r(fi, bi, 70 + s));
			}
		}
		// a broken tile near the edge
		if (h >= 8.0 && gl_r(fi, bi, 80) < 0.35) {
			float bw = 6.0 + floor(gl_r(fi, bi, 81) * 10.0);
			float bh = 3.0 + floor(gl_r(fi, bi, 82) * min(6.0, h - 3.0));
			float x = exc + open * floor(gl_r(fi, bi, 83) * 24.0 - 4.0) - (open < 0.0 ? bw : 0.0);
			float y = b.y + floor(gl_r(fi, bi, 84) * (h - bh));
			if (q.x >= x && q.x < x + bw && q.y >= y && q.y < y + bh && (q.x == x || q.y == y || q.x == x + bw - 1.0 || q.y == y + bh - 1.0)) {
				col = gl_r(fi, bi, 85) < 0.5 ? C[5].rgb : red.rgb;
			}
		}
		break;
	}
	// while it's all black, the signal still spits now and then
	if (t > IN1 && t < OUT0 + 0.05) {
		for (int s = 0; s < 3; s++) {
			if (gl_r(fi, s, 90) > 0.4) {
				continue;
			}
			float y = floor(gl_r(fi, s, 91) * TR_H);
			float x = floor(gl_r(fi, s, 92) * TR_W);
			float len = 3.0 + floor(pow(gl_r(fi, s, 93), 2.0) * 40.0);
			if (q.y == y && q.x >= x && q.x < x + len) {
				col = s == 0 ? C[4].rgb : s == 1 ? C[3].rgb : red.rgb;
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
