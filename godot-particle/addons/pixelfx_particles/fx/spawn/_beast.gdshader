// spawn/summon-rise's brute, as the original draws it: built part by part (`beast`: each pixel's frontmost part plus
// 16 on a crease over a part behind, its ambient light, how much it faces down, its rim toward the floor), heaving up
// out of the floor (`off`), shaded in its body and horn ramps and lit from the fire below (rims hot by the floor,
// broad planes only deep red), a dark edge all round, tusks catching the light, eye sockets smouldering until the
// eyes flare open (a white streak and a cross) and burn on; at the end it crumbles away from the top down (the
// original's hash). Colour layer; its warm mixes kept as they are.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_jsrand.gdshaderinc"

uniform vec2 size = vec2(52.0, 50.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D beast : filter_nearest;
uniform float off = 46.0;
uniform float k = 0.0;
uniform float fade = 0.0;
uniform float t = 0.0;
uniform float eyes_t = 2.3;
uniform float break_t = 1.05;
uniform float fade_t = 3.4;
uniform float rise_on = 0.0;
uniform vec2 eyes[4];
uniform vec2 tusks[4];
uniform vec2 glints[2];
uniform vec4 sh[5] : source_color;
uniform vec4 hr[5] : source_color;
uniform vec4 pal[8] : source_color;
uniform vec4 white : source_color = vec4(1.0);

ivec2 bsz() {
	return textureSize(beast, 0);
}

vec4 px(int x, int y) {
	ivec2 s = bsz();
	if (x < 0 || y < 0 || x >= s.x || y >= s.y) {
		return vec4(0.0);
	}
	return texelFetch(beast, ivec2(x, y), 0);
}

int part_at(int x, int y) {
	return int(mod(px(x, y).r + 0.5, 16.0));
}

bool gone(int x, int y) {
	float H = float(bsz().y);
	return fade > 0.0 && fade > 0.06 + 0.86 * (0.55 * (1.0 - float(y) / H) + 0.45 * js_rand3(x, y, 3));
}

vec3 mix8(vec3 a, vec3 b, float q) {
	vec3 a8 = floor(a * 255.0 + 0.5);
	vec3 b8 = floor(b * 255.0 + 0.5);
	return floor(a8 + (b8 - a8) * q) / 255.0;
}

// a horizontal 1 px line from x0 to x1 at row y: -1 off it, else u along it
float hline(vec2 cell, float x0, float x1, float y) {
	float a = floor(x0);
	float b = floor(x1);
	if (cell.y != floor(y) || cell.x < a || cell.x > b) {
		return -1.0;
	}
	return b > a ? (cell.x - a) / (b - a) : 0.0;
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	ivec2 bs = bsz();
	int W = bs.x;
	int H = bs.y;
	float x0 = -float(W) / 2.0;
	float oy = off - float(H);
	vec4 o = vec4(0.0);
	if (rise_on > 0.5) {
		int x = int(cell.x - x0);
		// the rows land on floor(y + oy): which row of the brute is this cell
		int y = int(ceil(cell.y - oy - 1e-5));
		if (floor(float(y) + oy) != cell.y) {
			y -= 1;
		}
		if (float(y) + oy < 0.0 && floor(float(y) + oy) == cell.y) {
			int pt = part_at(x, y);
			if (pt == 0) {
				bool edge = part_at(x - 1, y) > 0 || part_at(x + 1, y) > 0 || part_at(x, y - 1) > 0 || part_at(x, y + 1) > 0;
				if (edge && x >= -1 && x <= W && y >= -1 && y <= H && !gone(x, clamp(y, 0, H - 1))) {
					o = sh[0];
				}
			} else if (!gone(x, y)) {
				vec4 b = px(x, y);
				bool crease = b.r > 15.5;
				float ly = float(y) + oy;
				float up_rim = exp(ly / 17.0) * k;
				float up_plane = exp(ly / 19.0) * k;
				float a = b.g;
				int si = crease ? 0 : a > 0.74 ? 4 : a > 0.56 ? 3 : a > 0.36 ? 2 : 1;
				if (pt == 2 && si > 0) {
					si = min(4, si + (y < 3 ? 2 : 1));
				}
				vec3 rc = pt == 2 ? hr[si].rgb : sh[si].rgb;
				float Lr = b.a * up_rim;
				float Lp = b.b * up_plane * 0.6;
				vec3 c = rc;
				if (Lr > 0.7) {
					c = pal[5].rgb;
				} else if (Lr > 0.48) {
					c = pal[4].rgb;
				} else if (Lr > 0.3 || Lp > 0.42) {
					c = pal[3].rgb;
				} else if (Lr > 0.17 || Lp > 0.26) {
					c = mix8(pal[2].rgb, rc, 0.3);
				} else if (Lr > 0.08 || Lp > 0.12) {
					c = mix8(rc, pal[1].rgb, 0.6);
				}
				o = vec4(c, 1.0);
			}
			for (int i = 0; i < 4; i++) {
				ivec2 q = ivec2(tusks[i]);
				if (q.x == x && q.y == y && !gone(x, y)) {
					o = vec4(mix8(hr[4].rgb, pal[4].rgb, 0.35 * k), 1.0);
				}
			}
			for (int i = 0; i < 4; i++) {
				ivec2 q = ivec2(eyes[i]);
				if (q.x == x && q.y == y && !gone(x, y)) {
					o = t > eyes_t - 0.05 ? (t < eyes_t + 0.1 ? white : pal[6]) : t > break_t + 0.5 ? pal[2] : sh[0];
				}
			}
		}
		// the eyes: a flare as they open, then a steady burn that outlasts the body
		if (t > eyes_t - 0.05) {
			float k2 = (1.0 - smoothstep(fade_t + 0.6, fade_t + 1.0, t)) * (0.85 + 0.15 * sin(t * 13.0));
			for (int i = 0; i < 2; i++) {
				float ex = glints[i].x;
				float ey = glints[i].y + off;
				if (ey >= 0.0) {
					continue;
				}
				float g = (t - eyes_t) / 0.3;
				if (g > 0.0 && g < 1.0) {
					float L = 9.0 * pow(1.0 - g, 1.5);
					float u = hline(cell, ex - L, ex + L, ey);
					if (u >= 0.0) {
						o = abs(u - 0.5) < 0.18 ? white : abs(u - 0.5) < 0.35 ? pal[6] : pal[5];
					}
					if (g < 0.4 && cell.x == floor(ex) && cell.y >= floor(ey - 2.0 * (1.0 - g)) && cell.y <= floor(ey + 2.0 * (1.0 - g))) {
						o = pal[6];
					}
				} else if (fade > 0.6 && k2 > 0.05 && all(equal(cell, floor(vec2(ex, ey))))) {
					o = pal[6];
				}
			}
		}
	}
	if (o.a < 0.5) {
		discard;
	}
	COLOR = vec4(o.rgb, 1.0);
}
