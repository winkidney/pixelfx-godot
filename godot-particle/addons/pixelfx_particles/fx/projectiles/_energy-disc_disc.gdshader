// The energy disc (projectiles/energy-disc.js): a white hub in a dark collar, spiral arms of energy churning, a
// bright rim; past the rim hooked teeth that run white on their leading faces and a dim blur ring where they've just
// been, and a pale ring over the rim. Centred on the rect; key t (0 -> 1 over the loop: three turns).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(32.0);
uniform float t = 0.0;
uniform float R = 9.0;
uniform float teeth = 8.0;
uniform vec4 cols[7];

void fragment() {
	vec2 p = floor(UV * size) + 0.5 - size * 0.5;
	float TAU_ = 6.28318530718;
	float rot = TAU_ * 3.0 * t;
	float sg = TAU_ / teeth;
	float r = length(p);
	float th = atan(p.y, p.x);
	vec4 c = vec4(0.0);
	if (r > R + 4.6) {
		discard;
	}
	if (r <= R) {
		if (r < 1.8) {
			c = cols[6];
		} else if (r < 2.9) {
			c = cols[1];
		} else if (r > R - 1.1) {
			c = cols[5];
		} else {
			float arm = sin(3.0 * (th - rot * 0.5) - r * 0.85);
			c = arm > 0.65 ? cols[5] : arm > 0.2 ? cols[4] : arm > -0.3 ? cols[3] : cols[2];
		}
	} else {
		float ph = fract((th - rot) / sg);
		float hh = 4.2 * pow(ph, 1.4);
		if (r - R < hh) {
			c = ph > 0.86 ? cols[6] : ph > 0.6 ? cols[6] : ph > 0.35 ? cols[5] : cols[4];
			if (ph > 0.86) {
				c = vec4(1.0);
			}
		} else if (r - R < 1.6) {
			c = cols[2];
		}
	}
	// the ring over the rim (p.ring(0, 0, R + 0.5, 1, C6))
	if (r <= R + 0.5 && r >= R - 0.5) {
		c = cols[6];
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
