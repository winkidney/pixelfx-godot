// The glitch's hero, clean or broken (src/fx/scifi/glitch.js draws the hero itself): the stand-in's own pixels (`tex`,
// feet at the origin) re-drawn each frame from that frame's corruption, rolled at build time from the original's
// rand(seed, frame, ...) into `data` (one column a frame): the red and cyan ghosts of an RGB split, rows torn sideways
// (tinted), interlaced, rolled up with the top slice repeated at the bottom, posterised, a bar of light rolling down,
// torn rows smearing their edge pixel out, junk blocks. Key `frame` (the original's frame, 0..71). Colour layer.
//   data rows: 0 (split, roll, interlace, poster), 1 (bar, junk count), 2..2+h (each body row: dx, tint 0/1 red/2 cyan,
//   smear length), 48.. (junk: x, y, w, h), 56.. (junk: colour index, checker)
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(88.0, 64.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D tex : filter_nearest;
uniform sampler2D data : filter_nearest, repeat_disable;
uniform float frame = 0.0;
// the effect's palette, C[0] .. C[6]
uniform vec4 pal[7] : source_color;

vec4 D(int f, int row) {
	return texelFetch(data, ivec2(f, row), 0);
}

vec4 body(ivec2 q) {
	ivec2 ts = textureSize(tex, 0);
	if (q.x < 0 || q.y < 0 || q.x >= ts.x || q.y >= ts.y) {
		return vec4(0.0);
	}
	vec4 c = texelFetch(tex, q, 0);
	return c.a < 0.5 ? vec4(0.0) : vec4(c.rgb, 1.0);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	ivec2 P = ivec2(floor(center + (UV - 0.5) * size + 0.001));
	ivec2 ts = textureSize(tex, 0);
	int ax = -ts.x / 2;
	int ay = -ts.y;
	int h = ts.y;
	int f = int(frame + 0.5);
	vec4 m0 = D(f, 0);
	vec4 m1 = D(f, 1);
	int split = int(m0.x);
	int roll = int(m0.y);
	bool interlace = m0.z > 0.5;
	bool poster = m0.w > 0.5;
	float bar = m1.x;
	int nj = int(m1.y + 0.5);
	vec4 c = vec4(0.0);
	bool have = false;
	// junk blocks, the last drawn on top
	for (int i = 5; i >= 0; i--) {
		if (i >= nj) {
			continue;
		}
		vec4 J = D(f, 48 + i);
		vec4 K = D(f, 56 + i);
		ivec2 o = P - ivec2(J.xy);
		if (o.x >= 0 && o.y >= 0 && o.x < int(J.z) && o.y < int(J.w)) {
			vec4 jc = pal[int(K.x)];
			c = K.y > 0.5 && ((o.x + o.y) & 1) == 0 ? pal[0] : jc;
			have = true;
			break;
		}
	}
	// a roll leaves the top slice repeated at the bottom, every other pixel, darkened
	if (!have && roll < 0) {
		int my = P.y - (ay + h + roll);
		if (my >= 0 && my < -roll) {
			int mx = P.x - ax;
			vec4 cc = body(ivec2(mx, my));
			if (cc.a > 0.0 && ((mx + my) & 1) == 1) {
				c = vec4(mix(cc.rgb, pal[1].rgb, 0.5), 1.0);
				have = true;
			}
		}
	}
	int my = P.y - roll - ay;
	vec4 row = my >= 0 && my < h ? D(f, 2 + my) : vec4(0.0);
	int dx = int(row.x);
	// the body itself, row by row: torn, interlaced, rolled, posterised, tinted where the bar passes
	if (!have && my >= 0 && my < h && !(interlace && (my & 1) == 1)) {
		int mx = P.x - dx - ax;
		vec4 cc = body(ivec2(mx, my));
		if (cc.a > 0.0) {
			vec3 col = cc.rgb;
			int tint = int(row.y + 0.5);
			if (poster) {
				col = luma(cc.rgb) > 0.32 ? pal[5].rgb : pal[1].rgb;
			} else if (tint > 0) {
				col = mix(cc.rgb, tint == 1 ? pal[2].rgb : pal[4].rgb, 0.6);
			} else if (abs(float(ay + my) - bar) < 1.0) {
				col = mix(cc.rgb, pal[5].rgb, 0.35);
			}
			c = vec4(col, 1.0);
			have = true;
		} else if (row.z > 0.5) {
			// a torn row smears its edge pixel out sideways, fading
			int L = int(row.z + 0.5);
			bool right = dx > 0;
			int edge = -1;
			for (int x = 0; x < 64; x++) {
				if (x >= ts.x) {
					break;
				}
				int xx = right ? ts.x - 1 - x : x;
				if (body(ivec2(xx, my)).a > 0.0) {
					edge = xx;
					break;
				}
			}
			if (edge >= 0) {
				int i = right ? P.x - (ax + edge + dx) : (ax + edge + dx) - P.x;
				if (i >= 1 && i <= L) {
					float a = 1.0 - float(i) / float(L + 1);
					if (a >= pfx_threshold(FRAGCOORD.xy)) {
						c = vec4(body(ivec2(edge, my)).rgb, 1.0);
						have = true;
					}
				}
			}
		}
	}
	// the split: the red and cyan ghosts offset either side; the original draws both pixel by pixel across each row,
	// so where they overlap the one from further right in the body wins (red when split > 0)
	if (!have && split != 0 && my >= 0 && my < h) {
		bool cy = body(ivec2(P.x - dx - split - ax, my)).a > 0.0;
		bool rd = body(ivec2(P.x - dx + split - ax, my)).a > 0.0;
		if (rd && (!cy || split > 0)) {
			c = pal[2];
			have = true;
		} else if (cy) {
			c = pal[4];
			have = true;
		}
	}
	if (!have) {
		discard;
	}
	c.a = 1.0;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
