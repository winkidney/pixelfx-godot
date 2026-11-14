// Leaf storm's wind: 1 px streaks running round tilted rings (the far halves behind the character, the near halves in
// front), bright at the head and fading down a tail, and scuffs swept round the floor. Each band is the original's:
// a ring of radius r at height y0 squashed to `squash`, its head turning `turns` times a loop, an arc `span` radians
// behind it, rising `rise` px per radian. Rasterised as the original's dense dots are: a pixel is lit where the curve
// crosses it. Key `t` 0 -> 1 over the loop. Colour layer, translucent (the tails blend).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

const int NB = 22;
uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
// 1: the near halves (in front), -1: the far halves (behind)
uniform float side = 1.0;
// per band: y0, radius, head at t = 0 (radians), span (radians)
uniform vec4 band_a[NB];
// per band: turns per loop, rise, squash, kind (0 wind, 1 floor scuff)
uniform vec4 band_b[NB];
uniform float count = 0.0;
uniform vec4 c2 : source_color;
uniform vec4 c3 : source_color;
uniform vec4 c4 : source_color;
uniform vec4 c5 : source_color;


float curve_y(float th, float head, vec4 a, vec4 b) {
	float s = mod(head - th, TAU);
	return a.x + sin(th) * a.y * b.z - s * b.y * 4.0;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 cell = floor(p);
	vec4 acc = vec4(0.0);
	float br = side > 0.0 ? 1.0 : -1.0;
	for (int j = 0; j < NB; j++) {
		if (float(j) >= count) {
			break;
		}
		vec4 a = band_a[j];
		vec4 b = band_b[j];
		float r = a.y;
		if (abs(p.y - a.x) > r * b.z + a.w * abs(b.y) * 4.0 + 2.0) {
			continue;
		}
		float c0 = cell.x / r;
		float c1 = (cell.x + 1.0) / r;
		if (c1 < -1.0 || c0 > 1.0) {
			continue;
		}
		c0 = clamp(c0, -1.0, 1.0);
		c1 = clamp(c1, -1.0, 1.0);
		float head = a.z + TAU * b.x * t;
		float tha = br * acos(c0);
		float thb = br * acos(c1);
		float ya = curve_y(tha, head, a, b);
		float yb = curve_y(thb, head, a, b);
		float lo = min(ya, yb);
		float hi = max(ya, yb);
		if (c0 < 0.0 && c1 > 0.0) {
			float ym = curve_y(br * 1.5707963, head, a, b);
			lo = min(lo, ym);
			hi = max(hi, ym);
		}
		if (hi < cell.y || lo >= cell.y + 1.0) {
			continue;
		}
		float th = br * acos(clamp((cell.x + 0.5) / r, -1.0, 1.0));
		float s = mod(head - th, TAU);
		if (s > a.w) {
			continue;
		}
		float k = s / a.w;
		vec4 c;
		float al;
		if (b.w > 0.5) {
			// a scuff on the floor: dithered out along its tail
			c = k < 0.4 ? c3 : c2;
			if (1.0 - k < pfx_threshold(FRAGCOORD.xy)) {
				continue;
			}
			al = 1.0;
		} else {
			if (side > 0.0) {
				c = k < 0.06 ? vec4(1.0) : k < 0.15 ? c5 : k < 0.4 ? c4 : c3;
			} else {
				c = k < 0.3 ? c3 : c2;
			}
			al = k < 0.45 ? 1.0 : clamp(1.6 * (1.0 - k), 0.0, 1.0);
		}
		// over what's there
		float na = al + acc.a * (1.0 - al);
		acc.rgb = (c.rgb * al + acc.rgb * acc.a * (1.0 - al)) / max(na, 1e-4);
		acc.a = na;
	}
	if (acc.a <= 0.0) {
		discard;
	}
	vec4 col = acc;
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
