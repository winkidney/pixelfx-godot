// A waterfall (water/waterfall): a river slides out of a notch, rolls over a white curl and falls h px as a sheet of 1
// px lanes (dark see-through lanes between lit ones, white dashes sliding down them and stretching as the water speeds
// up, the lower third splitting into fanning strands) into a churning foot of foam over a dark pool with caustics, a
// lit far shore and the falls mirrored in the chop. All the original's noise, exactly. Key `t` 0 -> 1 over the loop.
//   mode 0: the pool's water (soft, behind)      mode 1: its far-shore glints and the reflection (behind)
//   mode 2: the sheet's see-through lanes (soft)  mode 3: the river, the sheet's lit lanes and the curl
//   mode 4: the churning foot
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float H = 92.0;
uniform float W = 13.0;
uniform float seed = 5.0;
uniform vec2 pool_r = vec2(56.0, 11.0);
uniform float mode = 3.0;

const float F_TAU = 6.28318530718;

float half_w(float d) {
	return W + 3.2 * pow(clamp(d / H, 0.0, 1.0), 1.6);
}

// the sheet at pixel cell (X, y): 0 nothing, 1 a see-through lane (colour, alpha), 2 a lit lane (colour)
int sheet(float X, float y, out vec4 c) {
	c = vec4(0.0);
	int S = int(seed);
	float ph = t;
	if (y < -H + 2.0 || y > -1.0 || abs(X + 0.5) > W + 8.5) {
		return 0;
	}
	float x = X + 0.5;
	float d = y + 0.5 + H;
	float v = d / H;
	float s = sqrt(d + 3.0);
	float split = smoothstep(0.56, 0.95, v);
	float glass = 1.0 - smoothstep(4.0, 24.0, d);
	float wob = js_tile(x < 0.0 ? 2.0 : 11.0, s * 1.4 - ph * 12.0, 0.0, 12.0, S + 2) * (0.4 + 1.8 * v);
	float hw = half_w(d) + wob;
	float ax = abs(x);
	if (ax > hw) {
		return 0;
	}
	float e = ax / hw;
	bool edge = false;
	if (split > 0.0) {
		float fan = js_tile(3.0, s * 0.8 - ph * 4.0, 0.0, 4.0, S + 61) * 1.6;
		float f = fract((x / (1.0 + 0.22 * split) + fan + 64.0) / 5.4);
		if (f > 1.0 - 0.46 * split) {
			return 0;
		}
		edge = f < 0.2;
	}
	float dash = js_tile(X * 1.618 + 0.31, s * 1.5 - ph * 20.0, 0.0, 20.0, S);
	if (js_rand2(int(X), S + 60) < 0.48 && e < 0.86 && !edge) {
		c = vec4((dash > 0.45 ? pal[4] : glass > 0.5 ? pal[3] : pal[2]).rgb, dash > 0.45 ? 0.7 : 0.42 + 0.15 * v);
		return 1;
	}
	float broad = js_tile(floor((x + 40.0) / 3.0) * 2.7, s * 0.45 - ph * 6.0, 0.0, 6.0, S + 1);
	float b = -0.34 + 0.46 * v + 0.3 * broad - glass * 0.5 + 0.35 * smoothstep(0.7, 1.0, e) * (x < 0.0 ? 1.0 : 0.3)
		- (x > 0.0 ? 0.12 * e : 0.0) + (edge ? 0.3 : 0.0);
	if (dash > 0.2 - 0.22 * v) {
		b += 0.36 + 0.7 * (dash - 0.2);
	}
	if (b > -0.2) {
		c = b > 0.62 ? pal[7] : b > 0.34 ? pal[6] : b > 0.08 ? pal[5] : pal[4];
		return 2;
	}
	c = vec4(pal[3].rgb, 0.8);
	return 1;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 P = floor(p);
	int S = int(seed);
	float ph = t;
	float T = ph * F_TAU;
	vec4 c = vec4(0.0);
	if (mode < 0.5) {
		vec2 q = (p - vec2(0.0, 2.0)) / pool_r;
		float d = dot(q, q);
		if (d > 1.0) {
			discard;
		}
		c = vec4((d < 0.12 ? pal[2] : pal[1]).rgb, 0.62 * min(1.0, (1.0 - d) * 4.0) + (pfx_threshold(FRAGCOORD.xy) - 0.5) / 8.0);
	} else if (mode < 1.5) {
		for (int i = 0; i < 7; i++) {
			float a = 3.14159265 * (1.12 + 0.76 * ((float(i) + 0.5) / 7.0));
			vec2 g = vec2(cos(a) * pool_r.x * 0.96, 2.0 + sin(a) * pool_r.y * 0.96);
			float k = sin(ph * F_TAU * 2.0 + float(i) * 2.4);
			if (k > 0.2 && all(equal(floor(g), P))) {
				c = k > 0.8 ? pal[6] : pal[4];
			}
		}
		if (p.y >= 3.0 && p.y <= 10.0 && abs(p.x) <= W + 3.0) {
			float n = js_tile(p.x * 0.9, (p.y - 3.0) * 0.35 + ph * 6.0, 0.0, 6.0, S + 6);
			float k = 1.0 - (p.y - 3.0) / 7.0;
			if (abs(p.x) <= W + 2.0 - (p.y - 3.0) * 0.4 && n >= 0.25 + (1.0 - k) * 0.4) {
				c = (n > 0.6 && k > 0.6) ? pal[6] : pal[5];
			}
		}
	} else if (mode < 2.5) {
		vec4 cc;
		if (sheet(P.x, P.y, cc) == 1) {
			c = cc;
		}
	} else if (mode < 3.5) {
		// the river sliding out of the notch
		float top = -H - 6.0;
		if (p.y >= top && p.y <= -H && abs(p.x) <= W + 3.0) {
			float back = top + 1.5 + js_tile(p.x * 0.3, 4.0, 0.0, 0.0, S + 62) * 1.5;
			float v = (p.y - back) / (-H - back);
			float hw = W + 2.0 - (1.0 - v) * 3.0;
			if (p.y >= back && abs(p.x) <= hw) {
				float n = js_tile(p.x * 0.32, (p.y - top) * 0.7 - ph * 8.0, 0.0, 8.0, S + 3);
				c = n > 0.66 ? pal[6] : n > 0.4 ? pal[5] : v < 0.5 ? pal[3] : pal[4];
			}
		}
		// trickles down the wet faces either side of the notch
		if ((P.x == -W - 3.0 || P.x == W + 3.0) && P.y >= -H - 2.0 && P.y < -H + 7.0) {
			c = fract(P.y * 0.35 - ph * 6.0) < 0.3 ? pal[6] : pal[3];
		}
		vec4 cc;
		if (sheet(P.x, P.y, cc) == 2) {
			c = cc;
		}
		// the curl over the edge
		if (P.x >= -W && P.x <= W) {
			if (P.y == -H - 1.0) {
				c = pal[4];
			} else if (P.y == -H) {
				c = pal[7];
			} else if (P.y == -H + 1.0) {
				c = js_tile(P.x * 0.45, ph * 4.0, 0.0, 4.0, S + 4) > 0.2 ? pal[6] : pal[5];
			}
		}
	} else {
		float R = W + 10.0;
		if (p.y >= -13.0 && p.y <= 3.0 && abs(p.x) <= R) {
			float ax = abs(p.x);
			float lump = js_tile(p.x * 0.22, ph * 6.0, 0.0, 6.0, S + 7) * 3.0 + js_tile(p.x * 0.55 + 9.0, ph * 12.0, 0.0, 12.0, S + 8) * 1.5;
			float top = -8.0 + lump + pow(ax / R, 2.0) * 7.0;
			if (ax <= R - max(0.0, -p.y - 1.0) * 0.6 && p.y >= top) {
				float n = js_tile(p.x * 0.5, (p.y - top) * 0.5 - ph * 10.0, 0.0, 10.0, S + 9);
				float boil = js_tile(p.x * 0.42 + 3.0, p.y * 0.42 - ph * 8.0, 0.0, 8.0, S + 12);
				float u = p.y - top;
				if (p.y > 1.0) {
					c = n > 0.0 ? pal[5] : pal[4];
				} else if (u < 1.2) {
					c = pal[7];
				} else if (boil < -0.3) {
					c = u > 4.0 ? pal[4] : pal[5];
				} else if (boil < -0.05) {
					c = pal[6];
				} else {
					c = n > -0.2 ? pal[7] : pal[6];
				}
			}
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
