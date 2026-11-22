// The black hole, light layer (see _black-hole.gdshaderinc): the photon ring's light and the sparkle on every other
// cell of the disk's hottest steps.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/shadow/_black-hole.gdshaderinc"

uniform vec4 pal[10] : source_color;
uniform float strength = 1.0;

float bayer(vec2 fc) {
	const float B[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);
	ivec2 q = ivec2(fc) % 4;
	return (B[q.y * 4 + q.x] + 0.5) / 16.0;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center + 0.001) + 0.5;
	vec2 s;
	float rf;
	bool unlit;
	int kind = bh_hole(p, s, rf, unlit);
	vec3 sum = vec3(0.0);
	if (kind == 2) {
		sum = (rf > 0.55 ? pal[8] : pal[7]).rgb * 0.3;
	} else if (kind == 3 && mod(floor(p.x) + floor(p.y), 2.0) < 0.5) {
		float I = s.x * 1.3 * (1.0 + 0.55 * s.y) * (1.0 + 0.25 * bh_pulse());
		float f = clamp(I, 0.0, 1.0) * 7.0;
		float i = floor(f);
		if (f - i > bayer(FRAGCOORD.xy)) {
			i = min(7.0, i + 1.0);
		}
		if (i >= 4.0) {
			vec4 c = pal[int(i) + 1];
			if (s.y > 0.35 && i >= 5.0) {
				c = mix(c, pal[9], min(1.0, (s.y - 0.35) * 2.0));
			}
			sum = c.rgb * 0.3 * clamp(I - 0.35, 0.0, 1.0);
		}
	}
	COLOR = vec4(sum * strength, 1.0);
}
