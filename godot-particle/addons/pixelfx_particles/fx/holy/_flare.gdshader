// An 8-ray flare (the originals' flare()): long rays on the axes, shorter between, white at the heart cooling to
// c6 then c5 along them, their outer part dithering out with `k`. Draw it on a rect centred on its heart (the
// heart is the pixel just right of and below the rect's middle); key `reach` and `k`.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(96.0);
uniform float reach = 0.0;
uniform float k = 1.0;
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);

void fragment() {
	vec2 q = floor((UV - 0.5) * size);
	if (reach < 1.0) {
		discard;
	}
	float best = -1.0;
	for (int i = 0; i < 8; i++) {
		float an = float(i) * PI / 4.0;
		vec2 d = vec2(cos(an), sin(an));
		float len = i % 4 == 0 ? reach : (i % 2 == 0 ? reach * 0.6 : reach * 0.3);
		float along = dot(q, d);
		float perp = abs(q.x * d.y - q.y * d.x);
		if (along >= -0.25 && along <= len + 0.25 && perp < 0.55) {
			float u = clamp(along / len, 0.0, 1.0);
			if (best < 0.0 || u < best) {
				best = u;
			}
		}
	}
	if (best < 0.0) {
		discard;
	}
	vec4 c = best < 0.35 ? vec4(1.0) : best < 0.7 ? c6 : c5;
	c.a = best < 0.6 ? 1.0 : k * 1.5 * (1.0 - best) + 0.2;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
