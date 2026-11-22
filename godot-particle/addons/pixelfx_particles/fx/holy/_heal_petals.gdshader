// The heal's lotus of light (holy/heal, soft layer): eight petals, each with a lit rim, a white vein, a translucent
// warm body and a white tip; `back` draws the ones on the far side of the ring (behind the character).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/holy/_heal_petal.gdshaderinc"

uniform vec2 size = vec2(64.0, 32.0);
uniform vec2 center = vec2(0.0);
uniform bool back = false;
uniform vec4 pal[8] : source_color;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec4 c = vec4(0.0);
	for (int k = 0; k < NP; k++) {
		float b;
		bool near;
		vec4 q = petal_at(k, b, near);
		if (near == back || b <= 0.02) {
			continue;
		}
		vec2 ax = q.zw - q.xy;
		float L = length(ax);
		if (L < 1.5) {
			continue;
		}
		ax /= L;
		float g = pa[k] + t * 0.4;
		float W = pw[k] * min(1.0, b) * (0.35 + 0.65 * abs(sin(g)));
		vec2 d = p - q.xy;
		float u = dot(d, ax) / L;
		if (u < 0.0 || u > 1.0) {
			continue;
		}
		float hw = W * pow(sin(PI * pow(u, 0.6)), 0.7) + 0.2;
		float v = abs(-d.x * ax.y + d.y * ax.x) / hw;
		if (v > 1.0) {
			continue;
		}
		if (u > 0.9) {
			c = vec4(1.0);
		} else if (v > 0.7) {
			c = u < 0.3 ? pal[3] : u < 0.7 ? pal[5] : pal[6];
		} else if (v < 0.2 && u > 0.15 && u < 0.85) {
			if ((back ? 0.75 : 0.85) >= pfx_threshold(FRAGCOORD.xy)) {
				c = u < 0.55 ? pal[5] : pal[6];
			}
		} else {
			vec4 s = vec4((u < 0.45 ? pal[3] : pal[4]).rgb, back ? 0.6 : 0.45);
			float oa = s.a + c.a * (1.0 - s.a);
			c = vec4((s.rgb * s.a + c.rgb * c.a * (1.0 - s.a)) / oa, oa);
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
