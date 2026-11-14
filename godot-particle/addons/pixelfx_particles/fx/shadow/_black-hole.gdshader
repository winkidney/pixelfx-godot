// The black hole, colour layer (see _black-hole.gdshaderinc): the disk in the original's dithered ramp steps (the
// side turning toward us brighter and icier, the receding side duller), the shadow and the photon ring. mode 1 draws
// only the shadow's unlit part, on a node above the light layer (the original's unlight()).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/shadow/_black-hole.gdshaderinc"

uniform float mode = 0.0;
// C[0] .. C[7] then white, ice
uniform vec4 pal[10] : source_color;

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center + 0.001) + 0.5;
	vec2 s;
	float rf;
	bool unlit;
	int kind = bh_hole(p, s, rf, unlit);
	if (kind == 0 || (mode > 0.5 && !unlit)) {
		discard;
	}
	vec4 c;
	if (kind == 1) {
		c = pal[0];
	} else if (kind == 2) {
		c = rf > 0.55 ? pal[8] : pal[7];
	} else {
		// RAMP = C1..C7, white (n = 8)
		float I = s.x * 1.3 * (1.0 + 0.55 * s.y) * (1.0 + 0.25 * bh_pulse());
		float f = clamp(I, 0.0, 1.0) * 7.0;
		float i = floor(f);
		if (f - i > pfx_threshold(FRAGCOORD.xy)) {
			i = min(7.0, i + 1.0);
		}
		if (i < 0.5 && I < 0.12) {
			discard;
		}
		c = pal[int(i) + 1];
		if (s.y > 0.35 && i >= 5.0) {
			c = mix(c, pal[9], min(1.0, (s.y - 0.35) * 2.0));
		}
		if (s.y < -0.4 && i >= 2.0 && i < 6.0) {
			c = mix(c, pal[3], 0.35);
		}
	}
	c.a = 1.0;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
