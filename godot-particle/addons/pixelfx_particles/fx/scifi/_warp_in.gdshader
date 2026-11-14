// Warp in (src/fx/scifi/warp-in.js), from the effect's clock `t` (the original's own, keyed a frame at a time):
//   mode 0, behind the stand-in: the floor's far half (the pool of light, the ripples where rings land, the slam's
//           shockwaves, the snap's ring), the rings' far halves, the column (bands of the ramp across it, strands,
//           pulses scrolling down it, a glassy hollow opening in it, narrowing to a thread), the guide thread and
//           the target before it lands
//   mode 1, in front: the hero built out of light (the blueprint flickering first, then each row as the scanline
//           crosses it, white-hot and cooling through the beam's colour to its own, the newest rows jittering), the
//           scanline with a glint at each end of the body, the rings' near halves, the floor's near half, the set
//           body's outline flaring, the slam's star
// Colour layer (the column's hollow translucent).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_scifi.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_jsrand.gdshaderinc"

uniform vec2 size = vec2(192.0, 168.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform int mode = 0;
uniform int seed = 3;
uniform float W = 15.0;
uniform sampler2D tex : filter_nearest;
uniform vec4 pal[8] : source_color;
uniform float rings[12];
uniform int ring_count = 0;
uniform float strands[5];

#include "res://addons/pixelfx_particles/fx/scifi/_warp.gdshaderinc"

const float SLAM = 0.34;
const float OPEN = 0.52;
const float SCAN0 = 0.62;
const float SCAN1 = 1.4;
const float COOL = 0.42;
const float DONE = 1.82;
const float CLOSE = 1.9;
const float SNAP = 2.16;
const float TOP = -128.0;

float width_at(float tt) {
	if (tt < SLAM) {
		return 0.0;
	}
	if (tt < CLOSE) {
		return W * (1.0 + 0.45 * exp(-(tt - SLAM) * 14.0) + 0.03 * sin(tt * 31.0));
	}
	return mix(W, 0.7, e_out_cubic((tt - CLOSE) / (SNAP - CLOSE)));
}

float scan_y(float tt) {
	return mix(float(AY) - 2.0, 1.0, e_in_out_sine((tt - SCAN0) / (SCAN1 - SCAN0)));
}

float scan_t(float y) {
	return SCAN0 + ((SCAN1 - SCAN0) * acos(1.0 - 2.0 * clamp((y + 0.5 - (float(AY) - 2.0)) / (3.0 - float(AY)), 0.0, 1.0))) / PI;
}

bool row_of(int y, out int r0, out int r1) {
	r0 = 1000;
	r1 = -1000;
	if (y < AY || y >= AY + AH) {
		return false;
	}
	for (int i = 0; i < 64; i++) {
		if (i >= AW) {
			break;
		}
		if (on_body(ivec2(AX + i, y))) {
			r0 = min(r0, AX + i);
			r1 = max(r1, AX + i);
		}
	}
	return r1 >= r0;
}

// the floor: the far (side -1) or near (1) half
void floor_at(inout vec4 c, ivec2 P, bool near, float thr) {
	int side = near ? 1 : -1;
	if (!near) {
		float on = t < SLAM ? e_smooth(0.0, SLAM, t) * 0.5 : 1.0 - e_smooth(SNAP, SNAP + 0.5, t);
		if (on > 0.01 && P.y >= -4 && P.y <= 4) {
			float rx = W * 1.9 + (t < SLAM ? 0.0 : 2.0 * sin(t * 6.0));
			float x = float(P.x);
			if (x >= floor(-rx) && x <= ceil(rx)) {
				float d = length(vec2((x + 0.5) / rx, (float(P.y) + 0.5) / 4.0));
				if (d <= 1.0) {
					float a = on * clamp((1.05 - d) * 2.4, 0.0, 1.0);
					if (a >= thr && a > 0.0) {
						c = d < 0.35 ? pal[7] : d < 0.6 ? pal[6] : d < 0.85 ? pal[5] : pal[4];
					}
				}
			}
		}
	}
	for (int i = 0; i < 12; i++) {
		if (i >= ring_count) {
			break;
		}
		float k = (t - rings[i] - 0.5) / 0.35;
		if (k >= 0.0 && k < 1.0) {
			band_at(c, P, vec2(0.0), W * (1.2 + 1.3 * e_out_cubic(k)), 0.16, 1.5, 1.0 - k, pal[3], pal[4], pal[5], pal[6], side, false, thr);
		}
	}
	for (int i = 0; i < 2; i++) {
		float dd = i == 0 ? 0.0 : 0.08;
		float s = i == 0 ? 1.0 : 0.65;
		float k = (t - SLAM - dd) / 0.55;
		if (k >= 0.0 && k < 1.0) {
			band_at(c, P, vec2(0.0, 0.5), 92.0 * s * e_out_cubic(k), 0.16, max(1.0, 5.0 * (1.0 - k)), 1.15 - k, pal[3], pal[5], pal[6], vec4(1.0), side, k < 0.25, thr);
		}
	}
	float k = (t - SNAP) / 0.45;
	if (k >= 0.0 && k < 1.0) {
		band_at(c, P, vec2(0.0), 10.0 + 26.0 * e_out_cubic(k), 0.16, 2.0 * (1.0 - k) + 0.5, 1.1 - k, pal[4], pal[5], pal[6], vec4(1.0), side, k < 0.3, thr);
	}
}

// the rings riding down the beam: the far (side -1) or near (1) halves
void rings_at(inout vec4 c, ivec2 P, int side, float thr) {
	float w = width_at(t);
	for (int i = 0; i < 12; i++) {
		if (i >= ring_count) {
			break;
		}
		float k = (t - rings[i]) / 0.5;
		if (k < 0.0 || k >= 1.0) {
			continue;
		}
		float y = mix(TOP + 6.0, -1.0, e_in_quad(k));
		float rx = w * 1.18 + 1.0;
		vec4 rc = k < 0.25 ? vec4(1.0) : pal[6];
		band_at(c, P, vec2(0.0, y), rx, 2.6 / rx, 1.5, 1.0, pal[3], pal[5], rc, vec4(1.0), side, false, thr);
	}
}

vec4 column(ivec2 P, vec4 c, float thr) {
	float w = width_at(t);
	if (w <= 0.05 || t > SNAP + 0.14) {
		return c;
	}
	float bottom = t - SLAM < 0.06 ? mix(TOP, 0.0, e_in_cubic(clamp((t - SLAM) / 0.06, 0.0, 1.0) * 0.5 + 0.5)) : t > SNAP ? mix(0.0, TOP, e_out_expo((t - SNAP) / 0.14)) : 0.0;
	float y = float(P.y);
	if (y < floor(TOP) || y >= bottom) {
		return c;
	}
	bool hero = t - SLAM < 0.07;
	float hollow = 0.78 * e_smooth(OPEN - 0.16, OPEN, t);
	float thin = 1.0 - clamp((w - 1.5) / (W - 1.5), 0.0, 1.0);
	float pulse = mod((y - TOP) * 0.028 - t * 2.6, 1.0) < 0.09 ? 1.0 : 0.0;
	float x = float(P.x);
	if (x < floor(-w * 1.35) || x > ceil(w * 1.35)) {
		return c;
	}
	float q = abs(x + 0.5) / w;
	if (q > 1.35) {
		return c;
	}
	if (hero) {
		float a = q < 1.0 ? 1.0 : (1.35 - q) / 0.35;
		return a >= thr ? (q < 0.55 ? vec4(1.0) : q < 0.8 ? pal[6] : q < 1.0 ? pal[5] : pal[4]) : c;
	}
	if (w < 2.4) {
		float a = q < 1.0 ? 1.0 : (1.35 - q) / 0.35;
		return a >= thr ? (q < 0.7 ? vec4(1.0) : pal[6]) : c;
	}
	float strand = 0.0;
	for (int s = 0; s < 5; s++) {
		if (abs((x + 0.5) / w - (strands[s] - 0.5) * 1.3 - 0.06 * sin(t * (1.5 + float(s)) + float(s) * 2.0)) < 0.05) {
			strand = 1.0;
		}
	}
	if (q < hollow) {
		return blend_over(c, strand > 0.5 || pulse > 0.5 ? pal[6].rgb : pal[5].rgb, clamp(0.12 + 0.3 * q * q + 0.3 * strand + 0.25 * pulse + 0.7 * thin, 0.0, 1.0));
	}
	if (q < 0.78) {
		float lvl = max(0.0, (q < 0.22 ? 0.0 : q < 0.45 ? 1.0 : 2.0) - pulse - strand);
		return lvl < 0.5 ? vec4(1.0) : lvl < 1.5 ? pal[6] : pal[5];
	}
	if (q < 0.96) {
		return q > 0.86 && q < 0.93 ? vec4(1.0) : pal[6];
	}
	float a = (1.35 - q) / 0.39;
	return a >= thr ? (q < 1.1 ? pal[5] : pal[4]) : c;
}

vec4 back_layer(ivec2 P, float thr) {
	vec4 c = vec4(0.0);
	floor_at(c, P, false, thr);
	rings_at(c, P, -1, thr);
	c = column(P, c, thr);
	if (t < SLAM) {
		// the guide thread pricking down to the spot, brightening, and a target on the floor closing in
		float a = e_smooth(0.0, SLAM * 0.8, t) * 0.8;
		float head = mix(TOP, 0.0, e_out_cubic(t / (SLAM * 0.6)));
		float y = float(P.y);
		if (P.x == 0 && y >= TOP && y < head) {
			float al = a * (0.35 + 0.65 * ((y - TOP) / -TOP));
			if (al >= thr) {
				c = (P.y & 1) == 0 ? pal[6] : pal[5];
			}
		}
		float rx = mix(34.0, 12.0, e_out_cubic(t / SLAM));
		float k = e_smooth(0.0, 0.15, t);
		for (int i = 0; i < 48; i++) {
			if ((i / 4) % 2 == 1) {
				continue;
			}
			float g = float(i) / 48.0 * TAU + t * 3.0;
			if (all(equal(floor(vec2(cos(g) * rx, sin(g) * rx * 0.16)), vec2(P))) && k >= thr) {
				c = i % 4 == 0 ? vec4(1.0) : pal[5];
			}
		}
	}
	return c;
}

vec4 front_layer(ivec2 P, float thr) {
	vec4 c = vec4(0.0);
	// the hero, built out of light
	if (t < DONE && t >= SCAN0 - 0.2) {
		int blink = int(floor(t * 24.0));
		// the original draws the body pixel by pixel across each row: the one from further right wins a cell
		for (int dxi = 1; dxi >= -1; dxi--) {
			ivec2 b = P - ivec2(dxi, 0);
			if (!on_body(b)) {
				continue;
			}
			float a = t - scan_t(float(b.y));
			if (a < 0.0) {
				if (dxi == 0) {
					bool edge = !on_body(b + ivec2(1, 0)) || !on_body(b - ivec2(1, 0)) || !on_body(b + ivec2(0, 1)) || !on_body(b - ivec2(0, 1));
					if (edge && float(js_hash3(b.x, b.y, blink)) / 4294967296.0 < 0.6) {
						float al = 0.8 * e_smooth(SCAN0 - 0.25, SCAN0 - 0.05, t);
						if (al >= thr && al > 0.0) {
							c = pal[1];
						}
					}
				}
				continue;
			}
			float j = float(js_hash3(seed, b.x - AX, b.y - AY)) / 4294967296.0;
			int dx = a < 0.06 && j < 0.3 ? (j < 0.15 ? -1 : 1) : 0;
			if (dx != dxi) {
				continue;
			}
			float k = a / COOL;
			vec3 bc = body_px(b).rgb;
			c = k < 0.18 ? vec4(1.0) : k < 0.45 ? vec4(mix(bc, pal[6].rgb, 0.72), 1.0) : k < 0.75 ? vec4(mix(bc, pal[5].rgb, 0.38), 1.0) : vec4(bc, 1.0);
		}
	}
	// the scanline: a white rule across the beam, hottest where it crosses the body
	if (t > SCAN0 && t < SCAN1) {
		int y = int(floor(scan_y(t)));
		float w = width_at(t) * 1.5;
		int r0;
		int r1;
		bool has = row_of(y, r0, r1);
		if (P.y == y && float(P.x) >= floor(-w) && float(P.x) <= ceil(w)) {
			bool inside = has && P.x >= r0 && P.x <= r1;
			float al = inside ? 1.0 : 1.0 - abs(float(P.x) + 0.5) / (w + 1.0);
			if (al >= thr) {
				c = inside ? vec4(1.0) : pal[6];
			}
		}
		if (has) {
			sparkle_at(c, P, vec2(float(r0) + 0.5, float(y)), 2.0, pal[6], pal[5]);
			sparkle_at(c, P, vec2(float(r1) + 0.5, float(y)), 2.0, pal[6], pal[5]);
		}
	}
	rings_at(c, P, 1, thr);
	floor_at(c, P, true, thr);
	// the set body's outline flares as it lands
	if (t >= DONE && t < DONE + 0.3 && !on_body(P) && (on_body(P + ivec2(1, 0)) || on_body(P - ivec2(1, 0)) || on_body(P + ivec2(0, 1)) || on_body(P - ivec2(0, 1)))) {
		if (1.0 - (t - DONE) / 0.3 >= thr) {
			c = pal[6];
		}
	}
	if (t > SLAM && t < SLAM + 0.16) {
		sparkle_at(c, P, vec2(0.0, -2.0), 12.0 * (1.0 - (t - SLAM) / 0.16), pal[6], pal[5]);
	}
	return c;
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size + 0.001);
	ivec2 P = ivec2(cell);
	float thr = pfx_threshold(FRAGCOORD.xy);
	vec4 c = mode == 0 ? back_layer(P, thr) : front_layer(P, thr);
	if (c.a <= 0.0) {
		discard;
	}
	if (px_out(c, FRAGCOORD.xy, c.a < 0.999)) {
		discard;
	}
	COLOR = c;
}
