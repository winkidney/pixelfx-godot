// The cracks the smite splits in the floor (holy/smite, colour layer): `data` holds, per pixel, how far out along
// its crack it is (r * 2), how long that crack takes to cool (g: cool - 1.5), where it is along its path (b: grown when
// b < grow) and its kind (a: 1 the crack, 0.5 its deeper lower edge near the heart). They grow out, white-hot, and
// cool down the gold ramp, each at its own pace; the crater at the heart cools too. Key t (seconds since the hit).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec2 lo = vec2(0.0);
uniform sampler2D data : filter_nearest;
uniform float t = -1.0;
uniform float grow = 0.0;
uniform vec4 pal[8] : source_color;

vec4 heat_col(float h) {
	return h > 0.85 ? vec4(1.0) : h > 0.65 ? pal[6] : h > 0.45 ? pal[5] : h > 0.3 ? pal[4] : h > 0.18 ? pal[3] : pal[2];
}

void fragment() {
	if (t < 0.0) {
		discard;
	}
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 cell = floor(p);
	vec4 c = vec4(0.0);
	ivec2 q = ivec2(cell - lo);
	ivec2 ts = textureSize(data, 0);
	if (q.x >= 0 && q.y >= 0 && q.x < ts.x && q.y < ts.y) {
		vec4 d = texelFetch(data, q, 0);
		if (d.a > 0.25 && d.b <= grow) {
			float h = clamp(1.0 - t / (d.g + 1.5) - d.r * 2.0 * 0.5, 0.0, 1.0);
			if (h > 0.0) {
				c = d.a > 0.75 ? heat_col(h) : (h > 0.5 ? pal[4] : pal[2]);
				c.a = h < 0.12 ? h / 0.12 : 1.0;
			}
		}
	}
	// the crater: a 1 px oval at the heart, white, then gold, then amber, fading
	float hh = clamp(1.0 - t / 1.6, 0.0, 1.0);
	if (hh > 0.0) {
		int n = int(ceil(5.0 * TAU * 1.5)) + 6;
		for (int j = 0; j < 64; j++) {
			if (j >= n) {
				break;
			}
			float g = float(j) / float(n) * TAU;
			if (floor(vec2(cos(g) * 5.0, sin(g) * 1.6)) == cell) {
				float a = min(1.0, hh * 3.0);
				if (a >= 1.0 || a > pfx_threshold(FRAGCOORD.xy)) {
					c = hh > 0.6 ? vec4(1.0) : hh > 0.3 ? pal[5] : pal[3];
				}
			}
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
