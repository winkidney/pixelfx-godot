// spawn/coin-drop's coins, as the original draws them (drawCoin): a coin turning in the air (its face squashed toward
// the edge, the rim showing side-on, a glint as it faces us), lying flat on the floor with a glint running over it now
// and then, and winking out with a last star and a ring. Colour layer, on whole cells of the effect's coordinates.
//   rows: 0 (x, y, on, mode: 1 spinning, 2 flat, 3 winking out), 1 (spinning: cos(phase), glint; flat: glint arm;
//   winking: star arm, ring radius, ring alpha)
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_track.gdshaderinc"

uniform vec4 pal[8] : source_color;
uniform vec4 white : source_color = vec4(1.0);

// the original's COIN (8 x 8) and FLAT (7 x 3) sprites as palette steps (-1: empty)
const int COIN[64] = int[](
	-1, -1, 1, 1, 1, 1, -1, -1,
	-1, 1, 6, 6, 5, 4, 1, -1,
	1, 6, 5, 4, 4, 4, 3, 1,
	1, 6, 4, 3, 6, 4, 3, 1,
	1, 5, 4, 3, 6, 4, 3, 1,
	1, 5, 4, 4, 4, 4, 3, 1,
	-1, 1, 3, 3, 3, 3, 1, -1,
	-1, -1, 1, 1, 1, 1, -1, -1);
const int FLAT[21] = int[](
	-1, 5, 6, 6, 6, 5, -1,
	1, 5, 4, 4, 4, 3, 1,
	-1, 1, 3, 3, 3, 1, -1);

// the original's sparkle() at cell s: arms n, c then tip past 0.6 of the way, diagonals at 3 and 6, a white heart
vec4 sparkle(vec2 a, vec2 s, float n, vec4 c, vec4 tip) {
	if (n < 1.0) {
		return vec4(0.0);
	}
	vec2 d = a - s;
	vec2 ad = abs(d);
	if (ad.x < 0.5 && ad.y < 0.5) {
		return white;
	}
	if ((ad.x < 0.5 || ad.y < 0.5) && max(ad.x, ad.y) <= n + 0.1) {
		return max(ad.x, ad.y) > n * 0.6 ? tip : c;
	}
	if (n >= 3.0 && ad.x > 0.5 && ad.x < 1.5 && ad.y > 0.5 && ad.y < 1.5) {
		return c;
	}
	if (n >= 6.0 && ad.x > 1.5 && ad.x < 2.5 && ad.y > 1.5 && ad.y < 2.5) {
		return tip;
	}
	return vec4(0.0);
}

void vertex() {
	tk_cu = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 r0 = tk_row(0);
	vec4 r1 = tk_row(1);
	vec2 p = tk_pos();
	vec2 a = tk_abs(UV);
	int mode = int(r0.w + 0.5);
	vec4 c = vec4(0.0);
	if (mode == 1) {
		float cs = r1.x;
		float sx = abs(cs);
		if (sx < 0.28) {
			float dy = a.y - floor(p.y);
			if (a.x == floor(p.x) && abs(dy) < 3.5) {
				c = abs(dy) > 2.5 ? pal[1] : dy < 0.0 ? pal[6] : pal[5];
			} else if (sx > 0.12 && a.x == floor(p.x + (cs > 0.0 ? 1.0 : -1.0)) && abs(dy) < 2.5) {
				c = pal[3];
			}
		} else {
			float half_w = 4.0 * sx;
			if (a.x >= floor(p.x - half_w) && a.x < ceil(p.x + half_w)) {
				int col = int(floor((a.x + 0.5 - p.x) / sx + 4.0));
				int row = int(a.y - floor(p.y - 3.5));
				if (col >= 0 && col <= 7 && row >= 0 && row <= 7) {
					if (cs < 0.0) {
						col = 7 - col;
					}
					int k = COIN[row * 8 + col];
					if (k >= 0) {
						c = pal[k];
					}
				}
			}
		}
		if (r1.y > 0.5 && all(equal(a, floor(p - vec2(1.0, 2.0))))) {
			c = white;
		}
	} else if (mode == 2) {
		vec2 f = a - vec2(floor(p.x + 0.5) - 3.0, -3.0);
		if (f.x >= 0.0 && f.x <= 6.0 && f.y >= 0.0 && f.y <= 2.0) {
			int k = FLAT[int(f.y) * 7 + int(f.x)];
			if (k >= 0) {
				c = pal[k];
			}
		}
		vec4 s = sparkle(a, floor(vec2(p.x - 1.0, -3.0)), r1.x, white, pal[5]);
		if (s.a > 0.0) {
			c = s;
		}
	} else if (mode == 3) {
		c = sparkle(a, floor(vec2(p.x, -2.0)), r1.x, white, pal[5]);
		vec2 d = a + 0.5 - vec2(p.x, -3.0);
		float dd = length(d);
		if (dd <= r1.y && dd >= r1.y - 1.0) {
			c = vec4(pal[6].rgb, r1.z);
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
