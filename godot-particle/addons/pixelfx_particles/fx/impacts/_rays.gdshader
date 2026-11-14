// hit-spark's cross flare (src/fx/impacts/hit-spark.js ray() and diamond()): rays fat at the root and a hair at the
// tip, a 1 px spine cooling outward (white, hi, mid, lo along it) with flanks in side_hi near the root and side_lo
// further out, round a crisp diamond with a pale rim. rays[i] = (angle, length, width, from: 0..1, where it starts).
// Key scale_len / scale_w / from / diamond / the colours on the original's frames.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec4 rays[8];
uniform float count = 0.0;
// only the first `count` rays; `first` > 0.5: only the first ray
uniform float first = 0.0;
uniform float scale_len = 1.0;
uniform float scale_w = 1.0;
uniform float w_fixed = 0.0;
uniform float from = 0.0;
uniform vec4 c_white : source_color = vec4(1.0);
uniform vec4 c_hi : source_color = vec4(1.0);
uniform vec4 c_mid : source_color = vec4(1.0);
uniform vec4 c_lo : source_color = vec4(1.0);
uniform vec4 side_hi : source_color = vec4(1.0);
uniform vec4 side_lo : source_color = vec4(1.0);
// the diamond's radius (< 0: none), its rim colour
uniform float diamond = 4.0;
uniform vec4 rim : source_color = vec4(1.0);

void fragment() {
	vec4 tint = COLOR;
	vec2 q = floor((UV - 0.5) * size) + 0.5;
	vec2 cell = q - 0.5;
	int n = first > 0.5 ? 1 : int(count + 0.5);
	vec4 c = vec4(0.0);
	for (int i = 0; i < 8; i++) {
		if (i >= n) {
			break;
		}
		vec4 r = rays[i];
		vec2 u = vec2(cos(r.x), sin(r.x));
		float L = r.y * scale_len;
		float w = w_fixed > 0.0 ? w_fixed : r.z * scale_w;
		float dd = dot(q, u);
		float oo = abs(dot(q, vec2(-u.y, u.x)));
		float line = 0.5 * max(abs(u.x), abs(u.y));
		if (dd < from * L - line || dd > L + line) {
			continue;
		}
		float d = clamp(dd, from * L, L);
		float f = d / L;
		float hw = w * pow(1.0 - f, 1.6);
		if (oo <= line) {
			c = f < 0.3 ? c_white : f < 0.62 ? c_hi : f < 0.88 ? c_mid : c_lo;
		} else if (hw > 0.45 && oo <= floor(hw * 2.0) * 0.5 + line) {
			c = (f < 0.3 && oo < 1.0 + line * 0.5) ? side_hi : side_lo;
		}
	}
	if (diamond >= 0.0) {
		float m = abs(cell.x) + abs(cell.y);
		if (m <= diamond + 0.1) {
			c = c_white;
		} else if (m <= diamond + 1.1) {
			c = rim;
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
